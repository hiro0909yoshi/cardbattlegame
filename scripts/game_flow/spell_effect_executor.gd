extends RefCounted
class_name SpellEffectExecutor

## スペル効果の実行を担当
## spell_phase_handler.gd から効果実行ロジックを分離

var spell_phase_handler = null  # 親への参照

func _init(handler):
	spell_phase_handler = handler

## スペル効果を実行
func execute_spell_effect(spell_card: Dictionary, target_data: Dictionary):
	var handler = spell_phase_handler
	handler.current_state = handler.State.EXECUTING_EFFECT
	
	# 復帰[ブック]フラグをリセット
	handler.spell_failed = false
	
	# 発動通知を表示（クリック待ち）
	var caster_name = "プレイヤー%d" % (handler.current_player_id + 1)
	if handler.player_system and handler.current_player_id >= 0 and handler.current_player_id < handler.player_system.players.size():
		caster_name = handler.player_system.players[handler.current_player_id].name
	await handler._show_spell_cast_notification(caster_name, target_data, spell_card, false)
	
	# スペル効果を実行
	var parsed = spell_card.get("effect_parsed", {})
	var effects = parsed.get("effects", [])
	
	# 復帰[ブック]判定（常にデッキに戻す場合）
	var return_to_deck = parsed.get("return_to_deck", false)
	if return_to_deck:
		if handler.game_flow_manager and handler.game_flow_manager.spell_land:
			if handler.game_flow_manager.spell_land.return_spell_to_deck(handler.current_player_id, spell_card):
				handler.spell_failed = true
	
	# 復帰[手札]判定（スペルカードを手札に戻す - ゴブリンズレア等）
	var return_to_hand = parsed.get("return_to_hand", false)
	if return_to_hand:
		handler.spell_failed = true
	
	# 効果を適用
	for effect in effects:
		await apply_single_effect(effect, target_data)
	
	# カードを捨て札に（復帰[ブック]/復帰[手札]時はスキップ）
	if handler.card_system and not handler.spell_failed:
		var hand = handler.card_system.get_all_cards_for_player(handler.current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == spell_card.get("id", -2):
				handler.card_system.discard_card(handler.current_player_id, i, "use")
				break
	elif handler.spell_failed and return_to_hand:
		print("[復帰[手札]] %s は手札に残ります" % spell_card.get("name", "?"))
	
	# 効果発動完了
	handler.spell_used.emit(spell_card)
	
	# カード選択中の場合は完了後に処理
	if handler.card_selection_handler and handler.card_selection_handler.is_selecting():
		return
	
	# 少し待機してからカメラを戻す
	await handler.get_tree().create_timer(0.5).timeout
	handler._return_camera_to_player()
	
	# さらに待機してからスペルフェーズ完了
	await handler.get_tree().create_timer(0.5).timeout
	handler.complete_spell_phase()

## 単一の効果を適用
func apply_single_effect(effect: Dictionary, target_data: Dictionary):
	var handler = spell_phase_handler
	var effect_type = effect.get("effect_type", "")
	var gfm = handler.game_flow_manager  # 短縮参照
	
	match effect_type:
		# === 魔力操作系 ===
		"drain_magic", "drain_magic_conditional", "drain_magic_by_land_count", "drain_magic_by_lap_diff", \
		"gain_magic", "gain_magic_by_rank", "gain_magic_by_lap", "gain_magic_from_destroyed_count", \
		"gain_magic_from_spell_cost", "balance_all_magic", "gain_magic_from_land_chain", \
		"mhp_to_magic", "drain_magic_by_spell_count":
			if gfm and gfm.spell_magic:
				var context = {
					"rank": handler._get_player_ranking(handler.current_player_id),
					"from_player_id": target_data.get("player_id", -1),
					"tile_index": target_data.get("tile_index", -1),
					"card_system": handler.card_system
				}
				var result = await gfm.spell_magic.apply_effect(effect, handler.current_player_id, context)
				if result.has("next_effect") and not result["next_effect"].is_empty():
					await apply_single_effect(result["next_effect"], target_data)
		
		# === ダイス系 ===
		"dice_fixed", "dice_range", "dice_multi", "dice_range_magic":
			if gfm and gfm.spell_dice:
				gfm.spell_dice.apply_effect_from_parsed(effect, target_data, handler.current_player_id)
		
		# === ステータス呪い系 ===
		"stat_boost":
			var target_type = target_data.get("type", "")
			if target_type == "land" or target_type == "creature":
				var tile_index = target_data.get("tile_index", -1)
				if gfm and gfm.spell_curse_stat:
					gfm.spell_curse_stat.apply_curse_from_effect(effect, tile_index)
		
		# === クリーチャー呪い系 ===
		"skill_nullify", "battle_disable", "ap_nullify", "stat_reduce", "random_stat_curse", \
		"command_growth_curse", "plague_curse", "creature_curse", "forced_stop", "indomitable", \
		"land_effect_disable", "land_effect_grant", "metal_form", "magic_barrier", "destroy_after_battle", \
		"bounty_curse", "grant_mystic_arts", "land_curse":
			var target_type = target_data.get("type", "")
			if target_type == "land" or target_type == "creature":
				var tile_index = target_data.get("tile_index", -1)
				if gfm and gfm.spell_curse:
					gfm.spell_curse.apply_effect(effect, tile_index)
		
		# === 通行料呪い系 ===
		"toll_share", "toll_disable", "toll_fixed", "toll_multiplier", "peace", "curse_toll_half":
			if gfm and gfm.spell_curse_toll:
				var tile_index = target_data.get("tile_index", -1)
				var target_player_id = target_data.get("player_id", -1)
				gfm.spell_curse_toll.apply_curse_from_effect(effect, tile_index, target_player_id, handler.current_player_id)
		
		# === コスト修飾系 ===
		"life_force_curse":
			var target_player_id = target_data.get("player_id", handler.current_player_id)
			if gfm and gfm.spell_cost_modifier:
				gfm.spell_cost_modifier.apply_life_force(target_player_id)
		
		# === ドロー・手札操作系 ===
		"draw", "draw_cards", "draw_by_rank", "draw_by_type", "discard_and_draw_plus", \
		"check_hand_elements", "check_hand_synthesis", \
		"destroy_curse_cards", "destroy_expensive_cards", "destroy_duplicate_cards", \
		"destroy_selected_card", "steal_selected_card", "destroy_from_deck_selection", \
		"draw_from_deck_selection", "steal_item_conditional", \
		"add_specific_card", "destroy_and_draw", "swap_creature", \
		"transform_to_card", "reset_deck", "destroy_deck_top":
			if gfm and gfm.spell_draw:
				var context = {
					"rank": handler._get_player_ranking(handler.current_player_id),
					"target_player_id": target_data.get("player_id", handler.current_player_id),
					"tile_index": target_data.get("tile_index", -1)
				}
				var result = gfm.spell_draw.apply_effect(effect, handler.current_player_id, context)
				if result.has("next_effect") and not result["next_effect"].is_empty():
					apply_single_effect(result["next_effect"], target_data)
		
		# === 土地操作系 ===
		"change_element", "change_level", "set_level", "abandon_land", "destroy_creature", \
		"change_element_bidirectional", "change_element_to_dominant", \
		"find_and_change_highest_level", "conditional_level_change", \
		"align_mismatched_lands", "self_destruct", "change_caster_tile_element":
			if gfm and gfm.spell_land:
				var success = gfm.spell_land.apply_land_effect(effect, target_data, handler.current_player_id)
				if not success and effect.get("return_to_deck_on_fail", false):
					if gfm.spell_land.return_spell_to_deck(handler.current_player_id, handler.selected_spell_card):
						handler.spell_failed = true
		
		# === ダメージ・回復系 ===
		"damage", "heal", "full_heal", "clear_down":
			if handler.spell_damage:
				await handler.spell_damage.apply_effect(handler, effect, target_data)
		
		# === ダウン操作系 ===
		"down_clear":
			if handler.board_system and handler.board_system.movement_controller and handler.board_system.movement_controller.spell_movement:
				handler.board_system.movement_controller.spell_movement.clear_down_state_for_player(handler.current_player_id, handler.board_system.tile_nodes)
		
		"set_down":
			var tile_index = target_data.get("tile_index", -1)
			if tile_index >= 0 and handler.board_system and handler.board_system.movement_controller and handler.board_system.movement_controller.spell_movement:
				handler.board_system.movement_controller.spell_movement.set_down_state_for_tile(tile_index, handler.board_system.tile_nodes)
		
		# === クリーチャー移動系 ===
		"move_to_adjacent_enemy", "move_steps", "move_self", "destroy_and_move":
			if handler.spell_creature_move:
				await handler.spell_creature_move.apply_effect(effect, target_data, handler.current_player_id)
		
		# === クリーチャー配置系 ===
		"place_creature":
			if handler.spell_creature_place and handler.board_system:
				var result = handler.spell_creature_place.apply_place_effect(
					effect, target_data, handler.current_player_id, handler.board_system, handler.player_system
				)
				if not result.get("success", false):
					print("[SpellEffectExecutor] クリーチャー配置失敗")
		
		"draw_and_place":
			if gfm and gfm.spell_draw:
				gfm.spell_draw.apply_effect(effect, handler.current_player_id, {})
		
		# === クリーチャー交換系 ===
		"swap_with_hand", "swap_board_creatures":
			if handler.spell_creature_swap:
				var result = await handler.spell_creature_swap.apply_effect(effect, target_data, handler.current_player_id)
				if not result.get("success", false) and result.get("return_to_deck", false):
					if gfm and gfm.spell_land:
						if gfm.spell_land.return_spell_to_deck(handler.current_player_id, handler.selected_spell_card):
							handler.spell_failed = true
		
		# === スペル借用系 ===
		"use_hand_spell":
			if handler.spell_borrow:
				await handler.spell_borrow.apply_use_hand_spell(handler.current_player_id)
		
		"use_target_mystic_art":
			if handler.spell_borrow:
				await handler.spell_borrow.apply_use_target_mystic_art(target_data, handler.current_player_id)
		
		# === クリーチャー変身系 ===
		"transform":
			if handler.spell_transform:
				handler.spell_transform.apply_effect(effect, target_data, handler.current_player_id)
		
		"discord_transform":
			if handler.spell_transform:
				handler.spell_transform.apply_discord_transform(handler.current_player_id)
		
		# === 呪い除去系 ===
		"purify_all":
			if handler.spell_purify:
				var result = handler.spell_purify.purify_all(handler.current_player_id)
				if handler.ui_manager and handler.ui_manager.phase_label:
					var type_count = result.removed_types.size()
					handler.ui_manager.phase_label.text = "%d種類の呪いを消去 G%d獲得" % [type_count, result.gold_gained]
		
		"remove_creature_curse":
			if handler.spell_purify:
				var tile_index = target_data.get("tile_index", -1)
				handler.spell_purify.remove_creature_curse(tile_index)
		
		"remove_world_curse":
			if handler.spell_purify:
				handler.spell_purify.remove_world_curse()
		
		"remove_all_player_curses":
			if handler.spell_purify:
				handler.spell_purify.remove_all_player_curses()
		
		# === クリーチャー手札戻し系 ===
		"return_to_hand":
			if handler.spell_creature_return:
				handler.spell_creature_return.apply_effect(effect, target_data, handler.current_player_id)
		
		# === ステータス増減スペル ===
		"permanent_hp_change", "permanent_ap_change", "conditional_ap_change", "secret_tiny_army":
			if gfm and gfm.spell_curse_stat:
				await gfm.spell_curse_stat.apply_effect(handler, effect, target_data, handler.current_player_id, handler.selected_spell_card)
		
		# === 自壊効果 ===
		"self_destroy":
			var tile_index = target_data.get("caster_tile_index", target_data.get("tile_index", -1))
			var clear_land = effect.get("clear_land", true)
			if gfm and gfm.spell_magic:
				gfm.spell_magic.apply_self_destroy(tile_index, clear_land)
		
		# === ワープ系 ===
		"warp_to_nearest_vacant", "warp_to_nearest_gate", "warp_to_target":
			if gfm and gfm.spell_player_move:
				var result: Dictionary
				match effect_type:
					"warp_to_nearest_vacant":
						result = gfm.spell_player_move.warp_to_nearest_vacant(handler.current_player_id)
					"warp_to_nearest_gate":
						result = gfm.spell_player_move.warp_to_nearest_gate(handler.current_player_id)
					"warp_to_target":
						var tile_idx = target_data.get("tile_index", -1)
						result = gfm.spell_player_move.warp_to_target(handler.current_player_id, tile_idx)
				print("[SpellEffectExecutor] %s" % result.get("message", ""))
				if result.get("success", false):
					handler.skip_dice_phase = true
		
		# === 移動呪い系 ===
		"curse_movement_reverse":
			if gfm and gfm.spell_player_move:
				var duration = effect.get("duration", 1)
				gfm.spell_player_move.apply_movement_reverse_curse(duration)
		
		"gate_pass":
			if gfm and gfm.spell_player_move:
				var gate_key = target_data.get("gate_key", "")
				var result = gfm.spell_player_move.trigger_gate_pass(handler.current_player_id, gate_key)
				print("[SpellEffectExecutor] %s" % result.get("message", ""))
		
		"grant_direction_choice":
			if gfm and gfm.spell_player_move:
				var target_player_id = target_data.get("player_id", handler.current_player_id)
				var duration = effect.get("duration", 1)
				gfm.spell_player_move.grant_direction_choice(target_player_id, duration)
		
		# === 世界呪い ===
		"world_curse":
			if gfm and gfm.spell_world_curse:
				gfm.spell_world_curse.apply(effect)

## 全クリーチャー対象スペルを実行
func execute_spell_on_all_creatures(spell_card: Dictionary, target_info: Dictionary):
	var handler = spell_phase_handler
	handler.current_state = handler.State.EXECUTING_EFFECT
	
	# 発動通知を表示
	var caster_name = "プレイヤー%d" % (handler.current_player_id + 1)
	if handler.player_system and handler.current_player_id >= 0 and handler.current_player_id < handler.player_system.players.size():
		caster_name = handler.player_system.players[handler.current_player_id].name
	
	var target_data_for_notification = {"type": "all"}
	await handler._show_spell_cast_notification(caster_name, target_data_for_notification, spell_card, false)
	
	# スペル効果を取得
	var parsed = spell_card.get("effect_parsed", {})
	var effects = parsed.get("effects", [])
	
	# 対象クリーチャーを取得
	var targets = TargetSelectionHelper.get_valid_targets(handler, "creature", target_info)
	
	# 各対象に効果を適用
	for target in targets:
		for effect in effects:
			await apply_single_effect(effect, target)
	
	# カードを捨て札に
	if handler.card_system and not handler.spell_failed:
		var hand = handler.card_system.get_all_cards_for_player(handler.current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == spell_card.get("id", -2):
				handler.card_system.discard_card(handler.current_player_id, i, "use")
				break
	
	# 効果発動完了
	handler.spell_used.emit(spell_card)
	
	# 少し待機してからカメラを戻す
	await handler.get_tree().create_timer(0.5).timeout
	handler._return_camera_to_player()
	
	await handler.get_tree().create_timer(0.5).timeout
	handler.complete_spell_phase()

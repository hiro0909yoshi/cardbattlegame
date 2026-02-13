extends RefCounted
class_name SpellEffectExecutor

## スペル効果の実行を担当
## spell_phase_handler.gd から効果実行ロジックを分離

var spell_phase_handler = null  # 親への参照

# === 直接参照（GFM経由を廃止） ===
var spell_magic = null
var spell_dice = null
var spell_curse_stat = null
var spell_curse = null
var spell_curse_toll = null
var spell_cost_modifier = null
var spell_draw = null
var spell_land = null
var spell_player_move = null
var spell_world_curse = null

func _init(handler):
	spell_phase_handler = handler

## スペルシステム参照を設定（GFM経由を廃止）
func set_spell_systems(systems: Dictionary) -> void:
	spell_magic = systems.get("spell_magic")
	spell_dice = systems.get("spell_dice")
	spell_curse_stat = systems.get("spell_curse_stat")
	spell_curse = systems.get("spell_curse")
	spell_curse_toll = systems.get("spell_curse_toll")
	spell_cost_modifier = systems.get("spell_cost_modifier")
	spell_draw = systems.get("spell_draw")
	spell_land = systems.get("spell_land")
	spell_player_move = systems.get("spell_player_move")
	spell_world_curse = systems.get("spell_world_curse")

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
	await handler.show_spell_cast_notification(caster_name, target_data, spell_card, false)
	
	# スペル効果を実行
	var parsed = spell_card.get("effect_parsed", {})
	var effects = parsed.get("effects", [])
	
	# 復帰[ブック]判定（常にデッキに戻す場合）
	var return_to_deck = parsed.get("return_to_deck", false)
	if return_to_deck:
		if spell_land:
			if spell_land.return_spell_to_deck(handler.current_player_id, spell_card):
				handler.spell_failed = true
	
	# 復帰[手札]判定（スペルカードを手札に戻す - ゴブリンズレア等）
	var return_to_hand = parsed.get("return_to_hand", false)
	if return_to_hand:
		handler.spell_failed = true
	
	# 効果を適用
	for effect in effects:
		await apply_single_effect(effect, target_data)
	
	# カードを捨て札に（復帰[ブック]/復帰[手札]/外部スペル時はスキップ）
	if handler.card_system and not handler.spell_failed and not handler.is_external_spell_mode:
		var hand = handler.card_system.get_all_cards_for_player(handler.current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == spell_card.get("id", -2):
				handler.card_system.discard_card(handler.current_player_id, i, "use")
				break
	elif handler.spell_failed and return_to_hand:
		print("[復帰[手札]] %s は手札に残ります" % spell_card.get("name", "?"))
	elif handler.is_external_spell_mode:
		print("[外部スペル] %s は消滅" % spell_card.get("name", "?"))
	
	# 効果発動完了
	handler.spell_used.emit(spell_card)
	
	# カード選択中の場合は完了後に処理
	if handler.card_selection_handler and handler.card_selection_handler.is_selecting():
		return
	
	# 少し待機してからカメラを戻す
	await handler.get_tree().create_timer(0.5).timeout
	handler.return_camera_to_player()
	
	# さらに待機してからスペルフェーズ完了
	await handler.get_tree().create_timer(0.5).timeout
	handler.complete_spell_phase()

## 単一の効果を適用
func apply_single_effect(effect: Dictionary, target_data: Dictionary):
	var handler = spell_phase_handler
	var effect_type = effect.get("effect_type", "")

	match effect_type:
		# === EP操作系 ===
		"drain_magic", "drain_magic_conditional", "drain_magic_by_land_count", "drain_magic_by_lap_diff", \
		"gain_magic", "gain_magic_by_rank", "gain_magic_by_lap", "gain_magic_from_destroyed_count", \
		"gain_magic_from_spell_cost", "balance_all_magic", "gain_magic_from_land_chain", \
		"mhp_to_magic", "drain_magic_by_spell_count":
			if spell_magic:
				var context = {
					"rank": handler.get_player_ranking(handler.current_player_id),
					"from_player_id": target_data.get("player_id", -1),
					"tile_index": target_data.get("tile_index", -1),
					"card_system": handler.card_system
				}
				var result = await spell_magic.apply_effect(effect, handler.current_player_id, context)
				if result.has("next_effect") and not result["next_effect"].is_empty():
					await apply_single_effect(result["next_effect"], target_data)
		
		# === ダイス系 ===
		"dice_fixed", "dice_range", "dice_multi", "dice_range_magic":
			if spell_dice:
				spell_dice.apply_effect_from_parsed(effect, target_data, handler.current_player_id)
		
		# === ステータス呪い系 ===
		"stat_boost":
			var target_type = target_data.get("type", "")
			if target_type == "land" or target_type == "creature":
				var tile_index = target_data.get("tile_index", -1)
				if spell_curse_stat:
					spell_curse_stat.apply_curse_from_effect(effect, tile_index)
		
		# === クリーチャー呪い系 ===
		"skill_nullify", "battle_disable", "ap_nullify", "stat_reduce", "random_stat_curse", \
		"command_growth_curse", "plague_curse", "creature_curse", "forced_stop", "indomitable", \
		"land_effect_disable", "land_effect_grant", "metal_form", "magic_barrier", "destroy_after_battle", \
		"bounty_curse", "grant_mystic_arts", "land_curse", "apply_curse":
			var target_type = target_data.get("type", "")
			if target_type == "land" or target_type == "creature":
				var tile_index = target_data.get("tile_index", -1)
				if spell_curse:
					spell_curse.apply_effect(effect, tile_index)
		
		# === 通行料呪い系 ===
		"toll_share", "toll_disable", "toll_fixed", "toll_multiplier", "peace", "curse_toll_half":
			if spell_curse_toll:
				var tile_index = target_data.get("tile_index", -1)
				var target_player_id = target_data.get("player_id", -1)
				spell_curse_toll.apply_curse_from_effect(effect, tile_index, target_player_id, handler.current_player_id)
		
		# === プレイヤー呪い系 ===
		"player_curse":
			if spell_curse:
				var curse_type = effect.get("curse_type", "")
				var duration = effect.get("duration", -1)
				var params = {
					"name": effect.get("name", ""),
					"description": effect.get("description", "")
				}
				# 追加パラメータをコピー（ignore_item_restriction, ignore_summon_condition等）
				for key in ["ignore_item_restriction", "ignore_summon_condition", "spell_protection"]:
					if effect.has(key):
						params[key] = effect.get(key)
				
				# all_playersの場合は全プレイヤーに呪いをかける
				if effect.get("all_players", false) or target_data.get("type") == "all_players":
					var player_count = handler.player_system.players.size() if handler.player_system else 2
					for pid in range(player_count):
						spell_curse.curse_player(pid, curse_type, duration, params, handler.current_player_id)
				else:
					var target_player_id = target_data.get("player_id", handler.current_player_id)
					spell_curse.curse_player(target_player_id, curse_type, duration, params, handler.current_player_id)
		
		# === コスト修飾系 ===
		"life_force_curse":
			var target_player_id = target_data.get("player_id", handler.current_player_id)
			if spell_cost_modifier:
				spell_cost_modifier.apply_life_force(target_player_id)
		
		# === ドロー・手札操作系 ===
		"draw", "draw_cards", "draw_by_rank", "draw_by_type", "discard_and_draw_plus", \
		"check_hand_elements", "check_hand_synthesis", \
		"destroy_curse_cards", "destroy_expensive_cards", "destroy_duplicate_cards", \
		"destroy_selected_card", "steal_selected_card", "destroy_from_deck_selection", \
		"draw_from_deck_selection", "steal_item_conditional", \
		"add_specific_card", "destroy_and_draw", "swap_creature", \
		"transform_to_card", "reset_deck", "destroy_deck_top":
			if spell_draw:
				var context = {
					"rank": handler.get_player_ranking(handler.current_player_id),
					"target_player_id": target_data.get("player_id", handler.current_player_id),
					"tile_index": target_data.get("tile_index", -1)
				}
				var result = spell_draw.apply_effect(effect, handler.current_player_id, context)
				if result.has("next_effect") and not result["next_effect"].is_empty():
					apply_single_effect(result["next_effect"], target_data)
		
		# === 土地操作系 ===
		"change_element", "change_level", "set_level", "abandon_land", "destroy_creature", \
		"change_element_bidirectional", "change_element_to_dominant", \
		"find_and_change_highest_level", "conditional_level_change", \
		"align_mismatched_lands", "self_destruct", "change_caster_tile_element":
			if spell_land:
				var success = spell_land.apply_land_effect(effect, target_data, handler.current_player_id)
				if not success and effect.get("return_to_deck_on_fail", false):
					if spell_land.return_spell_to_deck(handler.current_player_id, handler.selected_spell_card):
						handler.spell_failed = true
		
		# === ダメージ・回復系 ===
		"damage", "heal", "full_heal", "clear_down":
			if handler.spell_damage:
				await handler.spell_damage.apply_effect(handler, effect, target_data)
		
		# === ダウン操作系 ===
		"down_clear":
			if handler.board_system:
				handler.board_system.clear_down_state_for_player(handler.current_player_id)
		
		"set_down":
			var tile_index = target_data.get("tile_index", -1)
			if tile_index >= 0 and handler.board_system:
				handler.board_system.set_down_state_for_tile(tile_index)
		
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
			if spell_draw:
				spell_draw.apply_effect(effect, handler.current_player_id, {})
		
		# === クリーチャー交換系 ===
		"swap_with_hand", "swap_board_creatures":
			if handler.spell_creature_swap:
				var result = await handler.spell_creature_swap.apply_effect(effect, target_data, handler.current_player_id)
				if not result.get("success", false) and result.get("return_to_deck", false):
					if spell_land:
						if spell_land.return_spell_to_deck(handler.current_player_id, handler.selected_spell_card):
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
				if handler.ui_manager and handler.ui_manager.global_comment_ui:
					var type_count = result.removed_types.size()
					var message = "%d種類の呪いを消去 %dEP獲得" % [type_count, result.ep_gained]
					await handler.ui_manager.show_comment_and_wait(message)
		
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
			if spell_curse_stat:
				await spell_curse_stat.apply_effect(handler, effect, target_data, handler.current_player_id, handler.selected_spell_card)
		
		# === 自壊効果 ===
		"self_destroy":
			var tile_index = target_data.get("caster_tile_index", target_data.get("tile_index", -1))
			var clear_land = effect.get("clear_land", true)
			if spell_magic:
				spell_magic.apply_self_destroy(tile_index, clear_land)
		
		# === ワープ系 ===
		"warp_to_nearest_vacant", "warp_to_nearest_gate", "warp_to_target":
			if spell_player_move:
				var result: Dictionary
				match effect_type:
					"warp_to_nearest_vacant":
						result = spell_player_move.warp_to_nearest_vacant(handler.current_player_id)
					"warp_to_nearest_gate":
						result = await spell_player_move.warp_to_nearest_gate(handler.current_player_id)
					"warp_to_target":
						var tile_idx = target_data.get("tile_index", -1)
						result = await spell_player_move.warp_to_target(handler.current_player_id, tile_idx)
				print("[SpellEffectExecutor] %s" % result.get("message", ""))
				if result.get("success", false):
					handler.skip_dice_phase = true
		
		# === 移動呪い系 ===
		"curse_movement_reverse":
			if spell_player_move:
				var duration = effect.get("duration", 1)
				spell_player_move.apply_movement_reverse_curse(duration)
		
		"gate_pass":
			if spell_player_move:
				var gate_key = target_data.get("gate_key", target_data.get("checkpoint", ""))
				var result = spell_player_move.trigger_gate_pass(handler.current_player_id, gate_key)
				print("[SpellEffectExecutor] %s" % result.get("message", ""))
		
		"grant_direction_choice":
			if spell_player_move:
				var target_player_id = target_data.get("player_id", handler.current_player_id)
				var duration = effect.get("duration", 1)
				spell_player_move.grant_direction_choice(target_player_id, duration)
		
		# === 世界呪い ===
		"world_curse":
			if spell_world_curse:
				spell_world_curse.apply(effect)

## 全クリーチャー対象スペルを実行
func execute_spell_on_all_creatures(spell_card: Dictionary, target_info: Dictionary):
	var handler = spell_phase_handler
	handler.current_state = handler.State.EXECUTING_EFFECT
	
	# 発動通知を表示
	var caster_name = "プレイヤー%d" % (handler.current_player_id + 1)
	if handler.player_system and handler.current_player_id >= 0 and handler.current_player_id < handler.player_system.players.size():
		caster_name = handler.player_system.players[handler.current_player_id].name
	
	var target_data_for_notification = {"type": "all"}
	await handler.show_spell_cast_notification(caster_name, target_data_for_notification, spell_card, false)
	
	# スペル効果を取得
	var parsed = spell_card.get("effect_parsed", {})
	var effects = parsed.get("effects", [])
	
	# 対象クリーチャーを取得
	var targets = TargetSelectionHelper.get_valid_targets(handler, "creature", target_info)
	
	# 各対象に効果を適用
	for target in targets:
		for effect in effects:
			await apply_single_effect(effect, target)
	
	# カードを捨て札に（外部スペル時はスキップ）
	if handler.card_system and not handler.spell_failed and not handler.is_external_spell_mode:
		var hand = handler.card_system.get_all_cards_for_player(handler.current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == spell_card.get("id", -2):
				handler.card_system.discard_card(handler.current_player_id, i, "use")
				break
	elif handler.is_external_spell_mode:
		print("[外部スペル] %s は消滅" % spell_card.get("name", "?"))
	
	# 効果発動完了
	handler.spell_used.emit(spell_card)
	
	# 外部スペルモードの場合は完了シグナルを発火してリターン
	if handler.is_external_spell_mode:
		handler.external_spell_finished.emit()
		return
	
	# 少し待機してからカメラを戻す
	await handler.get_tree().create_timer(0.5).timeout
	handler.return_camera_to_player()
	
	await handler.get_tree().create_timer(0.5).timeout
	handler.complete_spell_phase()

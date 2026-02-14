extends RefCounted
class_name SpellEffectExecutor

## スペル効果の実行を担当
## spell_phase_handler.gd から効果実行ロジックを分離

var spell_phase_handler = null  # 親への参照

# === コンテナ直接参照（辞書展開廃止） ===
var spell_container: SpellSystemContainer = null

# === Strategy パターン対応 ===
const SpellStrategyFactory = preload("res://scripts/spells/strategies/spell_strategy_factory.gd")

func _init(handler):
	spell_phase_handler = handler

## スペルシステムコンテナを設定（辞書展開廃止）
func set_spell_container(container: SpellSystemContainer) -> void:
	spell_container = container

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
		if spell_container and spell_container.spell_land:
			if spell_container.spell_land.return_spell_to_deck(handler.current_player_id, spell_card):
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

	# ========================================
	# Strategy パターン試行（Phase 3-A-1）
	# ========================================
	if SpellStrategyFactory.has_effect_strategy(effect_type):
		var strategy = SpellStrategyFactory.create_effect_strategy(effect_type)
		if strategy:
			# Strategy のコンテキストを構築（直接参照を含める）
			var context = {
				"effect": effect,
				"target_data": target_data,
				"spell_phase_handler": handler,
				"current_player_id": handler.current_player_id,
				"spell_card": handler.selected_spell_card,
				"board_system": handler.board_system,
				"spell_container": spell_container,
				"spell_effect_executor": self,
				# === 直接参照（2段チェーンアクセス廃止） ===
				"spell_draw": spell_container.spell_draw if spell_container else null,
				"spell_dice": spell_container.spell_dice if spell_container else null,
				"spell_land": spell_container.spell_land if spell_container else null,
				"spell_magic": spell_container.spell_magic if spell_container else null,
				"spell_curse": spell_container.spell_curse if spell_container else null,
				"spell_curse_stat": spell_container.spell_curse_stat if spell_container else null,
				"spell_curse_toll": spell_container.spell_curse_toll if spell_container else null,
				"spell_cost_modifier": spell_container.spell_cost_modifier if spell_container else null,
				"spell_player_move": spell_container.spell_player_move if spell_container else null,
				"spell_creature_move": handler.spell_creature_move if handler else null,
				"spell_damage": handler.spell_damage if handler else null,
				"spell_purify": handler.spell_purify if handler else null,
				"spell_creature_place": handler.spell_creature_place if handler else null,
				"spell_creature_swap": handler.spell_creature_swap if handler else null,
				"spell_borrow": handler.spell_borrow if handler else null,
				"spell_transform": handler.spell_transform if handler else null,
				"spell_creature_return": handler.spell_creature_return if handler else null,
				"card_system": handler.card_system if handler else null,
				"player_system": handler.player_system if handler else null,
			}

			# バリデーション
			if strategy.validate(context):
				# 実行（既存ロジックはスキップ）
				await strategy.execute(context)
				return
			else:
				# バリデーション失敗 → フォールバック
				push_warning("[SpellEffectExecutor] Strategy バリデーション失敗 (effect_type: %s)" % effect_type)
		else:
			# Strategy 作成失敗 → フォールバック
			push_warning("[SpellEffectExecutor] Strategy 作成失敗 (effect_type: %s)" % effect_type)

	# ========================================
	# フォールバック: 未実装の effect_type
	# ========================================
	# 全ての effect_type は Strategy で実装済み
	# ここに到達した場合は未知の effect_type
	push_error("[SpellEffectExecutor] 未実装の effect_type: %s" % effect_type)

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

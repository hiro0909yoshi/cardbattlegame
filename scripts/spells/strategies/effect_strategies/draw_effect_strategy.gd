## DrawEffectStrategy - ドロー効果の戦略実装
## draw, draw_cards, draw_by_rank, draw_by_type, draw_from_deck_selection, draw_and_place
class_name DrawEffectStrategy
extends SpellStrategy

## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# Level 1: 必須キーの存在確認
	var required = ["effect", "spell_phase_handler", "spell_draw"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_phase_handler", "spell_draw"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_draw の実体確認（直接参照）
	var spell_draw = context.get("spell_draw")
	if not spell_draw:
		_log_error("spell_draw が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認（draw 系）
	var valid_types = ["draw", "draw_cards", "draw_by_rank", "draw_by_type", "draw_from_deck_selection", "draw_and_place"]
	if effect_type not in valid_types:
		_log_error("無効な effect_type: %s（draw 系のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

## 実行（スペル効果の適用）
func execute(context: Dictionary) -> void:
	var spell_draw = context.get("spell_draw")
	var spell_phase_handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")
	var current_player_id = context.get("current_player_id", 0)

	# null チェック（直接参照）
	if not spell_draw:
		_log_error("spell_draw が初期化されていません")
		return

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# SpellDraw に委譲（context 構築）
	var context_for_draw = {
		"rank": spell_phase_handler.get_player_ranking(current_player_id) if spell_phase_handler else 0,
		"target_player_id": context.get("target_data", {}).get("player_id", current_player_id),
		"tile_index": context.get("target_data", {}).get("tile_index", -1)
	}

	var result = spell_draw.apply_effect(effect, current_player_id, context_for_draw)

	# next_effect がある場合は処理（spell_draw は内部で next_effect を返す場合がある）
	if result.has("next_effect") and not result.get("next_effect", {}).is_empty():
		# フォールバックスペルエフェクトエグゼキューターに委譲する必要がある場合
		# ここでは省略（既に spell_draw が処理している）
		_log("next_effect を検出 (内部で処理済み)")

	_log("効果実行完了")

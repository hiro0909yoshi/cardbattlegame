## HandManipulationEffectStrategy - 手札操作効果の戦略実装
class_name HandManipulationEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	var required = ["effect", "spell_draw"]
	if not _validate_context_keys(context, required):
		return false

	var refs = ["spell_draw"]
	if not _validate_references(context, refs):
		return false

	var spell_draw = context.get("spell_draw")
	if not spell_draw:
		_log_error("spell_draw が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	var valid_types = [
		"discard_and_draw_plus", "check_hand_elements", "check_hand_synthesis",
		"destroy_curse_cards", "destroy_expensive_cards", "destroy_duplicate_cards",
		"destroy_selected_card", "steal_selected_card", "destroy_from_deck_selection",
		"steal_item_conditional", "add_specific_card", "destroy_and_draw",
		"swap_creature", "transform_to_card", "reset_deck", "destroy_deck_top"
	]
	if effect_type not in valid_types:
		_log_error("無効な effect_type: %s（手札操作系のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> void:
	var spell_draw = context.get("spell_draw")
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var current_player_id = context.get("current_player_id", 0)

	if not spell_draw:
		_log_error("spell_draw が初期化されていません")
		return

	_log("効果実行開始 (effect_type: %s)" % effect.get("effect_type", ""))

	# context 構築（元のロジックを再現）
	var draw_context = {
		"rank": handler.get_player_ranking(current_player_id) if handler else 0,
		"target_player_id": target_data.get("player_id", current_player_id),
		"tile_index": target_data.get("tile_index", -1)
	}

	# spell_draw に委譲
	var result = spell_draw.apply_effect(effect, current_player_id, draw_context)

	# next_effect がある場合は処理
	if result.has("next_effect") and not result.get("next_effect", {}).is_empty():
		var spell_effect_executor = context.get("spell_effect_executor")
		if spell_effect_executor:
			await spell_effect_executor.apply_single_effect(result["next_effect"], target_data)

	_log("効果実行完了")

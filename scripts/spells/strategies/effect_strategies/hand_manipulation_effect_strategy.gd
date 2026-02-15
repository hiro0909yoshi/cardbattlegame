## HandManipulationEffectStrategy - 手札操作効果の戦略実装
class_name HandManipulationEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

	var required = ["effect", "spell_draw"]
	if not _validate_context_keys(context, required):
		return false

	var refs = ["spell_draw"]
	if not _validate_references(context, refs):
		return false

	var spell_draw = context.get("spell_draw")
	if not spell_draw:
		_log_error("spell_draw が初期化されていません（context を確認）")
		# ★ NEW: コンテキスト内容をダンプ
		print("[HandManipulationEffectStrategy] === context contents ===")
		for key in context.keys():
			var val = context[key]
			if val == null:
				print("  - %s: null ⚠️" % key)
			elif val is Object and not (val is Dictionary):
				print("  - %s: %s (object)" % [key, val.get_class()])
			else:
				print("  - %s: %s" % [key, typeof(val)])
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false

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

func execute(context: Dictionary) -> Dictionary:
	var spell_draw = context.get("spell_draw")
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")
	var current_player_id = context.get("current_player_id", 0)

	if not spell_draw:
		_log_error("spell_draw が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# context 構築（元のロジックを再現）
	var draw_context = {
		"rank": handler.get_player_ranking(current_player_id) if handler else 0,
		"target_player_id": target_data.get("player_id", current_player_id),
		"tile_index": target_data.get("tile_index", -1)
	}

	# spell_draw に委譲
	var result = spell_draw.apply_effect(effect, current_player_id, draw_context)

	# ★ NEW: effect_message を構築
	var effect_message = ""
	match effect_type:
		"destroy_selected_card":
			effect_message = "敵のカードを破壊！"
		"destroy_curse_cards":
			effect_message = "呪いカードを破壊！"
		"draw":
			effect_message = "カードをドロー"
		"draw_cards":
			var count = effect.get("count", 1)
			effect_message = "%d枚ドロー" % count
		"draw_by_rank":
			effect_message = "順位でカードドロー"
		"draw_by_type":
			effect_message = "属性でカードドロー"
		"draw_from_deck_selection":
			effect_message = "デッキから選択ドロー"
		"draw_and_place":
			effect_message = "ドロー後配置"
		"discard_and_draw_plus":
			effect_message = "捨てるとドロー増加"
		"check_hand_elements":
			effect_message = "手札属性チェック"
		"check_hand_synthesis":
			effect_message = "手札合成チェック"
		"destroy_expensive_cards":
			effect_message = "高コストカード破壊"
		"destroy_duplicate_cards":
			effect_message = "重複カード破壊"
		"steal_selected_card":
			effect_message = "敵カード奪取"
		"destroy_from_deck_selection":
			effect_message = "デッキから破壊"
		"steal_item_conditional":
			effect_message = "条件付きアイテム奪取"
		"add_specific_card":
			effect_message = "特定カード追加"
		"destroy_and_draw":
			effect_message = "破壊してドロー"
		"swap_creature":
			effect_message = "クリーチャー交換"
		"transform_to_card":
			effect_message = "カードに変身"
		"reset_deck":
			effect_message = "デッキリセット"
		"destroy_deck_top":
			effect_message = "デッキトップ破壊"
		_:
			effect_message = "カード操作実行"

	# next_effect がある場合は処理
	if result.has("next_effect") and not result.get("next_effect", {}).is_empty():
		var spell_effect_executor = context.get("spell_effect_executor")
		if spell_effect_executor:
			await spell_effect_executor.apply_single_effect(result["next_effect"], target_data)

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": result.get("success", true)
	}

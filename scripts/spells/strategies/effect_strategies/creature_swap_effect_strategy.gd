## CreatureSwapEffectStrategy - クリーチャー交換効果の戦略実装
## swap_with_hand, swap_board_creatures (2個)
class_name CreatureSwapEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	# Level 1: 必須キーの存在確認
	var required = ["effect", "spell_creature_swap"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_creature_swap"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_creature_swap の実体確認（直接参照）
	var spell_creature_swap = context.get("spell_creature_swap")
	if not spell_creature_swap:
		_log_error("spell_creature_swap が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認（2個）
	if effect_type not in ["swap_with_hand", "swap_board_creatures"]:
		_log_error("無効な effect_type: %s（swap_with_hand/swap_board_creatures のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> void:
	var spell_creature_swap = context.get("spell_creature_swap")
	var handler = context.get("spell_phase_handler")
	var spell_land = context.get("spell_land")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var current_player_id = context.get("current_player_id", 0)

	# null チェック（直接参照）
	if not spell_creature_swap:
		_log_error("spell_creature_swap が初期化されていません")
		return

	_log("効果実行開始 (effect_type: %s)" % effect.get("effect_type", ""))

	# spell_creature_swap に委譲（await - 元のロジックを再現）
	var result = await spell_creature_swap.apply_effect(effect, target_data, current_player_id)

	# 失敗時に return_to_deck 処理
	if not result.get("success", false) and result.get("return_to_deck", false):
		if spell_land and handler and handler.spell_state:
			var selected_spell_card = handler.spell_state.selected_spell_card if handler.spell_state else {}
			if spell_land.return_spell_to_deck(current_player_id, selected_spell_card):
				handler.spell_failed = true

	_log("効果実行完了")

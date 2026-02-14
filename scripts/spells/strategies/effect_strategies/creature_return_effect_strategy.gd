## CreatureReturnEffectStrategy - クリーチャー手札戻し効果の戦略実装
## return_to_hand (1個)
class_name CreatureReturnEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	# Level 1: 必須キーの存在確認
	var required = ["effect", "spell_creature_return"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_creature_return"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_creature_return の実体確認（直接参照）
	var spell_creature_return = context.get("spell_creature_return")
	if not spell_creature_return:
		_log_error("spell_creature_return が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認（1個）
	if effect_type != "return_to_hand":
		_log_error("無効な effect_type: %s（return_to_hand のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> void:
	var spell_creature_return = context.get("spell_creature_return")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var current_player_id = context.get("current_player_id", 0)

	# null チェック（直接参照）
	if not spell_creature_return:
		_log_error("spell_creature_return が初期化されていません")
		return

	_log("効果実行開始 (effect_type: return_to_hand)")

	# spell_creature_return に委譲（元のロジックを再現）
	spell_creature_return.apply_effect(effect, target_data, current_player_id)

	_log("効果実行完了")

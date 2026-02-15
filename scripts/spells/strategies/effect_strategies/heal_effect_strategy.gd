## HealEffectStrategy - 回復効果の戦略実装（heal, full_heal）
class_name HealEffectStrategy
extends SpellStrategy

## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

	# Level 1: 必須キーの存在確認
	var required = ["effect", "target_data", "spell_damage"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_damage"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_damage の実体確認（直接参照）
	var spell_damage = context.get("spell_damage")
	if not spell_damage:
		_log_error("spell_damage が初期化されていません（context を確認）")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認
	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false

	# effect_type の有効性確認（heal または full_heal）
	if effect_type not in ["heal", "full_heal"]:
		_log_error("無効な effect_type: %s（heal または full_heal のみ対応）" % effect_type)
		return false

	var target_data = context.get("target_data", {})
	var tile_index = target_data.get("tile_index", -1)

	# ターゲットタイルの有効性確認
	if tile_index < 0:
		_log_error("ターゲットタイルが選択されていません (tile_index: %d)" % tile_index)
		return false

	# heal 時はheal値チェック
	if effect_type == "heal":
		var value = effect.get("value", 0)
		if value <= 0:
			_log_error("回復値が無効です (value: %d)" % value)
			return false
		_log("バリデーション成功 (effect_type: heal, tile_index: %d, value: %d)" % [tile_index, value])
	else:
		# full_heal 時は値チェック不要
		_log("バリデーション成功 (effect_type: full_heal, tile_index: %d)" % tile_index)

	return true

## 実行（スペル効果の適用）
func execute(context: Dictionary) -> Dictionary:
	var spell_damage = context.get("spell_damage")
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")
	var tile_index = target_data.get("tile_index", -1)

	# null チェック（直接参照）
	if not spell_damage:
		_log_error("spell_damage が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: %s, tile_index: %d)" % [effect_type, tile_index])

	# ★ NEW: effect_message を構築
	var effect_message = ""

	match effect_type:
		"heal":
			var value = effect.get("value", 0)
			await spell_damage.apply_heal_effect(handler, tile_index, value)
			effect_message = "%dHP回復" % value
		"full_heal":
			await spell_damage.apply_full_heal_effect(handler, tile_index)
			effect_message = "完全回復"
		_:
			_log_error("未対応の effect_type: %s" % effect_type)
			return { "effect_message": "" }

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": true
	}

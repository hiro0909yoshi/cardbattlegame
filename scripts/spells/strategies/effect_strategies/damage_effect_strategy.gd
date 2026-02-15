## DamageEffectStrategy - ダメージ効果の戦略実装
class_name DamageEffectStrategy
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
		# ★ NEW: コンテキスト内容をダンプ
		print("[DamageEffectStrategy] === context contents ===")
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

	var value = effect.get("value", 0)

	# ダメージ値の有効性確認
	if value <= 0:
		_log_error("ダメージ値が無効です (value: %d)" % value)
		return false

	var target_data = context.get("target_data", {})
	var tile_index = target_data.get("tile_index", -1)

	# ターゲットタイルの有効性確認
	if tile_index < 0:
		_log_error("ターゲットタイルが選択されていません (tile_index: %d)" % tile_index)
		return false

	_log("バリデーション成功 (tile_index: %d, value: %d)" % [tile_index, value])
	return true

## 実行（スペル効果の適用）
func execute(context: Dictionary) -> Dictionary:
	var spell_damage = context.get("spell_damage")
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var value = effect.get("value", 0)

	# null チェック（直接参照）
	if not spell_damage:
		_log_error("spell_damage が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (tile_index: %d, value: %d)" % [target_data.get("tile_index", -1), value])

	# SpellDamage に委譲
	await spell_damage.apply_damage_effect(handler, target_data.get("tile_index", -1), value)

	# ★ NEW: effect_message を構築
	var effect_message = "%dダメージ" % value

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": true
	}

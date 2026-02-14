## DamageEffectStrategy - ダメージ効果の戦略実装
class_name DamageEffectStrategy
extends SpellStrategy

## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# Level 1: 必須キーの存在確認
	var required = ["effect", "target_data", "spell_phase_handler"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_phase_handler"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_damage の存在確認
	var handler = context.get("spell_phase_handler")
	if not handler or not handler.spell_damage:
		_log_error("spell_damage が初期化されていません")
		return false

	var effect = context.get("effect", {})
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
func execute(context: Dictionary) -> void:
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var value = effect.get("value", 0)

	# null チェック
	if not handler or not handler.spell_damage:
		_log_error("spell_damage が初期化されていません")
		return

	_log("効果実行開始 (tile_index: %d, value: %d)" % [target_data.get("tile_index", -1), value])

	# SpellDamage に委譲
	await handler.spell_damage.apply_damage_effect(handler, target_data.get("tile_index", -1), value)

	_log("効果実行完了")

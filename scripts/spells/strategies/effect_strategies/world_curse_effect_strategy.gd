## WorldCurseEffectStrategy - 世界呪い効果の戦略実装
## world_curse (1個)
class_name WorldCurseEffectStrategy
extends SpellStrategy

## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# Level 1: 必須キーの存在確認
	var required = ["effect", "spell_world_curse"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_world_curse"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_world_curse の実体確認（直接参照）
	var spell_world_curse = context.get("spell_world_curse")
	if not spell_world_curse:
		_log_error("spell_world_curse が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	if effect_type != "world_curse":
		_log_error("無効な effect_type: %s（world_curse のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: world_curse)")
	return true

## 実行（スペル効果の適用）
func execute(context: Dictionary) -> void:
	var spell_world_curse = context.get("spell_world_curse")
	var effect = context.get("effect", {})

	# null チェック（直接参照）
	if not spell_world_curse:
		_log_error("spell_world_curse が初期化されていません")
		return

	_log("効果実行開始 (effect_type: world_curse)")

	# spell_world_curse に委譲
	spell_world_curse.apply(effect)

	_log("効果実行完了")

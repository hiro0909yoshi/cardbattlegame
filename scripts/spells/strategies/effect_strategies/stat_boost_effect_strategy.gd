## StatBoostEffectStrategy - ステータス刻印効果の戦略実装
## stat_boost (1個)
class_name StatBoostEffectStrategy
extends SpellStrategy

## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

	# Level 1: 必須キーの存在確認
	var required = ["effect", "spell_curse_stat"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_curse_stat"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_curse_stat の実体確認（直接参照）
	var spell_curse_stat = context.get("spell_curse_stat")
	if not spell_curse_stat:
		_log_error("spell_curse_stat が初期化されていません（context を確認）")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false


	if effect_type != "stat_boost":
		_log_error("無効な effect_type: %s（stat_boost のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: stat_boost)")
	return true

## 実行（スペル効果の適用）
func execute(context: Dictionary) -> Dictionary:
	var spell_curse_stat = context.get("spell_curse_stat")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})

	# null チェック（直接参照）
	if not spell_curse_stat:
		_log_error("spell_curse_stat が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: stat_boost)")

	# 元のロジック (spell_effect_executor.gd Line 157-162) を再現
	var target_type = target_data.get("type", "")
	if target_type == "land" or target_type == "creature":
		var tile_index = target_data.get("tile_index", -1)
		spell_curse_stat.apply_curse_from_effect(effect, tile_index)
	else:
		_log("ターゲットタイプが land/creature ではありません (type: %s)" % target_type)

	# ★ NEW: effect_message を構築
	var effect_message = "ステータスを強化"

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": true
	}

## CreatureCurseEffectStrategy - クリーチャー呪い効果の戦略実装
## skill_nullify, battle_disable, ap_nullify, stat_reduce, random_stat_curse,
## command_growth_curse, plague_curse, creature_curse, forced_stop, indomitable,
## land_effect_disable, land_effect_grant, metal_form, magic_barrier, destroy_after_battle,
## bounty_curse, grant_mystic_arts, land_curse, apply_curse (19個)
class_name CreatureCurseEffectStrategy
extends SpellStrategy

## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# Level 1: 必須キーの存在確認
	var required = ["effect", "spell_curse"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_curse"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_curse の実体確認（直接参照）
	var spell_curse = context.get("spell_curse")
	if not spell_curse:
		_log_error("spell_curse が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認（19個）
	var valid_types = [
		"skill_nullify", "battle_disable", "ap_nullify", "stat_reduce", "random_stat_curse",
		"command_growth_curse", "plague_curse", "creature_curse", "forced_stop", "indomitable",
		"land_effect_disable", "land_effect_grant", "metal_form", "magic_barrier", "destroy_after_battle",
		"bounty_curse", "grant_mystic_arts", "land_curse", "apply_curse"
	]
	if effect_type not in valid_types:
		_log_error("無効な effect_type: %s（creature_curse 系のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

## 実行（スペル効果の適用）
func execute(context: Dictionary) -> void:
	var spell_curse = context.get("spell_curse")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")

	# null チェック（直接参照）
	if not spell_curse:
		_log_error("spell_curse が初期化されていません")
		return

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# target_type チェック（元のロジックを再現）
	var target_type = target_data.get("type", "")
	if target_type == "land" or target_type == "creature":
		var tile_index = target_data.get("tile_index", -1)
		spell_curse.apply_effect(effect, tile_index)
	else:
		_log("ターゲットタイプが land/creature ではありません (type: %s)" % target_type)

	_log("効果実行完了")

## CreatureCurseEffectStrategy - クリーチャー刻印効果の戦略実装
## skill_nullify, battle_disable, ap_nullify, stat_reduce, random_stat_curse,
## command_growth_curse, plague_curse, creature_curse, forced_stop, indomitable,
## land_effect_disable, land_effect_grant, metal_form, magic_barrier, destroy_after_battle,
## bounty_curse, grant_mystic_arts, land_curse, apply_curse (19個)
class_name CreatureCurseEffectStrategy
extends SpellStrategy

## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

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
		_log_error("spell_curse が初期化されていません（context を確認）")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false

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
func execute(context: Dictionary) -> Dictionary:
	var spell_curse = context.get("spell_curse")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")

	# null チェック（直接参照）
	if not spell_curse:
		_log_error("spell_curse が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# ★ NEW: effect_message を構築
	var effect_message = ""
	match effect_type:
		"skill_nullify":
			effect_message = "スキルを無効化"
		"battle_disable":
			effect_message = "戦闘不能化"
		"ap_nullify":
			effect_message = "AP無効化"
		"stat_reduce":
			effect_message = "ステータス低下"
		"random_stat_curse":
			effect_message = "ランダムな刻印"
		"command_growth_curse":
			effect_message = "昇華刻印"
		"plague_curse":
			effect_message = "疫病の刻印"
		"creature_curse":
			effect_message = "クリーチャー刻印"
		"forced_stop":
			effect_message = "停滞"
		"indomitable":
			effect_message = "奮闘スキル付与"
		"land_effect_disable":
			effect_message = "土地効果無効化"
		"land_effect_grant":
			effect_message = "土地効果付与"
		"metal_form":
			effect_message = "硬化"
		"magic_barrier":
			effect_message = "魔法障壁"
		"destroy_after_battle":
			effect_message = "戦闘後消滅"
		"bounty_curse":
			effect_message = "報奨金の刻印"
		"grant_mystic_arts":
			effect_message = "神秘術付与"
		"land_curse":
			effect_message = "土地刻印"
		"apply_curse":
			effect_message = "刻印適用"
		_:
			effect_message = "刻印効果実行"

	# target_type チェック（元のロジックを再現）
	var target_type = target_data.get("type", "")
	if target_type == "land" or target_type == "creature":
		var tile_index = target_data.get("tile_index", -1)
		spell_curse.apply_effect(effect, tile_index)
	else:
		_log("ターゲットタイプが land/creature ではありません (type: %s)" % target_type)

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": true
	}

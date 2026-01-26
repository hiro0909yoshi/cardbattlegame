##
## HP効果無効（HP Effect Immune）判定
## スペルやアルカナアーツによるHP/MHP変更効果を無効化する能力の判定を行う
##

class_name SpellHpImmune


## クリーチャーがHP効果無効を持っているか判定
## @param creature_data クリーチャーデータ
## @return bool HP効果無効を持っているか
static func has_hp_effect_immune(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	
	var creature_name = creature_data.get("name", "?")
	
	# 1. クリーチャー固有能力チェック（keywords）
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	if "HP効果無効" in keywords:
		print("[SpellHpImmune] %s はHP効果無効キーワードを持つため対象外" % creature_name)
		return true
	
	# 2. 呪いチェック（マスファンタズム等で付与）
	var curse = creature_data.get("curse", {})
	if curse.get("curse_type") == "hp_effect_immune":
		print("[SpellHpImmune] %s はHP効果無効呪いを持つため対象外" % creature_name)
		return true
	
	return false


## スペル/アルカナアーツがHP変更効果を持つか判定
## @param effect_parsed スペルのeffect_parsed
## @return bool HP変更効果を持つか
static func affects_hp(effect_parsed: Dictionary) -> bool:
	return effect_parsed.get("affects_hp", false)


## HP効果無効によりスキップすべきか判定（全体スペル用）
## @param creature_data クリーチャーデータ
## @param effect_parsed スペルのeffect_parsed
## @return bool スキップすべきか
static func should_skip_hp_effect(creature_data: Dictionary, effect_parsed: Dictionary) -> bool:
	if not affects_hp(effect_parsed):
		return false
	
	if has_hp_effect_immune(creature_data):
		print("[HP効果無効] %s はHP変更効果を無効化" % creature_data.get("name", "?"))
		return true
	
	return false


## ターゲット選択時にHP効果無効を持つクリーチャーを除外するフィルタ
## @param creatures Array[Dictionary] クリーチャーリスト
## @param effect_parsed スペルのeffect_parsed
## @return Array[Dictionary] フィルタされたリスト
static func filter_hp_immune_targets(creatures: Array, effect_parsed: Dictionary) -> Array:
	if not affects_hp(effect_parsed):
		return creatures
	
	var filtered = []
	for creature in creatures:
		if not has_hp_effect_immune(creature):
			filtered.append(creature)
		else:
			print("[HP効果無効] %s は対象から除外" % creature.get("name", "?"))
	
	return filtered

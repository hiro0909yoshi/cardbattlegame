class_name SpellCurseBattle
extends RefCounted

## 戦闘制限呪いシステム
## - skill_nullify: 戦闘能力不可（全スキル無効化）
## - battle_disable: 戦闘行動不可（攻撃・アイテム・援護使用不可）

# =============================================================================
# 呪いチェック
# =============================================================================

## battle_disable 呪いを持っているかチェック
static func has_battle_disable(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type") == "battle_disable"


## skill_nullify 呪いを持っているかチェック
static func has_skill_nullify(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type") == "skill_nullify"


# =============================================================================
# 呪い付与
# =============================================================================

## battle_disable 呪いを付与
static func apply_battle_disable(creature_data: Dictionary, name: String = "戦闘行動不可") -> void:
	creature_data["curse"] = {
		"curse_type": "battle_disable",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] 戦闘行動不可を付与: ", creature_data.get("name", "?"))


## skill_nullify 呪いを付与
static func apply_skill_nullify(creature_data: Dictionary, name: String = "戦闘能力不可") -> void:
	creature_data["curse"] = {
		"curse_type": "skill_nullify",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] 戦闘能力不可を付与: ", creature_data.get("name", "?"))


## plague 呪いを付与（衰弱: 戦闘終了時HP -= MHP/2）
static func apply_plague(creature_data: Dictionary, name: String = "衰弱") -> void:
	creature_data["curse"] = {
		"curse_type": "plague",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] 衰弱を付与: ", creature_data.get("name", "?"))


# =============================================================================
# 攻撃成功時の呪い付与チェック（ナイキー、バインドウィップ用）
# =============================================================================

## 攻撃成功時に呪いを付与するかチェックし、該当すれば付与
## attacker_data: 攻撃側のcreature_data
## defender_data: 防御側のcreature_data
## 戻り値: 呪いを付与したかどうか
static func check_and_apply_on_attack_success(attacker_data: Dictionary, defender_data: Dictionary) -> bool:
	var applied = false
	
	# クリーチャー能力からチェック
	var ability_parsed = attacker_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "on_attack_success_curse":
			var curse_type = effect.get("curse_type", "")
			match curse_type:
				"battle_disable":
					apply_battle_disable(defender_data, effect.get("name", "戦闘行動不可"))
					print("【攻撃成功時呪い】", attacker_data.get("name", "?"), " → ", 
						  defender_data.get("name", "?"), " に戦闘行動不可を付与")
					applied = true
				"plague":
					apply_plague(defender_data, effect.get("name", "衰弱"))
					print("【攻撃成功時呪い】", attacker_data.get("name", "?"), " → ", 
						  defender_data.get("name", "?"), " に衰弱を付与")
					applied = true
	
	# アイテムからチェック
	var items = attacker_data.get("items", [])
	for item in items:
		var item_effects = item.get("effect_parsed", {}).get("effects", [])
		for effect in item_effects:
			if effect.get("effect_type") == "on_attack_success_curse":
				var curse_type = effect.get("curse_type", "")
				match curse_type:
					"battle_disable":
						apply_battle_disable(defender_data, effect.get("name", "戦闘行動不可"))
						print("【攻撃成功時呪い】", item.get("name", "?"), " → ", 
							  defender_data.get("name", "?"), " に戦闘行動不可を付与")
						applied = true
					"plague":
						apply_plague(defender_data, effect.get("name", "衰弱"))
						print("【攻撃成功時呪い】", item.get("name", "?"), " → ", 
							  defender_data.get("name", "?"), " に衰弱を付与")
						applied = true
	
	return applied

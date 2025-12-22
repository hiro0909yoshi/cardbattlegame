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
## 攻撃成功時の呪い付与
## @return Dictionary { "applied": bool, "curse_name": String }
static func check_and_apply_on_attack_success(attacker_data: Dictionary, defender_data: Dictionary) -> Dictionary:
	var result = {"applied": false, "curse_name": ""}
	
	# クリーチャー能力からチェック
	var ability_parsed = attacker_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		# trigger形式（新）とeffect_type形式（旧）両方に対応
		var is_on_attack_success = (
			effect.get("trigger") == "on_attack_success" and effect.get("effect_type") == "apply_curse"
		) or effect.get("effect_type") == "on_attack_success_curse"
		
		if is_on_attack_success:
			var curse_type = effect.get("curse_type", "")
			var curse_result = _apply_curse_effect(curse_type, effect, attacker_data.get("name", "?"), defender_data)
			if curse_result.get("applied", false):
				result["applied"] = true
				result["curse_name"] = curse_result.get("curse_name", "")
	
	# アイテムからチェック
	var items = attacker_data.get("items", [])
	for item in items:
		var item_effects = item.get("effect_parsed", {}).get("effects", [])
		for effect in item_effects:
			var is_on_attack_success = (
				effect.get("trigger") == "on_attack_success" and effect.get("effect_type") == "apply_curse"
			) or effect.get("effect_type") == "on_attack_success_curse"
			
			if is_on_attack_success:
				var curse_type = effect.get("curse_type", "")
				var curse_result = _apply_curse_effect(curse_type, effect, item.get("name", "?"), defender_data)
				if curse_result.get("applied", false):
					result["applied"] = true
					result["curse_name"] = curse_result.get("curse_name", "")
	
	return result


## 呪い効果を適用するヘルパー関数
## @return Dictionary { "applied": bool, "curse_name": String }
static func _apply_curse_effect(curse_type: String, effect: Dictionary, source_name: String, defender_data: Dictionary) -> Dictionary:
	var curse_name = effect.get("name", "")
	match curse_type:
		"battle_disable":
			if curse_name.is_empty():
				curse_name = "戦闘行動不可"
			apply_battle_disable(defender_data, curse_name)
			print("【攻撃成功時呪い】", source_name, " → ", 
				  defender_data.get("name", "?"), " に戦闘行動不可を付与")
			return {"applied": true, "curse_name": curse_name}
		"plague":
			if curse_name.is_empty():
				curse_name = "衰弱"
			apply_plague(defender_data, curse_name)
			print("【攻撃成功時呪い】", source_name, " → ", 
				  defender_data.get("name", "?"), " に衰弱を付与")
			return {"applied": true, "curse_name": curse_name}
		"creature_toll_disable":
			if curse_name.is_empty():
				curse_name = "通行料無効"
			apply_creature_toll_disable(defender_data, curse_name)
			print("【攻撃成功時呪い】", source_name, " → ", 
				  defender_data.get("name", "?"), " に通行料無効を付与")
			return {"applied": true, "curse_name": curse_name}
	return {"applied": false, "curse_name": ""}


# =============================================================================
# 地形効果関連の呪い
# =============================================================================

## land_effect_disable 呪いを持っているかチェック（地形効果無効）
static func has_land_effect_disable(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type") == "land_effect_disable"


## land_effect_grant 呪いを持っているかチェック（地形効果付与）
static func has_land_effect_grant(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type") == "land_effect_grant"


## land_effect_disable 呪いを付与（地形効果無効）
static func apply_land_effect_disable(creature_data: Dictionary, name: String = "地形効果無効") -> void:
	creature_data["curse"] = {
		"curse_type": "land_effect_disable",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] 地形効果無効を付与: ", creature_data.get("name", "?"))


## land_effect_grant 呪いを付与（地形効果付与）
## params.grant_elements: 地形効果を得られる属性リスト（空の場合は全属性）
static func apply_land_effect_grant(creature_data: Dictionary, grant_elements: Array = [], name: String = "地形効果") -> void:
	creature_data["curse"] = {
		"curse_type": "land_effect_grant",
		"name": name,
		"duration": -1,
		"params": {
			"grant_elements": grant_elements
		}
	}
	var elements_str = "全属性" if grant_elements.is_empty() else str(grant_elements)
	print("[SpellCurseBattle] 地形効果付与: ", creature_data.get("name", "?"), " → ", elements_str)


# =============================================================================
# 地形効果拡張スキル（固有スキル）
# =============================================================================

## クリーチャーが追加で地形効果を得られる属性リストを取得
## 224 スプラウトリング: ["fire"]
## 316 サーペントフライ: ["water"]
## 430 ハーフリング: ["fire", "water", "earth", "wind"]
static func get_extra_land_elements(creature_data: Dictionary) -> Array:
	var ability_parsed = creature_data.get("ability_parsed", {})
	var extra_elements = ability_parsed.get("extra_land_elements", [])
	return extra_elements


## 地形効果を得られるかチェック（通常の属性一致 + 追加属性 + 呪い効果）
## creature_data: クリーチャーデータ
## tile_element: タイルの属性
## 戻り値: 地形効果を得られるかどうか
static func can_get_land_bonus(creature_data: Dictionary, tile_element: String) -> bool:
	# 地形効果無効呪いがあれば常にfalse
	if has_land_effect_disable(creature_data):
		print("  → 地形効果無効呪いにより無効")
		return false
	
	# 無属性タイルは全クリーチャーに地形効果を与える
	if tile_element == "neutral":
		print("  → 無属性タイル（全クリーチャーに地形効果）")
		return true
	
	var creature_element = creature_data.get("element", "")
	
	# 通常の属性一致チェック
	if creature_element == tile_element and TileHelper.is_element_type(creature_element):
		return true
	
	# 追加属性からの地形効果（固有スキル）
	var extra_elements = get_extra_land_elements(creature_data)
	if tile_element in extra_elements:
		print("  → 追加属性から地形効果: ", tile_element)
		return true
	
	# 地形効果付与呪いチェック
	if has_land_effect_grant(creature_data):
		var curse = creature_data.get("curse", {})
		var params = curse.get("params", {})
		var grant_elements = params.get("grant_elements", [])
		
		# grant_elementsが空なら全属性から地形効果を得る
		if grant_elements.is_empty():
			if TileHelper.is_element_type(tile_element):
				print("  → 地形効果付与呪い（全属性）")
				return true
		elif tile_element in grant_elements:
			print("  → 地形効果付与呪い: ", tile_element)
			return true
	
	return false


# =============================================================================
# メタルフォーム（metal_form）: 無効化[通常攻撃]、防具使用不可
# =============================================================================

## metal_form 呪いを持っているかチェック
static func has_metal_form(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type", "") == "metal_form"


## metal_form 呪いを付与
static func apply_metal_form(creature_data: Dictionary, name: String = "メタルフォーム") -> void:
	creature_data["curse"] = {
		"curse_type": "metal_form",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] メタルフォームを付与: ", creature_data.get("name", "?"))


# =============================================================================
# マジックバリア（magic_barrier）: 無効化[通常攻撃]、攻撃無効化時に敵にG100
# =============================================================================

## magic_barrier 呪いを持っているかチェック
static func has_magic_barrier(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type", "") == "magic_barrier"


## magic_barrier 呪いを付与
static func apply_magic_barrier(creature_data: Dictionary, name: String = "マジックバリア") -> void:
	creature_data["curse"] = {
		"curse_type": "magic_barrier",
		"name": name,
		"duration": -1,
		"params": {
			"gold_transfer": 100
		}
	}
	print("[SpellCurseBattle] マジックバリアを付与: ", creature_data.get("name", "?"))


# =============================================================================
# 戦闘後破壊（destroy_after_battle）: 次の戦闘で生き残った場合、戦闘後に破壊
# =============================================================================

## destroy_after_battle 呪いを持っているかチェック
static func has_destroy_after_battle(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type", "") == "destroy_after_battle"


## destroy_after_battle 呪いを付与
static func apply_destroy_after_battle(creature_data: Dictionary, name: String = "戦闘後破壊") -> void:
	creature_data["curse"] = {
		"curse_type": "destroy_after_battle",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] 戦闘後破壊を付与: ", creature_data.get("name", "?"))


# =============================================================================
# 通行料無効（creature_toll_disable）: クリーチャー単体の通行料が0になる
# =============================================================================

## creature_toll_disable 呪いを持っているかチェック
static func has_creature_toll_disable(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type", "") == "creature_toll_disable"


## creature_toll_disable 呪いを付与
static func apply_creature_toll_disable(creature_data: Dictionary, name: String = "通行料無効") -> void:
	creature_data["curse"] = {
		"curse_type": "creature_toll_disable",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] 通行料無効を付与: ", creature_data.get("name", "?"))

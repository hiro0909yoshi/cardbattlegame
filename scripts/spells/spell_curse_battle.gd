class_name SpellCurseBattle
extends RefCounted

## 戦闘制限刻印システム
## - skill_nullify: 錯乱（全スキル無効化）
## - battle_disable: 消沈（攻撃・アイテム・加勢使用不可）

# =============================================================================
# 刻印チェック
# =============================================================================

## battle_disable 刻印を持っているかチェック
static func has_battle_disable(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type") == "battle_disable"


## skill_nullify 刻印を持っているかチェック
static func has_skill_nullify(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type") == "skill_nullify"


# =============================================================================
# 刻印付与
# =============================================================================

## battle_disable 刻印を付与
static func apply_battle_disable(creature_data: Dictionary, name: String = "消沈") -> void:
	creature_data["curse"] = {
		"curse_type": "battle_disable",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] 消沈を付与: ", creature_data.get("name", "?"))


## skill_nullify 刻印を付与
static func apply_skill_nullify(creature_data: Dictionary, name: String = "錯乱") -> void:
	creature_data["curse"] = {
		"curse_type": "skill_nullify",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] 錯乱を付与: ", creature_data.get("name", "?"))


## plague 刻印を付与（衰弱: 戦闘終了時HP -= MHP/2）
static func apply_plague(creature_data: Dictionary, name: String = "衰弱") -> void:
	creature_data["curse"] = {
		"curse_type": "plague",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] 衰弱を付与: ", creature_data.get("name", "?"))


# =============================================================================
# 攻撃成功時の刻印付与チェック（ナイキー、バインドウィップ用）
# =============================================================================

## 攻撃成功時に刻印を付与するかチェックし、該当すれば付与
## attacker_data: 攻撃側のcreature_data
## defender_data: 防御側のcreature_data
## 戻り値: 刻印を付与したかどうか
## 攻撃成功時の刻印付与
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


## 刻印効果を適用するヘルパー関数
## @return Dictionary { "applied": bool, "curse_name": String }
static func _apply_curse_effect(curse_type: String, effect: Dictionary, source_name: String, defender_data: Dictionary) -> Dictionary:
	var curse_name = effect.get("name", "")
	match curse_type:
		"battle_disable":
			if curse_name.is_empty():
				curse_name = "消沈"
			apply_battle_disable(defender_data, curse_name)
			print("【攻撃成功時刻印】", source_name, " → ", 
				  defender_data.get("name", "?"), " に消沈を付与")
			return {"applied": true, "curse_name": curse_name}
		"plague":
			if curse_name.is_empty():
				curse_name = "衰弱"
			apply_plague(defender_data, curse_name)
			print("【攻撃成功時刻印】", source_name, " → ", 
				  defender_data.get("name", "?"), " に衰弱を付与")
			return {"applied": true, "curse_name": curse_name}
		"creature_toll_disable":
			if curse_name.is_empty():
				curse_name = "免罪"
			apply_creature_toll_disable(defender_data, curse_name)
			print("【攻撃成功時刻印】", source_name, " → ", 
				  defender_data.get("name", "?"), " に免罪を付与")
			return {"applied": true, "curse_name": curse_name}
	return {"applied": false, "curse_name": ""}


# =============================================================================
# 地形効果関連の刻印
# =============================================================================

## land_effect_disable 刻印を持っているかチェック（暗転）
static func has_land_effect_disable(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type") == "land_effect_disable"


## land_effect_grant 刻印を持っているかチェック（恩寵）
static func has_land_effect_grant(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type") == "land_effect_grant"


## land_effect_disable 刻印を付与（暗転）
static func apply_land_effect_disable(creature_data: Dictionary, name: String = "暗転") -> void:
	creature_data["curse"] = {
		"curse_type": "land_effect_disable",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] 暗転を付与: ", creature_data.get("name", "?"))


## land_effect_grant 刻印を付与（恩寵）
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
	print("[SpellCurseBattle] 恩寵: ", creature_data.get("name", "?"), " → ", elements_str)


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


## 地形効果を得られるかチェック（通常の属性一致 + 追加属性 + 刻印効果）
## creature_data: クリーチャーデータ
## tile_element: タイルの属性
## 戻り値: 地形効果を得られるかどうか
static func can_get_land_bonus(creature_data: Dictionary, tile_element: String) -> bool:
	# 暗転刻印があれば常にfalse
	if has_land_effect_disable(creature_data):
		print("  → 暗転刻印により無効")
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
	
	# 恩寵刻印チェック
	if has_land_effect_grant(creature_data):
		var curse = creature_data.get("curse", {})
		var params = curse.get("params", {})
		var grant_elements = params.get("grant_elements", [])
		
		# grant_elementsが空なら全属性から地形効果を得る
		if grant_elements.is_empty():
			if TileHelper.is_element_type(tile_element):
				print("  → 恩寵刻印（全属性）")
				return true
		elif tile_element in grant_elements:
			print("  → 恩寵刻印: ", tile_element)
			return true
	
	return false


# =============================================================================
# メタルフォーム（metal_form）: 無効化[通常攻撃]、防具使用不可
# =============================================================================

## metal_form 刻印を持っているかチェック
static func has_metal_form(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type", "") == "metal_form"


## metal_form 刻印を付与
static func apply_metal_form(creature_data: Dictionary, name: String = "メタルフォーム") -> void:
	creature_data["curse"] = {
		"curse_type": "metal_form",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] メタルフォームを付与: ", creature_data.get("name", "?"))


# =============================================================================
# マジックバリア（magic_barrier）: 無効化[通常攻撃]、攻撃無効化時に敵に100EP
# =============================================================================

## magic_barrier 刻印を持っているかチェック
static func has_magic_barrier(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type", "") == "magic_barrier"


## magic_barrier 刻印を付与
static func apply_magic_barrier(creature_data: Dictionary, name: String = "マジックバリア") -> void:
	creature_data["curse"] = {
		"curse_type": "magic_barrier",
		"name": name,
		"duration": -1,
		"params": {
			"ep_transfer": 100
		}
	}
	print("[SpellCurseBattle] マジックバリアを付与: ", creature_data.get("name", "?"))


# =============================================================================
# 崩壊（destroy_after_battle）: 次の戦闘で生き残った場合、戦闘後に破壊
# =============================================================================

## destroy_after_battle 刻印を持っているかチェック
static func has_destroy_after_battle(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type", "") == "destroy_after_battle"


## destroy_after_battle 刻印を付与
static func apply_destroy_after_battle(creature_data: Dictionary, name: String = "崩壊") -> void:
	creature_data["curse"] = {
		"curse_type": "destroy_after_battle",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] 崩壊を付与: ", creature_data.get("name", "?"))


# =============================================================================
# 免罪（creature_toll_disable）: クリーチャー単体の通行料が0になる
# =============================================================================

## creature_toll_disable 刻印を持っているかチェック
static func has_creature_toll_disable(creature_data: Dictionary) -> bool:
	var curse = creature_data.get("curse", {})
	return curse.get("curse_type", "") == "creature_toll_disable"


## creature_toll_disable 刻印を付与
static func apply_creature_toll_disable(creature_data: Dictionary, name: String = "免罪") -> void:
	creature_data["curse"] = {
		"curse_type": "creature_toll_disable",
		"name": name,
		"duration": -1,
		"params": {}
	}
	print("[SpellCurseBattle] 免罪を付与: ", creature_data.get("name", "?"))

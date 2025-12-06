## 戦闘中の土地効果スキル
##
## 攻撃成功時のダウン付与、土地変性、土地破壊など
## 土地タイルに対する効果を統一管理
##
## 【担当効果】
## - ショッカー: 攻撃成功時、敵をダウン
## - 将来: 土地変性、土地破壊など
##
## @version 1.0

class_name SkillLandEffects


# =============================================================================
# 攻撃成功時のダウン付与（ショッカー等）
# =============================================================================

## 攻撃成功時のダウン効果をチェックし、該当すれば適用
## @param attacker_data 攻撃側のcreature_data
## @param defender_tile 防御側のタイル（ダウン対象）
## @return ダウンを付与したかどうか
static func check_and_apply_on_attack_success_down(attacker_data: Dictionary, defender_tile: Node) -> bool:
	if not defender_tile:
		return false
	
	var applied = false
	
	# クリーチャー能力からチェック
	var ability_parsed = attacker_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("trigger") == "on_attack_success" and effect.get("effect_type") == "down_enemy":
			applied = _apply_down_to_tile(defender_tile, attacker_data.get("name", "?"))
			break
	
	# アイテムからチェック
	if not applied:
		var items = attacker_data.get("items", [])
		for item in items:
			var item_effects = item.get("effect_parsed", {}).get("effects", [])
			for effect in item_effects:
				if effect.get("trigger") == "on_attack_success" and effect.get("effect_type") == "down_enemy":
					applied = _apply_down_to_tile(defender_tile, item.get("name", "?"))
					break
			if applied:
				break
	
	return applied


## タイルにダウンを適用
static func _apply_down_to_tile(tile: Node, source_name: String) -> bool:
	if not tile:
		return false
	
	var creature_data = tile.creature_data if "creature_data" in tile else {}
	var creature_name = creature_data.get("name", "?")
	
	# 不屈チェック（ダウン無効）
	if _has_indomitable(creature_data):
		print("【ダウン無効】", creature_name, " は不屈を持っているためダウンしない")
		return false
	
	# 既にダウン中かチェック
	if tile.has_method("is_down") and tile.is_down():
		print("【ダウン済】", creature_name, " は既にダウン中")
		return false
	
	# ダウン適用
	if tile.has_method("set_down_state"):
		tile.set_down_state(true)
		print("【攻撃成功時ダウン】", source_name, " → ", creature_name, " をダウン")
		return true
	
	return false


## 不屈スキルを持っているかチェック
static func _has_indomitable(creature_data: Dictionary) -> bool:
	# キーワードチェック
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	if "不屈" in keywords:
		return true
	
	# 呪いチェック（不屈呪い）
	var curse = creature_data.get("curse", {})
	if curse.get("curse_type") == "indomitable":
		return true
	
	return false

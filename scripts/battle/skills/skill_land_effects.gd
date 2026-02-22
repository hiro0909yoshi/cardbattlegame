## 戦闘中の土地効果スキル
##
## 攻撃成功時のダウン付与、属性変化、土地破壊など
## 土地タイルに対する効果を統一管理
##
## 【担当効果】
## - ショッカー: 攻撃成功時、敵をダウン
## - 将来: 属性変化、土地破壊など
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
	
	# 奮闘チェック（ダウン無効）
	if _has_indomitable(creature_data):
		print("【ダウン無効】", creature_name, " は奮闘を持っているためダウンしない")
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


## 奮闘スキルを持っているかチェック
static func _has_indomitable(creature_data: Dictionary) -> bool:
	# キーワードチェック
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	if "奮闘" in keywords:
		return true
	
	# 刻印チェック（奮闘刻印）
	var curse = creature_data.get("curse", {})
	if curse.get("curse_type") == "indomitable":
		return true
	
	return false


# =============================================================================
# 戦闘勝利時の土地効果（属性変化・土地破壊）
# =============================================================================

## 戦闘勝利時の土地効果をチェックし適用
## @param winner_data 勝者のcreature_data
## @param tile_index 対象タイルのインデックス
## @param board_system ボードシステム参照
## @return 適用した効果の情報 { changed_element: String, level_reduced: bool }
static func check_and_apply_on_battle_won(winner_data: Dictionary, tile_index: int, board_system) -> Dictionary:
	var result = {
		"changed_element": "",
		"level_reduced": false
	}
	
	if not board_system:
		return result
	
	var ability_parsed = winner_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("trigger") != "on_battle_won":
			continue
		
		var effect_type = effect.get("effect_type", "")
		
		match effect_type:
			"change_tile_element":
				# 属性変化
				var new_element = effect.get("element", "")
				if new_element.is_empty():
					continue
				
				# バロンチェック（領土守護）
				if _tile_has_land_protection(tile_index, board_system):
					print("【不変】タイル%dは領土守護を持っています" % tile_index)
					continue
				
				# spell_land経由で属性変更
				if board_system:
					var success = board_system.change_tile_element(tile_index, new_element)
					if success:
						result["changed_element"] = new_element
						print("【属性変化】%s がタイル%dを%sに変性" % [
							winner_data.get("name", "?"), tile_index, new_element
						])
			
			"reduce_tile_level":
				# 土地破壊（レベル-1）
				var amount = effect.get("amount", 1)
				
				# バロンチェック（領土守護）
				if _tile_has_land_protection(tile_index, board_system):
					print("【土地破壊無効】タイル%dは領土守護を持っています" % tile_index)
					continue
				
				# spell_land経由でレベル変更
				if board_system:
					var success = board_system.change_tile_level(tile_index, -amount)
					if success:
						result["level_reduced"] = true
						print("【土地破壊】%s がタイル%dのレベルを-%d" % [
							winner_data.get("name", "?"), tile_index, amount
						])
	
	return result


## タイルが領土守護を持っているかチェック
## @param tile_index タイルインデックス
## @param board_system ボードシステム参照
## @return 無効化スキルを持っているか
static func _tile_has_land_protection(tile_index: int, board_system) -> bool:
	if not board_system or not board_system.tile_nodes.has(tile_index):
		return false
	
	var tile = board_system.tile_nodes[tile_index]
	var creature_data = tile.creature_data if "creature_data" in tile else {}
	
	if creature_data.is_empty():
		return false
	
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	return "領土守護" in keywords


## タイルのクリーチャーが領土守護を持っているか（外部公開用）
## @param creature_data クリーチャーデータ
## @return 無効化スキルを持っているか
static func has_land_protection(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	return "領土守護" in keywords

# SpellDamage - ダメージ・回復処理の統合クラス
# スペル・秘術共通で使用
class_name SpellDamage

var board_system_ref: Node = null

func _init(board_system: Node):
	board_system_ref = board_system

# ============================================
# ダメージ処理
# ============================================

## ダメージを適用（スペル・秘術共通）
## 戻り値: {success: bool, old_hp: int, new_hp: int, max_hp: int, destroyed: bool, creature_name: String}
func apply_damage(tile_index: int, value: int) -> Dictionary:
	var result = {
		"success": false,
		"old_hp": 0,
		"new_hp": 0,
		"max_hp": 0,
		"destroyed": false,
		"creature_name": ""
	}
	
	if not board_system_ref or tile_index < 0:
		return result
	
	if not board_system_ref.tile_nodes.has(tile_index):
		return result
	
	var tile = board_system_ref.tile_nodes[tile_index]
	if not tile or tile.creature_data.is_empty():
		return result
	
	var creature = tile.creature_data
	result["creature_name"] = creature.get("name", "Unknown")
	
	# MHP計算
	var base_hp = creature.get("hp", 0)
	var base_up_hp = creature.get("base_up_hp", 0)
	var max_hp = base_hp + base_up_hp
	result["max_hp"] = max_hp
	
	# current_hp取得（存在しない場合はMHP）
	var current_hp = creature.get("current_hp", max_hp)
	result["old_hp"] = current_hp
	
	# ダメージ適用
	var new_hp = max(0, current_hp - value)
	creature["current_hp"] = new_hp
	result["new_hp"] = new_hp
	result["success"] = true
	
	print("[SpellDamage] %s に %d ダメージ (HP: %d → %d / MHP: %d)" % [
		result["creature_name"], value, current_hp, new_hp, max_hp
	])
	
	# 撃破判定
	if new_hp <= 0:
		_destroy_creature(tile)
		result["destroyed"] = true
	
	return result


## クリーチャー破壊（レベル維持）
func _destroy_creature(tile: Node) -> void:
	var creature_name = tile.creature_data.get("name", "Unknown")
	var saved_level = tile.level  # レベル保存
	
	# クリーチャーデータをクリア（CreatureManagerと同期）
	tile.creature_data = {}
	tile.owner_id = -1
	tile.level = saved_level  # レベル維持（空き地として残る）
	
	if tile.has_method("update_visual"):
		tile.update_visual()
	
	print("[SpellDamage] クリーチャー撃破: %s (土地レベル %d 維持)" % [
		creature_name, saved_level
	])

# ============================================
# 回復処理
# ============================================

## HP回復を適用
## 戻り値: {success: bool, old_hp: int, new_hp: int, max_hp: int, creature_name: String}
func apply_heal(tile_index: int, value: int) -> Dictionary:
	var result = {
		"success": false,
		"old_hp": 0,
		"new_hp": 0,
		"max_hp": 0,
		"creature_name": ""
	}
	
	if not board_system_ref or tile_index < 0:
		return result
	
	if not board_system_ref.tile_nodes.has(tile_index):
		return result
	
	var tile = board_system_ref.tile_nodes[tile_index]
	if not tile or tile.creature_data.is_empty():
		return result
	
	var creature = tile.creature_data
	result["creature_name"] = creature.get("name", "Unknown")
	
	# MHP計算
	var base_hp = creature.get("hp", 0)
	var base_up_hp = creature.get("base_up_hp", 0)
	var max_hp = base_hp + base_up_hp
	result["max_hp"] = max_hp
	
	# current_hp取得
	var current_hp = creature.get("current_hp", max_hp)
	result["old_hp"] = current_hp
	
	# 回復適用（MHPを超えない）
	var new_hp = min(current_hp + value, max_hp)
	creature["current_hp"] = new_hp
	result["new_hp"] = new_hp
	result["success"] = true
	
	print("[SpellDamage] %s を %d 回復 (HP: %d → %d / MHP: %d)" % [
		result["creature_name"], value, current_hp, new_hp, max_hp
	])
	
	return result


## HP全回復
## 戻り値: {success: bool, old_hp: int, new_hp: int, max_hp: int, creature_name: String}
func apply_full_heal(tile_index: int) -> Dictionary:
	var result = {
		"success": false,
		"old_hp": 0,
		"new_hp": 0,
		"max_hp": 0,
		"creature_name": ""
	}
	
	if not board_system_ref or tile_index < 0:
		return result
	
	if not board_system_ref.tile_nodes.has(tile_index):
		return result
	
	var tile = board_system_ref.tile_nodes[tile_index]
	if not tile or tile.creature_data.is_empty():
		return result
	
	var creature = tile.creature_data
	result["creature_name"] = creature.get("name", "Unknown")
	
	# MHP計算
	var base_hp = creature.get("hp", 0)
	var base_up_hp = creature.get("base_up_hp", 0)
	var max_hp = base_hp + base_up_hp
	result["max_hp"] = max_hp
	
	# current_hp取得
	var current_hp = creature.get("current_hp", max_hp)
	result["old_hp"] = current_hp
	
	# 全回復
	creature["current_hp"] = max_hp
	result["new_hp"] = max_hp
	result["success"] = true
	
	print("[SpellDamage] %s HP全回復 (HP: %d → %d)" % [
		result["creature_name"], current_hp, max_hp
	])
	
	return result

# ============================================
# 通知テキスト生成
# ============================================

## ダメージ通知テキストを生成
static func format_damage_notification(result: Dictionary, damage_value: int) -> String:
	var text = "%sに%dダメージ！\n" % [result["creature_name"], damage_value]
	text += "HP: %d/%d → %d/%d" % [result["old_hp"], result["max_hp"], result["new_hp"], result["max_hp"]]
	
	if result["destroyed"]:
		text += "\n%sは倒された！" % result["creature_name"]
	
	return text


## 回復通知テキストを生成
static func format_heal_notification(result: Dictionary, heal_value: int = -1) -> String:
	var text = ""
	if heal_value > 0:
		text = "%sのHPが%d回復！\n" % [result["creature_name"], heal_value]
	else:
		text = "%sのHPが全回復！\n" % result["creature_name"]
	
	text += "HP: %d/%d → %d/%d" % [result["old_hp"], result["max_hp"], result["new_hp"], result["max_hp"]]
	return text

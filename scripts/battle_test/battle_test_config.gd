# バトルテスト設定データ
class_name BattleTestConfig
extends RefCounted

## 攻撃側設定
var attacker_creatures: Array = []      # クリーチャーID配列 (int配列)
var attacker_items: Array = []          # アイテムID配列 (int配列)
var attacker_spell: int = -1                 # スペルID (-1 = なし)
var attacker_owned_lands: Dictionary = {     # 保有土地数
	"fire": 0,
	"water": 0,
	"earth": 0,
	"wind": 0
}
var attacker_battle_land: String = "neutral"    # バトル発生土地の属性
var attacker_battle_land_level: int = 1      # バトル発生土地のレベル (1-5)
var attacker_has_adjacent: bool = false      # 隣接味方ドミニオあり

## 防御側設定
var defender_creatures: Array = []  # (int配列)
var defender_items: Array = []  # (int配列)
var defender_spell: int = -1
var defender_owned_lands: Dictionary = {
	"fire": 0,
	"water": 0,
	"earth": 0,
	"wind": 0
}
var defender_battle_land: String = "neutral"
var defender_battle_land_level: int = 1      # バトル発生土地のレベル (1-5)
var defender_has_adjacent: bool = false

## バリデーション
func validate() -> bool:
	if attacker_creatures.is_empty():
		push_error("攻撃側クリーチャーが未選択")
		return false
	if defender_creatures.is_empty():
		push_error("防御側クリーチャーが未選択")
		return false
	return true

## 設定の入れ替え
func swap_attacker_defender():
	# クリーチャー入れ替え
	var temp_creatures = attacker_creatures
	attacker_creatures = defender_creatures
	defender_creatures = temp_creatures
	
	# アイテム入れ替え
	var temp_items = attacker_items
	attacker_items = defender_items
	defender_items = temp_items
	
	# スペル入れ替え
	var temp_spell = attacker_spell
	attacker_spell = defender_spell
	defender_spell = temp_spell
	
	# 保有土地入れ替え
	var temp_lands = attacker_owned_lands.duplicate()
	attacker_owned_lands = defender_owned_lands.duplicate()
	defender_owned_lands = temp_lands
	
	# バトル土地入れ替え
	var temp_battle_land = attacker_battle_land
	attacker_battle_land = defender_battle_land
	defender_battle_land = temp_battle_land
	
	# バトル土地レベル入れ替え
	var temp_land_level = attacker_battle_land_level
	attacker_battle_land_level = defender_battle_land_level
	defender_battle_land_level = temp_land_level
	
	# 隣接条件入れ替え
	var temp_adjacent = attacker_has_adjacent
	attacker_has_adjacent = defender_has_adjacent
	defender_has_adjacent = temp_adjacent

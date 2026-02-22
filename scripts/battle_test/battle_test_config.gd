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

	# ========== 新規追加: 刻印スペル入れ替え ==========
	var temp_curse_spell = attacker_curse_spell_id
	attacker_curse_spell_id = defender_curse_spell_id
	defender_curse_spell_id = temp_curse_spell

## ========== 新規追加: 刻印スペル設定 ==========

## 刻印スペルID（0 = 刻印なし）
var attacker_curse_spell_id: int = 0
var defender_curse_spell_id: int = 0

## ========== 新規追加: バフ設定 ==========

## 攻撃側バフ設定
var attacker_buff_config: Dictionary = {
	"base_up_hp": 0,
	"base_up_ap": 0,
	"item_bonus_hp": 0,
	"item_bonus_ap": 0,
	"spell_bonus_hp": 0,
	"permanent_effects": [],
	"temporary_effects": []
}

## 防御側バフ設定
var defender_buff_config: Dictionary = {
	"base_up_hp": 0,
	"base_up_ap": 0,
	"item_bonus_hp": 0,
	"item_bonus_ap": 0,
	"spell_bonus_hp": 0,
	"permanent_effects": [],
	"temporary_effects": []
}

## ========== 新規追加: ビジュアルモード設定 ==========

## ビジュアルモード（BattleScreen表示）
var visual_mode: bool = false

## 自動進行（クリック待ちなし）
var auto_advance: bool = false

## バトル速度（1.0 = 通常速度）
var battle_speed: float = 1.0

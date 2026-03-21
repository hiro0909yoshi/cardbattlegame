# バトルテスト結果データ
class_name BattleTestResult
extends RefCounted

## 基本情報
var battle_id: int

## 攻撃側情報
var attacker_id: int
var attacker_name: String
var attacker_item_id: int
var attacker_item_name: String
var attacker_spell_id: int
var attacker_spell_name: String
var attacker_base_ap: int                    # 基礎AP
var attacker_base_hp: int                    # 基礎HP
var attacker_final_ap: int                   # 最終AP（スキル適用後）
var attacker_final_hp: int                   # 残HP
var attacker_skills_triggered: Array = []  # 発動したスキル (String配列)
var attacker_granted_skills: Array = []    # アイテム・スペルで付与されたスキル (String配列)
var attacker_effect_info: Dictionary = {}  # 効果情報（base_up_hp/ap, 効果配列）

## 防御側情報
var defender_id: int
var defender_name: String
var defender_item_id: int
var defender_item_name: String
var defender_spell_id: int
var defender_spell_name: String
var defender_base_ap: int
var defender_base_hp: int
var defender_final_ap: int
var defender_final_hp: int
var defender_skills_triggered: Array = []  # (String配列)
var defender_granted_skills: Array = []  # (String配列)
var defender_effect_info: Dictionary = {}  # 効果情報（base_up_hp/ap, 効果配列）

## バトル結果
var winner: String  # "attacker" or "defender"
var battle_duration_ms: int  # バトル実行時間（ミリ秒）

## バトル条件
var battle_land: String
var attacker_owned_lands: Dictionary
var defender_owned_lands: Dictionary
var attacker_has_adjacent: bool
var defender_has_adjacent: bool

## ダメージ詳細
var damage_dealt_by_attacker: int
var damage_dealt_by_defender: int
var first_strike_occurred: bool  # 先制攻撃が発生したか

## 帰還結果
var attacker_item_returned: bool = false    # 攻撃側アイテムが復帰したか
var attacker_item_return_type: String = ""  # "hand" or "deck" or ""
var defender_item_returned: bool = false    # 防御側アイテムが復帰したか
var defender_item_return_type: String = ""  # "hand" or "deck" or ""

## 手札復活結果
var attacker_revive_to_hand: bool = false  # 攻撃側が手札復活したか
var defender_revive_to_hand: bool = false  # 防御側が手札復活したか

## 手札枚数（形見[カード]等の検証用）
var attacker_hand_count: int = 0
var defender_hand_count: int = 0

## 術攻撃フラグ
var attacker_is_using_scroll: bool = false
var defender_is_using_scroll: bool = false

## ダウン状態（攻撃成功時ダウン等）
var defender_tile_down: bool = false

## 勝利時土地効果
var land_effect_changed_element: String = ""  # 属性変化先（""=なし）
var land_effect_level_reduced: bool = false    # 土地破壊が発生したか

## 刻印情報（バトル後のcreature_data["curse"]）
var attacker_curse: Dictionary = {}  # {"curse_type": "...", "name": "..."} or {}
var defender_curse: Dictionary = {}  # {"curse_type": "...", "name": "..."} or {}

## バトル中に実際に発動した効果（状態差分から検出）
var attacker_battle_effects: Array = []  # 例: ["蓄魔", "変質", "刻印[消沈]"]
var defender_battle_effects: Array = []

## CSV/JSON出力用
func to_dict() -> Dictionary:
	return {
		"battle_id": battle_id,
		"attacker_name": attacker_name,
		"attacker_item": attacker_item_name,
		"attacker_spell": attacker_spell_name,
		"attacker_base_ap": attacker_base_ap,
		"attacker_final_ap": attacker_final_ap,
		"attacker_final_hp": attacker_final_hp,
		"attacker_skills": ",".join(attacker_skills_triggered),
		"attacker_granted_skills": ",".join(attacker_granted_skills),
		"defender_name": defender_name,
		"defender_item": defender_item_name,
		"defender_spell": defender_spell_name,
		"defender_base_ap": defender_base_ap,
		"defender_final_ap": defender_final_ap,
		"defender_final_hp": defender_final_hp,
		"defender_skills": ",".join(defender_skills_triggered),
		"defender_granted_skills": ",".join(defender_granted_skills),
		"winner": winner,
		"damage_attacker": damage_dealt_by_attacker,
		"damage_defender": damage_dealt_by_defender,
		"battle_land": battle_land,
	}

## デバッグ用文字列
func get_summary() -> String:
	return "[%d] %s vs %s → 勝者: %s" % [
		battle_id,
		attacker_name,
		defender_name,
		winner
	]

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

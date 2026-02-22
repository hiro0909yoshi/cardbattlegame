extends Node
class_name SkillLogSystem

# スキル・戦闘ログを管理・表示するシステム
# 全てのスキル発動を記録し、視覚的に表示

signal log_added(log_entry: Dictionary)
signal battle_started(attacker: String, defender: String)
signal battle_ended(result: Dictionary)

# ログタイプ
enum LogType {
	SKILL_ACTIVATED,    # スキル発動
	BATTLE_START,       # 戦闘開始
	BATTLE_DAMAGE,      # ダメージ
	BATTLE_END,         # 戦闘終了
	CONDITION_CHECK,    # 条件判定
	EFFECT_APPLIED,     # 効果適用
	KEYWORD_TRIGGERED   # キーワード発動
}

# ログ保存用配列
var battle_logs: Array = []
var current_battle_logs: Array = []  # 現在の戦闘のログ
var max_log_entries: int = 100

# 色設定
var log_colors = {
	LogType.SKILL_ACTIVATED: Color.YELLOW,
	LogType.BATTLE_START: Color.CYAN,
	LogType.BATTLE_DAMAGE: Color.RED,
	LogType.BATTLE_END: Color.GREEN,
	LogType.CONDITION_CHECK: Color.GRAY,
	LogType.EFFECT_APPLIED: Color.ORANGE,
	LogType.KEYWORD_TRIGGERED: Color.MAGENTA
}

# スキル発動ログ
func log_skill_activation(skill_name: String, user: String, target: String = "", details: Dictionary = {}):
	var entry = {
		"type": LogType.SKILL_ACTIVATED,
		"timestamp": Time.get_ticks_msec(),
		"skill_name": skill_name,
		"user": user,
		"target": target,
		"details": details,
		"message": _format_skill_message(skill_name, user, target, details)
	}
	_add_log(entry)
	return entry

# キーワード能力発動ログ
func log_keyword_triggered(keyword: String, creature_name: String, effect_details: Dictionary = {}):
	var entry = {
		"type": LogType.KEYWORD_TRIGGERED,
		"timestamp": Time.get_ticks_msec(),
		"keyword": keyword,
		"creature": creature_name,
		"details": effect_details,
		"message": _format_keyword_message(keyword, creature_name, effect_details)
	}
	_add_log(entry)
	return entry

# 戦闘開始ログ
func log_battle_start(attacker: Dictionary, defender: Dictionary, field_info: Dictionary = {}):
	current_battle_logs.clear()
	
	var entry = {
		"type": LogType.BATTLE_START,
		"timestamp": Time.get_ticks_msec(),
		"attacker": attacker.get("name", "不明"),
		"attacker_stats": {
			"ap": attacker.get("ap", 0),
			"hp": attacker.get("hp", 0),
			"element": attacker.get("element", "")
		},
		"defender": defender.get("name", "不明"),
		"defender_stats": {
			"ap": defender.get("ap", 0),
			"hp": defender.get("hp", 0),
			"element": defender.get("element", "")
		},
		"field": field_info,
		"message": "【戦闘開始】%s (AP:%d/HP:%d) vs %s (AP:%d/HP:%d)" % [
			attacker.get("name", "不明"),
			attacker.get("ap", 0),
			attacker.get("hp", 0),
			defender.get("name", "不明"),
			defender.get("ap", 0),
			defender.get("hp", 0)
		]
	}
	_add_log(entry)
	emit_signal("battle_started", entry.attacker, entry.defender)
	return entry

# 条件チェックログ
func log_condition_check(condition_type: String, result: bool, details: Dictionary = {}):
	var entry = {
		"type": LogType.CONDITION_CHECK,
		"timestamp": Time.get_ticks_msec(),
		"condition": condition_type,
		"result": result,
		"details": details,
		"message": "  条件判定[%s]: %s %s" % [
			condition_type,
			"✓" if result else "✗",
			_format_condition_details(condition_type, details)
		]
	}
	_add_log(entry)
	return entry

# 効果適用ログ
func log_effect_applied(effect_type: String, target: String, value: Variant, details: Dictionary = {}):
	var entry = {
		"type": LogType.EFFECT_APPLIED,
		"timestamp": Time.get_ticks_msec(),
		"effect": effect_type,
		"target": target,
		"value": value,
		"details": details,
		"message": _format_effect_message(effect_type, target, value, details)
	}
	_add_log(entry)
	return entry

# ダメージログ
func log_battle_damage(source: String, target: String, damage: int, damage_type: String = "通常"):
	var entry = {
		"type": LogType.BATTLE_DAMAGE,
		"timestamp": Time.get_ticks_msec(),
		"source": source,
		"target": target,
		"damage": damage,
		"damage_type": damage_type,
		"message": "  %s → %s: %d ダメージ (%s)" % [source, target, damage, damage_type]
	}
	_add_log(entry)
	return entry

# 戦闘終了ログ
func log_battle_end(winner: String, loser: String, reason: String = ""):
	var entry = {
		"type": LogType.BATTLE_END,
		"timestamp": Time.get_ticks_msec(),
		"winner": winner,
		"loser": loser,
		"reason": reason,
		"message": "【戦闘終了】勝者: %s %s" % [winner, ("(" + reason + ")") if reason else ""],
		"battle_summary": current_battle_logs.duplicate()
	}
	_add_log(entry)
	emit_signal("battle_ended", {"winner": winner, "loser": loser})
	return entry

# 強化専用ログ
func log_power_strike(creature_name: String, base_ap: int, modified_ap: int, condition: String):
	var increase = modified_ap - base_ap
	var percentage = int((float(modified_ap) / float(base_ap) - 1.0) * 100)
	
	return log_keyword_triggered("強化", creature_name, {
		"base_ap": base_ap,
		"modified_ap": modified_ap,
		"increase": increase,
		"percentage": percentage,
		"condition": condition,
		"message_override": "【強化発動！】%s: AP %d → %d (+%d, +%d%%) [条件: %s]" % [
			creature_name, base_ap, modified_ap, increase, percentage, condition
		]
	})

# 先制攻撃ログ
func log_first_strike(creature_name: String):
	return log_keyword_triggered("先制", creature_name, {
		"message_override": "【先制攻撃】%s が先制攻撃！" % creature_name
	})

# 無効化ログ
func log_nullification(defender_name: String, attack_type: String):
	return log_keyword_triggered("無効化", defender_name, {
		"attack_type": attack_type,
		"message_override": "【無効化】%s が %s を無効化！" % [defender_name, attack_type]
	})

# 内部：ログ追加
func _add_log(entry: Dictionary):
	current_battle_logs.append(entry)
	battle_logs.append(entry)
	
	# 最大数を超えたら古いものを削除
	if battle_logs.size() > max_log_entries:
		battle_logs.pop_front()
	
	# コンソール出力
	print(entry.message)
	
	# シグナル発信
	emit_signal("log_added", entry)

# フォーマット用ヘルパー関数
func _format_skill_message(skill_name: String, user: String, target: String, details: Dictionary) -> String:
	var msg = "【%s】使用者: %s" % [skill_name, user]
	if target:
		msg += " → 対象: %s" % target
	if details.has("message_override"):
		return details.message_override
	return msg

func _format_keyword_message(keyword: String, creature: String, details: Dictionary) -> String:
	if details.has("message_override"):
		return details.message_override
	return "【%s】%s の能力が発動！" % [keyword, creature]

func _format_condition_details(condition_type: String, details: Dictionary) -> String:
	match condition_type:
		"mhp_below":
			return "(MHP %d 以下)" % details.get("value", 0)
		"mhp_above":
			return "(MHP %d 以上)" % details.get("value", 0)
		"enemy_element":
			return "(敵属性: %s)" % details.get("element", "")
		"on_element_land":
			return "(土地属性: %s)" % details.get("element", "")
		"has_all_elements":
			return "(火水地風全て保有)"
		"enemy_no_item":
			return "(敵アイテムなし)"
		"with_weapon":
			return "(武器装備中)"
		"adjacent_ally_land":
			return "(隣接地が自ドミニオ)"
		_:
			return ""

func _format_effect_message(effect_type: String, target: String, value: Variant, details: Dictionary) -> String:
	match effect_type:
		"modify_stats":
			var stat = details.get("stat", "")
			var operation = details.get("operation", "")
			return "  効果: %s の %s %s%s" % [
				target, stat,
				"+" if operation == "add" else "",
				str(value)
			]
		"power_strike":
			return "  効果: %s の攻撃力 ×%.1f" % [target, value]
		_:
			return "  効果: %s に %s (%s)" % [target, effect_type, str(value)]

# 現在の戦闘ログを取得
func get_current_battle_logs() -> Array:
	return current_battle_logs

# 全ログを取得
func get_all_logs() -> Array:
	return battle_logs

# ログをクリア
func clear_logs():
	battle_logs.clear()
	current_battle_logs.clear()

# ログを文字列として出力
func export_logs_as_text() -> String:
	var text = "=== 戦闘・スキルログ ===\n"
	for entry in battle_logs:
		text += "[%s] %s\n" % [
			Time.get_time_string_from_system(),
			entry.message
		]
	return text

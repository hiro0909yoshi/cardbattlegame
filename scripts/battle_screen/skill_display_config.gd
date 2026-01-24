## スキル表示設定（マッピングテーブル）
##
## スキル発動時の表示名・エフェクト・SEを一元管理する。
## effect_type（英語）から表示情報を取得できる。
##
## 使い方:
##   var config = SkillDisplayConfig.get_config("penetration")
##   # → {"name": "貫通", "effect": "", "sound": ""}
##
## パラメータ分岐:
##   var config = SkillDisplayConfig.get_config("change_tile_element", {"element": "water"})
##   # → {"name": "土地変性", "effect": "element_change_water", "sound": ""}

class_name SkillDisplayConfig

## スキル設定テーブル
const CONFIG = {
	# ========================================
	# 戦闘開始前に発動するスキル
	# ========================================
	"stat_change": {
		"name": "ステータス変化",
		"effect": "",
		"sound": ""
	},
	"random_stat": {
		"name": "ランダムステータス",
		"effect": "",
		"sound": ""
	},
	"support": {
		"name": "応援",
		"effect": "",
		"sound": ""
	},
	"assist": {
		"name": "援護",
		"effect": "",
		"sound": ""
	},
	"merge": {
		"name": "合体",
		"effect": "",
		"sound": ""
	},
	"first_strike": {
		"name": "先制",
		"effect": "",
		"sound": ""
	},
	"last_strike": {
		"name": "後手",
		"effect": "",
		"sound": ""
	},
	"resonance": {
		"name": "感応",
		"effect": "",
		"sound": ""
	},
	"power_strike": {
		"name": "強打",
		"effect": "",
		"sound": ""
	},
	"penetration": {
		"name": "貫通",
		"effect": "",
		"sound": ""
	},
	"scroll_attack": {
		"name": "巻物攻撃",
		"effect": "",
		"sound": ""
	},
	"scroll_power_strike": {
		"name": "巻物強打",
		"effect": "",
		"sound": ""
	},
	
	# ========================================
	# 戦闘終了時に発動するスキル
	# ========================================
	"regeneration": {
		"name": "再生",
		"effect": "",
		"sound": ""
	},
	"swap_ap_mhp": {
		"name": "AP⇔MHP交換",
		"effect": "",
		"sound": ""
	},
	"reduce_enemy_mhp": {
		"name": "MHP減少",
		"effect": "",
		"sound": ""
	},
	"level_up_battle_land": {
		"name": "土地レベルアップ",
		"effect": "",
		"sound": ""
	},
	"item_return": {
		"name": "アイテム復帰",
		"effect": "",
		"sound": ""
	},
	
	# ========================================
	# 死亡時に発動するスキル
	# ========================================
	"self_destruct": {
		"name": "自壊",
		"effect": "",
		"sound": ""
	},
	"death_revenge": {
		"name": "道連れ",
		"effect": "",
		"sound": ""
	},
	"legacy_magic": {
		"name": "遺産（魔力）",
		"effect": "",
		"sound": ""
	},
	"legacy_card": {
		"name": "遺産（カード）",
		"effect": "",
		"sound": ""
	},
	"revive": {
		"name": "死者復活",
		"effect": "",
		"sound": ""
	},
	"revive_to_hand": {
		"name": "手札復活",
		"effect": "",
		"sound": ""
	},
	"annihilate": {
		"name": "抹消",
		"effect": "",
		"sound": ""
	},
	"revenge_mhp_damage": {
		"name": "雪辱",
		"effect": "",
		"sound": ""
	},
	"apply_curse": {
		"name": "呪い付与",
		"effect": "",
		"sound": ""
	},
	
	# ========================================
	# 攻撃成功時に発動するスキル
	# ========================================
	"ap_drain": {
		"name": "APドレイン",
		"effect": "",
		"sound": ""
	},
	"destroy_item": {
		"name": "アイテム破壊",
		"effect": "",
		"sound": ""
	},
	"steal_item": {
		"name": "アイテム盗み",
		"effect": "",
		"sound": ""
	},
	"magic_gain": {
		"name": "魔力獲得",
		"effect": "",
		"sound": ""
	},
	
	# ========================================
	# 即死・反射判定時に発動するスキル
	# ========================================
	"instant_death": {
		"name": "即死",
		"effect": "",
		"sound": ""
	},
	"reflect_damage": {
		"name": "反射",
		"effect": "",
		"sound": ""
	},
	"transform": {
		"name": "変身",
		"effect": "",
		"sound": ""
	},
	"nullify_abilities": {
		"name": "能力無効化",
		"effect": "",
		"sound": ""
	},
	
	# ========================================
	# パラメータ分岐が必要なスキル
	# ========================================
	"change_tile_element": {
		"name": "土地変性",
		"effect_by_element": {
			"water": "element_change_water",
			"fire": "element_change_fire",
			"wind": "element_change_wind",
			"earth": "element_change_earth"
		},
		"sound": ""
	}
}

## 設定を取得
##
## @param effect_type: スキルのeffect_type
## @param params: 分岐用パラメータ（省略可）
## @return: {name, effect, sound} または空Dictionary
static func get_config(effect_type: String, params: Dictionary = {}) -> Dictionary:
	var base = CONFIG.get(effect_type, {})
	if base.is_empty():
		return {}
	
	var result = {
		"name": base.get("name", ""),
		"effect": "",
		"sound": base.get("sound", "")
	}
	
	# パラメータに基づいてエフェクト決定
	if base.has("effect_by_element") and params.has("element"):
		result["effect"] = base["effect_by_element"].get(params["element"], "")
	else:
		result["effect"] = base.get("effect", "")
	
	return result

## スキル名を取得（簡易版）
##
## @param effect_type: スキルのeffect_type
## @return: スキル名（見つからなければ空文字）
static func get_skill_name(effect_type: String) -> String:
	var config = CONFIG.get(effect_type, {})
	return config.get("name", "")

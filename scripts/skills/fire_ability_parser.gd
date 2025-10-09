# 火属性カードのability_parsed追加スクリプト

extends Node

# このスクリプトは火属性カードにability_parsedを追加するためのパーサー
# 実際にはJSONファイルに直接追加する必要がありますが、
# ここではパース例を示します

func parse_fire_abilities():
	var parsed_abilities = {
		# ID: 1 - アームドパラディン
		1: {
			"effects": [
				{
					"effect_type": "set_stats",
					"target": "self",
					"stat": "AP",
					"formula": "fire_lands * 10"
				},
				{
					"effect_type": "nullify",
					"nullify_type": "scroll"
				}
			]
		},
		
		# ID: 2 - アモン
		2: {
			"effects": [
				{
					"effect_type": "affinity",
					"element": "火",
					"st_bonus": 20,
					"hp_bonus": 20,
					"conditions": [
						{"condition_type": "element_land_count", "element": "火", "count": 1}
					]
				}
			],
			"keywords": ["防魔"]
		},
		
		# ID: 4 - ウリエル
		4: {
			"keywords": ["強打"],
			"keyword_conditions": {
				"強打": {
					"condition_type": "has_mark",
					"mark": "○"
				}
			},
			"effects": [
				{
					"effect_type": "power_strike",
					"multiplier": 1.5,
					"conditions": [
						{"condition_type": "has_mark", "mark": "○"}
					]
				}
			]
		},
		
		# ID: 7 - キメラ
		7: {
			"keywords": ["先制"],
			"effects": [
				{
					"effect_type": "modify_stats",
					"target": "self",
					"stat": "AP",
					"operation": "add",
					"formula": "turn_count * 10"
				}
			]
		},
		
		# ID: 9 - グラディエーター
		9: {
			"keywords": ["強打"],
			"keyword_conditions": {
				"強打": {
					"condition_type": "has_all_elements"
				}
			},
			"effects": [
				{
					"effect_type": "power_strike",
					"multiplier": 1.5,
					"conditions": [
						{"condition_type": "has_all_elements"}
					]
				}
			]
		},
		
		# ID: 11 - ケットシー
		11: {
			"keywords": ["防魔"],
			"effects": [
				{
					"effect_type": "nullify",
					"nullify_type": "st_above",
					"value": 40
				}
			]
		},
		
		# ID: 12 - コンジャラー
		12: {
			"keywords": ["巻物強打"],
			"effects": [
				{
					"effect_type": "scroll_power_strike",
					"multiplier": 1.5
				}
			]
		},
		
		# ID: 14 - シールドメイデン
		14: {
			"keywords": ["不屈"]
		},
		
		# ID: 15 - ジェネラルカン
		15: {
			"keywords": ["先制"],
			"effects": [
				{
					"effect_type": "modify_stats",
					"target": "self",
					"stat": "AP",
					"operation": "add",
					"formula": "mhp50_count * 5"
				}
			]
		},
		
		# ID: 16 - シグルド
		16: {
			"effects": [
				{
					"effect_type": "instant_death",
					"conditions": [
						{"condition_type": "st_above", "value": 50}
					],
					"probability": 60
				},
				{
					"effect_type": "nullify",
					"nullify_type": "mhp_above",
					"value": 50
				}
			]
		},
		
		# ID: 17 - シャラザード
		17: {
			"keywords": ["援護"],
			"keyword_conditions": {
				"援護": {
					"elements": ["火"]
				}
			}
		},
		
		# ID: 18 - ショッカー
		18: {
			"keywords": ["先制", "不屈"],
			"effects": [
				{
					"effect_type": "down_status",
					"target": "enemy",
					"trigger": "on_attack_success"
				}
			]
		},
		
		# ID: 19 - ティアマト
		19: {
			"keywords": ["先制", "強打"],
			"keyword_conditions": {
				"強打": {
					"condition_type": "enemy_element",
					"element": "水"
				}
			},
			"effects": [
				{
					"effect_type": "power_strike",
					"multiplier": 1.5,
					"conditions": [
						{"condition_type": "enemy_element", "element": "水"}
					]
				},
				{
					"effect_type": "change_element",
					"target": "land",
					"element": "火"
				}
			]
		},
		
		# ID: 25 - ナイトエラント
		25: {
			"keywords": ["反射"],
			"effects": [
				{
					"effect_type": "synthesis",
					"element": "火",
					"transform_to": "アームドパラディン"
				},
				{
					"effect_type": "reflect",
					"reflect_type": "normal",
					"ratio": 0.5
				}
			]
		},
		
		# ID: 26 - ネビロス
		26: {
			"keywords": ["強打"],
			"keyword_conditions": {
				"強打": {
					"condition_type": "enemy_no_item"
				}
			},
			"effects": [
				{
					"effect_type": "draw",
					"max_cards": 5
				},
				{
					"effect_type": "power_strike",
					"multiplier": 1.5,
					"conditions": [
						{"condition_type": "enemy_no_item"}
					]
				}
			]
		},
		
		# ID: 27 - バーアル
		27: {
			"keywords": ["先制"],
			"effects": [
				{
					"effect_type": "sacrifice",
					"target": "hand",
					"count": 1,
					"random": true
				}
			]
		},
		
		# ID: 28 - バードメイデン
		28: {
			"keywords": ["不屈"]
		},
		
		# ID: 29 - バーナックル
		29: {
			"keywords": ["防御型"]
		},
		
		# ID: 35 - バルキリー
		35: {
			"keywords": ["援護", "先制"],
			"keyword_conditions": {
				"援護": {
					"elements": ["風", "火"]
				}
			},
			"effects": [
				{
					"effect_type": "modify_stats",
					"target": "self",
					"stat": "AP",
					"operation": "add",
					"value": 10,
					"trigger": "on_enemy_destroy"
				}
			]
		},
		
		# ID: 36 - ピュトン
		36: {
			"keywords": ["貫通"],
			"keyword_conditions": {
				"貫通": {
					"condition_type": "st_above",
					"value": 40
				}
			},
			"effects": [
				{
					"effect_type": "magic_gain",
					"value": 100,
					"trigger": "on_invasion"
				}
			]
		},
		
		# ID: 38 - ファイアービーク
		38: {
			"keywords": ["先制", "貫通", "強打"],
			"keyword_conditions": {
				"貫通": {
					"condition_type": "enemy_element",
					"element": "水"
				},
				"強打": {
					"condition_type": "enemy_element",
					"element": "水"
				}
			},
			"effects": [
				{
					"effect_type": "power_strike",
					"multiplier": 1.5,
					"conditions": [
						{"condition_type": "enemy_element", "element": "水"}
					]
				}
			]
		},
		
		# ID: 39 - フェイ
		39: {
			"keywords": ["巻物強打"]
		},
		
		# ID: 40 - フェニックス
		40: {
			"keywords": ["復活"]
		},
		
		# ID: 41 - フレイムデューク
		41: {
			"keywords": ["先制", "強打"],
			"keyword_conditions": {
				"強打": {
					"condition_type": "with_weapon"
				}
			},
			"effects": [
				{
					"effect_type": "power_strike",
					"multiplier": 1.5,
					"conditions": [
						{"condition_type": "with_weapon"}
					]
				},
				{
					"effect_type": "item_return",
					"destination": "book"
				}
			]
		},
		
		# ID: 42 - フロギストン
		42: {
			"keywords": ["強打"],
			"keyword_conditions": {
				"強打": {
					"condition_type": "mhp_below",
					"value": 40
				}
			},
			"effects": [
				{
					"effect_type": "power_strike",
					"multiplier": 1.5,
					"conditions": [
						{"condition_type": "mhp_below", "value": 40}
					]
				}
			]
		},
		
		# ID: 46 - ムシュフシュ
		46: {
			"keywords": ["強打"],
			"keyword_conditions": {
				"強打": {
					"condition_type": "on_element_land",
					"elements": ["火", "地"]
				}
			},
			"effects": [
				{
					"effect_type": "affinity",
					"element": "地",
					"st_bonus": 20,
					"hp_bonus": 10
				},
				{
					"effect_type": "power_strike",
					"multiplier": 1.5,
					"conditions": [
						{"condition_type": "on_element_land", "elements": ["火", "地"]}
					]
				}
			]
		},
		
		# ID: 49 - ローンビースト
		49: {
			"keywords": ["強打"],
			"keyword_conditions": {
				"強打": {
					"condition_type": "adjacent_ally_land"
				}
			},
			"effects": [
				{
					"effect_type": "modify_stats",
					"target": "self",
					"stat": "HP",
					"operation": "add",
					"value": "base_st"
				},
				{
					"effect_type": "power_strike",
					"multiplier": 1.5,
					"conditions": [
						{"condition_type": "adjacent_ally_land"}
					]
				}
			]
		}
	}
	
	return parsed_abilities

# デバッグ用：特定カードのability_parsedを表示
func print_card_parsed(card_id: int):
	var abilities = parse_fire_abilities()
	if abilities.has(card_id):
		print("Card ID %d ability_parsed:" % card_id)
		print(JSON.stringify(abilities[card_id], "\t"))
	else:
		print("Card ID %d has no special abilities to parse" % card_id)

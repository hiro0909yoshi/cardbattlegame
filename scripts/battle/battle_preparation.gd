extends Node
class_name BattlePreparation

# バトル準備フェーズ処理
# BattleParticipantの作成、アイテム効果、土地ボーナス計算を担当

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# システム参照
var board_system_ref = null
var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null

func setup_systems(board_system, card_system: CardSystem, player_system: PlayerSystem):
	board_system_ref = board_system
	card_system_ref = card_system
	player_system_ref = player_system

## 両者のBattleParticipantを準備
func prepare_participants(attacker_index: int, card_data: Dictionary, tile_info: Dictionary, attacker_item: Dictionary = {}, defender_item: Dictionary = {}) -> Dictionary:
	# 侵略側の準備（土地ボーナスなし）
	var attacker_base_hp = card_data.get("hp", 0)
	var attacker_land_bonus = 0  # 侵略側は土地ボーナスなし
	var attacker_ap = card_data.get("ap", 0)
	
	var attacker = BattleParticipant.new(
		card_data,
		attacker_base_hp,
		attacker_land_bonus,
		attacker_ap,
		true,  # is_attacker
		attacker_index
	)
	
	# 防御側の準備（土地ボーナスあり）
	var defender_creature = tile_info.get("creature", {})
	print("\n【防御側クリーチャーデータ】", defender_creature)
	var defender_base_hp = defender_creature.get("hp", 0)
	var defender_land_bonus = calculate_land_bonus(defender_creature, tile_info)  # 防御側のみボーナス
	
	# 貫通スキルチェック：攻撃側が貫通を持つ場合、防御側の土地ボーナスを無効化
	if check_penetration_skill(card_data, defender_creature, tile_info):
		print("【貫通発動】防御側の土地ボーナス ", defender_land_bonus, " を無効化")
		defender_land_bonus = 0
	
	var defender_ap = defender_creature.get("ap", 0)
	var defender_owner = tile_info.get("owner", -1)
	
	var defender = BattleParticipant.new(
		defender_creature,
		defender_base_hp,
		defender_land_bonus,
		defender_ap,
		false,  # is_attacker
		defender_owner
	)
	
	# アイテム効果を適用
	if not attacker_item.is_empty():
		apply_item_effects(attacker, attacker_item)
	if not defender_item.is_empty():
		apply_item_effects(defender, defender_item)
	
	return {
		"attacker": attacker,
		"defender": defender
	}

## アイテム効果を適用
func apply_item_effects(participant: BattleParticipant, item_data: Dictionary) -> void:
	print("[アイテム効果適用] ", item_data.get("name", "???"))
	
	# ability_parsedから効果を取得
	var ability_parsed = item_data.get("ability_parsed", {})
	if ability_parsed.is_empty():
		print("  警告: ability_parsedが定義されていません")
		return
	
	var effects = ability_parsed.get("effects", [])
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		var value = effect.get("value", 0)
		
		match effect_type:
			"buff_ap":
				participant.current_ap += value
				print("  AP+", value, " → ", participant.current_ap)
			
			"buff_hp":
				participant.item_bonus_hp += value
				participant.update_current_hp()
				print("  HP+", value, " → ", participant.current_hp)
			
			"debuff_ap":
				participant.current_ap -= value
				print("  AP-", value, " → ", participant.current_ap)
			
			"debuff_hp":
				participant.item_bonus_hp -= value
				participant.update_current_hp()
				print("  HP-", value, " → ", participant.current_hp)
			
			"grant_skill":
				# スキル付与（例：強打、先制など）
				var skill_name = effect.get("skill", "")
				
				# 条件チェック
				var condition = effect.get("condition", {})
				if not condition.is_empty():
					if not check_skill_grant_condition(participant, condition):
						print("  スキル付与条件不一致: ", skill_name, " → スキップ")
						continue
				
				grant_skill_to_participant(participant, skill_name, effect)
				print("  スキル付与: ", skill_name)
			
			_:
				print("  未実装の効果タイプ: ", effect_type)

## スキル付与条件をチェック
func check_skill_grant_condition(participant: BattleParticipant, condition: Dictionary) -> bool:
	var condition_type = condition.get("condition_type", "")
	
	match condition_type:
		"user_element":
			# 使用者（クリーチャー）の属性が指定された属性のいずれかに一致するか
			var required_elements = condition.get("elements", [])
			var user_element = participant.creature_data.get("element", "")
			return user_element in required_elements
		
		_:
			print("  未実装の条件タイプ: ", condition_type)
			return false

## パーティシパントにスキルを付与
func grant_skill_to_participant(participant: BattleParticipant, skill_name: String, _skill_data: Dictionary) -> void:
	match skill_name:
		"先制":
			participant.has_first_strike = true
		
		"後手":
			participant.has_last_strike = true
		
		"強打":
			# 強打スキルを付与
			if not participant.creature_data.has("ability_parsed"):
				participant.creature_data["ability_parsed"] = {}
			
			var ability_parsed = participant.creature_data["ability_parsed"]
			if not ability_parsed.has("keywords"):
				ability_parsed["keywords"] = []
			
			if not "強打" in ability_parsed["keywords"]:
				ability_parsed["keywords"].append("強打")
			
			# effectsにも強打効果を追加（条件なしで常に発動）
			if not ability_parsed.has("effects"):
				ability_parsed["effects"] = []
			
			# 強打効果を構築（条件なし）
			var power_strike_effect = {
				"effect_type": "power_strike",
				"multiplier": 1.5,
				"conditions": []  # アイテムで付与された強打は無条件で発動
			}
			
			ability_parsed["effects"].append(power_strike_effect)
		
		_:
			print("  未実装のスキル: ", skill_name)

## 土地ボーナスを計算
func calculate_land_bonus(creature_data: Dictionary, tile_info: Dictionary) -> int:
	var creature_element = creature_data.get("element", "")
	var tile_element = tile_info.get("element", "")
	var tile_level = tile_info.get("level", 1)
	
	print("【土地ボーナス計算】クリーチャー:", creature_data.get("name", "?"), " 属性:", creature_element)
	print("  タイル属性:", tile_element, " レベル:", tile_level)
	
	if creature_element == tile_element and creature_element in ["fire", "water", "wind", "earth"]:
		var bonus = tile_level * 10
		print("  → 属性一致！ボーナス:", bonus)
		return bonus
	
	print("  → 属性不一致、ボーナスなし")
	return 0

## 貫通スキルの判定
func check_penetration_skill(attacker_data: Dictionary, defender_data: Dictionary, _tile_info: Dictionary) -> bool:
	# 攻撃側のability_parsedから貫通スキルを取得
	var ability_parsed = attacker_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 貫通スキルがない場合
	if not "貫通" in keywords:
		return false
	
	# 貫通スキルの条件をチェック
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var penetrate_condition = keyword_conditions.get("貫通", {})
	
	# 条件がない場合は無条件発動
	if penetrate_condition.is_empty():
		print("【貫通】無条件発動")
		return true
	
	# 条件チェック
	var condition_type = penetrate_condition.get("condition_type", "")
	
	match condition_type:
		"enemy_is_element":
			# 敵が特定属性の場合
			var required_elements = penetrate_condition.get("elements", "")
			var defender_element = defender_data.get("element", "")
			if defender_element == required_elements:
				print("【貫通】条件満たす: 敵が", required_elements, "属性")
				return true
			else:
				print("【貫通】条件不成立: 敵が", defender_element, "属性（要求:", required_elements, "）")
				return false
		
		"attacker_st_check":
			# 攻撃側のSTが一定以上の場合
			var operator = penetrate_condition.get("operator", ">=")
			var value = penetrate_condition.get("value", 0)
			var attacker_st = attacker_data.get("ap", 0)  # APがSTに相当
			
			var meets_condition = false
			match operator:
				">=": meets_condition = attacker_st >= value
				">": meets_condition = attacker_st > value
				"==": meets_condition = attacker_st == value
			
			if meets_condition:
				print("【貫通】条件満たす: ST ", attacker_st, " ", operator, " ", value)
				return true
			else:
				print("【貫通】条件不成立: ST ", attacker_st, " ", operator, " ", value)
				return false
		
		_:
			# 未知の条件タイプ
			print("【貫通】未知の条件タイプ:", condition_type)
			return false

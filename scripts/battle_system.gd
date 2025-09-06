extends Node
class_name BattleSystem

# バトル管理システム

signal battle_started(attacker: Dictionary, defender: Dictionary)
signal battle_ended(winner: String, result: Dictionary)
signal damage_dealt(amount: int, target: String)

# バトル結果
enum BattleResult {
	ATTACKER_WIN,
	DEFENDER_WIN,
	DRAW
}

func _ready():
	print("BattleSystem: 初期化")

# バトルを実行
func execute_battle(attacker_data: Dictionary, defender_data: Dictionary) -> Dictionary:
	emit_signal("battle_started", attacker_data, defender_data)
	
	print("バトル開始！")
	print("攻撃側: ", attacker_data.name, " (ST:", attacker_data.damage, " HP:", attacker_data.block, ")")
	print("防御側: ", defender_data.name, " (ST:", defender_data.damage, " HP:", defender_data.block, ")")
	
	# 簡易バトル計算（後で詳細実装）
	var attacker_st = attacker_data.damage
	var defender_hp = defender_data.block
	
	var result = {
		"winner": "",
		"damage": 0,
		"result_type": BattleResult.DRAW
	}
	
	# シンプルな判定（ST > HPなら勝利）
	if attacker_st > defender_hp:
		result.winner = "attacker"
		result.damage = attacker_st - defender_hp
		result.result_type = BattleResult.ATTACKER_WIN
		print("攻撃側の勝利！")
	elif defender_hp > attacker_st:
		result.winner = "defender"
		result.damage = defender_hp - attacker_st
		result.result_type = BattleResult.DEFENDER_WIN
		print("防御側の勝利！")
	else:
		result.winner = "draw"
		result.result_type = BattleResult.DRAW
		print("引き分け！")
	
	emit_signal("battle_ended", result.winner, result)
	return result

# 侵略バトル（土地を奪う）
func invasion_battle(attacker_creature: Dictionary, defender_creature: Dictionary, tile_info: Dictionary) -> Dictionary:
	# 地形効果を計算
	var terrain_bonus = calculate_terrain_bonus(attacker_creature, defender_creature, tile_info)
	
	# 修正後の能力値
	var modified_attacker = attacker_creature.duplicate()
	var modified_defender = defender_creature.duplicate()
	
	if terrain_bonus.attacker_bonus > 0:
		modified_attacker.damage += terrain_bonus.attacker_bonus
	if terrain_bonus.defender_bonus > 0:
		modified_defender.block += terrain_bonus.defender_bonus
	
	return execute_battle(modified_attacker, modified_defender)

# 地形ボーナスを計算
func calculate_terrain_bonus(attacker: Dictionary, defender: Dictionary, tile: Dictionary) -> Dictionary:
	var bonus = {
		"attacker_bonus": 0,
		"defender_bonus": 0
	}
	
	# 属性一致ボーナス（仮実装）
	if attacker.element == tile.element:
		bonus.attacker_bonus += 10
		print("攻撃側に地形ボーナス +10")
	
	if defender.element == tile.element:
		bonus.defender_bonus += 10
		print("防御側に地形ボーナス +10")
	
	return bonus

# アイテムカードの効果を適用
func apply_item_effect(creature: Dictionary, item: Dictionary) -> Dictionary:
	var modified = creature.duplicate()
	
	match item.type:
		"weapon":
			modified.damage += item.value
			print("武器効果: ST +", item.value)
		"armor":
			modified.block += item.value
			print("防具効果: HP +", item.value)
		"spell":
			# 特殊効果（後で実装）
			print("呪文効果: ", item.name)
	
	return modified

# ダメージ計算
func calculate_damage(attacker_st: int, defender_hp: int, modifiers: Dictionary = {}) -> int:
	var damage = max(0, attacker_st - defender_hp)
	
	# 修正値を適用
	if modifiers.has("critical"):
		damage *= 2
		print("クリティカルヒット！")
	
	if modifiers.has("defense_bonus"):
		damage = max(0, damage - modifiers.defense_bonus)
	
	return damage

# バトル予測（UI表示用）
func predict_battle_outcome(attacker: Dictionary, defender: Dictionary, tile: Dictionary) -> Dictionary:
	var terrain = calculate_terrain_bonus(attacker, defender, tile)
	
	var prediction = {
		"attacker_st": attacker.damage + terrain.attacker_bonus,
		"defender_hp": defender.block + terrain.defender_bonus,
		"likely_winner": ""
	}
	
	if prediction.attacker_st > prediction.defender_hp:
		prediction.likely_winner = "attacker"
	elif prediction.defender_hp > prediction.attacker_st:
		prediction.likely_winner = "defender"
	else:
		prediction.likely_winner = "draw"
	
	return prediction

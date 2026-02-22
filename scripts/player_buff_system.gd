extends Node
class_name PlayerBuffSystem

# スキル効果管理システム

# TODO: 将来実装予定
# signal skill_activated(skill_name: String, target: String)
signal buff_applied(target: String, buff_type: String, value: int)
signal debuff_applied(target: String, debuff_type: String, value: int)

# アクティブなスキル効果
var active_skills = {}
var player_buffs = {}  # プレイヤーごとのバフ/デバフ

func _ready():
	initialize_player_buffs()

# プレイヤーバフを初期化
func initialize_player_buffs():
	for i in range(4):  # 最大4人プレイヤー
		player_buffs[i] = []  # 空の配列で初期化（動的バフ管理用）

# スキルを登録
func register_skill(skill_name: String, effect: Dictionary):
	active_skills[skill_name] = effect
	print("SkillSystem: スキル登録 - ", skill_name)

# バフ配列から特定タイプの合計値を計算
func _calculate_buff_total(player_id: int, buff_type: String) -> float:
	var total = 0.0
	if player_buffs.has(player_id):
		for buff in player_buffs[player_id]:
			if buff["type"] == buff_type:
				total += buff["value"]
	return total

# カードコストを修正
func modify_card_cost(base_cost: int, card_data: Dictionary, player_id: int) -> int:
	var modified_cost = base_cost
	
	# バフ配列から card_cost_reduction の合計を計算
	var total_reduction = _calculate_buff_total(player_id, "card_cost")
	modified_cost -= int(total_reduction)
	
	# カード属性による修正（例：特定属性のコスト削減）
	if active_skills.has("element_affinity"):
		var skill = active_skills["element_affinity"]
		if card_data.element == skill.element:
			modified_cost -= skill.reduction
	
	return max(0, modified_cost)  # コストは0未満にならない

# ダイスロールを修正
func modify_dice_roll(base_roll: int, player_id: int) -> int:
	var modified_roll = base_roll
	
	# バフ配列から dice_bonus の合計を計算
	var dice_bonus = _calculate_buff_total(player_id, "dice")
	modified_roll += int(dice_bonus)
	
	# 特殊スキル（例：ダイス目固定）
	if active_skills.has("dice_control"):
		var skill = active_skills["dice_control"]
		if skill.active:
			modified_roll = skill.fixed_value
	
	return clamp(modified_roll, 1, 12)  # 1-12の範囲に制限

# 通行料を修正
func modify_toll(base_toll: int, attacker_id: int, defender_id: int) -> int:
	var modified_toll = float(base_toll)
	
	# バフ配列から toll_multiplier の合計を計算
	var toll_multiplier = _calculate_buff_total(defender_id, "toll")
	if toll_multiplier > 0:
		modified_toll *= (1.0 + toll_multiplier * 0.1)
	
	# 攻撃側のペナルティ軽減
	if active_skills.has("toll_protection"):
		var skill = active_skills["toll_protection"]
		if skill.player_id == attacker_id:
			modified_toll *= skill.reduction_rate
	
	return int(modified_toll)

# ドロー枚数を修正
func modify_draw_count(base_count: int, player_id: int) -> int:
	var modified_count = base_count
	
	# バフ配列から draw_bonus の合計を計算
	var draw_bonus = _calculate_buff_total(player_id, "draw")
	modified_count += int(draw_bonus)
	
	# スペルカード効果
	if active_skills.has("extra_draw"):
		var skill = active_skills["extra_draw"]
		if skill.player_id == player_id:
			modified_count += skill.bonus_cards
	
	return modified_count

# バトル能力を修正
func modify_creature_stats(creature: Dictionary, player_id: int, _is_attacker: bool) -> Dictionary:
	var modified = creature.duplicate()
	
	# バフ配列から battle_st_bonus と battle_hp_bonus の合計を計算
	var st_bonus = _calculate_buff_total(player_id, "battle_st")
	var hp_bonus = _calculate_buff_total(player_id, "battle_hp")
	modified.damage += int(st_bonus)
	modified.block += int(hp_bonus)
	
	# 属性相性
	if active_skills.has("element_advantage"):
		var skill = active_skills["element_advantage"]
		modified = apply_element_advantage(modified, skill)
	
	return modified

# 属性相性を適用
func apply_element_advantage(creature: Dictionary, _advantage_table: Dictionary) -> Dictionary:
	# 火 > 風 > 土 > 水 > 火 のような相性
	# 実装は後で詳細化
	return creature

# バフを適用
func apply_buff(player_id: int, buff_type: String, value: int, duration: int = -1):
	if not player_buffs.has(player_id):
		return
	
	# バフオブジェクトを配列に追加（動的管理）
	var buff = {
		"type": buff_type,
		"value": value,
		"duration": duration
	}
	player_buffs[player_id].append(buff)
	
	emit_signal("buff_applied", str(player_id), buff_type, value)
	print("バフ適用: プレイヤー", player_id + 1, " - ", buff_type, " +", value)

# デバフを適用
func apply_debuff(player_id: int, debuff_type: String, value: int, duration: int = -1):
	# バフの逆の値を適用
	apply_buff(player_id, debuff_type, -value, duration)
	emit_signal("debuff_applied", str(player_id), debuff_type, value)

# ターン終了時の処理
func end_turn_cleanup():
	# 持続時間のあるスキルを減少
	for skill_name in active_skills:
		var skill = active_skills[skill_name]
		if skill.has("duration") and skill.duration > 0:
			skill.duration -= 1
			if skill.duration == 0:
				active_skills.erase(skill_name)
				print("スキル終了: ", skill_name)

# スキル効果をクリア
func clear_all_effects():
	active_skills.clear()
	initialize_player_buffs()
	print("SkillSystem: 全効果をクリア")

## 奮闘スキルまたは奮闘刻印を持っているかチェック
static func has_unyielding(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	
	# 1. 奮闘スキル判定
	var ability_detail = creature_data.get("ability_detail", "")
	if "奮闘" in ability_detail:
		return true
	
	# 2. 奮闘刻印判定
	if SpellMovement.has_indomitable_curse(creature_data):
		return true
	
	return false

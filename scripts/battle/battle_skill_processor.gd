extends Node
class_name BattleSkillProcessor

# バトルスキル処理
# 感応、強打、2回攻撃、巻物攻撃などのスキル適用を担当

var board_system_ref = null

func setup_systems(board_system):
	board_system_ref = board_system

## バトル前スキル適用
func apply_pre_battle_skills(participants: Dictionary, tile_info: Dictionary, attacker_index: int) -> void:
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	
	# プレイヤー土地情報取得
	var player_lands = board_system_ref.get_player_lands_by_element(attacker_index)
	
	# 【Phase 1】応援スキル適用（盤面全体を対象にバフ）
	var battle_tile_index = tile_info.get("index", -1)
	apply_support_skills_to_all(participants, battle_tile_index)
	
	# 侵略側のスキル適用
	var attacker_context = ConditionChecker.build_battle_context(
		attacker.creature_data,
		defender.creature_data,
		tile_info,
		{
			"player_lands": player_lands,
			"battle_tile_index": tile_info.get("index", -1),
			"player_id": attacker_index,
			"board_system": board_system_ref
		}
	)
	apply_skills(attacker, attacker_context)
	
	# 防御側のスキル適用
	var defender_lands = board_system_ref.get_player_lands_by_element(defender.player_id) if defender.player_id >= 0 else {}
	var defender_context = ConditionChecker.build_battle_context(
		defender.creature_data,
		attacker.creature_data,
		tile_info,
		{
			"player_lands": defender_lands,
			"battle_tile_index": tile_info.get("index", -1),
			"player_id": defender.player_id,
			"board_system": board_system_ref
		}
	)
	apply_skills(defender, defender_context)
	
	# 巻物攻撃による土地ボーナスHP無効化
	if attacker.is_using_scroll and defender.land_bonus_hp > 0:
		print("【巻物攻撃】防御側の土地ボーナス ", defender.land_bonus_hp, " を無効化")
		defender.land_bonus_hp = 0
		defender.update_current_hp()

## スキル適用
func apply_skills(participant: BattleParticipant, context: Dictionary) -> void:
	var effect_combat = load("res://scripts/skills/effect_combat.gd").new()
	
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	var has_scroll_power_strike = "巻物強打" in keywords
	
	# 1. 巻物攻撃判定（最優先）
	check_scroll_attack(participant, context)
	
	# 2. 感応スキルを適用
	# 巻物強打の場合は感応を適用、通常の巻物攻撃の場合はスキップ
	if not participant.is_using_scroll or has_scroll_power_strike:
		apply_resonance_skill(participant, context)
	
	# 3. 土地数比例効果を適用（Phase 3追加）
	apply_land_count_effects(participant, context)
	
	# 4. 強打スキルを適用（巻物強打を含む）
	apply_power_strike_skills(participant, context, effect_combat)
	
	# 5. 2回攻撃スキルを判定
	check_double_attack(participant)

## 2回攻撃スキル判定
func check_double_attack(participant: BattleParticipant) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "2回攻撃" in keywords:
		participant.attack_count = 2
		print("【2回攻撃】", participant.creature_data.get("name", "?"), " 攻撃回数: 2回")

## 巻物攻撃判定
func check_scroll_attack(participant: BattleParticipant, _context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 巻物攻撃 or 巻物強打を持つか
	if not ("巻物攻撃" in keywords or "巻物強打" in keywords):
		return
	
	# 巻物攻撃フラグを立てる
	participant.is_using_scroll = true
	
	# AP設定を取得
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var scroll_config = {}
	
	# 巻物攻撃の設定を優先
	if "巻物攻撃" in keywords:
		scroll_config = keyword_conditions.get("巻物攻撃", {})
	elif "巻物強打" in keywords:
		scroll_config = keyword_conditions.get("巻物強打", {})
	
	# scroll_typeに基づいてAPを設定
	var scroll_type = scroll_config.get("scroll_type", "base_st")
	var base_ap = participant.creature_data.get("ap", 0)
	
	match scroll_type:
		"fixed_st":
			# 固定値
			var value = scroll_config.get("value", base_ap)
			participant.current_ap = value
			print("【巻物攻撃】", participant.creature_data.get("name", "?"), " AP固定:", value)
		"base_st":
			# 基本STのまま
			participant.current_ap = base_ap
			print("【巻物攻撃】", participant.creature_data.get("name", "?"), " AP=基本ST:", base_ap)
		_:
			# デフォルトは基本ST
			participant.current_ap = base_ap
			print("【巻物攻撃】", participant.creature_data.get("name", "?"), " AP=基本ST:", base_ap)

## 強打スキル適用（巻物強打を含む）
func apply_power_strike_skills(participant: BattleParticipant, context: Dictionary, effect_combat) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 巻物強打判定（最優先）
	if "巻物強打" in keywords and participant.is_using_scroll:
		# 巻物強打は無条件でAP×1.5
		var original_ap = participant.current_ap
		participant.current_ap = int(participant.current_ap * 1.5)
		print("【巻物強打】", participant.creature_data.get("name", "?"), 
			  " AP: ", original_ap, " → ", participant.current_ap, " (×1.5)")
		return
	
	# 通常の強打判定
	if "強打" in keywords:
		var modified_creature_data = participant.creature_data.duplicate()
		modified_creature_data["ap"] = participant.current_ap  # 現在のAPを設定
		var modified = effect_combat.apply_power_strike(modified_creature_data, context)
		participant.current_ap = modified.get("ap", participant.current_ap)
		
		if modified.get("power_strike_applied", false):
			print("【強打発動】", participant.creature_data.get("name", "?"), " AP:", participant.current_ap)

## 感応スキルを適用（自己バフ型）
func apply_resonance_skill(participant: BattleParticipant, context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 感応スキルがない場合
	if not "感応" in keywords:
		return
	
	# 感応条件を取得
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var resonance_condition = keyword_conditions.get("感応", {})
	
	if resonance_condition.is_empty():
		return
	
	# 必要な属性を取得
	var required_element = resonance_condition.get("element", "")
	
	# プレイヤーの土地情報を取得
	var player_lands = context.get("player_lands", {})
	var owned_count = player_lands.get(required_element, 0)
	
	# 感応発動判定：指定属性の土地を1つでも所有していれば発動
	if owned_count > 0:
		var stat_bonus = resonance_condition.get("stat_bonus", {})
		var ap_bonus = stat_bonus.get("ap", 0)
		var hp_bonus = stat_bonus.get("hp", 0)
		
		if ap_bonus > 0 or hp_bonus > 0:
			print("【感応発動】", participant.creature_data.get("name", "?"))
			print("  必要属性:", required_element, " 所持数:", owned_count)
			
			# APボーナス適用
			if ap_bonus > 0:
				var old_ap = participant.current_ap
				participant.current_ap += ap_bonus
				print("  AP: ", old_ap, " → ", participant.current_ap, " (+", ap_bonus, ")")
			
			# HPボーナス適用（resonance_bonus_hpに追加）
			if hp_bonus > 0:
				var old_hp = participant.current_hp
				participant.resonance_bonus_hp += hp_bonus
				participant.update_current_hp()
				print("  HP: ", old_hp, " → ", participant.current_hp, " (+", hp_bonus, ")")

## 土地数比例効果を適用（Phase 3追加）
func apply_land_count_effects(participant: BattleParticipant, context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	# プレイヤーの土地情報を取得
	var player_lands = context.get("player_lands", {})
	
	for effect in effects:
		if effect.get("effect_type") == "land_count_multiplier":
			# 対象属性の土地数を合計
			var target_elements = effect.get("elements", [])
			var total_count = 0
			
			for element in target_elements:
				total_count += player_lands.get(element, 0)
			
			# multiplierを適用
			var multiplier = effect.get("multiplier", 1)
			var bonus = total_count * multiplier
			
			# statに応じてボーナスを適用
			var stat = effect.get("stat", "ap")
			
			if stat == "ap":
				var old_ap = participant.current_ap
				participant.current_ap += bonus
				print("【土地数比例】", participant.creature_data.get("name", "?"))
				print("  対象属性:", target_elements, " 合計土地数:", total_count)
				print("  AP: ", old_ap, " → ", participant.current_ap, " (+", bonus, ")")
			
			elif stat == "hp":
				var old_hp = participant.current_hp
				participant.temporary_bonus_hp += bonus
				participant.update_current_hp()
				print("【土地数比例】", participant.creature_data.get("name", "?"))
				print("  対象属性:", target_elements, " 合計土地数:", total_count)
				print("  HP: ", old_hp, " → ", participant.current_hp, " (+", bonus, ")")

## 応援スキル適用（盤面全体を対象）
func apply_support_skills_to_all(participants: Dictionary, battle_tile_index: int) -> void:
	if board_system_ref == null:
		return
	
	# 応援持ちクリーチャーを取得（Dictionaryから値の配列を取得）
	var support_dict = board_system_ref.get_support_creatures()
	var support_creatures = support_dict.values()
	
	if support_creatures.is_empty():
		return
	
	print("【応援スキルチェック】応援持ちクリーチャー数: ", support_creatures.size())
	
	# バトル参加者（侵略側・防御側）に応援効果を適用
	var battle_participants = [participants["attacker"], participants["defender"]]
	
	for supporter_data in support_creatures:
		var supporter_creature = supporter_data["creature_data"]
		var supporter_player_id = supporter_data["player_id"]
		var supporter_tile_index = supporter_data.get("tile_index", -1)
		var ability_parsed = supporter_creature.get("ability_parsed", {})
		var effects = ability_parsed.get("effects", [])
		
		for effect in effects:
			if effect.get("effect_type") != "support":
				continue
			
			# 対象範囲とボーナスを取得
			var target = effect.get("target", {})
			var bonus = effect.get("bonus", {})
			
			# 各バトル参加者に対して応援効果をチェック
			for participant in battle_participants:
				if check_support_target(participant, target, supporter_player_id):
					apply_support_bonus(participant, bonus, supporter_creature.get("name", "?"), battle_tile_index, participant.player_id)

## 応援対象判定
func check_support_target(participant: BattleParticipant, target: Dictionary, supporter_player_id: int) -> bool:
	var scope = target.get("scope", "")
	var conditions = target.get("conditions", [])
	
	# scope="all_creatures"なら全クリーチャーが対象
	if scope != "all_creatures":
		return false
	
	# 条件チェック
	for condition in conditions:
		var condition_type = condition.get("condition_type", "")
		
		# 属性条件
		if condition_type == "element":
			var required_elements = condition.get("elements", [])
			var creature_element = participant.creature_data.get("element", "")
			
			if not creature_element in required_elements:
				return false
		
		# バトル役割条件（侵略側/防御側）
		elif condition_type == "battle_role":
			var required_role = condition.get("role", "")
			
			# 侵略側判定
			if required_role == "attacker" and not participant.is_attacker:
				return false
			
			# 防御側判定
			elif required_role == "defender" and participant.is_attacker:
				return false
		
		# 名前条件（部分一致）
		elif condition_type == "name_contains":
			var name_pattern = condition.get("name_pattern", "")
			var creature_name = participant.creature_data.get("name", "")
			
			if not name_pattern in creature_name:
				return false
		
		# 種族条件
		elif condition_type == "race":
			var required_race = condition.get("race", "")
			var creature_race = participant.creature_data.get("race", "")
			
			if creature_race != required_race:
				return false
		
		# 所有者一致条件（自クリーチャー）
		elif condition_type == "owner_match":
			# 応援者と対象が同じプレイヤーIDか判定
			if participant.player_id != supporter_player_id:
				return false
	
	return true

## 応援ボーナス適用
func apply_support_bonus(participant: BattleParticipant, bonus: Dictionary, supporter_name: String, battle_tile_index: int, target_player_id: int) -> void:
	var hp_bonus = bonus.get("hp", 0)
	var ap_bonus = bonus.get("ap", 0)
	
	# 隣接自領地数による動的ボーナス
	var ap_per_adjacent = bonus.get("ap_per_adjacent_land", 0)
	var hp_per_adjacent = bonus.get("hp_per_adjacent_land", 0)
	
	if ap_per_adjacent > 0 or hp_per_adjacent > 0:
		# 戦闘タイルの隣接自領地数を取得
		var adjacent_ally_count = _count_adjacent_ally_lands(battle_tile_index, target_player_id)
		ap_bonus += ap_per_adjacent * adjacent_ally_count
		hp_bonus += hp_per_adjacent * adjacent_ally_count
		print("  → 戦闘タイル", battle_tile_index, "の隣接自領地数: ", adjacent_ally_count)
	
	if hp_bonus == 0 and ap_bonus == 0:
		return
	
	print("【応援効果】", supporter_name, " → ", participant.creature_data.get("name", "?"))
	
	# HPボーナス適用
	if hp_bonus > 0:
		var old_hp = participant.current_hp
		participant.temporary_bonus_hp += hp_bonus
		participant.update_current_hp()
		print("  HP: ", old_hp, " → ", participant.current_hp, " (+", hp_bonus, ")")
	
	# APボーナス適用
	if ap_bonus > 0:
		var old_ap = participant.current_ap
		participant.current_ap += ap_bonus
		print("  AP: ", old_ap, " → ", participant.current_ap, " (+", ap_bonus, ")")

## 隣接自領地数を数える
func _count_adjacent_ally_lands(tile_index: int, player_id: int) -> int:
	if board_system_ref == null or tile_index < 0:
		return 0
	
	var neighbors = board_system_ref.tile_neighbor_system.get_spatial_neighbors(tile_index)
	var ally_count = 0
	
	for neighbor_index in neighbors:
		# TileDataManagerから正しくタイル情報を取得
		var tile_info = board_system_ref.tile_data_manager.get_tile_info(neighbor_index)
		if tile_info and tile_info.get("owner", -1) == player_id:
			ally_count += 1
	
	return ally_count

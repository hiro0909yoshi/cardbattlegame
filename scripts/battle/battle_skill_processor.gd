extends Node
class_name BattleSkillProcessor

# バトルスキル処理
# 感応、強打、2回攻撃、巻物攻撃などのスキル適用を担当

var board_system_ref = null
var game_flow_manager_ref = null

func setup_systems(board_system, game_flow_manager = null):
	board_system_ref = board_system
	game_flow_manager_ref = game_flow_manager

## バトル前スキル適用
func apply_pre_battle_skills(participants: Dictionary, tile_info: Dictionary, attacker_index: int) -> void:
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	
	# 【Phase 0】変身スキル適用（戦闘開始時）
	apply_battle_start_transform(attacker)
	apply_battle_start_transform(defender)
	
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
			"board_system": board_system_ref,
			"game_flow_manager": board_system_ref.game_flow_manager if board_system_ref else null
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
			"board_system": board_system_ref,
			"game_flow_manager": board_system_ref.game_flow_manager if board_system_ref else null
		}
	)
	apply_skills(defender, defender_context)
	
	# 巻物攻撃による土地ボーナスHP無効化
	if attacker.is_using_scroll and defender.land_bonus_hp > 0:
		print("【巻物攻撃】防御側の土地ボーナス ", defender.land_bonus_hp, " を無効化")
		defender.land_bonus_hp = 0
		defender.update_current_hp()
	
	# アイテム破壊・盗み処理
	apply_item_manipulation(attacker, defender)

## スキル適用
func apply_skills(participant: BattleParticipant, context: Dictionary) -> void:
	var effect_combat = load("res://scripts/skills/effect_combat.gd").new()
	
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	var has_scroll_power_strike = "巻物強打" in keywords
	
	# 0. ターン数ボーナスを適用（最優先、他のスキルより前）
	apply_turn_number_bonus(participant, context)
	
	# 1. 巻物攻撃判定（最優先）
	check_scroll_attack(participant, context)
	
	# 2. 感応スキルを適用
	# 巻物強打の場合は感応を適用、通常の巻物攻撃の場合はスキップ
	if not participant.is_using_scroll or has_scroll_power_strike:
		apply_resonance_skill(participant, context)
	
	# 3. 土地数比例効果を適用（Phase 3追加）
	apply_land_count_effects(participant, context)
	
	# 3.5. 破壊数効果を適用（ソウルコレクター用）
	apply_destroy_count_effects(participant)
	
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
	
	# バフチェック: base_up_ap以外のバフが入っていたら発動しない
	var base_ap = participant.creature_data.get("ap", 0)
	var expected_ap = base_ap + participant.base_up_ap
	
	if participant.current_ap != expected_ap:
		# base_up_ap以外のバフが入っている → 巻物攻撃不可
		print("【巻物攻撃不可】", participant.creature_data.get("name", "?"), 
			  " バフ検出（AP:", participant.current_ap, "≠", expected_ap, "）通常攻撃に変更")
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

## 反射スキルチェック
## 攻撃を受けた時、ダメージを反射するスキルの判定と処理
func check_reflect_damage(attacker_p: BattleParticipant, defender_p: BattleParticipant, original_damage: int, attack_type: String) -> Dictionary:
	"""
	反射スキルのチェックと反射ダメージの計算
	
	@param attacker_p: 攻撃側参加者
	@param defender_p: 防御側参加者  
	@param original_damage: 元のダメージ量
	@param attack_type: 攻撃タイプ ("normal" or "scroll")
	@return Dictionary {
		"has_reflect": bool,  # 反射スキルがあるか
		"reflect_damage": int,  # 反射するダメージ量
		"self_damage": int  # 防御側が受けるダメージ量
	}
	"""
	
	var result = {
		"has_reflect": false,
		"reflect_damage": 0,
		"self_damage": original_damage
	}
	
	# 1. 攻撃側が「反射無効」を持っているかチェック
	if _has_nullify_reflect(attacker_p):
		print("  【反射無効】攻撃側が反射無効を持つため、反射スキルは発動しない")
		return result
	
	# 2. 防御側の反射スキルを取得
	var reflect_effect = _get_reflect_effect(defender_p, attack_type)
	if reflect_effect == null:
		return result
	
	# 3. 条件チェック（条件付き反射の場合）
	var conditions = reflect_effect.get("conditions", [])
	if conditions.size() > 0:
		var context = _build_reflect_context(attacker_p, defender_p)
		if not _check_reflect_conditions(conditions, context):
			print("  【反射】条件不成立のため反射スキップ")
			return result
	
	# 4. 反射ダメージ計算
	var reflect_ratio = reflect_effect.get("reflect_ratio", 0.5)
	var self_damage_ratio = reflect_effect.get("self_damage_ratio", 0.5)
	
	result["has_reflect"] = true
	result["reflect_damage"] = int(original_damage * reflect_ratio)
	result["self_damage"] = int(original_damage * self_damage_ratio)
	
	var defender_name = defender_p.creature_data.get("name", "?")
	var attacker_name = attacker_p.creature_data.get("name", "?")
	
	if reflect_ratio >= 1.0:
		print("  【反射100%】", defender_name, " が攻撃を完全に反射")
	else:
		print("  【反射", int(reflect_ratio * 100), "%】", defender_name, " がダメージを反射")
	
	print("    - ", defender_name, " が受けるダメージ: ", result["self_damage"])
	print("    - ", attacker_name, " に返すダメージ: ", result["reflect_damage"])
	
	return result

## 攻撃側が「反射無効」を持っているかチェック
func _has_nullify_reflect(attacker_p: BattleParticipant) -> bool:
	var ability_parsed = attacker_p.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "nullify_reflect":
			return true
	
	# アイテムもチェック
	var items = attacker_p.creature_data.get("items", [])
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var item_effects = effect_parsed.get("effects", [])
		for effect in item_effects:
			if effect.get("effect_type") == "nullify_reflect":
				return true
	
	return false

## 防御側の反射スキルを取得
func _get_reflect_effect(defender_p: BattleParticipant, attack_type: String):
	"""
	防御側の反射スキルを取得
	
	@param defender_p: 防御側参加者
	@param attack_type: 攻撃タイプ ("normal" or "scroll")
	@return Dictionary or null
	"""
	
	# クリーチャー自身のスキルをチェック
	var ability_parsed = defender_p.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "reflect_damage":
			var attack_types = effect.get("attack_types", [])
			if attack_type in attack_types:
				return effect
	
	# アイテムをチェック
	var items = defender_p.creature_data.get("items", [])
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var item_effects = effect_parsed.get("effects", [])
		for effect in item_effects:
			if effect.get("effect_type") == "reflect_damage":
				var attack_types = effect.get("attack_types", [])
				if attack_type in attack_types:
					return effect
	
	return null

## 反射条件チェック用のコンテキスト構築
func _build_reflect_context(attacker_p: BattleParticipant, defender_p: BattleParticipant) -> Dictionary:
	return {
		"attacker": attacker_p,
		"defender": defender_p,
		"attacker_has_item": _has_any_item(attacker_p)
	}

## クリーチャーがアイテムを持っているかチェック
func _has_any_item(participant: BattleParticipant) -> bool:
	var items = participant.creature_data.get("items", [])
	return items.size() > 0

## 反射条件チェック
func _check_reflect_conditions(conditions: Array, context: Dictionary) -> bool:
	for condition in conditions:
		var condition_type = condition.get("condition_type", "")
		
		if condition_type == "enemy_no_item":
			# 敵アイテム未使用時
			if context.get("attacker_has_item", false):
				return false
		# 他の条件タイプを追加可能
	
	return true

## アイテム破壊・盗み処理（戦闘開始前）
func apply_item_manipulation(first: BattleParticipant, second: BattleParticipant) -> void:
	"""
	先制攻撃の順序でアイテム破壊・盗みを処理
	
	@param first: 先に行動する側
	@param second: 後に行動する側
	"""
	
	# 先に行動する側の処理
	_process_item_manipulation(first, second)
	
	# 後に行動する側の処理（アイテムがまだ残っていれば）
	_process_item_manipulation(second, first)

## 単一参加者のアイテム破壊・盗み処理
func _process_item_manipulation(actor: BattleParticipant, target: BattleParticipant) -> void:
	# 対象がアイテム破壊・盗み無効を持つかチェック
	if _has_nullify_item_manipulation(target):
		return
	
	# アイテム破壊スキルをチェック
	var destroy_effect = _get_destroy_item_effect(actor)
	if destroy_effect:
		_execute_destroy_item(actor, target, destroy_effect)
		return
	
	# アイテム盗みスキルをチェック
	var steal_effect = _get_steal_item_effect(actor)
	if steal_effect:
		_execute_steal_item(actor, target, steal_effect)

## アイテム破壊・盗み無効を持つかチェック
func _has_nullify_item_manipulation(participant: BattleParticipant) -> bool:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "nullify_item_manipulation":
			var participant_name = participant.creature_data.get("name", "?")
			print("  【アイテム操作無効】", participant_name, " がアイテム破壊・盗みを無効化")
			return true
	
	return false

## アイテム破壊スキルを取得
func _get_destroy_item_effect(participant: BattleParticipant):
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "destroy_item":
			var triggers = effect.get("triggers", [])
			if "before_battle" in triggers:
				return effect
	
	return null

## アイテム盗みスキルを取得
func _get_steal_item_effect(participant: BattleParticipant):
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "steal_item":
			var triggers = effect.get("triggers", [])
			if "before_battle" in triggers:
				# 条件チェック: 自分がアイテム未使用
				var conditions = effect.get("conditions", [])
				for condition in conditions:
					if condition.get("condition_type") == "self_no_item":
						if _has_any_item(participant):
							return null  # 自分がアイテムを持っている場合は盗めない
				return effect
	
	return null

## アイテム破壊を実行
func _execute_destroy_item(actor: BattleParticipant, target: BattleParticipant, effect: Dictionary) -> void:
	var target_items = target.creature_data.get("items", [])
	if target_items.is_empty():
		return
	
	# 対象のアイテムタイプをチェック
	var target_item = target_items[0]
	var item_type = target_item.get("item_type", "")
	var target_types = effect.get("target_types", [])
	
	# タイプが一致するかチェック
	# 「道具」は武器・防具・アクセサリを含む
	var type_matches = false
	if item_type in target_types:
		type_matches = true
	elif "道具" in target_types and item_type in ["武器", "防具", "アクセサリ"]:
		type_matches = true
	
	if not type_matches:
		return
	
	var actor_name = actor.creature_data.get("name", "?")
	var target_name = target.creature_data.get("name", "?")
	var item_name = target_item.get("name", "???")
	
	print("【アイテム破壊】", actor_name, " が ", target_name, " の ", item_name, " を破壊")
	
	# アイテムを削除
	target.creature_data["items"] = []
	
	# アイテム効果を無効化（ステータスを再計算）
	_remove_item_effects(target, target_item)

## アイテム盗みを実行
func _execute_steal_item(actor: BattleParticipant, target: BattleParticipant, _effect: Dictionary) -> void:
	var target_items = target.creature_data.get("items", [])
	if target_items.is_empty():
		return
	
	var actor_name = actor.creature_data.get("name", "?")
	var target_name = target.creature_data.get("name", "?")
	var stolen_item = target_items[0]
	var item_name = stolen_item.get("name", "???")
	
	print("【アイテム盗み】", actor_name, " が ", target_name, " の ", item_name, " を奪った")
	
	# 対象からアイテムを削除
	target.creature_data["items"] = []
	_remove_item_effects(target, stolen_item)
	
	# 自分にアイテムを追加
	if not actor.creature_data.has("items"):
		actor.creature_data["items"] = []
	actor.creature_data["items"].append(stolen_item)
	
	# アイテム効果を適用
	_apply_stolen_item_effects(actor, stolen_item)

## アイテム効果を削除（ステータスを元に戻す）
func _remove_item_effects(participant: BattleParticipant, item: Dictionary) -> void:
	var effect_parsed = item.get("effect_parsed", {})
	var stat_bonus = effect_parsed.get("stat_bonus", {})
	
	var st = stat_bonus.get("st", 0)
	var hp = stat_bonus.get("hp", 0)
	
	if st > 0:
		participant.current_ap -= st
		print("    - ST-", st, " → ", participant.current_ap)
	
	if hp > 0:
		participant.item_bonus_hp -= hp
		participant.update_current_hp()
		print("    - HP-", hp, " → ", participant.current_hp)

## 盗んだアイテムの効果を適用
func _apply_stolen_item_effects(participant: BattleParticipant, item: Dictionary) -> void:
	var effect_parsed = item.get("effect_parsed", {})
	var stat_bonus = effect_parsed.get("stat_bonus", {})
	
	var st = stat_bonus.get("st", 0)
	var hp = stat_bonus.get("hp", 0)
	
	if st > 0:
		participant.current_ap += st
		print("    + ST+", st, " → ", participant.current_ap)
	
	if hp > 0:
		participant.item_bonus_hp += hp
		participant.update_current_hp()
		print("    + HP+", hp, " → ", participant.current_hp)

# ========================================
# 変身スキル処理
# ========================================

## 戦闘開始時の変身スキル適用
func apply_battle_start_transform(participant: BattleParticipant) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "transform" and effect.get("trigger") == "on_battle_start":
			_execute_transform(participant, effect)

## 変身実行
func _execute_transform(participant: BattleParticipant, effect: Dictionary) -> void:
	var transform_type = effect.get("transform_type", "")
	
	# 変身前のデータを保存（戦闘後復帰用）
	var revert_after_battle = effect.get("revert_after_battle", false)
	if revert_after_battle and not participant.creature_data.has("original_creature_data"):
		participant.creature_data["original_creature_data"] = participant.creature_data.duplicate(true)
		print("【変身】元データ保存: ", participant.creature_data.get("name", "?"))
	
	match transform_type:
		"random":
			_transform_to_random(participant)
		"forced":
			# コカトリスなどの強制変身は攻撃成功時に処理
			pass
		_:
			print("【警告】未実装の変身タイプ: ", transform_type)

## ランダム変身
func _transform_to_random(participant: BattleParticipant) -> void:
	print("【変身】ランダム変身開始: ", participant.creature_data.get("name", "?"))
	
	# 全クリーチャーリストを取得
	var all_creatures = _get_all_creatures()
	if all_creatures.is_empty():
		print("【エラー】変身先クリーチャーが見つかりません")
		return
	
	# ランダムに選択
	randomize()
	var random_creature = all_creatures[randi() % all_creatures.size()]
	
	# 変身実行
	_replace_creature_data(participant, random_creature)
	print("【変身完了】", participant.creature_data.get("name", "?"), " に変身")

## クリーチャーデータを置き換え
func _replace_creature_data(participant: BattleParticipant, new_creature_data: Dictionary) -> void:
	# 元のデータを保存（original_creature_dataがあれば保持）
	var original_data = participant.creature_data.get("original_creature_data", null)
	
	# 新しいクリーチャーデータで置き換え
	participant.creature_data = new_creature_data.duplicate(true)
	
	# 元データを復元（戦闘後復帰用）
	if original_data != null:
		participant.creature_data["original_creature_data"] = original_data
	
	# 効果をリセット
	participant.creature_data["permanent_effects"] = []
	participant.creature_data["temporary_effects"] = []
	
	# ステータスを再計算
	participant.base_hp = new_creature_data.get("hp", 0)
	participant.base_ap = new_creature_data.get("ap", 0)
	participant.current_ap = participant.base_ap
	participant.current_hp = participant.base_hp

## 全クリーチャーリストを取得
func _get_all_creatures() -> Array:
	var creatures = []
	
	# CardLoaderから全クリーチャーを取得
	var card_loader = load("res://scripts/card_loader.gd").new()
	
	# 全クリーチャーを取得（CardLoaderのget_all_creatures()を使用）
	creatures = card_loader.get_all_creatures()
	
	return creatures

## 戦闘終了後の変身復帰
func revert_transform_after_battle(participant: BattleParticipant) -> void:
	if participant.creature_data.has("original_creature_data"):
		var original_data = participant.creature_data["original_creature_data"]
		print("【変身復帰】", participant.creature_data.get("name", "?"), " → ", original_data.get("name", "?"))
		participant.creature_data = original_data
		participant.creature_data.erase("original_creature_data")

## ターン数ボーナスを適用（ラーバキン用）
func apply_turn_number_bonus(participant: BattleParticipant, context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "turn_number_bonus":
			# GameFlowManagerから現在のターン数を取得
			var game_flow_manager = context.get("game_flow_manager")
			if not game_flow_manager:
				print("【ターン数ボーナス】GameFlowManagerが見つかりません")
				print("  context keys: ", context.keys())
				print("  board_system_ref: ", board_system_ref)
				if board_system_ref:
					print("  board_system_ref.game_flow_manager: ", board_system_ref.game_flow_manager)
				return
			
			var current_turn = game_flow_manager.current_turn_number
			var ap_mode = effect.get("ap_mode", "add")
			var hp_mode = effect.get("hp_mode", "add")
			
			# AP処理
			var old_ap = participant.current_ap
			if ap_mode == "subtract":
				# STから現ターン数を引く
				participant.current_ap = max(0, participant.current_ap - current_turn)
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " ST減算: ", old_ap, " → ", participant.current_ap, " (-", current_turn, ")")
			elif ap_mode == "add":
				participant.current_ap += current_turn
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " ST+", current_turn, " (ターン", current_turn, ")")
			elif ap_mode == "override":
				# STを現ターン数で上書き
				participant.current_ap = current_turn
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " ST上書き: ", old_ap, " → ", current_turn, " (ターン", current_turn, ")")
			
			# HP処理
			if hp_mode == "add":
				# temporary_bonus_hpに現ターン数を加算
				participant.temporary_bonus_hp += current_turn
				participant.update_current_hp()  # HPを再計算
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " HP+", current_turn, " (ターン", current_turn, ") → MHP:", participant.current_hp)
			elif hp_mode == "subtract":
				# temporary_bonus_hpから現ターン数を引く
				participant.temporary_bonus_hp -= current_turn
				participant.update_current_hp()  # HPを再計算
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " HP-", current_turn, " (ターン", current_turn, ") → MHP:", participant.current_hp)
			
			return

# ========================================
# 破壊数カウント効果
# ========================================

# 破壊数カウント効果を適用（ソウルコレクター用）
func apply_destroy_count_effects(participant: BattleParticipant):
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "destroy_count_multiplier":
			var stat = effect.get("stat", "ap")
			var multiplier = effect.get("multiplier", 5)
			
			# GameFlowManagerから破壊数取得
			var destroy_count = 0
			if game_flow_manager_ref:
				destroy_count = game_flow_manager_ref.get_destroy_count()
			
			var bonus_value = destroy_count * multiplier
			
			if stat == "ap":
				participant.temporary_bonus_ap += bonus_value
				participant.current_ap += bonus_value
				print("【破壊数効果】", participant.creature_data.get("name", "?"), 
					  " ST+", bonus_value, " (破壊数:", destroy_count, " × ", multiplier, ")")
			elif stat == "hp":
				participant.temporary_bonus_hp += bonus_value
				participant.update_current_hp()
				print("【破壊数効果】", participant.creature_data.get("name", "?"), 
					  " HP+", bonus_value, " (破壊数:", destroy_count, " × ", multiplier, ")")

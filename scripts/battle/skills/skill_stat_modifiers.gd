extends RefCounted
class_name SkillStatModifiers

## ステータス修正系スキルの処理
## 
## 対象effect_type:
## - turn_number_bonus: ターン数ボーナス（ラーバキン）
## - destroy_count_multiplier: 破壊数効果（ソウルコレクター）
## - constant_stat_bonus: 常時補正（アイスウォール、トルネード）
## - hand_count_multiplier: 手札数効果（リリス、フォースアンクレット）
## - land_count_multiplier: 土地数効果（アームドパラディン等7体）
## - battle_land_element_bonus / enemy_element_bonus: 戦闘地条件（アンフィビアン、カクタスウォール）
## - defender_fixed_ap: 防御時固定ST（ガーゴイル）
## - battle_land_level_bonus: 戦闘地レベル効果（ネッシー）
## - owned_land_threshold: 自ドミニオ数閾値（バーンタイタン）
## - specific_creature_count: 特定クリーチャーカウント（ハイプワーカー）
## - race_creature_stat_replace: 種族配置数ステータス（レッドキャップ）
## - adjacent_owned_land: 隣接自ドミニオ条件（タイガーヴェタ）

# ConditionChecker はグローバルクラスとして利用可能


## 土地数効果を適用（アームドパラディン等）
static func apply_land_count_effects(participant, context: Dictionary) -> void:
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
			
			# operation（加算 or 代入）
			var operation = effect.get("operation", "add")
			
			# statに応じてボーナスを適用
			var stat = effect.get("stat", "ap")
			
			if stat == "ap" or stat == "both":
				var old_ap = participant.current_ap
				if operation == "set":
					participant.current_ap = bonus
				else:
					participant.current_ap += bonus
				print("【土地数比例】", participant.creature_data.get("name", "?"))
				print("  対象属性:", target_elements, " 合計土地数:", total_count)
				print("  AP: ", old_ap, " → ", participant.current_ap, " (", operation, " ", bonus, ")")
			
			if stat == "hp" or stat == "both":
				var old_hp = participant.current_hp
				if operation == "set":
					# setの場合はbase_hpとcurrent_hpを計算値に設定
					# creature_data["hp"]は元の値を維持（戦闘後の復元用）
					participant.base_hp = bonus
					participant.current_hp = bonus
				else:
					participant.temporary_bonus_hp += bonus
				print("【土地数比例】", participant.creature_data.get("name", "?"))
				print("  対象属性:", target_elements, " 合計土地数:", total_count)
				print("  HP: ", old_hp, " → ", participant.current_hp, " (", operation, " ", bonus, ")")


## ターン数ボーナスを適用（ラーバキン用）
static func apply_turn_number_bonus(participant, _context: Dictionary, game_flow_manager_ref: Node) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "turn_number_bonus":
			# GameFlowManagerから現在のターン数を取得
			var current_turn = 1
			if game_flow_manager_ref:
				current_turn = game_flow_manager_ref.current_turn_number
			
			# APモードを取得（subtract: 引く, add: 足す, override: 上書き）
			var ap_mode = effect.get("ap_mode", "subtract")
			# HPモードを取得
			var hp_mode = effect.get("hp_mode", "none")
			
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
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " HP+", current_turn, " (ターン", current_turn, ")")
			elif hp_mode == "subtract":
				# temporary_bonus_hpから現ターン数を引く
				participant.temporary_bonus_hp -= current_turn
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " HP-", current_turn, " (ターン", current_turn, ")")
			
			return


## 破壊数カウント効果を適用（ソウルコレクター用）
static func apply_destroy_count_effects(participant, lap_system = null) -> void:
	if not participant or not participant.creature_data:
		return

	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])

	for effect in effects:
		if effect.get("effect_type") == "destroy_count_multiplier":
			var stat = effect.get("stat", "ap")
			var multiplier = effect.get("multiplier", 5)

			# LapSystemから破壊数取得
			var destroy_count = 0
			if lap_system:
				destroy_count = lap_system.get_destroy_count()
			
			var bonus_value = destroy_count * multiplier
			
			if stat == "ap":
				participant.temporary_bonus_ap += bonus_value
				participant.current_ap += bonus_value
				print("【破壊数効果】", participant.creature_data.get("name", "?"), 
					  " ST+", bonus_value, " (破壊数:", destroy_count, " × ", multiplier, ")")
			elif stat == "hp":
				participant.temporary_bonus_hp += bonus_value
				print("【破壊数効果】", participant.creature_data.get("name", "?"), 
					  " HP+", bonus_value, " (破壊数:", destroy_count, " × ", multiplier, ")")


## 常時補正効果を適用（アイスウォール、トルネード用）
static func apply_constant_stat_bonus(participant) -> void:
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "constant_stat_bonus":
			var stat = effect.get("stat", "ap")
			var value = effect.get("value", 0)
			
			if stat == "ap":
				participant.temporary_bonus_ap += value
				participant.current_ap += value
				print("【常時補正】", participant.creature_data.get("name", "?"), 
					  " ST", ("+" if value >= 0 else ""), value)
			elif stat == "hp":
				participant.temporary_bonus_hp += value
				print("【常時補正】", participant.creature_data.get("name", "?"), 
					  " HP", ("+" if value >= 0 else ""), value)


## 手札数効果を適用（リリス用）
static func apply_hand_count_effects(participant, player_id: int, card_system) -> void:
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "hand_count_multiplier":
			var stat = effect.get("stat", "hp")
			var multiplier = effect.get("multiplier", 10)
			
			# CardSystemから手札数取得
			var hand_count = 0
			if card_system:
				hand_count = card_system.get_hand_size_for_player(player_id)
			
			var bonus_value = hand_count * multiplier
			
			if stat == "ap":
				participant.temporary_bonus_ap += bonus_value
				participant.current_ap += bonus_value
				print("【手札数効果】", participant.creature_data.get("name", "?"), 
					  " ST+", bonus_value, " (手札数:", hand_count, " × ", multiplier, ")")
			elif stat == "hp":
				participant.temporary_bonus_hp += bonus_value
				print("【手札数効果】", participant.creature_data.get("name", "?"), 
					  " HP+", bonus_value, " (手札数:", hand_count, " × ", multiplier, ")")


## 戦闘地条件効果を適用（アンフィビアン、カクタスウォール用）
static func apply_battle_condition_effects(participant, context: Dictionary) -> void:
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		
		# 戦闘地の属性条件
		if effect_type == "battle_land_element_bonus":
			var condition = effect.get("condition", {})
			var allowed_elements = condition.get("battle_land_elements", [])
			
			# 戦闘地の属性を取得
			var battle_land_element = context.get("battle_land_element", "")
			
			if battle_land_element in allowed_elements:
				var stat = effect.get("stat", "ap")
				var value = effect.get("value", 0)
				
				if stat == "ap":
					participant.temporary_bonus_ap += value
					participant.current_ap += value
					print("【戦闘地条件】", participant.creature_data.get("name", "?"), 
						  " 戦闘地:", battle_land_element, " → ST+", value)
				elif stat == "hp":
					participant.temporary_bonus_hp += value
					print("【戦闘地条件】", participant.creature_data.get("name", "?"), 
						  " 戦闘地:", battle_land_element, " → HP+", value)
		
		# 敵の属性条件
		elif effect_type == "enemy_element_bonus":
			var condition = effect.get("condition", {})
			var allowed_elements = condition.get("enemy_elements", [])
			
			# 敵の属性を取得
			var enemy_element = context.get("enemy_element", "")
			
			if enemy_element in allowed_elements:
				var stat = effect.get("stat", "ap")
				var value = effect.get("value", 0)
				
				if stat == "ap":
					participant.temporary_bonus_ap += value
					participant.current_ap += value
					print("【敵属性条件】", participant.creature_data.get("name", "?"), 
						  " 敵:", enemy_element, " → ST+", value)
				elif stat == "hp":
					participant.temporary_bonus_hp += value
					print("【敵属性条件】", participant.creature_data.get("name", "?"), 
						  " 敵:", enemy_element, " → HP+", value)


## Phase 3-B効果を適用（中程度の条件効果）
static func apply_phase_3b_effects(participant, context: Dictionary, board_system_ref: Node) -> void:
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		
		# 1. 防御時固定ST（ガーゴイル）
		if effect_type == "defender_fixed_ap":
			var is_attacker = context.get("is_attacker", true)
			if not is_attacker:  # 防御側のみ
				var fixed_ap = effect.get("value", 50)
				participant.current_ap = fixed_ap
				print("【防御時固定ST】", participant.creature_data.get("name", "?"), 
					  " ST=", fixed_ap)
		
		# 2. 戦闘地レベル効果（ネッシー）
		elif effect_type == "battle_land_level_bonus":
			var condition_data = effect.get("condition", {})
			var required_element = condition_data.get("battle_land_element", "water")
			
			# 既存のConditionCheckerを使用して属性チェック
			var checker = ConditionChecker.new()
			var element_condition = {
				"condition_type": "on_element_land",
				"element": required_element
			}
			var is_on_element = checker.evaluate_single_condition(element_condition, context)
			
			if is_on_element:
				var tile_level = context.get("tile_level", 1)
				var multiplier = effect.get("multiplier", 10)
				var bonus = tile_level * multiplier
				
				var stat = effect.get("stat", "hp")
				if stat == "hp":
					participant.temporary_bonus_hp += bonus
					print("【戦闘地レベル効果】", participant.creature_data.get("name", "?"), 
						  " HP+", bonus, " (レベル:", tile_level, " × ", multiplier, ")")
		
		# 3. 自ドミニオ数閾値効果（バーンタイタン）
		elif effect_type == "owned_land_threshold":
			var threshold = effect.get("threshold", 5)
			var operation = effect.get("operation", "gte")  # gte, lt, etc
			
			# BoardSystemから自ドミニオ数を取得
			var player_id = context.get("player_id", 0)
			var owned_land_count = 0
			if board_system_ref:
				owned_land_count = board_system_ref.get_player_owned_land_count(player_id)
			
			var condition_met = false
			if operation == "gte":
				condition_met = owned_land_count >= threshold
			
			if condition_met:
				var stat_changes = effect.get("stat_changes", {})
				var ap_change = stat_changes.get("ap", 0)
				var hp_change = stat_changes.get("hp", 0)
				
				if ap_change != 0:
					participant.temporary_bonus_ap += ap_change
					participant.current_ap += ap_change
					print("【自ドミニオ数閾値】", participant.creature_data.get("name", "?"), 
						  " ST", ("+" if ap_change >= 0 else ""), ap_change, 
						  " (自ドミニオ:", owned_land_count, ")")
				
				if hp_change != 0:
					participant.temporary_bonus_hp += hp_change
					print("【自ドミニオ数閾値】", participant.creature_data.get("name", "?"), 
						  " HP", ("+" if hp_change >= 0 else ""), hp_change, 
						  " (自ドミニオ:", owned_land_count, ")")
		
		# 4. 特定クリーチャーカウント（ハイプワーカー）
		elif effect_type == "specific_creature_count":
			var target_name = effect.get("target_name", "")
			var multiplier = effect.get("multiplier", 10)
			var include_self = effect.get("include_self", true)
			
			# BoardSystemから特定クリーチャーをカウント
			var player_id = context.get("player_id", 0)
			var creature_count = 0
			if board_system_ref:
				creature_count = board_system_ref.count_creatures_by_name(player_id, target_name)
			
			# 侵略側（配置されていない）の場合、自分を除外
			var is_placed = context.get("is_placed_on_tile", false)
			if include_self and is_placed:
				# 自分も含める（既にカウント済み）
				pass
			elif not is_placed and creature_count > 0:
				# 侵略側は自分を除外
				creature_count -= 1
			
			var bonus = creature_count * multiplier
			
			var stat_changes = effect.get("stat_changes", {})
			var affects_ap = stat_changes.get("ap", true)
			var affects_hp = stat_changes.get("hp", true)
			
			if affects_ap:
				participant.temporary_bonus_ap += bonus
				participant.current_ap += bonus
			
			if affects_hp:
				participant.temporary_bonus_hp += bonus
			
			print("【特定クリーチャーカウント】", participant.creature_data.get("name", "?"), 
				  " ST&HP+", bonus, " (", target_name, ":", creature_count, " × ", multiplier, ")")
		
		# 4.5. 種族配置数でステータス決定（レッドキャップ）
		elif effect_type == "race_creature_stat_replace":
			var target_race = effect.get("target_race", "")
			var multiplier = effect.get("multiplier", 20)
			
			# BoardSystemから特定種族をカウント（配置済みのみ）
			var player_id = context.get("player_id", 0)
			var race_count = 0
			if board_system_ref:
				race_count = board_system_ref.count_creatures_by_race(player_id, target_race)
			
			var stat_value = int(race_count * multiplier)
			
			# ステータスを置き換え
			participant.base_hp = stat_value
			participant.current_ap = stat_value
			participant.current_hp = stat_value
			
			print("【種族配置数ステータス】", participant.creature_data.get("name", "?"),
				  " AP&HP=", stat_value, " (", target_race, ":", race_count, " × ", multiplier, ")")
		
		# 5. 他属性カウント（リビングクローブ）- SkillItemCreatureで処理済みのためスキップ
		elif effect_type == "other_element_count":
			pass  # apply_skills()の先頭でSkillItemCreature.apply_as_creature()により処理済み
		
		# 6. 隣接自ドミニオ条件（タイガーヴェタ）
		elif effect_type == "adjacent_owned_land":
			# 既存のConditionCheckerを使用
			var checker = ConditionChecker.new()
			var condition = {"condition_type": "adjacent_ally_land"}
			var has_adjacent_ally = checker.evaluate_single_condition(condition, context)
			
			if has_adjacent_ally:
				var stat_changes = effect.get("stat_changes", {})
				var ap_change = stat_changes.get("ap", 0)
				var hp_change = stat_changes.get("hp", 0)
				
				if ap_change != 0:
					participant.temporary_bonus_ap += ap_change
					participant.current_ap += ap_change
					print("【隣接自ドミニオ】", participant.creature_data.get("name", "?"), 
						  " ST+", ap_change)
				
				if hp_change != 0:
					participant.temporary_bonus_hp += hp_change
					print("【隣接自ドミニオ】", participant.creature_data.get("name", "?"), 
						  " HP+", hp_change)


## Phase 3-C効果を適用（ローンビースト、ジェネラルカン）
static func apply_phase_3c_effects(participant, context: Dictionary, board_system_ref: Node) -> void:
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		
		# 1. 基礎APをHPに加算（ローンビースト）
		if effect_type == "base_ap_to_hp":
			var base_ap = participant.creature_data.get("ap", 0)
			var base_up_ap = participant.creature_data.get("base_up_ap", 0)
			var total_base_ap = base_ap + base_up_ap
			
			participant.temporary_bonus_hp += total_base_ap
			print("【基礎AP→HP】", participant.creature_data.get("name", "?"), 
				  " HP+", total_base_ap, " (基礎AP: ", base_ap, "+", base_up_ap, ")")
		
		# 2. 条件付き配置数カウント（ジェネラルカン）
		elif effect_type == "conditional_land_count":
			var creature_condition = effect.get("creature_condition", {})
			var stat = effect.get("stat", "ap")
			var multiplier = effect.get("multiplier", 5)
			
			# プレイヤーの全タイルを取得
			var player_id = context.get("player_id", 0)
			if not board_system_ref:
				continue
			
			var player_tiles = board_system_ref.get_player_tiles(player_id)
			var qualified_count = 0
			
			# 各タイルのクリーチャーが条件を満たすかチェック
			for tile in player_tiles:
				if not tile.creature_data:
					continue
				
				# 条件チェック
				var condition_type = creature_condition.get("condition_type", "")
				if condition_type == "mhp_above":
					var threshold = creature_condition.get("value", 50)
					var creature_mhp = tile.creature_data.get("hp", 0) + tile.creature_data.get("base_up_hp", 0)
					if creature_mhp >= threshold:
						qualified_count += 1
			
			var bonus = qualified_count * multiplier
			
			if stat == "ap":
				participant.temporary_bonus_ap += bonus
				participant.current_ap += bonus
				print("【条件付き配置数】", participant.creature_data.get("name", "?"), 
					  " ST+", bonus, " (MHP50以上: ", qualified_count, " × ", multiplier, ")")
			elif stat == "hp":
				participant.temporary_bonus_hp += bonus
				print("【条件付き配置数】", participant.creature_data.get("name", "?"), 
					  " HP+", bonus, " (MHP50以上: ", qualified_count, " × ", multiplier, ")")

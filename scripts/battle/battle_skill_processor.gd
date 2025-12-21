extends Node
class_name BattleSkillProcessor

# バトルスキル処理
# 感応、強打、2回攻撃、巻物攻撃などのスキル適用を担当

# スキルモジュール
const SupportSkill = preload("res://scripts/battle/skills/skill_support.gd")
const ResonanceSkill = preload("res://scripts/battle/skills/skill_resonance.gd")
const ScrollAttackSkill = preload("res://scripts/battle/skills/skill_scroll_attack.gd")
const ReflectSkill = preload("res://scripts/battle/skills/skill_reflect.gd")
const ItemManipulationSkill = preload("res://scripts/battle/skills/skill_item_manipulation.gd")
const TransformSkill = preload("res://scripts/battle/skills/skill_transform.gd")
const PenetrationSkill = preload("res://scripts/battle/skills/skill_penetration.gd")
const PowerStrikeSkill = preload("res://scripts/battle/skills/skill_power_strike.gd")
const DoubleAttackSkill = preload("res://scripts/battle/skills/skill_double_attack.gd")
const FirstStrikeSkill = preload("res://scripts/battle/skills/skill_first_strike.gd")
const SpecialCreatureSkill = preload("res://scripts/battle/skills/skill_special_creature.gd")
var _skill_magic_gain = preload("res://scripts/battle/skills/skill_magic_gain.gd")

var board_system_ref = null
var game_flow_manager_ref = null
var card_system_ref = null

func setup_systems(board_system, game_flow_manager = null, card_system = null):
	board_system_ref = board_system
	game_flow_manager_ref = game_flow_manager
	card_system_ref = card_system

## バトル前スキル適用
func apply_pre_battle_skills(participants: Dictionary, tile_info: Dictionary, attacker_index: int) -> void:
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	
	# 🚫 【最優先】能力無効化チェック: ウォーロックディスク or skill_nullify呪いがある場合
	var SkillSpecialCreatureScript = load("res://scripts/battle/skills/skill_special_creature.gd")
	var has_nullify = _has_warlock_disk(attacker) or _has_warlock_disk(defender) or \
					  _has_skill_nullify_curse(attacker) or _has_skill_nullify_curse(defender)
	
	if has_nullify:
		print("【能力無効化発動】全スキル・変身・応援をスキップして基礎ステータスでバトル")
		# 敵の能力を無効化
		SkillSpecialCreatureScript.apply_nullify_enemy_abilities(attacker, defender)
		SkillSpecialCreatureScript.apply_nullify_enemy_abilities(defender, attacker)
		return  # ここで処理を終了し、バトルへ
	
	# 【Phase 0】変身スキル適用（戦闘開始時）
	var card_loader = load("res://scripts/card_loader.gd").new()
	TransformSkill.process_transform_effects(attacker, defender, card_loader, "on_battle_start")
	
	# プレイヤー土地情報取得
	var player_lands = board_system_ref.get_player_lands_by_element(attacker_index)
	
	# 【Phase 1】応援スキル適用（盤面全体を対象にバフ）
	var battle_tile_index = tile_info.get("index", -1)
	SupportSkill.apply_to_all(participants, battle_tile_index, board_system_ref)
	
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
			"game_flow_manager": game_flow_manager_ref,
			"is_placed_on_tile": false,  # 侵略側は配置されていない
			"enemy_mhp_override": defender.get_max_hp(),  # 計算済みMHPを渡す
			"enemy_name": defender.creature_data.get("name", ""),  # 敵の名前
			"opponent": defender,  # スクイドマントルチェック用
			"is_attacker": true  # 攻撃側フラグ
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
			"game_flow_manager": game_flow_manager_ref,
			"is_attacker": false,  # 防御側
			"is_placed_on_tile": true,  # 防御側は配置されている
			"enemy_mhp_override": attacker.get_max_hp(),  # 計算済みMHPを渡す
			"enemy_name": attacker.creature_data.get("name", ""),  # 敵の名前
			"opponent": attacker,  # スクイドマントルチェック用
			"is_defender": true  # 防御側フラグ
		}
	)
	apply_skills(defender, defender_context)
	
	# 貫通スキルによる土地ボーナスHP無効化
	# スクイドマントルチェック
	if not defender.has_squid_mantle:
		PenetrationSkill.apply_penetration(attacker, defender)
	else:
		print("【スクイドマントル】貫通を無効化")
	
	# 巻物攻撃による土地ボーナスHP無効化
	if attacker.is_using_scroll and defender.land_bonus_hp > 0:
		print("【巻物攻撃】防御側の土地ボーナス ", defender.land_bonus_hp, " を無効化")
		defender.land_bonus_hp = 0
		# update_current_hp() は呼ばない（current_hp が状態値になったため）
	
	# アイテム破壊・盗み処理
	apply_item_manipulation(attacker, defender)
	
	# 💰 魔力獲得スキル適用（バトル開始時）
	apply_magic_gain_on_battle_start(attacker, defender)

## スキル適用
func apply_skills(participant: BattleParticipant, context: Dictionary) -> void:
	
	var _has_scroll_power_strike = PowerStrikeSkill.has_scroll_power_strike(participant.creature_data)
	
	# 0. アイテムクリーチャーのクリーチャー時効果を適用
	if SkillItemCreature.is_item_creature(participant.creature_data):
		SkillItemCreature.apply_as_creature(participant, board_system_ref)
	# リビングクローブをアイテムとして使用した場合（フラグで判定）
	elif participant.creature_data.get("has_living_clove_effect", false):
		SkillItemCreature.apply_living_clove_stat(participant, board_system_ref)
	
	# 0.1. オーガロード（ID: 407）: オーガ配置時能力値上昇
	var creature_id = participant.creature_data.get("id", -1)
	if creature_id == 407:
		var ogre_player_id = context.get("player_id", 0)
		SpecialCreatureSkill.apply_ogre_lord_bonus(participant, ogre_player_id, board_system_ref)
	
	# 0.5. ターン数ボーナスを適用（最優先、他のスキルより前）
	apply_turn_number_bonus(participant, context)
	
	# 1. 感応スキルを適用
	ResonanceSkill.apply(participant, context)
	
	# 3. 土地数比例効果を適用（Phase 3追加）
	apply_land_count_effects(participant, context)
	
	# 3.5. 破壊数効果を適用（ソウルコレクター用）
	apply_destroy_count_effects(participant)
	
	# 3.6. 手札数効果を適用（リリス用）
	var player_id = context.get("player_id", 0)
	apply_hand_count_effects(participant, player_id, card_system_ref)
	
	# 3.7. 常時補正効果を適用（アイスウォール、トルネード用）
	apply_constant_stat_bonus(participant)
	
	# 3.8. 戦闘地条件効果を適用（アンフィビアン、カクタスウォール用）
	apply_battle_condition_effects(participant, context)
	
	# 3.9. Phase 3-B 効果（ガーゴイル、ネッシー、バーンタイタン等）
	apply_phase_3b_effects(participant, context)
	
	# 3.10. Phase 3-C 効果（ローンビースト、ジェネラルカン）
	apply_phase_3c_effects(participant, context)
	
	# 4. 先制・後手スキルを適用
	FirstStrikeSkill.apply(participant)
	
	# 5. 強打スキルを適用（巻物強打を含む）
	apply_power_strike_skills(participant, context)
	
	# 6. 巻物攻撃判定
	ScrollAttackSkill.apply(participant, context)
	
	# 7. 2回攻撃スキルを判定
	check_double_attack(participant, context)
	
	# 8. アイテム巻物が使用中の場合、AP を最終固定
	if participant.is_using_scroll:
		var ability_parsed = participant.creature_data.get("ability_parsed", {})
		var keyword_conditions = ability_parsed.get("keyword_conditions", {})
		var scroll_config = keyword_conditions.get("巻物攻撃", {})
		var scroll_type = scroll_config.get("scroll_type", "base_ap")
		var board_system = board_system_ref
		
		match scroll_type:
			"fixed_ap":
				var value = scroll_config.get("value", 0)
				participant.current_ap = value
				print("【AP最終固定】", participant.creature_data.get("name", "?"), 
					  " AP:", value)
			"base_ap":
				var base_ap = participant.creature_data.get("ap", 0)
				participant.current_ap = base_ap
				print("【AP最終固定】", participant.creature_data.get("name", "?"), 
					  " AP=基本AP:", base_ap)
			"land_count":
				var elements = scroll_config.get("elements", [])
				var multiplier = scroll_config.get("multiplier", 1)
				var total_count = 0
				if board_system:
					var scroll_player_id = context.get("player_id", 0)
					for element in elements:
						total_count += board_system.count_creatures_by_element(scroll_player_id, element)
				var calculated_ap = total_count * multiplier
				participant.current_ap = calculated_ap
				print("【AP最終固定】", participant.creature_data.get("name", "?"), 
					  " AP=", elements, "土地数", total_count, "×", multiplier, "=", calculated_ap)

## 2回攻撃スキル判定
func check_double_attack(participant: BattleParticipant, context: Dictionary) -> void:
	# スクイドマントルチェック：防御側がスクイドマントルを持つ場合は2回攻撃無効化
	var opponent = context.get("opponent")
	if opponent and opponent.has_squid_mantle and context.get("is_attacker", false):
		print("【スクイドマントル】", participant.creature_data.get("name", "?"), "の2回攻撃を無効化")
		return
	
	DoubleAttackSkill.apply(participant)

## 強打スキル適用（巻物強打を含む）
func apply_power_strike_skills(participant: BattleParticipant, context: Dictionary) -> void:
	# スクイドマントルチェック：防御側がスクイドマントルを持つ場合は強打無効化
	var opponent = context.get("opponent")
	if opponent and opponent.has_squid_mantle and context.get("is_attacker", false):
		print("【スクイドマントル】", participant.creature_data.get("name", "?"), "の強打を無効化")
		return
	
	PowerStrikeSkill.apply(participant, context)
	print("【強打適用後】", participant.creature_data.get("name", "?"), " AP:", participant.current_ap)


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
					# setの場合は一度リセットしてから設定
					var base_mhp = participant.get_max_hp()
					participant.current_hp = base_mhp
					participant.temporary_bonus_hp = bonus - base_mhp
				else:
					participant.temporary_bonus_hp += bonus
				print("【土地数比例】", participant.creature_data.get("name", "?"))
				print("  対象属性:", target_elements, " 合計土地数:", total_count)
				print("  HP: ", old_hp, " → ", participant.current_hp, " (", operation, " ", bonus, ")")


## アイテム破壊・盗み処理（戦闘開始前）
func apply_item_manipulation(first: BattleParticipant, second: BattleParticipant) -> void:
	"""
	先制攻撃の順序でアイテム破壊・盗みを処理
	
	@param first: 先に行動する側
	@param second: 後に行動する側
	"""
	ItemManipulationSkill.apply(first, second)

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
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " HP+", current_turn, " (ターン", current_turn, ")")
			elif hp_mode == "subtract":
				# temporary_bonus_hpから現ターン数を引く
				participant.temporary_bonus_hp -= current_turn
				print("【ターン数ボーナス】", participant.creature_data.get("name", "?"), 
					  " HP-", current_turn, " (ターン", current_turn, ")")
			
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
			
			# LapSystemから破壊数取得
			var destroy_count = 0
			if game_flow_manager_ref and game_flow_manager_ref.lap_system:
				destroy_count = game_flow_manager_ref.lap_system.get_destroy_count()
			
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

## Phase 3-C効果を適用（ローンビースト、ジェネラルカン）
func apply_phase_3c_effects(participant: BattleParticipant, context: Dictionary):
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
					# BattleParticipantのget_max_hp()を使用してMHP取得
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

## Phase 3-B効果を適用（中程度の条件効果）
func apply_phase_3b_effects(participant: BattleParticipant, context: Dictionary):
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		
		# 1. 防御時固定ST（ガーゴイル） - 既存の条件チェック不要（is_attackerで直接判定）
		if effect_type == "defender_fixed_ap":
			var is_attacker = context.get("is_attacker", true)
			if not is_attacker:  # 防御側のみ
				var fixed_ap = effect.get("value", 50)
				participant.current_ap = fixed_ap
				print("【防御時固定ST】", participant.creature_data.get("name", "?"), 
					  " ST=", fixed_ap)
		
		# 2. 戦闘地レベル効果（ネッシー） - 既存のon_element_land条件を使用
		elif effect_type == "battle_land_level_bonus":
			var condition_data = effect.get("condition", {})
			var required_element = condition_data.get("battle_land_element", "water")
			
			# 既存のConditionCheckerを使用して属性チェック
			var checker = ConditionChecker.new()
			var element_condition = {
				"condition_type": "on_element_land",
				"element": required_element
			}
			var is_on_element = checker._evaluate_single_condition(element_condition, context)
			
			if is_on_element:
				var tile_level = context.get("tile_level", 1)
				var multiplier = effect.get("multiplier", 10)
				var bonus = tile_level * multiplier
				
				var stat = effect.get("stat", "hp")
				if stat == "hp":
					participant.temporary_bonus_hp += bonus
					print("【戦闘地レベル効果】", participant.creature_data.get("name", "?"), 
						  " HP+", bonus, " (レベル:", tile_level, " × ", multiplier, ")")
		
		# 3. 自領地数閾値効果（バーンタイタン）
		elif effect_type == "owned_land_threshold":
			var threshold = effect.get("threshold", 5)
			var operation = effect.get("operation", "gte")  # gte, lt, etc
			
			# BoardSystemから自領地数を取得
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
					print("【自領地数閾値】", participant.creature_data.get("name", "?"), 
						  " ST", ("+" if ap_change >= 0 else ""), ap_change, 
						  " (自領地:", owned_land_count, ")")
				
				if hp_change != 0:
					participant.temporary_bonus_hp += hp_change
					print("【自領地数閾値】", participant.creature_data.get("name", "?"), 
						  " HP", ("+" if hp_change >= 0 else ""), hp_change, 
						  " (自領地:", owned_land_count, ")")
		
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
			
			# 侵略側（配置されていない）は自分を含めない
			# count_creatures_by_raceは配置済みのみカウントするので追加処理不要
			
			var stat_value = int(race_count * multiplier)
			
			# ステータスを置き換え（基本値を上書き）
			participant.creature_data["ap"] = stat_value
			participant.creature_data["hp"] = stat_value
			participant.current_ap = stat_value
			participant.current_hp = stat_value
			# max_hpはget_max_hp()で計算されるため、creature_data["hp"]を設定すればOK
			
			print("【種族配置数ステータス】", participant.creature_data.get("name", "?"),
				  " AP&HP=", stat_value, " (", target_race, ":", race_count, " × ", multiplier, ")")
		
		# 5. 他属性カウント（リビングクローブ）- SkillItemCreatureで処理済みのためスキップ
		elif effect_type == "other_element_count":
			pass  # apply_skills()の先頭でSkillItemCreature.apply_as_creature()により処理済み
		
		# 6. 隣接自領地条件（タイガーヴェタ） - 既存の条件チェック機能を使用
		elif effect_type == "adjacent_owned_land":
			# 既存のConditionCheckerを使用
			var checker = ConditionChecker.new()
			var condition = {"condition_type": "adjacent_ally_land"}
			var has_adjacent_ally = checker._evaluate_single_condition(condition, context)
			
			if has_adjacent_ally:
				var stat_changes = effect.get("stat_changes", {})
				var ap_change = stat_changes.get("ap", 0)
				var hp_change = stat_changes.get("hp", 0)
				
				if ap_change != 0:
					participant.temporary_bonus_ap += ap_change
					participant.current_ap += ap_change
					print("【隣接自領地】", participant.creature_data.get("name", "?"), 
						  " ST+", ap_change)
				
				if hp_change != 0:
					participant.temporary_bonus_hp += hp_change
					print("【隣接自領地】", participant.creature_data.get("name", "?"), 
						  " HP+", hp_change)

## ランダムステータス効果を適用（スペクター用）
## バトル準備時に呼び出され、STとHPをランダムな値に設定する
func apply_random_stat_effects(participant: BattleParticipant) -> void:
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "random_stat":
			var stat = effect.get("stat", "both")
			var min_value = effect.get("min", 10)
			var max_value = effect.get("max", 70)
			
			randomize()
			
			# STをランダムに設定
			if stat == "ap" or stat == "both":
				var random_ap = randi() % (max_value - min_value + 1) + min_value
				var base_ap = participant.creature_data.get("ap", 0)
				var base_up_ap = participant.creature_data.get("base_up_ap", 0)
				participant.temporary_bonus_ap = random_ap - (base_ap + base_up_ap)
				participant.update_current_ap()
				print("【ランダム能力値】", participant.creature_data.get("name", "?"), 
					  " ST=", participant.current_ap, " (", min_value, "~", max_value, ")")
			
			# HPをランダムに設定
			if stat == "hp" or stat == "both":
				var random_hp = randi() % (max_value - min_value + 1) + min_value
				# temporary_bonus_hpを使ってHPを設定
				var base_mhp = participant.get_max_hp()
				participant.temporary_bonus_hp = random_hp - base_mhp
				# update_current_hp() は呼ばない（current_hp が状態値になったため）
				print("【ランダム能力値】", participant.creature_data.get("name", "?"), 
					  " HP=", participant.current_hp, " (", min_value, "~", max_value, ")")
			
			return

## 💰 バトル開始時の魔力獲得スキルを適用
func apply_magic_gain_on_battle_start(attacker: BattleParticipant, defender: BattleParticipant) -> void:
	"""
	バトル開始時に発動する魔力獲得スキルをまとめて適用
	- 侵略時魔力獲得（攻撃側のみ）
	- 無条件魔力獲得（両側）
	"""
	# spell_magic_refを直接使う（BattleParticipantから取得）
	var spell_magic = attacker.spell_magic_ref
	if not spell_magic:
		return
	
	# 魔力獲得スキルを適用
	_skill_magic_gain.apply_on_battle_start(attacker, defender, spell_magic)

## 戦闘地条件効果を適用（アンフィビアン、カクタスウォール用）
func apply_battle_condition_effects(participant: BattleParticipant, context: Dictionary):
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
					# update_current_hp() は呼ばない（current_hp が状態値になったため）
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
					# update_current_hp() は呼ばない（current_hp が状態値になったため）
					print("【敵属性条件】", participant.creature_data.get("name", "?"), 
						  " 敵:", enemy_element, " → HP+", value)

## 常時補正効果を適用（アイスウォール、トルネード用）
func apply_constant_stat_bonus(participant: BattleParticipant):
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
				# update_current_hp() は呼ばない（current_hp が状態値になったため）
				print("【常時補正】", participant.creature_data.get("name", "?"), 
					  " HP", ("+" if value >= 0 else ""), value)

## 手札数効果を適用（リリス用）
func apply_hand_count_effects(participant: BattleParticipant, player_id: int, card_system):
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
				# update_current_hp() は呼ばない（current_hp が状態値になったため）
				print("【手札数効果】", participant.creature_data.get("name", "?"), 
					  " HP+", bonus_value, " (手札数:", hand_count, " × ", multiplier, ")")

## ウォーロックディスクチェック
##
## パーティシパントがウォーロックディスクを装備しているかチェック
##
## @param participant チェック対象のパーティシパント
## @return ウォーロックディスクを装備していればtrue
func _has_warlock_disk(participant: BattleParticipant) -> bool:
	var items = participant.creature_data.get("items", [])
	
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var effects = effect_parsed.get("effects", [])
		
		for effect in effects:
			if effect.get("effect_type") == "nullify_all_enemy_abilities":
				return true
	
	return false

## skill_nullify 呪いを持っているかチェック
func _has_skill_nullify_curse(participant: BattleParticipant) -> bool:
	return SpellCurseBattle.has_skill_nullify(participant.creature_data)

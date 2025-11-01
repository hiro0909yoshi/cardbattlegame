extends Node
class_name BattlePreparation

# バトル準備フェーズ処理
# BattleParticipantの作成、アイテム効果、土地ボーナス計算を担当

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")
const TransformSkill = preload("res://scripts/battle/skills/skill_transform.gd")
const FirstStrikeSkill = preload("res://scripts/battle/skills/skill_first_strike.gd")
const DoubleAttackSkill = preload("res://scripts/battle/skills/skill_double_attack.gd")

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
	
	# base_up_hpを設定（手札から出す場合はないはずだが、移動侵略の場合はある）
	attacker.base_up_hp = card_data.get("base_up_hp", 0)
	attacker.base_up_ap = card_data.get("base_up_ap", 0)
	
	# 現在HPから復元（手札から出す場合は満タン、移動侵略の場合はダメージ後の値）
	var attacker_max_hp = attacker.get_max_hp()
	var attacker_current_hp = card_data.get("current_hp", attacker_max_hp)
	
	# base_hpに現在HPから永続ボーナスを引いた値を設定
	attacker.base_hp = attacker_current_hp - attacker.base_up_hp
	
	# current_hpを再計算
	attacker.update_current_hp()
	
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
	
	# base_up_hpを設定
	defender.base_up_hp = defender_creature.get("base_up_hp", 0)
	
	# 現在HPから復元（ない場合は満タン）
	var defender_max_hp = defender.get_max_hp()
	var defender_current_hp = defender_creature.get("current_hp", defender_max_hp)
	
	# base_hpに現在HPから永続ボーナスを引いた値を設定
	# （BattleParticipant.base_hpは「基本HPの現在値」を意味する）
	defender.base_hp = defender_current_hp - defender.base_up_hp
	
	# current_hpを再計算
	defender.update_current_hp()
	
	# 効果配列を適用
	apply_effect_arrays(attacker, card_data)
	apply_effect_arrays(defender, defender_creature)
	
	# アイテム効果を適用
	if not attacker_item.is_empty():
		# アイテムデータをクリーチャーのitemsに追加（反射チェックで使用）
		if not attacker.creature_data.has("items"):
			attacker.creature_data["items"] = []
		attacker.creature_data["items"].append(attacker_item)
		apply_item_effects(attacker, attacker_item, defender)
	
	if not defender_item.is_empty():
		# アイテムデータをクリーチャーのitemsに追加（反射チェックで使用）
		if not defender.creature_data.has("items"):
			defender.creature_data["items"] = []
		defender.creature_data["items"].append(defender_item)
		apply_item_effects(defender, defender_item, attacker)
	
	# アイテムクリーチャー・バフ処理
	# リビングアーマー（ID: 438）: クリーチャーとして戦闘時ST+50
	var attacker_id = attacker.creature_data.get("id", -1)
	var defender_id = defender.creature_data.get("id", -1)
	
	if attacker_id == 438:
		attacker.temporary_bonus_ap += 50
		print("[リビングアーマー] クリーチャーとして戦闘 ST+50")
	
	if defender_id == 438:
		defender.temporary_bonus_ap += 50
		print("[リビングアーマー] クリーチャーとして戦闘 ST+50")
	
	# ブルガサリ（ID: 339）: アイテム使用時ST+20
	if attacker_id == 339:
		if not attacker_item.is_empty():
			attacker.temporary_bonus_ap += 20
			print("[ブルガサリ] 自分がアイテム使用 ST+20")
		if not defender_item.is_empty():
			# 敵がアイテムを使用したフラグを設定（永続バフは後で）
			attacker.enemy_used_item = true
	
	if defender_id == 339:
		if not defender_item.is_empty():
			defender.temporary_bonus_ap += 20
			print("[ブルガサリ] 自分がアイテム使用 ST+20")
		if not attacker_item.is_empty():
			# 敵がアイテムを使用したフラグを設定（永続バフは後で）
			defender.enemy_used_item = true
	
	# オーガロード（ID: 407）: オーガ配置時能力値上昇
	if attacker_id == 407:
		_apply_ogre_lord_bonus(attacker, attacker_index)
	
	if defender_id == 407:
		_apply_ogre_lord_bonus(defender, defender_owner)
	
	# アイテムクリーチャー効果適用後、current_apを再計算
	if attacker_id == 438 or attacker_id == 339 or attacker_id == 407:
		attacker.current_ap = attacker.creature_data.get("ap", 0) + attacker.base_up_ap + attacker.temporary_bonus_ap
	if defender_id == 438 or defender_id == 339 or defender_id == 407:
		defender.current_ap = defender.creature_data.get("ap", 0) + defender.base_up_ap + defender.temporary_bonus_ap
	
	# ランダムステータス効果を適用（スペクター用）
	_apply_random_stat_effects(attacker)
	_apply_random_stat_effects(defender)
	
	# 🔄 戦闘開始時の変身処理（アイテム効果適用後）
	var transform_result = {}
	if card_system_ref:
		# CardLoaderのグローバル参照を取得
		# @GlobalScope.CardLoader は Autoload として自動的に利用可能
		var card_loader_instance = CardLoader if typeof(CardLoader) != TYPE_NIL else null
		
		if card_loader_instance != null and card_loader_instance.has_method("get_all_creatures"):
			print("【変身】CardLoader取得成功、全カード数: ", card_loader_instance.all_cards.size())
		else:
			print("【警告】CardLoaderが利用できません - 変身処理をスキップ")
		
		transform_result = TransformSkill.process_transform_effects(
			attacker, 
			defender, 
			card_loader_instance, 
			"on_battle_start"
		)
	
	return {
		"attacker": attacker,
		"defender": defender,
		"transform_result": transform_result
	}

## 効果配列（permanent_effects, temporary_effects）を適用
func apply_effect_arrays(participant: BattleParticipant, creature_data: Dictionary) -> void:
	# base_up_hp/apを適用（合成・マスグロース等）
	participant.base_up_hp = creature_data.get("base_up_hp", 0)
	participant.base_up_ap = creature_data.get("base_up_ap", 0)
	
	# 効果配列を保持（打ち消し効果判定用）
	participant.permanent_effects = creature_data.get("permanent_effects", [])
	participant.temporary_effects = creature_data.get("temporary_effects", [])
	
	# permanent_effectsから効果を計算
	for effect in participant.permanent_effects:
		if effect.get("type") == "stat_bonus":
			var stat = effect.get("stat", "")
			var value = effect.get("value", 0)
			if stat == "hp":
				participant.temporary_bonus_hp += value
			elif stat == "ap":
				participant.temporary_bonus_ap += value
	
	# temporary_effectsから効果を計算
	for effect in participant.temporary_effects:
		if effect.get("type") == "stat_bonus":
			var stat = effect.get("stat", "")
			var value = effect.get("value", 0)
			if stat == "hp":
				participant.temporary_bonus_hp += value
			elif stat == "ap":
				participant.temporary_bonus_ap += value
	
	# base_up_apをcurrent_apに反映
	participant.current_ap += participant.base_up_ap + participant.temporary_bonus_ap
	
	# HPを更新
	participant.update_current_hp()
	
	if participant.base_up_hp > 0 or participant.base_up_ap > 0:
		print("[効果] ", creature_data.get("name", "?"), 
			  " base_up_hp:", participant.base_up_hp, 
			  " base_up_ap:", participant.base_up_ap)
	if participant.temporary_bonus_hp > 0 or participant.temporary_bonus_ap > 0:
		print("[効果] ", creature_data.get("name", "?"), 
			  " temporary_bonus_hp:", participant.temporary_bonus_hp, 
			  " temporary_bonus_ap:", participant.temporary_bonus_ap)

## アイテムまたは援護クリーチャーの効果を適用
func apply_item_effects(participant: BattleParticipant, item_data: Dictionary, enemy_participant: BattleParticipant) -> void:
	var item_type = item_data.get("type", "")
	print("[アイテム効果適用] ", item_data.get("name", "???"), " (type: ", item_type, ")")
	
	# contextを構築（既存システムと同じ形式）
	var context = {
		"player_id": participant.player_id,
		"creature_element": participant.creature_data.get("element", ""),
		"creature_rarity": participant.creature_data.get("rarity", ""),
		"enemy_element": enemy_participant.creature_data.get("element", "") if enemy_participant else ""
	}
	
	# 援護クリーチャーの場合はAP/HPのみ加算
	if item_type == "creature":
		var creature_ap = item_data.get("ap", 0)
		var creature_hp = item_data.get("hp", 0)
		
		if creature_ap > 0:
			participant.current_ap += creature_ap
			print("  [援護] AP+", creature_ap, " → ", participant.current_ap)
		
		if creature_hp > 0:
			participant.item_bonus_hp += creature_hp
			participant.update_current_hp()
			print("  [援護] HP+", creature_hp, " → ", participant.current_hp)
		
		# 【ブラッドプリン専用処理】援護クリーチャーのMHPを永続吸収
		if participant.creature_data.get("id") == 137:
			# 援護クリーチャーのMHPを取得（hp + base_up_hp）
			var assist_base_hp = item_data.get("hp", 0)
			var assist_base_up_hp = item_data.get("base_up_hp", 0)
			var assist_mhp = assist_base_hp + assist_base_up_hp
			
			# ブラッドプリンの現在MHPを取得
			var current_mhp = participant.get_max_hp()
			
			# MHP上限100チェック
			var max_increase = 100 - current_mhp
			var actual_increase = min(assist_mhp, max_increase)
			
			if actual_increase > 0:
				# 永続的にMHPを上昇（creature_dataのみ更新、戦闘中は適用しない）
				var blood_purin_base_up_hp = participant.creature_data.get("base_up_hp", 0)
				participant.creature_data["base_up_hp"] = blood_purin_base_up_hp + actual_increase
				
				print("【ブラッドプリン効果】援護クリーチャー", item_data.get("name", "?"), "のMHP", assist_mhp, "を吸収")
				print("  MHP: ", current_mhp, " → ", current_mhp + actual_increase, " (+", actual_increase, ")")
		
		# 援護クリーチャーのスキルは継承されないのでここで終了
		return
	
	# 以下はアイテムカードの処理
	# effect_parsedから効果を取得（アイテムはeffect_parsedを使用）
	var effect_parsed = item_data.get("effect_parsed", {})
	if effect_parsed.is_empty():
		print("  警告: effect_parsedが定義されていません")
		return
	
	# stat_bonusを先に適用（ST+20、HP+20など）
	var stat_bonus = effect_parsed.get("stat_bonus", {})
	if not stat_bonus.is_empty():
		var st = stat_bonus.get("st", 0)
		var hp = stat_bonus.get("hp", 0)
		var force_st = stat_bonus.get("force_st", false)
		
		# force_st: STを絶対値で設定（例: スフィアシールドのST=0）
		if force_st:
			participant.current_ap = st
			print("  ST=", st, "（絶対値設定）")
		elif st > 0:
			participant.current_ap += st
			print("  ST+", st, " → ", participant.current_ap)
		
		if hp > 0:
			participant.item_bonus_hp += hp
			participant.update_current_hp()
			print("  HP+", hp, " → ", participant.current_hp)
	
	var effects = effect_parsed.get("effects", [])
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
			
			"element_count_bonus":
				# 属性別配置数ボーナス（既存システム活用）
				var elements = effect.get("elements", [])
				var multiplier = effect.get("multiplier", 1)
				var stat = effect.get("stat", "ap")
				var player_id = context.get("player_id", 0)
				
				var total_count = 0
				for element in elements:
					if board_system_ref:
						total_count += board_system_ref.count_creatures_by_element(player_id, element)
				
				var bonus = total_count * multiplier
				
				if stat == "ap":
					participant.current_ap += bonus
					print("  [属性配置数]", elements, ":", total_count, " × ", multiplier, " = AP+", bonus)
				elif stat == "hp":
					participant.item_bonus_hp += bonus
					participant.update_current_hp()
					print("  [属性配置数]", elements, ":", total_count, " × ", multiplier, " = HP+", bonus)
			
			"same_element_as_enemy_count":
				# 敵と同属性の配置数ボーナス（既存システム活用）
				var multiplier = effect.get("multiplier", 1)
				var stat = effect.get("stat", "ap")
				var player_id = context.get("player_id", 0)
				var enemy_element = context.get("enemy_element", "")
				
				var count = 0
				if enemy_element != "" and board_system_ref:
					count = board_system_ref.count_creatures_by_element(player_id, enemy_element)
				
				var bonus = count * multiplier
				
				if stat == "ap":
					participant.current_ap += bonus
					print("  [敵同属性配置数] 敵=", enemy_element, ":", count, " × ", multiplier, " = AP+", bonus)
				elif stat == "hp":
					participant.item_bonus_hp += bonus
					participant.update_current_hp()
					print("  [敵同属性配置数] 敵=", enemy_element, ":", count, " × ", multiplier, " = HP+", bonus)
			
			"hand_count_multiplier":
				# 手札数ボーナス（フォースアンクレット、リリスなど）
				var multiplier_hc = effect.get("multiplier", 1)
				var stat_hc = effect.get("stat", "ap")
				var player_id = context.get("player_id", 0)
				
				# CardSystemから手札数を取得
				var hand_count = 0
				if card_system_ref:
					hand_count = card_system_ref.get_hand_size_for_player(player_id)
				
				var bonus_hc = hand_count * multiplier_hc
				
				if stat_hc == "ap":
					participant.current_ap += bonus_hc
					print("  [手札数ボーナス] 手札:", hand_count, "枚 × ", multiplier_hc, " = ST+", bonus_hc)
				elif stat_hc == "hp":
					participant.item_bonus_hp += bonus_hc
					participant.update_current_hp()
					print("  [手札数ボーナス] 手札:", hand_count, "枚 × ", multiplier_hc, " = HP+", bonus_hc)
			
			"owned_land_count_bonus":
				# 自領地数ボーナス（マグマアーマー、ストームアーマー）
				var elements_olc = effect.get("elements", [])
				var multiplier_olc = effect.get("multiplier", 1)
				var stat_olc = effect.get("stat", "hp")
				var player_id_olc = context.get("player_id", 0)
				
				# BoardSystemから自領地数を取得
				var total_land_count = 0
				if board_system_ref:
					var player_lands = board_system_ref.get_player_lands_by_element(player_id_olc)
					for element in elements_olc:
						total_land_count += player_lands.get(element, 0)
				
				var bonus_olc = total_land_count * multiplier_olc
				
				if stat_olc == "ap":
					participant.current_ap += bonus_olc
					print("  [自領地数ボーナス] ", elements_olc, ":", total_land_count, "枚 × ", multiplier_olc, " = ST+", bonus_olc)
				elif stat_olc == "hp":
					participant.item_bonus_hp += bonus_olc
					participant.update_current_hp()
					print("  [自領地数ボーナス] ", elements_olc, ":", total_land_count, "枚 × ", multiplier_olc, " = HP+", bonus_olc)
			
			"grant_skill":
				# スキル付与（例：強打、先制など）
				var skill_name = effect.get("skill", "")
				
				# 条件チェック（skill_conditionsが配列の場合に対応）
				var skill_conditions = effect.get("skill_conditions", [])
				var condition = effect.get("condition", {})  # 後方互換性のため残す
				
				# skill_conditions（配列）がある場合はそちらを優先
				var conditions_to_check = []
				if not skill_conditions.is_empty():
					conditions_to_check = skill_conditions
				elif not condition.is_empty():
					conditions_to_check = [condition]
				
				# 巻物強打の場合は条件をスキップ（バトル時に評価）
				var skip_condition_check = (skill_name == "巻物強打")
				
				# 全ての条件をチェック（AND条件）
				var all_conditions_met = true
				if not skip_condition_check:
					for cond in conditions_to_check:
						if not check_skill_grant_condition(participant, cond, context):
							all_conditions_met = false
							break
				
				if all_conditions_met:
					grant_skill_to_participant(participant, skill_name, effect)
					if skip_condition_check:
						print("  スキル付与: ", skill_name, " (条件はバトル時に評価)")
					else:
						print("  スキル付与: ", skill_name)
			
			"st_drain":
				# STドレイン（サキュバスリング）
				# 敵のSTを全て吸収して自分のSTに加算、敵のSTは0になる
				var target = effect.get("target", "enemy")
				if target == "enemy" and enemy_participant:
					var drained_st = enemy_participant.current_ap
					if drained_st > 0:
						# 敵のSTを吸収
						participant.current_ap += drained_st
						# 敵のSTを0に
						enemy_participant.current_ap = 0
						enemy_participant.creature_data["ap"] = 0
						print("  [STドレイン] ", participant.creature_data.get("name", "?"), " が ", enemy_participant.creature_data.get("name", "?"), " のST", drained_st, "を吸収")
						print("    → 自ST:", participant.current_ap, " / 敵ST:", enemy_participant.current_ap)
			
			"grant_first_strike":
				# アイテム先制付与
				SkillFirstStrike.grant_skill(participant, "先制")
			
			"grant_last_strike":
				# アイテム後手付与
				SkillFirstStrike.grant_skill(participant, "後手")
			
			"grant_double_attack":
				# アイテム2回攻撃付与
				DoubleAttackSkill.grant_skill(participant)
			
			"reflect_damage", "nullify_reflect":
				# 反射系のスキルはバトル中にBattleSkillProcessorで処理されるため、ここではスキップ
				pass
			
			"revive":
				# 死者復活スキルを付与
				# effect_parsedの詳細情報はparticipant.creature_dataのitemsに保存されているので
				# ここではキーワードのみ追加
				if not participant.creature_data.has("ability_parsed"):
					participant.creature_data["ability_parsed"] = {}
				if not participant.creature_data["ability_parsed"].has("keywords"):
					participant.creature_data["ability_parsed"]["keywords"] = []
				
				if not "死者復活" in participant.creature_data["ability_parsed"]["keywords"]:
					participant.creature_data["ability_parsed"]["keywords"].append("死者復活")
					print("  スキル付与: 死者復活")
			
			"random_stat_bonus":
				# ランダムステータスボーナス（スペクターローブ等）
				var st_range = effect.get("st_range", {})
				var hp_range = effect.get("hp_range", {})
				
				var st_bonus = 0
				var hp_bonus = 0
				
				# STのランダムボーナス
				if not st_range.is_empty():
					var st_min = st_range.get("min", 0)
					var st_max = st_range.get("max", 0)
					st_bonus = randi() % int(st_max - st_min + 1) + st_min
					participant.current_ap += st_bonus
				
				# HPのランダムボーナス
				if not hp_range.is_empty():
					var hp_min = hp_range.get("min", 0)
					var hp_max = hp_range.get("max", 0)
					hp_bonus = randi() % int(hp_max - hp_min + 1) + hp_min
					participant.item_bonus_hp += hp_bonus
					participant.update_current_hp()
				
				print("  [ランダムボーナス] ST+", st_bonus, ", HP+", hp_bonus)
			
			"element_mismatch_bonus":
				# 属性不一致ボーナス（プリズムワンド）
				var user_element = participant.creature_data.get("element", "")
				var enemy_element = context.get("enemy_element", "")
				
				# 属性が異なる場合のみボーナス適用
				if user_element != enemy_element:
					var stat_bonus_data = effect.get("stat_bonus", {})
					var st = stat_bonus_data.get("st", 0)
					var hp = stat_bonus_data.get("hp", 0)
					
					if st > 0:
						participant.current_ap += st
					
					if hp > 0:
						participant.item_bonus_hp += hp
						participant.update_current_hp()
					
					print("  [属性不一致] ", user_element, " ≠ ", enemy_element, " → ST+", st, ", HP+", hp)
				else:
					print("  [属性不一致] ", user_element, " = ", enemy_element, " → ボーナスなし")
			
			"fixed_stat":
				# 固定値設定（ペトリフストーン: ST=0, HP=80）
				var stat = effect.get("stat", "")
				var fixed_value = int(effect.get("value", 0))
				var operation = effect.get("operation", "set")
				
				if operation == "set":
					if stat == "st":
						# 基本APを固定値に設定
						participant.creature_data["ap"] = fixed_value
						participant.current_ap = fixed_value
						print("  [固定値] ST=", fixed_value)
					elif stat == "hp":
						# 基本MHPを固定値に設定（土地ボーナス等はその後加算される）
						participant.creature_data["mhp"] = fixed_value
						participant.creature_data["hp"] = fixed_value
						participant.base_hp = fixed_value
						participant.base_up_hp = 0  # 合成等の永続ボーナスも無効化
						participant.update_current_hp()
						print("  [固定値] HP=", fixed_value)
			
			"nullify_item_manipulation":
				# アイテム破壊・盗み無効（エンジェルケープ）
				# ability_parsedにeffectを追加するだけでSkillItemManipulationが認識する
				if not participant.creature_data.has("ability_parsed"):
					participant.creature_data["ability_parsed"] = {}
				if not participant.creature_data["ability_parsed"].has("effects"):
					participant.creature_data["ability_parsed"]["effects"] = []
				
				# 既に登録されていなければ追加
				var already_has = false
				for existing_effect in participant.creature_data["ability_parsed"]["effects"]:
					if existing_effect.get("effect_type") == "nullify_item_manipulation":
						already_has = true
						break
				
				if not already_has:
					participant.creature_data["ability_parsed"]["effects"].append(effect)
					print("  アイテム破壊・盗み無効を付与")
			
			"nullify_attacker_special_attacks":
				# スクイドマントル：敵の特殊攻撃無効化
				participant.has_squid_mantle = true
				print("  スクイドマントル効果付与（敵の特殊攻撃無効化）")
			
			"change_element":
				# ニュートラルクローク：属性変更
				var target_element = effect.get("target_element", "neutral")
				var old_element = participant.creature_data.get("element", "")
				participant.creature_data["element"] = target_element
				print("  属性変更: ", old_element, " → ", target_element)
			
			"destroy_item":
				# アイテム破壊（リアクトアーマー）
				# ability_parsedにeffectを追加するだけでSkillItemManipulationが認識する
				if not participant.creature_data.has("ability_parsed"):
					participant.creature_data["ability_parsed"] = {}
				if not participant.creature_data["ability_parsed"].has("effects"):
					participant.creature_data["ability_parsed"]["effects"] = []
				
				# 既に登録されていなければ追加
				var already_has_destroy = false
				for existing_effect in participant.creature_data["ability_parsed"]["effects"]:
					if existing_effect.get("effect_type") == "destroy_item":
						already_has_destroy = true
						break
				
				if not already_has_destroy:
					participant.creature_data["ability_parsed"]["effects"].append(effect)
					var target_types = effect.get("target_types", [])
					print("  アイテム破壊を付与: ", target_types)
			
			"transform":
				# 変身効果をability_parsedに追加
				if not participant.creature_data.has("ability_parsed"):
					participant.creature_data["ability_parsed"] = {}
				if not participant.creature_data["ability_parsed"].has("effects"):
					participant.creature_data["ability_parsed"]["effects"] = []
				
				# 既に登録されていなければ追加
				var already_has_transform = false
				for existing_effect in participant.creature_data["ability_parsed"]["effects"]:
					if existing_effect.get("effect_type") == "transform" and existing_effect.get("trigger") == effect.get("trigger"):
						already_has_transform = true
						break
				
				if not already_has_transform:
					participant.creature_data["ability_parsed"]["effects"].append(effect)
					print("  変身効果を付与: ", effect.get("transform_type", ""))
			
			"instant_death":
				# 道連れなどの即死効果は戦闘中に処理されるため、ここでは何もしない
				pass
			
			"scroll_attack":
				# 巻物攻撃設定をability_parsedに追加
				if not participant.creature_data.has("ability_parsed"):
					participant.creature_data["ability_parsed"] = {}
				if not participant.creature_data["ability_parsed"].has("keywords"):
					participant.creature_data["ability_parsed"]["keywords"] = []
				if not participant.creature_data["ability_parsed"].has("keyword_conditions"):
					participant.creature_data["ability_parsed"]["keyword_conditions"] = {}
				
				# 巻物攻撃キーワードを追加
				if not "巻物攻撃" in participant.creature_data["ability_parsed"]["keywords"]:
					participant.creature_data["ability_parsed"]["keywords"].append("巻物攻撃")
				
				# 巻物攻撃の設定を追加
				var scroll_type = effect.get("scroll_type", "base_st")
				var scroll_config = {"scroll_type": scroll_type}
				
				match scroll_type:
					"fixed_st":
						scroll_config["value"] = effect.get("value", 0)
						print("  巻物攻撃を付与: ST固定", scroll_config["value"])
					"base_st":
						print("  巻物攻撃を付与: ST=基本ST")
					"land_count":
						scroll_config["elements"] = effect.get("elements", [])
						scroll_config["multiplier"] = effect.get("multiplier", 1)
						print("  巻物攻撃を付与: ST=土地数×", scroll_config["multiplier"], " (", scroll_config["elements"], ")")
				
				participant.creature_data["ability_parsed"]["keyword_conditions"]["巻物攻撃"] = scroll_config
			
			_:
				print("  未実装の効果タイプ: ", effect_type)

## スキル付与条件をチェック（既存ConditionCheckerを使用）
func check_skill_grant_condition(participant: BattleParticipant, condition: Dictionary, context: Dictionary) -> bool:
	# 既存のConditionCheckerを使用
	var checker = ConditionChecker.new()
	return checker._evaluate_single_condition(condition, context)

## パーティシパントにスキルを付与
func grant_skill_to_participant(participant: BattleParticipant, skill_name: String, _skill_data: Dictionary) -> void:
	match skill_name:
		"先制":
			FirstStrikeSkill.grant_skill(participant, "先制")
		
		"後手":
			FirstStrikeSkill.grant_skill(participant, "後手")
		
		"2回攻撃":
			DoubleAttackSkill.grant_skill(participant)
		
		"巻物強打":
			# 巻物強打スキルを付与
			if not participant.creature_data.has("ability_parsed"):
				participant.creature_data["ability_parsed"] = {}
			
			var ability_parsed = participant.creature_data["ability_parsed"]
			
			# キーワードに追加
			if not ability_parsed.has("keywords"):
				ability_parsed["keywords"] = []
			
			if not "巻物強打" in ability_parsed["keywords"]:
				ability_parsed["keywords"].append("巻物強打")
			
			# effectsにも巻物強打効果を追加
			if not ability_parsed.has("effects"):
				ability_parsed["effects"] = []
			
			# skill_conditionsから発動条件を取得（なければ無条件）
			var skill_conditions = _skill_data.get("skill_conditions", [])
			
			# 巻物強打効果を構築
			var scroll_power_strike_effect = {
				"effect_type": "scroll_power_strike",
				"multiplier": 1.5,
				"conditions": skill_conditions  # スキルの発動条件を設定
			}
			
			ability_parsed["effects"].append(scroll_power_strike_effect)
			print("  巻物強打スキル付与（条件数: ", skill_conditions.size(), "）")
		
		"強打":
			# 強打スキルを付与（SkillPowerStrikeモジュールを使用）
			if not participant.creature_data.has("ability_parsed"):
				participant.creature_data["ability_parsed"] = {}
			
			var ability_parsed = participant.creature_data["ability_parsed"]
			
			# キーワードに追加
			if not ability_parsed.has("keywords"):
				ability_parsed["keywords"] = []
			
			if not "強打" in ability_parsed["keywords"]:
				ability_parsed["keywords"].append("強打")
			
			# effectsにも強打効果を追加
			if not ability_parsed.has("effects"):
				ability_parsed["effects"] = []
			
			# skill_conditionsから発動条件を取得（なければ無条件）
			var skill_conditions = _skill_data.get("skill_conditions", [])
			
			# 強打効果を構築
			var power_strike_effect = {
				"effect_type": "power_strike",
				"multiplier": 1.5,
				"conditions": skill_conditions  # スキルの発動条件を設定
			}
			
			ability_parsed["effects"].append(power_strike_effect)
			print("  強打スキル付与（条件数: ", skill_conditions.size(), "）")
		
		"無効化":
			# 無効化スキルを付与
			if not participant.creature_data.has("ability_parsed"):
				participant.creature_data["ability_parsed"] = {}
			
			var ability_parsed = participant.creature_data["ability_parsed"]
			if not ability_parsed.has("keywords"):
				ability_parsed["keywords"] = []
			
			if not "無効化" in ability_parsed["keywords"]:
				ability_parsed["keywords"].append("無効化")
			
			# keyword_conditionsに無効化条件を追加（配列形式）
			if not ability_parsed.has("keyword_conditions"):
				ability_parsed["keyword_conditions"] = {}
			
			# 無効化条件を配列で管理（複数条件対応）
			if not ability_parsed["keyword_conditions"].has("無効化"):
				ability_parsed["keyword_conditions"]["無効化"] = []
			
			# skill_dataから無効化パラメータを取得
			var skill_params = _skill_data.get("skill_params", {})
			var nullify_type = skill_params.get("nullify_type", "normal_attack")
			var reduction_rate = skill_params.get("reduction_rate", 0.0)
			
			var nullify_data = {
				"nullify_type": nullify_type,
				"reduction_rate": reduction_rate,
				"conditions": []  # アイテムで付与された無効化は無条件で発動
			}
			
			# タイプに応じて追加パラメータを設定
			if nullify_type in ["st_below", "st_above", "mhp_below", "mhp_above"]:
				nullify_data["value"] = skill_params.get("value", 0)
			elif nullify_type == "element":
				nullify_data["elements"] = skill_params.get("elements", [])
			
			# 配列に追加（上書きしない）
			ability_parsed["keyword_conditions"]["無効化"].append(nullify_data)
			
			print("  無効化スキル付与: ", nullify_type)
		
		"貫通":
			# 貫通スキルを付与
			if not participant.creature_data.has("ability_parsed"):
				participant.creature_data["ability_parsed"] = {}
			
			var ability_parsed = participant.creature_data["ability_parsed"]
			if not ability_parsed.has("keywords"):
				ability_parsed["keywords"] = []
			
			if not "貫通" in ability_parsed["keywords"]:
				ability_parsed["keywords"].append("貫通")
			
			print("  貫通スキル付与")
		
		"即死":
			# 即死スキルを付与
			if not participant.creature_data.has("ability_parsed"):
				participant.creature_data["ability_parsed"] = {}
			
			var ability_parsed = participant.creature_data["ability_parsed"]
			if not ability_parsed.has("keywords"):
				ability_parsed["keywords"] = []
			
			if not "即死" in ability_parsed["keywords"]:
				ability_parsed["keywords"].append("即死")
			
			# keyword_conditionsに即死条件を追加
			if not ability_parsed.has("keyword_conditions"):
				ability_parsed["keyword_conditions"] = {}
			
			# skill_dataから即死パラメータを取得
			var skill_params = _skill_data.get("skill_params", {})
			var probability = skill_params.get("probability", 100)
			var target_elements = skill_params.get("target_elements", [])
			var target_type = skill_params.get("target_type", "")
			
			var instant_death_data = {
				"probability": probability
			}
			
			# 条件を追加
			if not target_elements.is_empty():
				instant_death_data["condition_type"] = "enemy_element"
				instant_death_data["elements"] = target_elements
			elif not target_type.is_empty():
				instant_death_data["condition_type"] = "enemy_type"
				instant_death_data["type"] = target_type
			
			ability_parsed["keyword_conditions"]["即死"] = instant_death_data
			
			print("  即死スキル付与: 確率=", probability, "% 条件=", instant_death_data.get("condition_type", "無条件"))
		
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
		
		"defender_st_check":
			# 防御側のSTが一定以上の場合
			var operator_d = penetrate_condition.get("operator", ">=")
			var value_d = penetrate_condition.get("value", 0)
			var defender_st = defender_data.get("ap", 0)  # APがSTに相当
			
			var meets_condition_d = false
			match operator_d:
				">=": meets_condition_d = defender_st >= value_d
				">": meets_condition_d = defender_st > value_d
				"==": meets_condition_d = defender_st == value_d
			
			if meets_condition_d:
				print("【貫通】条件満たす: 敵ST ", defender_st, " ", operator_d, " ", value_d)
				return true
			else:
				print("【貫通】条件不成立: 敵ST ", defender_st, " ", operator_d, " ", value_d)
				return false
		
		_:
			# 未知の条件タイプ
			print("【貫通】未知の条件タイプ:", condition_type)
			return false

## オーガロード（ID: 407）: オーガ配置時能力値上昇
func _apply_ogre_lord_bonus(participant: BattleParticipant, player_index: int) -> void:
	if not board_system_ref:
		return
	
	# 全タイルをチェックして、配置されているオーガの数と属性をカウント
	var fire_wind_ogre_count = 0  # 火風オーガの数
	var water_earth_ogre_count = 0  # 水地オーガの数
	
	# tile_data_managerからタイルノードを取得
	var tile_data_manager = board_system_ref.tile_data_manager
	if not tile_data_manager:
		return
	
	for tile_index in tile_data_manager.tile_nodes:
		var tile = tile_data_manager.tile_nodes[tile_index]
		
		# このタイルにクリーチャーが配置されているか?
		if tile.creature_data.is_empty():
			continue
		
		var creature_data = tile.creature_data
		
		# このクリーチャーの所有者がオーガロードと同じプレイヤーか?
		var creature_owner = tile.owner_id
		if creature_owner != player_index:
			continue
		
		# このクリーチャーがオーガか？
		var race = creature_data.get("race", "")
		if race != "オーガ":
			continue
		
		# オーガロード自身は除外
		if creature_data.get("id", -1) == 407:
			continue
		
		# オーガの属性を取得
		var element = creature_data.get("element", "")
		
		if element == "fire" or element == "wind":
			fire_wind_ogre_count += 1
		elif element == "water" or element == "earth":
			water_earth_ogre_count += 1
	
	# バフを適用
	var bonus_applied = false
	
	if fire_wind_ogre_count > 0:
		participant.temporary_bonus_ap += 20
		bonus_applied = true
		print("[オーガロード] 火風オーガ配置(", fire_wind_ogre_count, "体) ST+20")
	
	if water_earth_ogre_count > 0:
		participant.temporary_bonus_hp += 20
		participant.update_current_hp()
		bonus_applied = true
		print("[オーガロード] 水地オーガ配置(", water_earth_ogre_count, "体) HP+20")
	
	# バフが適用された場合はフラグを設定
	if bonus_applied:
		participant.has_ogre_bonus = true

## ランダムステータス効果を適用（スペクター用）
func _apply_random_stat_effects(participant: BattleParticipant) -> void:
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "random_stat":
			var stat = effect.get("stat", "both")
			var min_value = int(effect.get("min", 10))
			var max_value = int(effect.get("max", 70))
			
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
				var base_hp_value = participant.creature_data.get("hp", 0)
				var base_up_hp = participant.creature_data.get("base_up_hp", 0)
				participant.temporary_bonus_hp = random_hp - (base_hp_value + base_up_hp)
				participant.update_current_hp()
				print("【ランダム能力値】", participant.creature_data.get("name", "?"), 
					  " HP=", participant.current_hp, " (", min_value, "~", max_value, ")")
			
			return

func _apply_dice_condition_bonus(participant: BattleParticipant) -> void:
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "dice_condition_bonus":
			continue  # ここでは何もしない（MovementControllerで処理）

# バトル準備の完了を通知
func battle_preparation_completed():
	pass  # 必要に応じて処理を追加

# バトル終了後の処理
func process_battle_end(_attacker: BattleParticipant, _defender: BattleParticipant) -> void:
	pass  # 必要に応じて処理を追加

extends Node
class_name BattlePreparation

# バトル準備フェーズ処理
# BattleParticipantの作成、アイテム効果、土地ボーナス計算を担当

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")
const TransformProcessor = preload("res://scripts/battle/battle_transform_processor.gd")

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
	var attacker_max_hp = attacker_base_hp + attacker.base_up_hp
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
	var defender_max_hp = defender_base_hp + defender.base_up_hp
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
		apply_item_effects(attacker, attacker_item)
	
	if not defender_item.is_empty():
		# アイテムデータをクリーチャーのitemsに追加（反射チェックで使用）
		if not defender.creature_data.has("items"):
			defender.creature_data["items"] = []
		defender.creature_data["items"].append(defender_item)
		apply_item_effects(defender, defender_item)
	
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
		transform_result = TransformProcessor.process_transform_effects(
			attacker, 
			defender, 
			CardLoader, 
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
func apply_item_effects(participant: BattleParticipant, item_data: Dictionary) -> void:
	var item_type = item_data.get("type", "")
	print("[アイテム効果適用] ", item_data.get("name", "???"), " (type: ", item_type, ")")
	
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
			var blood_purin_base_hp = participant.creature_data.get("hp", 0)
			var blood_purin_base_up_hp = participant.creature_data.get("base_up_hp", 0)
			var current_mhp = blood_purin_base_hp + blood_purin_base_up_hp
			
			# MHP上限100チェック
			var max_increase = 100 - current_mhp
			var actual_increase = min(assist_mhp, max_increase)
			
			if actual_increase > 0:
				# 永続的にMHPを上昇（creature_dataのみ更新、戦闘中は適用しない）
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
		
		if st > 0:
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
			
			"reflect_damage", "nullify_reflect":
				# 反射系のスキルはバトル中にBattleSkillProcessorで処理されるため、ここではスキップ
				pass
			
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
func process_battle_end(attacker: BattleParticipant, defender: BattleParticipant) -> void:
	pass  # 必要に応じて処理を追加

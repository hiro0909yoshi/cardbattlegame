extends Node
class_name BattleSystem

# バトル管理システム - 3D専用版

# TODO: 将来実装予定
# signal battle_started(attacker: Dictionary, defender: Dictionary)
# TODO: 将来実装予定
# signal battle_ended(winner: String, result: Dictionary)
# TODO: 将来実装予定
# signal battle_animation_finished()
signal invasion_completed(success: bool, tile_index: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# バトル結果
enum BattleResult {
	ATTACKER_WIN,           # 侵略成功（土地獲得）
	DEFENDER_WIN,           # 防御成功（侵略側カード破壊）
	ATTACKER_SURVIVED       # 侵略失敗（侵略側カード手札に戻る）
}

# 属性相性テーブル（火→風→土→水→火）
var element_advantages = {
	"火": "風",
	"風": "土", 
	"土": "水",
	"水": "火"
}

# システム参照
var board_system_ref = null  # BoardSystem3D
var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null

func _ready():
	pass

# システム参照を設定
func setup_systems(board_system, card_system: CardSystem, player_system: PlayerSystem):
	board_system_ref = board_system
	card_system_ref = card_system
	player_system_ref = player_system

# バトル実行（3D版メイン処理）
func execute_3d_battle(attacker_index: int, card_index: int, tile_info: Dictionary) -> void:
	if not validate_systems():
		print("Error: システム参照が設定されていません")
		emit_signal("invasion_completed", false, tile_info.get("index", 0))
		return
	
	# カードインデックスが-1の場合は通行料支払い
	if card_index < 0:
		pay_toll_3d(attacker_index, tile_info)
		return
	
	var card_data = card_system_ref.get_card_data_for_player(attacker_index, card_index)
	if card_data.is_empty():
		pay_toll_3d(attacker_index, tile_info)
		return
	
	var cost = card_data.get("cost", 1) * GameConstants.CARD_COST_MULTIPLIER
	var current_player = player_system_ref.get_current_player()
	
	if current_player.magic_power < cost:
		pay_toll_3d(attacker_index, tile_info)
		return
	
	# カード使用
	card_system_ref.use_card_for_player(attacker_index, card_index)
	player_system_ref.add_magic(attacker_index, -cost)
	
	# 防御クリーチャーがいない場合（侵略）
	if tile_info.get("creature", {}).is_empty():
		execute_invasion_3d(attacker_index, card_data, tile_info)
		return
	
	# === 新しいバトルフロー ===
	print("========== バトル開始 ==========")
	
	# 1. 両者の準備
	var participants = _prepare_participants(attacker_index, card_data, tile_info)
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	
	print("侵略側: ", attacker.creature_data.get("name", "?"), " [", attacker.creature_data.get("element", "?"), "]")
	print("  基本HP:", attacker.base_hp, " + 土地ボーナス:", attacker.land_bonus_hp, " = MHP:", attacker.current_hp)
	var attacker_speed = "アイテム先制" if attacker.has_item_first_strike else ("後手" if attacker.has_last_strike else ("先制" if attacker.has_first_strike else "通常"))
	print("  AP:", attacker.current_ap, " 攻撃:", attacker_speed)
	
	print("防御側: ", defender.creature_data.get("name", "?"), " [", defender.creature_data.get("element", "?"), "]")
	print("  基本HP:", defender.base_hp, " + 土地ボーナス:", defender.land_bonus_hp, " = MHP:", defender.current_hp)
	var defender_speed = "アイテム先制" if defender.has_item_first_strike else ("後手" if defender.has_last_strike else ("先制" if defender.has_first_strike else "通常"))
	print("  AP:", defender.current_ap, " 攻撃:", defender_speed)
	
	# 2. バトル前スキル適用
	_apply_pre_battle_skills(participants, tile_info, attacker_index)
	
	# スキル適用後の最終ステータス表示
	print("
【スキル適用後の最終ステータス】")
	print("侵略側: ", attacker.creature_data.get("name", "?"))
	print("  HP:", attacker.current_hp, " (基本:", attacker.base_hp, " 感応:", attacker.resonance_bonus_hp, " 土地:", attacker.land_bonus_hp, ")")
	print("  AP:", attacker.current_ap)
	print("防御側: ", defender.creature_data.get("name", "?"))
	print("  HP:", defender.current_hp, " (基本:", defender.base_hp, " 感応:", defender.resonance_bonus_hp, " 土地:", defender.land_bonus_hp, ")")
	print("  AP:", defender.current_ap)
	
	# 3. 攻撃順決定
	var attack_order = _determine_attack_order(attacker, defender)
	var order_str = "侵略側 → 防御側" if attack_order[0].is_attacker else "防御側 → 侵略側"
	print("
【攻撃順】", order_str)
	
	# 4. 攻撃シーケンス実行
	_execute_attack_sequence(attack_order)
	
	# 5. 結果判定
	var result = _resolve_battle_result(attacker, defender)
	
	# 6. 結果に応じた処理
	_apply_post_battle_effects(result, attacker_index, card_data, tile_info, attacker, defender)
	
	print("================================")

# 侵略処理（防御クリーチャーなし）
func execute_invasion_3d(attacker_index: int, card_data: Dictionary, tile_info: Dictionary):
	print("侵略成功！土地を奪取")
	
	# 土地を奪取
	board_system_ref.set_tile_owner(tile_info["index"], attacker_index)
	board_system_ref.place_creature(tile_info["index"], card_data)
	
	# UI更新
	if board_system_ref.has_method("update_all_tile_displays"):
		board_system_ref.update_all_tile_displays()
	
	emit_signal("invasion_completed", true, tile_info["index"])

# 通行料支払い
func pay_toll_3d(payer_index: int, tile_info: Dictionary):
	var toll = board_system_ref.calculate_toll(tile_info["index"])
	var receiver_id = tile_info["owner"]
	
	if receiver_id >= 0 and receiver_id < player_system_ref.players.size():
		player_system_ref.pay_toll(payer_index, receiver_id, toll)
		print("通行料 ", toll, "G を支払いました")
	
	emit_signal("invasion_completed", false, tile_info["index"])

# システム検証
func validate_systems() -> bool:
	return board_system_ref != null and card_system_ref != null and player_system_ref != null

# === 新しいバトルシステム ===

# 両者のBattleParticipantを準備
func _prepare_participants(attacker_index: int, card_data: Dictionary, tile_info: Dictionary) -> Dictionary:
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
	print("
【防御側クリーチャーデータ】", defender_creature)
	var defender_base_hp = defender_creature.get("hp", 0)
	var defender_land_bonus = _calculate_land_bonus(defender_creature, tile_info)  # 防御側のみボーナス
	
	# 貫通スキルチェック：攻撃側が貫通を持つ場合、防御側の土地ボーナスを無効化
	if _check_penetration_skill(card_data, defender_creature, tile_info):
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
	
	return {
		"attacker": attacker,
		"defender": defender
	}

# 土地ボーナスを計算
func _calculate_land_bonus(creature_data: Dictionary, tile_info: Dictionary) -> int:
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

# 貫通スキルの判定
func _check_penetration_skill(attacker_data: Dictionary, defender_data: Dictionary, tile_info: Dictionary) -> bool:
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
	
	return false

# 攻撃順を決定（先制・後手判定）
func _determine_attack_order(attacker: BattleParticipant, defender: BattleParticipant) -> Array:
	# 優先順位: アイテム先制 > 後手 > 通常先制 > デフォルト
	
	# 1. アイテムで先制付与されている場合（最優先）
	if attacker.has_item_first_strike and not defender.has_item_first_strike:
		print("【攻撃順】侵略側（アイテム先制） → 防御側")
		return [attacker, defender]
	elif defender.has_item_first_strike and not attacker.has_item_first_strike:
		print("【攻撃順】防御側（アイテム先制） → 侵略側")
		return [defender, attacker]
	elif attacker.has_item_first_strike and defender.has_item_first_strike:
		print("【攻撃順】両者アイテム先制 → 侵略側優先")
		return [attacker, defender]
	
	# 2. 後手判定（先制より優先）
	if attacker.has_last_strike and not defender.has_last_strike:
		print("【攻撃順】防御側 → 侵略側（後手）")
		return [defender, attacker]
	elif defender.has_last_strike and not attacker.has_last_strike:
		print("【攻撃順】侵略側 → 防御側（後手）")
		return [attacker, defender]
	elif attacker.has_last_strike and defender.has_last_strike:
		print("【攻撃順】両者後手 → 侵略側優先")
		return [attacker, defender]
	
	# 3. 通常の先制判定
	if attacker.has_first_strike and not defender.has_first_strike:
		print("【攻撃順】侵略側（先制） → 防御側")
		return [attacker, defender]
	elif defender.has_first_strike and not attacker.has_first_strike:
		print("【攻撃順】防御側（先制） → 侵略側")
		return [defender, attacker]
	elif attacker.has_first_strike and defender.has_first_strike:
		print("【攻撃順】両者先制 → 侵略側優先")
		return [attacker, defender]
	
	# 4. デフォルト（侵略側先攻）
	print("【攻撃順】侵略側 → 防御側")
	return [attacker, defender]

# バトル前スキル適用
func _apply_pre_battle_skills(participants: Dictionary, tile_info: Dictionary, attacker_index: int) -> void:
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	
	# プレイヤー土地情報取得
	var player_lands = board_system_ref.get_player_lands_by_element(attacker_index)
	
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
	_apply_skills(attacker, attacker_context)
	
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
	_apply_skills(defender, defender_context)

# スキル適用
func _apply_skills(participant: BattleParticipant, context: Dictionary) -> void:
	var effect_combat = load("res://scripts/skills/effect_combat.gd").new()
	
	# 感応スキルを適用
	_apply_resonance_skill(participant, context)
	
	# 強打スキルを適用（現在のAPを基準に計算）
	var modified_creature_data = participant.creature_data.duplicate()
	modified_creature_data["ap"] = participant.current_ap  # 感応適用後のAPを設定
	var modified = effect_combat.apply_power_strike(modified_creature_data, context)
	participant.current_ap = modified.get("ap", participant.current_ap)
	
	if modified.get("power_strike_applied", false):
		print("【強打発動】", participant.creature_data.get("name", "?"), " AP:", participant.current_ap)
	
	# 2回攻撃スキルを判定
	_check_double_attack(participant)

# 2回攻撃スキル判定
func _check_double_attack(participant: BattleParticipant) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "2回攻撃" in keywords:
		participant.attack_count = 2
		print("【2回攻撃】", participant.creature_data.get("name", "?"), " 攻撃回数: 2回")

# 感応スキルを適用
func _apply_resonance_skill(participant: BattleParticipant, context: Dictionary) -> void:
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

# 攻撃シーケンス実行
func _execute_attack_sequence(attack_order: Array) -> void:
	for i in range(attack_order.size()):
		var attacker_p = attack_order[i]
		var defender_p = attack_order[(i + 1) % 2]
		
		# HPが0以下なら攻撃できない
		if not attacker_p.is_alive():
			continue
		
		# 攻撃回数分ループ
		for attack_num in range(attacker_p.attack_count):
			# 既に倒されていたら攻撃しない
			if not defender_p.is_alive():
				break
			
			# 攻撃実行
			var attacker_name = attacker_p.creature_data.get("name", "?")
			var defender_name = defender_p.creature_data.get("name", "?")
			
			# 攻撃ヘッダー
			if attacker_p.attack_count > 1:
				print("
【第", i + 1, "攻撃 - ", attack_num + 1, "回目】", "侵略側" if attacker_p.is_attacker else "防御側", "の攻撃")
			else:
				print("
【第", i + 1, "攻撃】", "侵略側" if attacker_p.is_attacker else "防御側", "の攻撃")
			
			print("  ", attacker_name, " AP:", attacker_p.current_ap, " → ", defender_name)
			
			# 防御側の貫通スキルは効果なし
			if not attacker_p.is_attacker:
				var defender_keywords = attacker_p.creature_data.get("ability_parsed", {}).get("keywords", [])
				if "貫通" in defender_keywords:
					print("  【貫通】防御側のため効果なし")
			
			# ダメージ適用
			var damage_breakdown = defender_p.take_damage(attacker_p.current_ap)
			
			print("  ダメージ処理:")
			if damage_breakdown["resonance_bonus_consumed"] > 0:
				print("    - 感応ボーナス: ", damage_breakdown["resonance_bonus_consumed"], " 消費")
			if damage_breakdown["land_bonus_consumed"] > 0:
				print("    - 土地ボーナス: ", damage_breakdown["land_bonus_consumed"], " 消費")
			if damage_breakdown["base_hp_consumed"] > 0:
				print("    - 基本HP: ", damage_breakdown["base_hp_consumed"], " 消費")
			print("  → 残HP: ", defender_p.current_hp, " (基本HP:", defender_p.base_hp, ")")
			
			# 即死判定（攻撃が通った後）
			if defender_p.is_alive():
				_check_instant_death(attacker_p, defender_p)
			
			# 倒されたらバトル終了
			if not defender_p.is_alive():
				print("  → ", defender_p.creature_data.get("name", "?"), " 撃破！")
				break

# 即死判定を行う
func _check_instant_death(attacker: BattleParticipant, defender: BattleParticipant) -> bool:
	# 即死スキルを持つかチェック
	var ability_parsed = attacker.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "即死" in keywords:
		# print("【即死判定】", attacker.creature_data.get("name", "?"), " は即死スキルを持たない")
		return false
	
	print("【即死判定開始】", attacker.creature_data.get("name", "?"), " → ", defender.creature_data.get("name", "?"))
	
	# 即死条件を取得
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var instant_death_condition = keyword_conditions.get("即死", {})
	
	if instant_death_condition.is_empty():
		return false
	
	# 条件チェック
	if not _check_instant_death_condition(instant_death_condition, attacker, defender):
		return false
	
	# 確率判定
	var probability = instant_death_condition.get("probability", 0)
	var random_value = randf() * 100.0
	
	if random_value <= probability:
		print("【即死発動】", attacker.creature_data.get("name", "?"), " → ", defender.creature_data.get("name", "?"), " (", probability, "% 判定成功)")
		defender.instant_death_flag = true
		defender.base_hp = 0
		defender.update_current_hp()
		return true
	else:
		print("【即死失敗】確率:", probability, "% 判定値:", int(random_value), "%")
		return false

# 即死条件をチェック
func _check_instant_death_condition(condition: Dictionary, attacker: BattleParticipant, defender: BattleParticipant) -> bool:
	var condition_type = condition.get("condition_type", "")
	
	match condition_type:
		"none":
			# 無条件
			return true
		
		"enemy_is_element":
			# 敵が特定属性
			var required_elements = condition.get("elements", "")
			var defender_element = defender.creature_data.get("element", "")
			
			# 「全」属性は全てに有効
			if required_elements == "全":
				return true
			
			if defender_element == required_elements:
				print("【即死条件】敵が", required_elements, "属性 → 条件満たす")
				return true
			else:
				print("【即死条件】敵が", defender_element, "属性（要求:", required_elements, "）→ 条件不成立")
				return false
		
		"defender_st_check":
			# 防御側のSTが一定以上（基本STで判定）
			var operator = condition.get("operator", ">=")
			var value = condition.get("value", 0)
			var defender_base_st = defender.creature_data.get("ap", 0)  # 基本STで判定
			
			var meets_condition = false
			match operator:
				">=": meets_condition = defender_base_st >= value
				">": meets_condition = defender_base_st > value
				"==": meets_condition = defender_base_st == value
			
			if meets_condition:
				print("【即死条件】防御側ST ", defender_base_st, " ", operator, " ", value, " → 条件満たす")
				return true
			else:
				print("【即死条件】防御側ST ", defender_base_st, " ", operator, " ", value, " → 条件不成立")
				return false
		
		"defender_role":
			# 使用者が防御側の場合のみ発動（キロネックス用）
			if not attacker.is_attacker:
				print("【即死条件】使用者が防御側 → 条件満たす")
				return true
			else:
				print("【即死条件】使用者が侵略側 → 条件不成立")
				return false
		
		"後手":
			# 後手条件（先制の逆）
			# この条件は先制判定で既に処理されているため、ここでは常にtrueを返す
			return true
		
		_:
			print("【即死条件】未知の条件タイプ:", condition_type)
			return false

# バトル結果を判定
func _resolve_battle_result(attacker: BattleParticipant, defender: BattleParticipant) -> BattleResult:
	if not defender.is_alive():
		return BattleResult.ATTACKER_WIN
	elif not attacker.is_alive():
		return BattleResult.DEFENDER_WIN
	else:
		return BattleResult.ATTACKER_SURVIVED

# バトル後の処理
func _apply_post_battle_effects(
	result: BattleResult,
	attacker_index: int,
	card_data: Dictionary,
	tile_info: Dictionary,
	attacker: BattleParticipant,
	defender: BattleParticipant
) -> void:
	var tile_index = tile_info["index"]
	
	# 再生スキル処理
	_apply_regeneration(attacker)
	_apply_regeneration(defender)
	
	match result:
		BattleResult.ATTACKER_WIN:
			print("
【結果】侵略成功！土地を獲得")
			# 土地を奪取
			board_system_ref.set_tile_owner(tile_index, attacker_index)
			# クリーチャー配置（HPは現在値）
			var placement_data = card_data.duplicate()
			placement_data["hp"] = attacker.base_hp  # ダメージを受けた状態で配置
			board_system_ref.place_creature(tile_index, placement_data)
			
			emit_signal("invasion_completed", true, tile_index)
		
		BattleResult.DEFENDER_WIN:
			print("
【結果】防御成功！侵略側カード破壊")
			# カードは既に捨て札に行っているので何もしない
			
			# 防御側クリーチャーのHPを更新（ダメージを受けたまま）
			_update_defender_hp(tile_info, defender)
			
			emit_signal("invasion_completed", false, tile_index)
		
		BattleResult.ATTACKER_SURVIVED:
			print("
【結果】両者生存 → 侵略失敗、カード手札に戻る")
			# カードを手札に戻す
			card_system_ref.return_card_to_hand(attacker_index, card_data)
			
			# 防御側クリーチャーのHPを更新（ダメージを受けたまま）
			_update_defender_hp(tile_info, defender)
			
			emit_signal("invasion_completed", false, tile_index)
	
	# 表示更新
	if board_system_ref.has_method("update_all_tile_displays"):
		board_system_ref.update_all_tile_displays()

# 再生スキル処理
func _apply_regeneration(participant: BattleParticipant) -> void:
	# 生き残っていない場合は発動しない
	if not participant.is_alive():
		return
	
	# 再生キーワードチェック
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "再生" in keywords:
		# 基本HPの最大値を取得（初期値）
		var max_base_hp = participant.creature_data.get("hp", 0)
		
		# 現在の基本HPが最大値未満なら回復
		if participant.base_hp < max_base_hp:
			var healed = max_base_hp - participant.base_hp
			participant.base_hp = max_base_hp
			participant.update_current_hp()
			print("【再生発動】", participant.creature_data.get("name", "?"), " HP回復: +", healed, " → ", participant.current_hp)

# 防御側クリーチャーのHPを更新
func _update_defender_hp(tile_info: Dictionary, defender: BattleParticipant) -> void:
	var tile_index = tile_info["index"]
	var creature_data = tile_info.get("creature", {}).duplicate()
	creature_data["hp"] = defender.base_hp  # ダメージを受けた基本HP
	
	# タイルのクリーチャーデータを更新
	board_system_ref.tile_data_manager.tile_nodes[tile_index].creature_data = creature_data

# _apply_attacker_land_bonus() は削除（新システムでは _calculate_land_bonus() を使用）

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
	print("  AP:", attacker.current_ap, " 先制:", "あり" if attacker.has_first_strike else "なし")
	
	print("防御側: ", defender.creature_data.get("name", "?"), " [", defender.creature_data.get("element", "?"), "]")
	print("  基本HP:", defender.base_hp, " + 土地ボーナス:", defender.land_bonus_hp, " = MHP:", defender.current_hp)
	print("  AP:", defender.current_ap, " 先制:", "あり" if defender.has_first_strike else "なし")
	
	# 2. バトル前スキル適用
	_apply_pre_battle_skills(participants, tile_info, attacker_index)
	
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

# 攻撃順を決定（先制判定）
func _determine_attack_order(attacker: BattleParticipant, defender: BattleParticipant) -> Array:
	if attacker.has_first_strike and defender.has_first_strike:
		return [attacker, defender]  # 両者先制 → 侵略側優先
	elif defender.has_first_strike:
		return [defender, attacker]  # 防御側のみ先制
	else:
		return [attacker, defender]  # デフォルト（侵略側先攻）

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
	var modified = effect_combat.apply_power_strike(participant.creature_data, context)
	
	participant.current_ap = modified.get("ap", participant.current_ap)
	
	if modified.get("power_strike_applied", false):
		print("【強打発動】", participant.creature_data.get("name", "?"), " AP:", participant.current_ap)

# 攻撃シーケンス実行
func _execute_attack_sequence(attack_order: Array) -> void:
	for i in range(attack_order.size()):
		var attacker_p = attack_order[i]
		var defender_p = attack_order[(i + 1) % 2]
		
		# HPが0以下なら攻撃できない
		if not attacker_p.is_alive():
			continue
		
		# 攻撃実行
		print("
【第", i + 1, "攻撃】", "侵略側" if attacker_p.is_attacker else "防御側", "の攻撃")
		print("  ", attacker_p.creature_data.get("name", "?"), " AP:", attacker_p.current_ap, " → ", defender_p.creature_data.get("name", "?"))
		
		# ダメージ適用
		var damage_breakdown = defender_p.take_damage(attacker_p.current_ap)
		
		print("  ダメージ処理:")
		if damage_breakdown["land_bonus_consumed"] > 0:
			print("    - 土地ボーナス: ", damage_breakdown["land_bonus_consumed"], " 消費")
		if damage_breakdown["base_hp_consumed"] > 0:
			print("    - 基本HP: ", damage_breakdown["base_hp_consumed"], " 消費")
		print("  → 残HP: ", defender_p.current_hp, " (基本HP:", defender_p.base_hp, ")")
		
		# 倒されたらバトル終了
		if not defender_p.is_alive():
			print("  → ", defender_p.creature_data.get("name", "?"), " 撃破！")
			break

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

# 防御側クリーチャーのHPを更新
func _update_defender_hp(tile_info: Dictionary, defender: BattleParticipant) -> void:
	var tile_index = tile_info["index"]
	var creature_data = tile_info.get("creature", {}).duplicate()
	creature_data["hp"] = defender.base_hp  # ダメージを受けた基本HP
	
	# タイルのクリーチャーデータを更新
	board_system_ref.tile_data_manager.tile_nodes[tile_index].creature_data = creature_data

# _apply_attacker_land_bonus() は削除（新システムでは _calculate_land_bonus() を使用）

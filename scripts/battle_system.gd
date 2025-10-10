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
	ATTACKER_WIN,
	DEFENDER_WIN,
	DRAW
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
	
	# スキルシステムを使った戦闘処理
	var effect_combat = load("res://scripts/skills/effect_combat.gd").new()
	
	# プレイヤーの土地所有状況を取得
	var player_lands = {"火": 0, "水": 0, "地": 0, "風": 0}
	if board_system_ref and board_system_ref.has_method("get_player_lands_by_element"):
		player_lands = board_system_ref.get_player_lands_by_element(attacker_index)
	else:
		# デバッグ用：全属性を持っていることにする
		print("【デバッグ】土地データ取得不可、テスト用に全属性保有とする")
		player_lands = {"火": 1, "水": 1, "地": 1, "風": 1}
	
	print("  プレイヤー土地: ", player_lands)
	
	# 戦闘コンテキストの構築
	var defender_creature = tile_info.get("creature", {})
	var battle_context = ConditionChecker.build_battle_context(
		card_data, 
		defender_creature,
		tile_info,
		{"player_lands": player_lands}
	)
	
	# 強打などの効果を適用
	var modified_attacker = effect_combat.apply_power_strike(card_data, battle_context)
	
	# 強打が適用されたか確認
	if modified_attacker.get("power_strike_applied", false):
		print("【強打発動！】AP: ", card_data.get("ap", 0), " → ", modified_attacker.get("ap", 0))
	
	# 修正後のステータスを使用
	var attacker_st = modified_attacker.get("ap", 0)
	var defender_hp = defender_creature.get("hp", 0)
	
	print("========== バトル開始 ==========")
	print("攻撃側: ", card_data.get("name", "不明"), " [", card_data.get("element", "?"), "]")
	print("  基本AP: ", card_data.get("ap", 0), " HP: ", card_data.get("hp", 0))
	print("  ability_parsed: ", card_data.get("ability_parsed", {}))
	print("防御側: ", tile_info.get("creature", {}).get("name", "不明"), " [", tile_info.get("creature", {}).get("element", "?"), "]")
	print("攻撃側AP: ", attacker_st, " vs 防御側HP: ", defender_hp)
	
	if attacker_st >= defender_hp:
		print(">>> 攻撃側の勝利！土地を獲得！")
		# 土地を奪取
		board_system_ref.set_tile_owner(tile_info["index"], attacker_index)
		board_system_ref.place_creature(tile_info["index"], card_data)
		
		# 表示更新
		if board_system_ref.has_method("update_all_tile_displays"):
			board_system_ref.update_all_tile_displays()
	else:
		print(">>> 防御側の勝利！土地を守った！")
	
	print("================================")
	
	# バトル終了シグナルを発行
	emit_signal("invasion_completed", attacker_st >= defender_hp, tile_info["index"])

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

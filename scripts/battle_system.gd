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
	var player_lands = {"fire": 0, "water": 0, "wind": 0, "earth": 0}
	if board_system_ref and board_system_ref.has_method("get_player_lands_by_element"):
		player_lands = board_system_ref.get_player_lands_by_element(attacker_index)
		print("【土地情報取得成功】プレイヤー", attacker_index, "の土地:")
		print("  fire:", player_lands.get("fire", 0), "個")
		print("  water:", player_lands.get("water", 0), "個")
		print("  wind:", player_lands.get("wind", 0), "個")
		print("  earth:", player_lands.get("earth", 0), "個")
		print("  other:", player_lands.get("other", 0), "個")
		print("  合計:", player_lands.get("fire", 0) + player_lands.get("water", 0) + player_lands.get("wind", 0) + player_lands.get("earth", 0))
	else:
		# デバッグ用：全属性を持っていることにする
		print("【エラー】土地データ取得不可 - board_system_ref=", board_system_ref != null)
		if board_system_ref:
			print("  has_method=", board_system_ref.has_method("get_player_lands_by_element"))
		player_lands = {"fire": 1, "water": 1, "wind": 1, "earth": 1}
	
	# 戦闘コンテキストの構築
	var defender_creature = tile_info.get("creature", {})
	var battle_context = ConditionChecker.build_battle_context(
		card_data, 
		defender_creature,
		tile_info,
		{
			"player_lands": player_lands,
			"battle_tile_index": tile_info.get("index", -1),
			"player_id": attacker_index,
			"board_system": board_system_ref
		}
	)
	
	# 攻撃側カードに土地ボーナスを適用
	var attacker_card = card_data.duplicate()
	_apply_attacker_land_bonus(attacker_card, tile_info)
	
	# 強打などの効果を適用
	var modified_attacker = effect_combat.apply_power_strike(attacker_card, battle_context)
	
	# 強打が適用されたか確認
	if modified_attacker.get("power_strike_applied", false):
		print("【強打発動！】AP: ", card_data.get("ap", 0), " → ", modified_attacker.get("ap", 0))
	
	# 修正後のステータスを使用
	var attacker_st = modified_attacker.get("ap", 0)
	
	# 防御側HPに土地ボーナスを加算
	var defender_base_hp = defender_creature.get("hp", 0)
	var defender_land_bonus = defender_creature.get("land_bonus_hp", 0)
	var defender_hp = defender_base_hp + defender_land_bonus
	
	if defender_land_bonus > 0:
		print("【防御側土地ボーナス】基本HP:", defender_base_hp, " + ボーナス:", defender_land_bonus, " = 合計:", defender_hp)
	
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

# 攻撃側カードに土地ボーナスを適用
func _apply_attacker_land_bonus(card_data: Dictionary, tile_info: Dictionary):
	var card_element = card_data.get("element", "")
	var tile_element = tile_info.get("element", "")
	var tile_level = tile_info.get("level", 1)
	
	# 属性が一致する場合
	if card_element == tile_element and card_element in ["fire", "water", "wind", "earth"]:
		var bonus_hp = tile_level * 10
		card_data["land_bonus_hp"] = bonus_hp
		
		print("【攻撃側土地ボーナス】", card_data.get("name", "?"), " on ", tile_element)
		print("  レベル", tile_level, " × 10 = +", bonus_hp, "HP")
	else:
		card_data["land_bonus_hp"] = 0

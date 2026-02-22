## 通行料支払いハンドラー
## 敵地での通行料計算・支払い処理を管理
class_name TollPaymentHandler
extends Node

## === UI Signal 定義（Phase 6-C: UI層分離） ===
signal toll_ui_comment_and_wait_requested(message: String, player_id: int)
signal toll_ui_comment_and_wait_completed()

# 依存システム
var player_system: Node = null
var board_system_3d: Node = null
var spell_curse_toll: Node = null

## セットアップ
func setup(p_player_system: Node, p_board_system_3d: Node, p_spell_curse_toll: Node) -> void:
	player_system = p_player_system
	board_system_3d = p_board_system_3d
	spell_curse_toll = p_spell_curse_toll

## 敵地での通行料支払い処理
## 現在のプレイヤーが敵地にいる場合、通行料を計算して支払う
func check_and_pay_toll_on_enemy_land() -> void:
	# 現在のプレイヤーとタイル情報を取得
	var current_player_index = player_system.current_player_index
	if not board_system_3d:
		return

	var current_tile_index = board_system_3d.get_player_tile(current_player_index)
	if current_tile_index < 0:
		return

	var tile_info = board_system_3d.get_tile_info(current_tile_index)

	# 敵地判定：タイルの所有者が現在のプレイヤーではなく、かつ同盟でない場合
	var tile_owner = tile_info.get("owner", -1)
	if tile_owner == -1 or tile_owner == current_player_index or player_system.is_same_team(current_player_index, tile_owner):
		# 自分の土地または同盟の土地または無所有タイル → 支払いなし
		return

	# 敵地にいる場合：通行料を計算・支払い
	var receiver_id = tile_info.get("owner", -1)
	var toll = board_system_3d.calculate_toll(current_tile_index)
	var toll_info = {"main_toll": toll, "bonus_toll": 0, "bonus_receiver_id": -1}

	# 通行料刻印がある場合、刻印システムに全ての計算を委譲
	if spell_curse_toll:
		toll_info = spell_curse_toll.calculate_final_toll(current_tile_index, current_player_index, receiver_id, toll)

	var main_toll = toll_info.get("main_toll", 0)
	var bonus_toll = toll_info.get("bonus_toll", 0)
	var bonus_receiver_id = toll_info.get("bonus_receiver_id", -1)

	# 主通行料の支払い実行
	if receiver_id >= 0 and receiver_id < player_system.players.size():
		player_system.pay_toll(current_player_index, receiver_id, main_toll)
		print("[敵地支払い] 通行料 ", main_toll, "EP を支払いました (受取: プレイヤー", receiver_id + 1, ")")

		# 通行料支払いコメント表示
		if main_toll > 0:
			await _show_toll_comment(current_player_index, main_toll)

	# 副収入の支払い実行
	if bonus_toll > 0 and bonus_receiver_id >= 0 and bonus_receiver_id < player_system.players.size():
		player_system.pay_toll(current_player_index, bonus_receiver_id, bonus_toll)
		print("[副収入] 通行料 ", bonus_toll, "EP を支払いました (受取: プレイヤー", bonus_receiver_id + 1, ")")

## 通行料支払いコメント表示
func _show_toll_comment(payer_id: int, toll_amount: int) -> void:
	var player_name = "プレイヤー"
	if payer_id < player_system.players.size():
		var player = player_system.players[payer_id]
		if player:
			player_name = player.name

	var message = "%s が %dEP 奪われた" % [player_name, toll_amount]
	toll_ui_comment_and_wait_requested.emit(message, payer_id)
	await toll_ui_comment_and_wait_completed

## 破産処理ハンドラー
## EPがマイナスになった際の土地売却処理を管理
class_name BankruptcyHandler
extends Node

# 定数
const START_TILE_INDEX = 0
const RESET_MAGIC = 300

# シグナル
signal bankruptcy_completed(player_id: int, was_reset: bool)  # 破産処理完了
signal land_sold(player_id: int, tile_index: int, value: int)  # 土地売却
# signal land_selection_requested(player_id: int, available_lands: Array)  # 土地選択UI要求（未使用）

## === UI Signal 定義（Phase 6-C: UI層分離） ===
signal bankruptcy_ui_comment_and_wait_requested(message: String, player_id: int)
signal bankruptcy_ui_comment_and_wait_completed()
signal bankruptcy_ui_player_info_updated()
signal bankruptcy_ui_card_info_shown(creature_data: Dictionary, tile_index: int)
signal bankruptcy_ui_info_panels_hidden()
# Phase 8-C: パネル分離 UI Signal
signal bankruptcy_info_panel_show_requested(current_magic: int, land_value: int)
signal bankruptcy_info_panel_hide_requested()

# 参照
var player_system: Node = null
var board_system: Node = null
var creature_manager: Node = null
var spell_curse: Node = null  # プレイヤー呪いクリア用
var target_selection_helper: Node = null  # 土地選択用

# 状態
var _is_processing: bool = false
var current_player_id: int = -1

## セットアップ
func setup(p_player_system: Node, p_board_system: Node, p_creature_manager: Node, p_spell_curse: Node = null, p_target_selection_helper: Node = null):
	player_system = p_player_system
	board_system = p_board_system
	creature_manager = p_creature_manager
	spell_curse = p_spell_curse
	target_selection_helper = p_target_selection_helper


# ===========================================
# 判定メソッド
# ===========================================

## 破産状態か判定（EP < 0）
func check_bankruptcy(player_id: int) -> bool:
	if not player_system:
		return false
	var magic = player_system.get_magic(player_id)
	return magic < 0


## プレイヤーの所有土地一覧を取得（タイルインデックスの配列）
## 同盟プレイヤーの土地も含む
func get_player_lands(player_id: int) -> Array:
	if not board_system:
		return []
	# 自分の土地
	var own_lands = board_system.get_player_owned_tiles(player_id)
	# 同盟の土地を追加
	var allied_lands = _get_allied_lands(player_id)
	return own_lands + allied_lands


## 土地の価値を取得（土地価値 = 売却価格）
func get_land_value(tile_index: int) -> int:
	if not board_system:
		return 0
	return board_system.calculate_land_value(tile_index)


## 同盟の土地を取得（破産時の売却候補用）
func _get_allied_lands(player_id: int) -> Array:
	if not player_system or not board_system:
		return []
	var lands: Array = []
	for tile_index in board_system.tile_nodes:
		var tile = board_system.tile_nodes[tile_index]
		if tile.owner_id >= 0 and tile.owner_id != player_id:
			if player_system.is_same_team(player_id, tile.owner_id):
				lands.append(tile_index)
	return lands


## 全土地の売却額合計を取得
func get_total_land_value(player_id: int) -> int:
	var lands = get_player_lands(player_id)
	var total = 0
	for tile_index in lands:
		total += get_land_value(tile_index)
	return total


## 売却で回復可能か判定
func can_recover_by_selling(player_id: int) -> bool:
	if not player_system:
		return false
	var magic = player_system.get_magic(player_id)
	var total_value = get_total_land_value(player_id)
	return magic + total_value >= 0


# ===========================================
# メッセージ表示
# ===========================================

## コメントを表示してクリック待ち
func _show_message(message: String, player_id: int = -1):
	bankruptcy_ui_comment_and_wait_requested.emit(message, player_id)
	await bankruptcy_ui_comment_and_wait_completed


## プレイヤー名を取得
func _get_player_name(player_id: int) -> String:
	if player_system and player_id >= 0 and player_id < player_system.players.size():
		return player_system.players[player_id].name
	return "プレイヤー%d" % (player_id + 1)


## UIを更新
func _update_ui():
	bankruptcy_ui_player_info_updated.emit()


# ===========================================
# 破産情報パネル
# ===========================================

## 破産情報パネルを表示（Signal駆動化）
func _show_bankruptcy_info_panel(current_magic: int, land_value: int):
	bankruptcy_info_panel_hide_requested.emit()
	bankruptcy_info_panel_show_requested.emit(current_magic, land_value)


## 破産情報パネルを非表示（Signal駆動化）
func _hide_bankruptcy_info_panel():
	bankruptcy_info_panel_hide_requested.emit()


# ===========================================
# 売却処理
# ===========================================

## 土地を売却
## @param tile_index 売却するタイルインデックス
## @param ep_recipient_id EP受取人プレイヤーID（-1の場合は土地所有者）
## @return 売却額
func sell_land(tile_index: int, ep_recipient_id: int = -1) -> int:
	if not board_system:
		return 0

	var tile = board_system.tile_nodes.get(tile_index)
	if not tile:
		return 0

	var owner_id = tile.owner_id
	if owner_id < 0:
		return 0

	# 売却価格を取得（売却前に計算）
	var value = get_land_value(tile_index)

	# クリーチャーを消滅（UI含む）
	if creature_manager and creature_manager.has_creature(tile_index):
		creature_manager.set_data(tile_index, {})
	tile.remove_creature()  # 3Dカード表示も削除

	# 土地の所有権を解除
	tile.owner_id = -1
	tile.level = 1
	tile.update_visual()

	# 連鎖が変わるので全タイルの通行料表示を更新
	if board_system and board_system.has_method("update_all_tile_displays"):
		board_system.update_all_tile_displays()

	# EPを加算（受取人IDを指定可能）
	if player_system:
		var recipient = ep_recipient_id if ep_recipient_id >= 0 else owner_id
		player_system.add_magic(recipient, value)
	
	# UIを更新
	_update_ui()
	
	print("[破産処理] タイル%d売却: %d蓄魔 (プレイヤー%d)" % [tile_index, value, owner_id + 1])
	
	land_sold.emit(owner_id, tile_index, value)
	
	return value


## 全土地を売却してスタート地点にリセット
func force_sell_all_and_reset(player_id: int):
	print("[破産処理] プレイヤー%d: 全土地売却＆リセット開始" % (player_id + 1))
	
	var player_name = _get_player_name(player_id)
	
	# 全土地を売却
	var lands = get_player_lands(player_id)
	for tile_index in lands:
		sell_land(tile_index)
	
	# EPを300にリセット
	if player_system:
		var current_magic = player_system.get_magic(player_id)
		var diff = RESET_MAGIC - current_magic
		player_system.add_magic(player_id, diff)
	
	# プレイヤー呪いをクリア
	if spell_curse:
		spell_curse.remove_curse_from_player(player_id)
	
	# 破産リセットメッセージ表示
	await _show_message("%sは破産した！\nスタート地点に戻されます" % player_name, player_id)
	
	# スタート地点に移動
	_move_player_to_start(player_id)
	
	print("[破産処理] プレイヤー%d: リセット完了 (EP: %d, タイル%d)" % [player_id + 1, RESET_MAGIC, START_TILE_INDEX])


## プレイヤーをスタート地点に移動
func _move_player_to_start(player_id: int):
	if board_system:
		# 3Dノードの位置も含めて移動
		board_system.place_player_at_tile(player_id, START_TILE_INDEX)
	
	if player_system:
		player_system.set_player_position(player_id, START_TILE_INDEX)
	
	print("[破産処理] プレイヤー%d: タイル%dに移動" % [player_id + 1, START_TILE_INDEX])


# ===========================================
# メイン処理
# ===========================================

## 破産処理メイン（プレイヤー/CPU分岐）
## @param player_id プレイヤーID
## @param is_cpu CPUかどうか
## @return 処理が行われたか
func process_bankruptcy(player_id: int, is_cpu: bool) -> bool:
	if not check_bankruptcy(player_id):
		return false
	
	if _is_processing:
		push_warning("[破産処理] 既に処理中です")
		return false
	
	_is_processing = true
	current_player_id = player_id
	
	print("[破産処理] プレイヤー%d: 破産処理開始 (EP: %d)" % [player_id + 1, player_system.get_magic(player_id)])
	
	# UIを更新（マイナスEPを表示）
	_update_ui()
	
	var was_reset = false
	
	# 回復不可能な場合は即座に全売却＆リセット
	if not can_recover_by_selling(player_id):
		force_sell_all_and_reset(player_id)
		was_reset = true
	else:
		# 回復可能な場合
		if is_cpu:
			await process_cpu_bankruptcy(player_id)
		else:
			await process_player_bankruptcy(player_id)
		
		# 処理後も回復できていなければリセット（安全策）
		if check_bankruptcy(player_id):
			force_sell_all_and_reset(player_id)
			was_reset = true
	
	_is_processing = false
	current_player_id = -1
	
	bankruptcy_completed.emit(player_id, was_reset)
	
	return true


## プレイヤー用破産処理（土地選択UIを表示）
func process_player_bankruptcy(player_id: int):
	var player_name = _get_player_name(player_id)
	
	# 破産開始メッセージ
	await _show_message("%sはEP不足！\n土地を売却してください" % player_name, player_id)
	
	while check_bankruptcy(player_id):
		var lands = get_player_lands(player_id)
		if lands.is_empty():
			break
		
		# 土地選択モード開始
		var selected_tile = await _show_land_selection_ui(player_id, lands)
		
		if selected_tile >= 0:
			var value = sell_land(selected_tile)
			await _show_message("土地を売却して%d蓄魔！\n現在のEP: %dEP" % [value, player_system.get_magic(player_id)], player_id)
		
		print("[破産処理] プレイヤー%d: 現在のEP %dEP" % [player_id + 1, player_system.get_magic(player_id)])


## 土地選択UIを表示して選択を待つ
func _show_land_selection_ui(player_id: int, lands: Array) -> int:
	# TargetSelectionHelperを使用
	if target_selection_helper:
		var _magic = player_system.get_magic(player_id)  # 将来の拡張用
		var message = "【破産処理】売却する土地を選択"
		
		# タイル切り替え時にクリーチャー情報と破産情報パネルを表示
		var on_tile_changed = func(tile_index: int):
			_show_creature_info_for_tile(tile_index)
			# 破産情報パネルを更新
			var current_magic = player_system.get_magic(current_player_id)
			var land_value = get_land_value(tile_index)
			_show_bankruptcy_info_panel(current_magic, land_value)
		
		target_selection_helper.tile_selection_changed.connect(on_tile_changed)
		
		var selected = await target_selection_helper.select_tile_from_list(lands, message)
		
		# 接続解除
		if target_selection_helper.tile_selection_changed.is_connected(on_tile_changed):
			target_selection_helper.tile_selection_changed.disconnect(on_tile_changed)
		
		# パネルを閉じる
		_hide_creature_info_panel()
		_hide_bankruptcy_info_panel()
		
		return selected
	
	# フォールバック：最初の土地を選択
	if not lands.is_empty():
		return lands[0]
	
	return -1


## タイルのクリーチャー情報を表示
func _show_creature_info_for_tile(tile_index: int):
	if not board_system or not board_system.tile_nodes:
		return

	var tile = board_system.tile_nodes.get(tile_index)
	if not tile:
		return

	# クリーチャーデータを取得
	var creature_data = {}
	if creature_manager and creature_manager.has_creature(tile_index):
		creature_data = creature_manager.get_data_ref(tile_index).duplicate()

	if creature_data.is_empty():
		# クリーチャーがいない場合は土地情報のみ
		_hide_creature_info_panel()
		return

	# 土地の売却価値を追加表示
	var land_value = get_land_value(tile_index)
	creature_data["_sell_value"] = land_value  # 一時的に追加

	# クリーチャー情報パネルを表示
	bankruptcy_ui_card_info_shown.emit(creature_data, tile_index)


## クリーチャー情報パネルを非表示
func _hide_creature_info_panel():
	bankruptcy_ui_info_panels_hidden.emit()


## CPU用破産処理（自動選択）
## 優先順位: 1. 自分の土地を売却、2. 同盟の土地を売却
func process_cpu_bankruptcy(player_id: int):
	print("[破産処理] CPU%d: 自動売却開始" % (player_id + 1))

	while check_bankruptcy(player_id):
		# まず自分の土地を取得
		var own_lands = board_system.get_player_owned_tiles(player_id)
		var best_tile = -1

		# 1. 自分の土地から選択
		if not own_lands.is_empty():
			best_tile = _select_land_to_sell_cpu(player_id, own_lands)

		# 2. 自分の土地がない場合は同盟の土地から選択
		if best_tile < 0:
			var allied_lands = _get_allied_lands(player_id)
			if not allied_lands.is_empty():
				best_tile = _select_land_to_sell_cpu(player_id, allied_lands)
				# 同盟の土地を売却する場合、EP受取人を破産者に設定
				if best_tile >= 0:
					var value = sell_land(best_tile, player_id)
					# 少し待機（演出用）
					await get_tree().create_timer(0.5).timeout
					print("[破産処理] CPU%d: 同盟の土地(タイル%d)を売却して%d蓄魔" % [player_id + 1, best_tile, value])
					print("[破産処理] CPU%d: 現在のEP %dEP" % [player_id + 1, player_system.get_magic(player_id)])
					continue

		if best_tile < 0:
			break

		sell_land(best_tile)

		# 少し待機（演出用）
		await get_tree().create_timer(0.5).timeout

		print("[破産処理] CPU%d: 現在のEP %dEP" % [player_id + 1, player_system.get_magic(player_id)])


## CPU用：売却する土地を選択
## 優先順位：
## 1. 連鎖がない土地（1連鎖）を優先して売却
## 2. 連鎖がある土地は高額な土地から売却
func _select_land_to_sell_cpu(_player_id: int, lands: Array) -> int:
	if lands.is_empty():
		return -1
	
	# 土地を連鎖有無で分類
	var no_chain_lands = []  # 連鎖なし（その属性で1つだけ）
	var chain_lands = []     # 連鎖あり（同属性複数）
	
	# 属性ごとの土地数をカウント
	var element_counts = {}
	for tile_index in lands:
		var tile = board_system.tile_nodes.get(tile_index)
		if tile:
			var element = tile.tile_type
			if not element_counts.has(element):
				element_counts[element] = []
			element_counts[element].append(tile_index)
	
	# 連鎖有無で分類
	for element in element_counts:
		var tiles = element_counts[element]
		if tiles.size() == 1:
			no_chain_lands.append(tiles[0])
		else:
			chain_lands.append_array(tiles)
	
	# 1. 連鎖がない土地があればそこから選択（高額順）
	if not no_chain_lands.is_empty():
		return _get_highest_value_tile(no_chain_lands)
	
	# 2. 連鎖がある土地は高額から売却
	if not chain_lands.is_empty():
		return _get_highest_value_tile(chain_lands)
	
	# フォールバック
	return lands[0]


## 最も価値の高い土地を取得
func _get_highest_value_tile(lands: Array) -> int:
	var best_tile = -1
	var highest_value = -1
	
	for tile_index in lands:
		var value = get_land_value(tile_index)
		if value > highest_value:
			highest_value = value
			best_tile = tile_index
	
	return best_tile

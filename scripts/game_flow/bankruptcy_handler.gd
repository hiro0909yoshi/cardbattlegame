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

# 参照
var player_system: Node = null
var board_system: Node = null
var creature_manager: Node = null
var spell_curse: Node = null  # プレイヤー呪いクリア用
var ui_manager: Node = null   # コメント表示用
var target_selection_helper: Node = null  # 土地選択用

# 状態
var _is_processing: bool = false
var current_player_id: int = -1

# 破産情報パネル
var bankruptcy_info_panel: Panel = null

## セットアップ
func setup(p_player_system: Node, p_board_system: Node, p_creature_manager: Node, p_spell_curse: Node = null, p_ui_manager: Node = null, p_target_selection_helper: Node = null):
	player_system = p_player_system
	board_system = p_board_system
	creature_manager = p_creature_manager
	spell_curse = p_spell_curse
	ui_manager = p_ui_manager
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
func get_player_lands(player_id: int) -> Array:
	if not board_system:
		return []
	return board_system.get_player_owned_tiles(player_id)


## 土地の価値を取得（土地価値 = 売却価格）
func get_land_value(tile_index: int) -> int:
	if not board_system:
		return 0
	return board_system.calculate_land_value(tile_index)


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
	if ui_manager and ui_manager.global_comment_ui:
		await ui_manager.global_comment_ui.show_and_wait(message, player_id, true)


## プレイヤー名を取得
func _get_player_name(player_id: int) -> String:
	if player_system and player_id >= 0 and player_id < player_system.players.size():
		return player_system.players[player_id].name
	return "プレイヤー%d" % (player_id + 1)


## UIを更新
func _update_ui():
	if ui_manager and ui_manager.has_method("update_player_info_panels"):
		ui_manager.update_player_info_panels()


# ===========================================
# 破産情報パネル
# ===========================================

## 破産情報パネルを表示
func _show_bankruptcy_info_panel(current_magic: int, land_value: int):
	_hide_bankruptcy_info_panel()
	
	if not ui_manager:
		return
	
	bankruptcy_info_panel = Panel.new()
	bankruptcy_info_panel.name = "BankruptcyInfoPanel"
	
	var viewport_size = ui_manager.get_viewport().get_visible_rect().size
	
	# サイズと位置
	var panel_width = 280 * 4
	var panel_height = 120 * 3  # 高さ調整（項目減）
	var margin = 30
	var panel_x = viewport_size.x - panel_width - margin - 200 - 600 + 200 + 100  # 右に300移動
	var panel_y = (viewport_size.y - panel_height) / 2 - 50 - 500  # 上に500移動
	
	bankruptcy_info_panel.position = Vector2(panel_x, panel_y)
	bankruptcy_info_panel.size = Vector2(panel_width, panel_height)
	bankruptcy_info_panel.z_index = 1000
	
	# パネルスタイル
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.1, 0.1, 0.95)  # 赤みがかった背景
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = Color(0.8, 0.2, 0.2, 1.0)  # 赤い枠
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	bankruptcy_info_panel.add_theme_stylebox_override("panel", style)
	
	# 現在のEP
	var current_label = Label.new()
	current_label.text = "現在のEP: %dEP" % current_magic
	current_label.position = Vector2(60, 60)
	current_label.add_theme_font_size_override("font_size", 80)
	if current_magic < 0:
		current_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # マイナスは赤
	else:
		current_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	bankruptcy_info_panel.add_child(current_label)
	
	# 売却後のEP
	var after_magic = current_magic + land_value
	var after_label = Label.new()
	after_label.text = "売却後: %dEP (+%dEP)" % [after_magic, land_value]
	after_label.position = Vector2(60, 180)
	after_label.add_theme_font_size_override("font_size", 80)
	if after_magic >= 0:
		after_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # プラスは緑
	else:
		after_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))  # まだマイナスは黄色
	bankruptcy_info_panel.add_child(after_label)
	
	ui_manager.add_child(bankruptcy_info_panel)


## 破産情報パネルを非表示
func _hide_bankruptcy_info_panel():
	if bankruptcy_info_panel:
		bankruptcy_info_panel.queue_free()
		bankruptcy_info_panel = null


# ===========================================
# 売却処理
# ===========================================

## 土地を売却
## @return 売却額
func sell_land(tile_index: int) -> int:
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
	
	# EPを加算
	if player_system:
		player_system.add_magic(owner_id, value)
	
	# UIを更新
	_update_ui()
	
	print("[破産処理] タイル%d売却: %dEP獲得 (プレイヤー%d)" % [tile_index, value, owner_id + 1])
	
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
	if board_system and board_system.movement_controller:
		# 3Dノードの位置も含めて移動
		board_system.movement_controller.place_player_at_tile(player_id, START_TILE_INDEX)
	
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
			await _show_message("土地を売却して%dEP獲得！\n現在のEP: %dEP" % [value, player_system.get_magic(player_id)], player_id)
		
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
	if not ui_manager or not ui_manager.creature_info_panel_ui:
		return
	
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
	ui_manager.creature_info_panel_ui.show_view_mode(creature_data, tile_index, false)


## クリーチャー情報パネルを非表示
func _hide_creature_info_panel():
	if ui_manager and ui_manager.creature_info_panel_ui:
		ui_manager.creature_info_panel_ui.hide_panel(false)


## CPU用破産処理（自動選択）
func process_cpu_bankruptcy(player_id: int):
	print("[破産処理] CPU%d: 自動売却開始" % (player_id + 1))
	
	while check_bankruptcy(player_id):
		var lands = get_player_lands(player_id)
		if lands.is_empty():
			break
		
		# 最も価値の低い土地を選択（簡易版）
		var best_tile = _select_land_to_sell_cpu(player_id, lands)
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

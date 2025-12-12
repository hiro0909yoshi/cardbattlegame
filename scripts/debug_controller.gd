extends Node
class_name DebugController

# デバッグ機能管理システム
# リリース版では無効化可能

signal debug_action(action: String, value: Variant)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# デバッグモード
var enabled = true  # falseにすればデバッグ機能を完全無効化
var debug_dice_mode = false
var fixed_dice_value = 0

# システム参照
var player_system
var board_system
var card_system
var ui_manager
var game_flow_manager

# カードID入力ダイアログ
var card_input_dialog: ConfirmationDialog = null
var card_id_input: LineEdit = null

func _ready():
	if enabled and OS.is_debug_build():
		print("【デバッグコマンド】")
		print("  SPACEキー: サイコロを振る")
		print("  Vキー: 通行料/HP/ST表示切替")
		print("  Sキー: シグナル接続状態を表示")
		print("  Dキー: CPU手札表示切替")
		print("  数字キー1-6: サイコロ固定")
		print("  0キー: サイコロ固定解除")
		print("  7キー: 敵の土地へ移動")
		print("  8キー: 空き地へ移動")
		print("  9キー: 魔力+1000G")
		print("  Hキー: カードID指定で手札追加")
		print("  Uキー: 現在プレイヤーの全土地のダウン解除")
		print("  Lキー: 現在のタイルをレベル4に")
	
	# カード追加ダイアログを作成
	create_card_input_dialog()

# システム参照を設定
func setup_systems(p_system: PlayerSystem, b_system, c_system: CardSystem, ui_system: UIManager, gf_manager = null):
	player_system = p_system
	board_system = b_system
	card_system = c_system
	ui_manager = ui_system
	game_flow_manager = gf_manager

# カードID入力ダイアログを作成
func create_card_input_dialog():
	card_input_dialog = ConfirmationDialog.new()
	card_input_dialog.title = "デバッグ: カード追加"
	card_input_dialog.dialog_text = "追加するカードIDを入力してください"
	card_input_dialog.size = Vector2(400, 150)
	
	# LineEditを作成 ※1.4倍
	card_id_input = LineEdit.new()
	card_id_input.placeholder_text = "カードID（例: 2001）"
	card_id_input.custom_minimum_size = Vector2(280, 42)
	
	# Enterキーで確定できるように設定
	card_id_input.text_submitted.connect(_on_card_id_text_submitted)
	
	# ダイアログにLineEditを追加
	card_input_dialog.add_child(card_id_input)
	
	# OKボタン押下時の処理
	card_input_dialog.confirmed.connect(_on_card_id_confirmed)
	
	# シーンツリーに追加（親がいない場合は後で追加）
	add_child(card_input_dialog)

# デバッグ入力を処理
func _input(event):
	if not enabled:
		return
	
	# リリースビルドでは無効
	if not OS.is_debug_build():
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_roll_dice()
			KEY_V:
				_toggle_tile_display()
			KEY_S:
				_show_signal_connections()
			KEY_D:
				_toggle_debug_mode()
			KEY_1:
				set_debug_dice(1)
			KEY_2:
				set_debug_dice(2)
			KEY_3:
				set_debug_dice(3)
			KEY_4:
				set_debug_dice(4)
			KEY_5:
				set_debug_dice(5)
			KEY_6:
				set_debug_dice(6)
			KEY_0:
				clear_debug_dice()
			KEY_7:
				move_to_enemy_land()
			KEY_8:
				move_to_empty_land()
			KEY_9:
				add_debug_magic()
			KEY_H:
				show_card_input_dialog()
			KEY_T:
				show_all_tiles_info()
			KEY_U:
				clear_current_player_down_states()
			KEY_L:
				set_current_tile_level_4()

# カードID入力ダイアログを表示
func show_card_input_dialog():
	if not card_input_dialog:
		print("【エラー】ダイアログが初期化されていません")
		return
	
	# 入力欄をクリア
	card_id_input.text = ""
	
	# ダイアログを中央に表示
	card_input_dialog.popup_centered()
	
	# 入力欄にフォーカス
	card_id_input.grab_focus()

# Enterキー押下時の処理（LineEditから呼ばれる）
func _on_card_id_text_submitted(_new_text: String):
	# ダイアログを閉じてから処理
	card_input_dialog.hide()
	# OKボタンと同じ処理を実行
	_on_card_id_confirmed()

# カードID確定時の処理（OKボタンまたはEnterキー）
func _on_card_id_confirmed():
	var input_text = card_id_input.text.strip_edges()
	
	# 入力が空の場合
	if input_text.is_empty():
		print("【デバッグ】カードIDが入力されていません")
		return
	
	# 大文字を小文字に変換（"A" -> "a"）
	input_text = input_text.to_lower()
	
	# 数値に変換（16進数対応: "0x7d1" や "7d1" など）
	var card_id = 0
	if input_text.begins_with("0x"):
		# 16進数形式（例: 0x7d1 = 2001）
		card_id = input_text.hex_to_int()
	elif input_text.is_valid_int():
		# 10進数形式（例: 2001）
		card_id = input_text.to_int()
	else:
		# 数値でない場合、16進数として試す（例: 7d1 = 2001）
		card_id = input_text.hex_to_int()
		if card_id == 0 and input_text != "0":
			print("【デバッグ】無効な入力: ", input_text)
			return
	
	# CardLoaderで存在確認
	if CardLoader:
		var card_data = CardLoader.get_card_by_id(card_id)
		if card_data.is_empty():
			print("【デバッグ】カードID ", card_id, " は存在しません")
			return
	else:
		print("【エラー】CardLoaderが見つかりません")
		return
	
	# 手札に追加
	add_card_to_hand(card_id)

# カードを手札に追加
func add_card_to_hand(card_id: int):
	if not card_system or not player_system:
		print("【エラー】システム参照が設定されていません")
		return
	
	var current_player = player_system.get_current_player()
	if not current_player:
		print("【エラー】現在のプレイヤーが見つかりません")
		return
	
	# カードデータを読み込んで手札に追加
	var card_data = card_system._load_card_data(card_id)
	if card_data.is_empty():
		print("【デバッグ】カードID ", card_id, " が見つかりません")
		return
	
	# 手札配列に直接追加
	if card_system.player_hands.has(current_player.id):
		card_system.player_hands[current_player.id]["data"].append(card_data)
		print("【デバッグ】カードID ", card_id, " (", card_data.get("name", "不明"), ") を手札に追加しました")
		
		# 🔧 重要: 現在のフェーズに応じてカード選択UIを再初期化
		if ui_manager:
			# プレイヤー情報パネルを更新
			if ui_manager.has_method("update_player_info_panels"):
				ui_manager.update_player_info_panels()
			
			# 現在のフィルター状態を確認
			var current_filter = ui_manager.card_selection_filter
			print("【デバッグ】現在のフィルター: ", current_filter)
			
			# スペルフェーズかどうかは、フィルターが"spell"かで判定
			var is_spell_phase = (current_filter == "spell")
			print("【デバッグ】is_spell_phase = ", is_spell_phase)
			
			if is_spell_phase:
				# スペルフェーズの場合: フィルターを"spell"に設定（念のため再設定）
				print("【デバッグ】スペルフェーズ中 - スペルフィルターを適用")
				ui_manager.card_selection_filter = "spell"
				print("【デバッグ】フィルター設定後: ", ui_manager.card_selection_filter)
			else:
				# 通常フェーズの場合: フィルターをクリア
				print("【デバッグ】通常フェーズ - フィルタークリア")
				if ui_manager.has_method("clear_card_selection_filter"):
					ui_manager.clear_card_selection_filter()
			
			# 手札表示を更新
			if ui_manager.hand_display:
				ui_manager.hand_display.update_hand_display(current_player.id)
			
			# カード選択UIを完全に再初期化
			if ui_manager.has_method("hide_card_selection_ui"):
				ui_manager.hide_card_selection_ui()
			
			# 次のフレームで再表示（確実に初期化）
			await get_tree().process_frame
			
			# スペルフェーズならmode="spell"、それ以外はmode="summon"
			if is_spell_phase and ui_manager.has_method("show_card_selection_ui_mode"):
				print("【デバッグ】show_card_selection_ui_mode(spell)呼び出し")
				print("【デバッグ】呼び出し直前のフィルター: ", ui_manager.card_selection_filter)
				ui_manager.show_card_selection_ui_mode(current_player, "spell")
				print("【デバッグ】呼び出し直後のフィルター: ", ui_manager.card_selection_filter)
			elif ui_manager.has_method("show_card_selection_ui"):
				print("【デバッグ】show_card_selection_ui(summon)呼び出し")
				ui_manager.show_card_selection_ui(current_player)
		
		emit_signal("debug_action", "add_card", card_id)
	else:
		print("【エラー】プレイヤー", current_player.id, "の手札が見つかりません")

# サイコロ固定
func set_debug_dice(value: int):
	debug_dice_mode = true
	fixed_dice_value = value
	print("【デバッグ】サイコロ固定: ", value)
	emit_signal("debug_action", "dice_fixed", value)

# サイコロ固定解除
func clear_debug_dice():
	debug_dice_mode = false
	fixed_dice_value = 0
	print("【デバッグ】サイコロ固定解除")
	emit_signal("debug_action", "dice_cleared", null)

# 固定ダイス値を取得
func get_fixed_dice() -> int:
	if debug_dice_mode:
		return fixed_dice_value
	return 0

# 敵の土地に移動
func move_to_enemy_land():
	if not player_system or not board_system:
		return
	
	var current_player = player_system.get_current_player()
	if not current_player:
		return
	
	for i in range(board_system.total_tiles):
		var tile_owner = board_system.tile_owners[i]
		if tile_owner >= 0 and tile_owner != current_player.id:
			print("【デバッグ】敵の土地（マス", i, "）へテレポート")
			player_system.place_player_at_tile(current_player.id, i, board_system)
			player_system.emit_signal("movement_completed", i)
			emit_signal("debug_action", "teleport", i)
			return
	
	print("【デバッグ】敵の土地が見つかりません")

# 空き地に移動
func move_to_empty_land():
	if not player_system or not board_system:
		return
	
	var current_player = player_system.get_current_player()
	if not current_player:
		return
	
	for i in range(board_system.total_tiles):
		if board_system.tile_owners[i] == -1:
			print("【デバッグ】空き地（マス", i, "）へテレポート")
			player_system.place_player_at_tile(current_player.id, i, board_system)
			player_system.emit_signal("movement_completed", i)
			emit_signal("debug_action", "teleport", i)
			return
	
	print("【デバッグ】空き地が見つかりません")

# デバッグ: 魔力追加
func add_debug_magic():
	if not player_system:
		return
	
	var current_player = player_system.get_current_player()
	if current_player:
		player_system.add_magic(current_player.id, 1000)
		print("【デバッグ】魔力+1000G")
		emit_signal("debug_action", "add_magic", 1000)

# CPU手札表示切替
func toggle_cpu_hand_display():
	if not ui_manager:
		return
	
	ui_manager.toggle_debug_mode()
	emit_signal("debug_action", "toggle_cpu_hand", ui_manager.debug_mode)

# 全タイル情報表示
func show_all_tiles_info():
	if not board_system:
		return
	
	# TODO: debug_print_all_tilesメソッドが存在しないためコメントアウト
	# board_system.debug_print_all_tiles()
	print("[DebugController] 全タイル情報表示（未実装）")
	emit_signal("debug_action", "show_tiles", null)

# 特定のタイルへ直接移動
func teleport_to_tile(tile_index: int):
	if not player_system or not board_system:
		return
	
	var current_player = player_system.get_current_player()
	if current_player and tile_index >= 0 and tile_index < board_system.total_tiles:
		print("【デバッグ】マス", tile_index, "へテレポート")
		player_system.place_player_at_tile(current_player.id, tile_index, board_system)
		player_system.emit_signal("movement_completed", tile_index)
		emit_signal("debug_action", "teleport", tile_index)

# 手札を最大まで補充
func fill_hand():
	if not card_system or not player_system:
		return
	
	var current_player = player_system.get_current_player()
	if current_player:
		var current_hand = card_system.get_hand_size_for_player(current_player.id)
		var to_draw = GameConstants.MAX_HAND_SIZE - current_hand
		if to_draw > 0:
			card_system.draw_cards_for_player(current_player.id, to_draw)
			print("【デバッグ】手札を", to_draw, "枚補充")
			emit_signal("debug_action", "fill_hand", to_draw)

# デバッグモードかチェック
func is_debug_mode() -> bool:
	return enabled and OS.is_debug_build()

# ============================================
# Phase 1-A: 領地コマンド用デバッグキー
# ============================================

# 領地コマンドハンドラー参照
var land_command_handler = null

# 領地コマンドハンドラーを設定
func set_land_command_handler(handler):
	land_command_handler = handler
	print("[DebugController] LandCommandHandler参照を設定")

# Uキー: 現在プレイヤーの全土地のダウン状態を解除
func clear_current_player_down_states():
	if not player_system or not board_system:
		print("【デバッグ】システム参照がありません")
		return
	
	var current_player = player_system.get_current_player()
	if not current_player:
		print("【デバッグ】現在のプレイヤーが見つかりません")
		return
	
	var player_id = current_player.id
	var cleared_count = 0
	
	# BoardSystem3Dのtile_nodesから所有地を取得
	if not board_system.tile_nodes:
		print("【デバッグ】タイルノードがありません")
		return
	
	for tile_index in board_system.tile_nodes.keys():
		var tile = board_system.tile_nodes[tile_index]
		if tile.owner_id == player_id:
			if tile.has_method("is_down") and tile.is_down():
				tile.clear_down_state()
				cleared_count += 1
				print("【デバッグ】ダウン解除: タイル", tile_index)
	
	if cleared_count > 0:
		print("【デバッグ】プレイヤー", player_id + 1, "の", cleared_count, "個の土地のダウン状態を解除しました")
		# 秘術ボタンの表示を更新
		if game_flow_manager and game_flow_manager.spell_phase_handler:
			game_flow_manager.spell_phase_handler.update_mystic_button_visibility()
	else:
		print("【デバッグ】ダウン状態の土地はありません")
	
	emit_signal("debug_action", "clear_down_states", player_id)

# 現在のプレイヤーが立っているタイルをレベル4にする（Lキー）
func set_current_tile_level_4():
	if not player_system or not board_system:
		print("【デバッグ】システム参照がありません")
		return
	
	var current_player = player_system.get_current_player()
	if not current_player:
		print("【デバッグ】現在のプレイヤーが見つかりません")
		return
	
	var tile_index = current_player.current_tile
	if not board_system.tile_nodes.has(tile_index):
		print("【デバッグ】タイルが見つかりません:", tile_index)
		return
	
	var tile = board_system.tile_nodes[tile_index]
	
	# タイルのレベルを4に設定
	tile.level = 4
	tile.update_visual()
	
	print("【デバッグ】タイル%d をレベル4に設定しました" % tile_index)
	emit_signal("debug_action", "set_level_4", tile_index)

# ============================================
# game_3d.gdから移動した入力処理
# ============================================

# SPACEキー: サイコロを振る
func _roll_dice():
	if game_flow_manager:
		game_flow_manager.roll_dice()

# Vキー: タイル表示モード切替
func _toggle_tile_display():
	if not board_system:
		return
	
	if board_system.tile_info_display:
		board_system.tile_info_display.switch_mode()
		board_system.update_all_tile_displays()
		var mode_name = board_system.tile_info_display.get_current_mode_name()
		print("表示切替: ", mode_name)
		
		# UIに一時表示
		if ui_manager and ui_manager.phase_label:
			var original_text = ui_manager.phase_label.text
			ui_manager.phase_label.text = "表示: " + mode_name
			await get_tree().create_timer(1.0).timeout
			if ui_manager and ui_manager.phase_label:
				ui_manager.phase_label.text = original_text

# Sキー: シグナル接続状態を表示
func _show_signal_connections():
	SignalRegistry.debug_print_connections()
	var stats = SignalRegistry.get_stats()
	print("総接続数: ", stats.get("total_connections", 0))

# Dキー: デバッグモード切替
func _toggle_debug_mode():
	if ui_manager:
		ui_manager.toggle_debug_mode()

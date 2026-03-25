extends Node
class_name DebugController

# デバッグ機能管理システム
# リリース版では無効化可能

signal debug_action(action: String, value: Variant)

# 定数をpreload

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

# サービス参照
var _message_service = null
var _card_selection_service = null

# === 直接参照（GFM経由を廃止） ===
var spell_phase_handler = null

# カードID入力ダイアログ
var card_input_dialog: ConfirmationDialog = null
var card_id_input: LineEdit = null

func _ready():
	if enabled and OS.is_debug_build():
		print("【デバッグコマンド】 SPACE:ダイス振る | V:表示切替 | 0-8:ダイス固定(0=解除) | 9:EP+1000 | H/J:手札追加 | U:ダウン解除 | L:Lv4 | C:CPU切替")

	# カード追加ダイアログを作成
	create_card_input_dialog()

# システム参照を設定
func setup_systems(p_system: PlayerSystem, b_system, c_system: CardSystem, ui_system: UIManager, gf_manager = null):
	player_system = p_system
	board_system = b_system
	card_system = c_system
	ui_manager = ui_system
	game_flow_manager = gf_manager

	# サービス解決
	if ui_system:
		_message_service = ui_system.message_service if ui_system.get("message_service") else null
		_card_selection_service = ui_system.card_selection_service if ui_system.get("card_selection_service") else null

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
				set_debug_dice(7)
			KEY_8:
				set_debug_dice(8)
			KEY_9:
				add_debug_magic()
			KEY_H:
				show_card_input_dialog()
			KEY_J:
				show_card_input_dialog_for_cpu()
			KEY_T:
				show_all_tiles_info()
			KEY_U:
				clear_current_player_down_states()
			KEY_L:
				set_current_tile_level_4()
			KEY_C:
				toggle_cpu_for_player_2()

# CPU切り替え（P2のcontrol_typeをトグル）
func toggle_cpu_for_player_2():
	if not game_flow_manager:
		return
	var player_id = 1  # P2
	if game_flow_manager.get_control_type(player_id) == "cpu":
		game_flow_manager.convert_to_local(player_id)
		print("【デバッグ】P2 → ローカル操作（次のフェーズから反映）")
	else:
		game_flow_manager.convert_to_cpu(player_id)
		print("【デバッグ】P2 → CPU操作（次のフェーズから反映）")

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
	var card_data = card_system.load_card_data(card_id)
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
			if ui_manager.player_info_service:
				ui_manager.player_info_service.update_panels()

			# 現在のフィルター状態を確認
			var current_filter = _card_selection_service.card_selection_filter if _card_selection_service else ""
			print("【デバッグ】現在のフィルター: ", current_filter)
			
			# スペルフェーズかどうかは、フィルターが"spell"かで判定
			var is_spell_phase = (current_filter == "spell")
			print("【デバッグ】is_spell_phase = ", is_spell_phase)
			
			if is_spell_phase:
				# スペルフェーズの場合: フィルターを"spell"に設定（念のため再設定）
				print("【デバッグ】スペルフェーズ中 - スペルフィルターを適用")
				if _card_selection_service:
					_card_selection_service.card_selection_filter = "spell"
					print("【デバッグ】フィルター設定後: ", _card_selection_service.card_selection_filter)
			else:
				# 通常フェーズの場合: フィルターをクリア
				print("【デバッグ】通常フェーズ - フィルタークリア")
				if _card_selection_service:
					_card_selection_service.clear_card_selection_filter()
			
			# 手札表示を更新
			if _card_selection_service:
				_card_selection_service.update_hand_display(current_player.id)
			
			# カード選択UIを完全に再初期化
			if _card_selection_service:
				_card_selection_service.hide_card_selection_ui()
			
			# 次のフレームで再表示（確実に初期化）
			await get_tree().process_frame
			
			# スペルフェーズならmode="spell"、それ以外はmode="summon"
			if _card_selection_service:
				if is_spell_phase:
					print("【デバッグ】呼び出し直前のフィルター: ", _card_selection_service.card_selection_filter)
					_card_selection_service.show_card_selection_ui_mode(current_player, "spell")
					print("【デバッグ】呼び出し直後のフィルター: ", _card_selection_service.card_selection_filter)
				else:
					_card_selection_service.show_card_selection_ui(current_player)
		
		emit_signal("debug_action", "add_card", card_id)
	else:
		print("【エラー】プレイヤー", current_player.id, "の手札が見つかりません")

# CPU用カードID入力ダイアログを表示
func show_card_input_dialog_for_cpu():
	if not card_input_dialog:
		print("【エラー】ダイアログが初期化されていません")
		return
	
	# CPUプレイヤーを取得
	var cpu_id = _get_first_cpu_player_id()
	if cpu_id < 0:
		print("【デバッグ】CPUプレイヤーが見つかりません")
		return
	
	card_id_input.text = ""
	card_input_dialog.title = "CPU(P%d)に手札追加 - カードID入力" % (cpu_id + 1)
	card_input_dialog.popup_centered()
	card_id_input.grab_focus()
	
	# 一時的にコールバックを差し替え
	if card_input_dialog.confirmed.is_connected(_on_card_id_confirmed):
		card_input_dialog.confirmed.disconnect(_on_card_id_confirmed)
	# 重複接続を防ぐ
	if not card_input_dialog.confirmed.is_connected(_on_cpu_card_id_confirmed):
		card_input_dialog.confirmed.connect(_on_cpu_card_id_confirmed, CONNECT_ONE_SHOT)
	
	if card_id_input.text_submitted.is_connected(_on_card_id_text_submitted):
		card_id_input.text_submitted.disconnect(_on_card_id_text_submitted)
	if not card_id_input.text_submitted.is_connected(_on_cpu_card_id_text_submitted):
		card_id_input.text_submitted.connect(_on_cpu_card_id_text_submitted, CONNECT_ONE_SHOT)

## CPU用 Enterキー押下時の処理
func _on_cpu_card_id_text_submitted(_new_text: String):
	card_input_dialog.hide()
	_on_cpu_card_id_confirmed()

# CPU用カードID確定
func _on_cpu_card_id_confirmed():
	var input_text = card_id_input.text.strip_edges()
	if input_text.is_empty():
		_restore_card_dialog_signals()
		return
	
	input_text = input_text.to_lower()
	var card_id = 0
	if input_text.begins_with("0x"):
		card_id = input_text.hex_to_int()
	elif input_text.is_valid_int():
		card_id = input_text.to_int()
	else:
		card_id = input_text.hex_to_int()
		if card_id == 0 and input_text != "0":
			print("【デバッグ】無効な入力: ", input_text)
			_restore_card_dialog_signals()
			return
	
	if CardLoader:
		var card_data = CardLoader.get_card_by_id(card_id)
		if card_data.is_empty():
			print("【デバッグ】カードID ", card_id, " は存在しません")
			_restore_card_dialog_signals()
			return
	
	add_card_to_cpu_hand(card_id)
	_restore_card_dialog_signals()

# CPUの手札にカードを追加
func add_card_to_cpu_hand(card_id: int):
	if not card_system or not player_system:
		return
	
	var cpu_id = _get_first_cpu_player_id()
	if cpu_id < 0:
		print("【デバッグ】CPUプレイヤーが見つかりません")
		return
	
	var card_data = card_system.load_card_data(card_id)
	if card_data.is_empty():
		print("【デバッグ】カードID ", card_id, " が見つかりません")
		return
	
	if card_system.player_hands.has(cpu_id):
		card_system.player_hands[cpu_id]["data"].append(card_data)
		var cpu_name = player_system.players[cpu_id].name if cpu_id < player_system.players.size() else "CPU"
		print("【デバッグ】カードID %d (%s) を %s(P%d) の手札に追加しました" % [card_id, card_data.get("name", "不明"), cpu_name, cpu_id + 1])
		
		if ui_manager and ui_manager.player_info_service:
			ui_manager.player_info_service.update_panels()

# 最初のCPUプレイヤーIDを取得
func _get_first_cpu_player_id() -> int:
	if not game_flow_manager:
		return -1
	var cpu_flags = game_flow_manager.player_is_cpu
	for i in range(cpu_flags.size()):
		if cpu_flags[i]:
			return i
	return -1

# ダイアログのシグナルを元に戻す
func _restore_card_dialog_signals():
	if not card_input_dialog.confirmed.is_connected(_on_card_id_confirmed):
		card_input_dialog.confirmed.connect(_on_card_id_confirmed)
	if not card_id_input.text_submitted.is_connected(_on_card_id_text_submitted):
		card_id_input.text_submitted.connect(_on_card_id_text_submitted)

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

# デバッグ: EP追加
func add_debug_magic():
	if not player_system:
		return
	
	var current_player = player_system.get_current_player()
	if current_player:
		player_system.add_magic(current_player.id, 1000)
		print("【デバッグ】EP+1000")
		emit_signal("debug_action", "add_magic", 1000)

# 全タイル情報表示
func show_all_tiles_info():
	if not board_system:
		return
	
	# TODO: debug_print_all_tilesメソッドが存在しないためコメントアウト
	# board_system.debug_print_all_tiles()
	print("[DebugController] 全タイル情報表示（未実装）")
	emit_signal("debug_action", "show_tiles", null)

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
# Phase 1-A: ドミニオコマンド用デバッグキー
# ============================================

# ドミニオコマンドハンドラー参照
var dominio_command_handler = null

# ドミニオコマンドハンドラーを設定
func set_dominio_command_handler(handler):
	dominio_command_handler = handler
	print("[DebugController] DominioCommandHandler参照を設定")

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
		# アルカナアーツボタンの表示を更新
		if spell_phase_handler and spell_phase_handler.mystic_arts_handler:
			spell_phase_handler.mystic_arts_handler.update_mystic_button_visibility()
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
	
	board_system.switch_tile_display_mode()
	board_system.update_all_tile_displays()
	var mode_name = board_system.get_tile_display_mode_name()
	print("表示切替: ", mode_name)
	
	# UIに一時表示
	if _message_service:
		var original_text = _message_service.get_phase_text()
		_message_service.set_phase_text("表示: " + mode_name)
		await get_tree().create_timer(1.0).timeout
		if _message_service:
			_message_service.set_phase_text(original_text)

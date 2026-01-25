extends Node
class_name ExplanationMode
## 説明モード
## ゲームを一時停止し、説明を表示、許可された操作で再開する

signal mode_entered
signal mode_exited

# 状態
var _is_active: bool = false
var _config: Dictionary = {}

# 外部参照
var _ui_manager = null
var _board_system_3d = null

# UI部品
var _popup: Control = null
var _overlay: Control = null

# ボタンコールバックのバックアップ
var _saved_confirm_callback: Callable = Callable()
var _saved_back_callback: Callable = Callable()
var _saved_up_callback: Callable = Callable()
var _saved_down_callback: Callable = Callable()
var _buttons_were_setup: bool = false  # ボタン設定をしたかどうか

# 終了待ちの内部シグナル
signal _exit_requested

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

## 初期化
func setup(ui_manager, board_system_3d):
	_ui_manager = ui_manager
	_board_system_3d = board_system_3d
	_create_ui()
	_connect_signals()

## UI部品を作成
func _create_ui():
	# ポップアップ
	var TutorialPopupClass = load("res://scripts/tutorial/tutorial_popup.gd")
	if TutorialPopupClass:
		var popup_layer = CanvasLayer.new()
		popup_layer.name = "PopupLayer"
		popup_layer.layer = 200
		popup_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(popup_layer)
		
		_popup = TutorialPopupClass.new()
		_popup.name = "ExplanationPopup"
		_popup.process_mode = Node.PROCESS_MODE_ALWAYS
		popup_layer.add_child(_popup)
	
	# オーバーレイ
	var TutorialOverlayClass = load("res://scripts/tutorial/tutorial_overlay.gd")
	if TutorialOverlayClass:
		var overlay_layer = CanvasLayer.new()
		overlay_layer.name = "OverlayLayer"
		overlay_layer.layer = 99
		overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(overlay_layer)
		
		_overlay = TutorialOverlayClass.new()
		_overlay.name = "ExplanationOverlay"
		overlay_layer.add_child(_overlay)
		
		# GlobalActionButtonsへの参照を設定
		if _ui_manager and _ui_manager.global_action_buttons:
			_overlay.set_global_action_buttons(_ui_manager.global_action_buttons)

## シグナル接続
func _connect_signals():
	# ポップアップのクリック
	if _popup and _popup.has_signal("clicked"):
		_popup.clicked.connect(_on_popup_clicked)
	
	# カード関連シグナル
	if _ui_manager and _ui_manager.card_selection_ui:
		var csu = _ui_manager.card_selection_ui
		if csu.has_signal("card_info_shown"):
			csu.card_info_shown.connect(_on_card_info_shown)
		if csu.has_signal("card_selected"):
			csu.card_selected.connect(_on_card_selected)
	
	# GlobalActionButtonsはコールバック方式なので、説明モード中に独自コールバックを設定する

## 説明モードに入る
## config: {
##   "message": String,
##   "popup_position": "top" | "left" | "right" (default: "top"),
##   "popup_offset_y": float (default: 0),
##   "exit_trigger": "click" | "button" | "card_tap" | "card_select",
##   "allowed_buttons": Array[String] (exit_trigger=buttonの時),
##   "card_filter": String (exit_trigger=card_*の時、オプション),
##   "highlights": Array[Dictionary]
## }
## highlights: [
##   {"type": "button", "targets": ["confirm", "up", "down"]},
##   {"type": "card", "filter": "green_ogre"},
##   {"type": "tile_toll", "target": "player_creature" | "player_position" | int}
## ]
func enter(config: Dictionary):
	if _is_active:
		# 既にアクティブな場合は先に終了
		exit()
	
	_is_active = true
	_config = config
	
	var exit_trigger = config.get("exit_trigger", "click")
	
	# ゲーム一時停止（クリック待ちの場合のみ）
	# ボタン待ちの場合はゲームを動かしたまま
	if exit_trigger == "click":
		get_tree().paused = true
	
	# ボタン終了の場合、GlobalActionButtonsを設定
	if exit_trigger == "button":
		_setup_button_callbacks(config.get("allowed_buttons", []))
	
	# メッセージ表示
	var message = config.get("message", "")
	if message != "" and _popup:
		var position = config.get("popup_position", "top")
		var offset_y = config.get("popup_offset_y", 0.0)
		
		# クリック終了の場合は「タップで次へ」を表示してクリック待ちを有効化
		if exit_trigger == "click":
			_popup.label.text = "[center]" + message + "\n[color=gray][font_size=50]タップで次へ[/font_size][/color][/center]"
			_popup.visible = true
			_popup.waiting_for_click = true
			_popup._apply_position(position, offset_y)
		else:
			_popup.show_message(message, position, offset_y)
	
	# ハイライト適用
	_apply_highlights(config.get("highlights", []))
	
	mode_entered.emit()

## 説明モードに入り、終了まで待機（await用）
func enter_and_wait(config: Dictionary):
	enter(config)
	await _exit_requested
	return true

## 説明モードを抜ける
func exit():
	if not _is_active:
		return
	
	_is_active = false
	
	# ボタンコールバックを復元
	_restore_button_callbacks()
	
	# ゲーム再開
	get_tree().paused = false
	
	# UI非表示
	if _popup:
		_popup.hide()
	
	# ハイライト解除
	_clear_highlights()
	
	_config = {}
	
	_exit_requested.emit()
	mode_exited.emit()

## ボタンコールバックを設定（説明モード用）
func _setup_button_callbacks(allowed_buttons: Array):
	if not _ui_manager:
		push_warning("[ExplanationMode] _ui_manager is null")
		return
	if not _ui_manager.global_action_buttons:
		push_warning("[ExplanationMode] global_action_buttons is null")
		return
	
	var gab = _ui_manager.global_action_buttons
	
	# 現在のコールバックをバックアップ
	_saved_confirm_callback = gab._confirm_callback
	_saved_back_callback = gab._back_callback
	_saved_up_callback = gab._up_callback
	_saved_down_callback = gab._down_callback
	
	# ボタン設定フラグを立てる
	_buttons_were_setup = true
	
	# GlobalActionButtonsとその子ボタンをポーズ中でも動作するように設定
	gab.process_mode = Node.PROCESS_MODE_ALWAYS
	gab.explanation_mode_active = true
	if gab.up_button:
		gab.up_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if gab.down_button:
		gab.down_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if gab.confirm_button:
		gab.confirm_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if gab.back_button:
		gab.back_button.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 許可されたボタンだけコールバックを設定
	var confirm_cb = Callable()
	var back_cb = Callable()
	var up_cb = Callable()
	var down_cb = Callable()
	
	if "confirm" in allowed_buttons:
		confirm_cb = _on_button_pressed.bind("confirm")
	if "back" in allowed_buttons:
		back_cb = _on_button_pressed.bind("back")
	if "up" in allowed_buttons:
		up_cb = _on_button_pressed.bind("up")
	if "down" in allowed_buttons:
		down_cb = _on_button_pressed.bind("down")
	
	gab.setup(confirm_cb, back_cb, up_cb, down_cb)

## ボタンコールバックを復元
func _restore_button_callbacks():
	# ボタン設定をしていない場合は何もしない
	if not _buttons_were_setup:
		return
	
	if not _ui_manager or not _ui_manager.global_action_buttons:
		return
	
	var gab = _ui_manager.global_action_buttons
	
	# process_modeを元に戻す
	gab.process_mode = Node.PROCESS_MODE_INHERIT
	gab.explanation_mode_active = false
	if gab.up_button:
		gab.up_button.process_mode = Node.PROCESS_MODE_INHERIT
	if gab.down_button:
		gab.down_button.process_mode = Node.PROCESS_MODE_INHERIT
	if gab.confirm_button:
		gab.confirm_button.process_mode = Node.PROCESS_MODE_INHERIT
	if gab.back_button:
		gab.back_button.process_mode = Node.PROCESS_MODE_INHERIT
	
	# コールバックを復元
	gab.setup(_saved_confirm_callback, _saved_back_callback, _saved_up_callback, _saved_down_callback)
	
	# バックアップをクリア
	_saved_confirm_callback = Callable()
	_saved_back_callback = Callable()
	_saved_up_callback = Callable()
	_saved_down_callback = Callable()
	_buttons_were_setup = false

## 現在アクティブか
func is_active() -> bool:
	return _is_active

## ハイライト適用
func _apply_highlights(highlights: Array):
	if not _overlay:
		return
	
	if highlights.is_empty():
		# ハイライトなし = 全ボタン無効化
		_overlay.disable_all_buttons()
		return
	
	for h in highlights:
		var h_type = h.get("type", "")
		match h_type:
			"button":
				var targets = h.get("targets", [])
				_overlay.highlight_buttons(targets, false)
			"card":
				var filter = h.get("filter", "")
				var card_nodes = _get_card_nodes(filter)
				# カードハイライト適用
				_overlay.highlight_hand_cards(card_nodes, false)
			"tile_toll":
				var target = h.get("target", "")
				_highlight_tile_toll(target)
			"player_info":
				var player_id = h.get("player_id", 0)
				_highlight_player_info_panel(player_id)

## ハイライト解除
func _clear_highlights():
	if _overlay:
		_overlay.hide_overlay()

## カードノード取得
func _get_card_nodes(filter: String) -> Array:
	var result = []
	if not _ui_manager:
		return result
	
	# 方法1: card_selection_uiから取得（召喚/バトル等のカード選択UI）
	var card_selection_ui = _ui_manager.card_selection_ui if "card_selection_ui" in _ui_manager else null
	if card_selection_ui:
		var ui_active = card_selection_ui.is_active if "is_active" in card_selection_ui else false
		if ui_active:
			var selection_buttons = card_selection_ui.selection_buttons if "selection_buttons" in card_selection_ui else []
			for btn in selection_buttons:
				if is_instance_valid(btn) and btn.visible:
					if filter == "" or _card_matches_filter(btn, filter):
						result.append(btn)
			if result.size() > 0:
				return result
	
	# 方法2: hand_displayから取得（常時表示の手札）
	var hand_display = _ui_manager.hand_display if "hand_display" in _ui_manager else null
	if hand_display:
		if "player_card_nodes" in hand_display:
			var player_cards = hand_display.player_card_nodes
			if player_cards.has(0):
				for card in player_cards[0]:
					if is_instance_valid(card) and card.visible:
						if filter == "" or _card_matches_filter(card, filter):
							result.append(card)
		elif hand_display.has_method("get_player_card_nodes"):
			var nodes = hand_display.get_player_card_nodes(0)
			for card in nodes:
				if is_instance_valid(card) and card.visible:
					if filter == "" or _card_matches_filter(card, filter):
						result.append(card)
	
	return result

## カードがフィルタにマッチするか
func _card_matches_filter(card_node, filter: String) -> bool:
	if filter == "":
		return true
	
	# カードIDを取得
	var card_id = _get_card_id(card_node)
	if card_id < 0:
		return false
	
	# フィルタ名からIDにマッピング
	# green_ogre = 210, long_sword = 1073
	match filter:
		"green_ogre":
			return card_id == 210
		"long_sword":
			return card_id == 1073
		_:
			# 数値文字列の場合は直接比較
			if filter.is_valid_int():
				return card_id == int(filter)
	
	return false

## カードノードからカードIDを取得
func _get_card_id(card_node) -> int:
	# card_idプロパティから取得
	if "card_id" in card_node:
		return card_node.card_id
	
	# card_dataから取得
	if "card_data" in card_node:
		return card_node.card_data.get("id", -1)
	
	# get_card_dataメソッドから取得
	if card_node.has_method("get_card_data"):
		var data = card_node.get_card_data()
		return data.get("id", -1)
	
	return -1

## 通行料ラベルハイライト
func _highlight_tile_toll(target):
	if not _overlay or not _board_system_3d:
		return
	
	var tile_index: int = -1
	
	if target is String:
		match target:
			"player_creature":
				tile_index = _find_player_creature_tile(0)
			"player_creature_latest":
				tile_index = _find_player_creature_tile_latest(0)
			"player_all_creatures":
				# プレイヤーの全クリーチャータイルをハイライト
				_highlight_all_player_creature_tiles(0)
				return
			"player_position":
				if _board_system_3d.game_flow_manager and _board_system_3d.game_flow_manager.player_system:
					tile_index = _board_system_3d.game_flow_manager.player_system.get_player_position(0)
	elif target is int:
		tile_index = target
	
	if tile_index < 0:
		return
	
	var tile_info_display = _board_system_3d.tile_info_display
	if not tile_info_display:
		print("[ExplanationMode] _highlight_tile_toll: tile_info_display is null")
		return
	
	var label = tile_info_display.tile_labels.get(tile_index)
	if not label or not label.visible:
		return
	
	var camera = _board_system_3d.camera
	if not camera:
		return
	
	_overlay.highlight_3d_object(label, camera, Vector2(200, 80))

## プレイヤーインフォパネルをハイライト
func _highlight_player_info_panel(player_id: int):
	if not _overlay or not _ui_manager:
		return
	
	var player_info_panel = _ui_manager.player_info_panel
	if not player_info_panel:
		push_warning("[ExplanationMode] player_info_panel is null")
		return
	
	# パネル配列から指定プレイヤーのパネルを取得
	if player_id < 0 or player_id >= player_info_panel.panels.size():
		push_warning("[ExplanationMode] Invalid player_id: %d" % player_id)
		return
	
	var panel = player_info_panel.panels[player_id]
	if not panel:
		return
	
	# パネルの位置とサイズを取得してオーバーレイに穴を開ける
	var panel_rect = panel.get_global_rect()
	_overlay.add_rect_hole(panel_rect.position, panel_rect.size)
	_overlay.visible = true

## プレイヤーのクリーチャーがいるタイルを探す（最初に見つかったもの）
func _find_player_creature_tile(player_id: int) -> int:
	if not _board_system_3d:
		return -1
	
	for tile_index in _board_system_3d.tile_nodes.keys():
		var tile = _board_system_3d.tile_nodes[tile_index]
		if tile and tile.owner_id == player_id and not tile.creature_data.is_empty():
			return tile_index
	
	return -1

## プレイヤーの最新のクリーチャータイルを探す（タイルインデックスが大きいもの）
func _find_player_creature_tile_latest(player_id: int) -> int:
	if not _board_system_3d:
		return -1
	
	var latest_tile = -1
	for tile_index in _board_system_3d.tile_nodes.keys():
		var tile = _board_system_3d.tile_nodes[tile_index]
		if tile and tile.owner_id == player_id and not tile.creature_data.is_empty():
			if tile_index > latest_tile:
				latest_tile = tile_index
	
	return latest_tile

## プレイヤーの全クリーチャータイルをハイライト
func _highlight_all_player_creature_tiles(player_id: int):
	if not _board_system_3d or not _overlay:
		return
	
	var tile_info_display = _board_system_3d.tile_info_display
	if not tile_info_display:
		return
	
	var camera = _board_system_3d.camera
	if not camera:
		return
	
	# 最初にクリアしてから全て追加
	_overlay.clear_holes()
	_overlay.allowed_buttons = []
	
	for tile_index in _board_system_3d.tile_nodes.keys():
		var tile = _board_system_3d.tile_nodes[tile_index]
		if tile and tile.owner_id == player_id and not tile.creature_data.is_empty():
			var label = tile_info_display.tile_labels.get(tile_index)
			if label and label.visible:
				# 3D位置をスクリーン座標に変換して穴を追加
				var screen_pos = camera.unproject_position(label.global_position)
				var size = Vector2(200, 80)
				var rect_pos = screen_pos - size / 2
				_overlay.add_rect_hole(rect_pos, size)
	
	_overlay.visible = true
	
	return -1

# === シグナルハンドラ ===

func _on_popup_clicked(_wait_id: int):
	if not _is_active:
		return
	
	var exit_trigger = _config.get("exit_trigger", "click")
	if exit_trigger == "click":
		exit()

func _on_button_pressed(button_name: String):
	# ボタン押下処理
	if not _is_active:
		return
	
	var exit_trigger = _config.get("exit_trigger", "")
	if exit_trigger != "button":
		return
	
	var allowed = _config.get("allowed_buttons", [])
	if button_name in allowed:
		# 許可されたボタン、説明モードを抜ける
		
		# 元のコールバックを保持
		var original_callback: Callable
		match button_name:
			"confirm":
				original_callback = _saved_confirm_callback
			"up":
				original_callback = _saved_up_callback
			"down":
				original_callback = _saved_down_callback
			"back":
				original_callback = _saved_back_callback
		
		# 説明モードを抜ける（コールバック復元される）
		exit()
		
		# 元のゲームのコールバックを呼び出す（遅延実行で次フレームに）
		if original_callback.is_valid():
			# 元のコールバックを遅延実行
			_call_original_callback.call_deferred(original_callback, button_name)

## 元のコールバックを呼び出す（遅延実行用）
func _call_original_callback(callback: Callable, _button_name: String):
	# 元のコールバック実行
	callback.call()

func _on_card_info_shown(_card_index: int):
	if not _is_active:
		return
	
	var exit_trigger = _config.get("exit_trigger", "")
	if exit_trigger == "card_tap":
		exit()

func _on_card_selected(_card_index: int):
	if not _is_active:
		return
	
	var exit_trigger = _config.get("exit_trigger", "")
	if exit_trigger == "card_select":
		exit()

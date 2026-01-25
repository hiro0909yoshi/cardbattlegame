extends CanvasLayer
class_name TutorialUI
## チュートリアルのUI管理（ポップアップ、クリック待ち）

signal click_received

# 外部参照
var ui_manager = null

# ポップアップ（既存のTutorialPopupを活用）
var _popup: Control = null

# 状態
var _waiting_for_click: bool = false

func _ready():
	layer = 200  # 最前面

func setup(uim):
	ui_manager = uim
	_create_popup()

## ポップアップを作成
func _create_popup():
	var TutorialPopupClass = load("res://scripts/tutorial/tutorial_popup.gd")
	_popup = TutorialPopupClass.new()
	_popup.name = "TutorialPopup"
	add_child(_popup)
	
	# クリックシグナルを接続
	if _popup.has_signal("clicked"):
		_popup.clicked.connect(_on_popup_clicked)

## メッセージを表示
func show_message(message: String, ui_config: Dictionary = {}):
	if not _popup or message == "":
		return
	
	var position = ui_config.get("position", "top")
	var offset_y = ui_config.get("offset_y", 0.0)
	
	_popup.show_message(message, position, offset_y)

## メッセージを表示してクリック待ち
func show_and_wait(message: String, ui_config: Dictionary = {}):
	if not _popup or message == "":
		return
	
	var position = ui_config.get("position", "top")
	var offset_y = ui_config.get("offset_y", 0.0)
	
	# ポップアップの show_and_wait は await で使える
	await _popup.show_and_wait(message, position, offset_y)

## クリック待ちを有効化
func enable_click_wait():
	_waiting_for_click = true
	if _popup:
		_popup.waiting_for_click = true

## クリック待ちを無効化
func disable_click_wait():
	_waiting_for_click = false
	if _popup:
		_popup.waiting_for_click = false

## ポップアップのクリック時
func _on_popup_clicked(_wait_id: int):
	if _waiting_for_click:
		_waiting_for_click = false
		click_received.emit()

## 非表示
func hide_ui():
	if _popup:
		_popup.hide()
	_waiting_for_click = false

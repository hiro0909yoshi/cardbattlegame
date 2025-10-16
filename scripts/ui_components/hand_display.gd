# HandDisplay - 手札表示UI管理
# UIManagerから分離された手札表示関連のUI処理
class_name HandDisplay
extends Node

# シグナル
signal card_drawn(card_data: Dictionary)
signal card_used(card_data: Dictionary)
signal hand_updated()

# UI要素
var hand_container: Control = null
var card_scene = preload("res://scenes/Card.tscn")
var player_card_nodes = {}  # player_id -> [card_nodes]

# カード表示定数
const CARD_WIDTH = 290
const CARD_HEIGHT = 390
const CARD_SPACING = 30

# システム参照
var card_system_ref = null
var player_system_ref = null

func _ready():
	pass

## 初期化
func initialize(ui_parent: Node, card_sys, player_sys):
	card_system_ref = card_sys
	player_system_ref = player_sys
	
	# 手札コンテナを作成
	hand_container = Control.new()
	hand_container.name = "Hand"
	hand_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # マウス入力を透過させる
	ui_parent.add_child(hand_container)
	
	# プレイヤーごとのカードノード配列を初期化
	for i in range(4):
		player_card_nodes[i] = []

## CardSystemのシグナルに接続
func connect_card_system_signals():
	if not card_system_ref:
		return
	
	if card_system_ref.has_signal("card_drawn"):
		card_system_ref.card_drawn.connect(_on_card_drawn)
	if card_system_ref.has_signal("card_used"):
		card_system_ref.card_used.connect(_on_card_used)
	if card_system_ref.has_signal("hand_updated"):
		card_system_ref.hand_updated.connect(_on_hand_updated)

## 手札表示を更新
func update_hand_display(player_id: int):
	if not card_system_ref or not hand_container:
		return
	
	# 全プレイヤーの既存カードノードを削除（ターン切り替え時に前のプレイヤーの手札を消す）
	for pid in player_card_nodes.keys():
		for card_node in player_card_nodes[pid]:
			if is_instance_valid(card_node):
				card_node.queue_free()
		player_card_nodes[pid].clear()
	
	# カードデータを取得
	var hand_data = card_system_ref.get_all_cards_for_player(player_id)
	
	# カードノードを生成
	for i in range(hand_data.size()):
		var card_data = hand_data[i]
		var card_node = create_card_node(card_data, i)
		if card_node:
			player_card_nodes[player_id].append(card_node)
	
	# 全カードを中央配置
	rearrange_hand(player_id)

## カードノードを生成
func create_card_node(card_data: Dictionary, _index: int) -> Node:
	if not is_instance_valid(hand_container):
		print("[HandDisplay] ERROR: 手札コンテナが無効です")
		return null
	
	if not card_scene:
		print("[HandDisplay] ERROR: card_sceneがロードされていません")
		return null
		
	var card = card_scene.instantiate()
	if not card:
		print("[HandDisplay] ERROR: カードのインスタンス化に失敗")
		return null
	
	card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	
	# カードフィルター適用
	var ui_manager = get_parent() if get_parent() else null
	var filter_mode = ""
	if ui_manager and "card_selection_filter" in ui_manager:
		filter_mode = ui_manager.card_selection_filter
	
	var card_type = card_data.get("type", "")
	var is_spell_card = card_type == "spell"
	var is_item_card = card_type == "item"
	
	# フィルターモードに応じてグレーアウト
	if filter_mode == "spell":
		# スペルフェーズ中: スペルカード以外をグレーアウト
		if not is_spell_card:
			card.modulate = Color(0.5, 0.5, 0.5, 1.0)
	elif filter_mode == "item":
		# アイテムフェーズ中: アイテムカード以外をグレーアウト
		if not is_item_card:
			card.modulate = Color(0.5, 0.5, 0.5, 1.0)
	elif filter_mode == "":
		# 通常フェーズ（召喚等）: スペルカードとアイテムカードをグレーアウト
		if is_spell_card or is_item_card:
			card.modulate = Color(0.5, 0.5, 0.5, 1.0)
		
	hand_container.add_child(card)
	
	# 位置は後でrearrange_hand()で設定するので仮配置
	var viewport_size = get_viewport().get_visible_rect().size
	var card_y = viewport_size.y - CARD_HEIGHT - 20
	card.position = Vector2(0, card_y)
	
	if card.has_method("load_card_data"):
		card.load_card_data(card_data.id)
	else:
		print("[HandDisplay] WARNING: カードにload_card_dataメソッドがありません")
	
	# 手札表示用カードは初期状態で選択不可（CardSelectionUIが必要に応じて有効化する）
	card.is_selectable = false
	
	return card

## 手札を再配置（動的スケール対応）
func rearrange_hand(player_id: int):
	var card_nodes = player_card_nodes[player_id]
	if card_nodes.is_empty():
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var hand_size = card_nodes.size()
	
	# CardUIHelperを使用してレイアウト計算
	var layout = CardUIHelper.calculate_card_layout(viewport_size, hand_size)
	
	# 各カードを配置
	for i in range(card_nodes.size()):
		var card = card_nodes[i]
		if is_instance_valid(card):
			card.position = Vector2(layout.start_x + i * (layout.card_width + layout.spacing), layout.card_y)
			card.size = Vector2(layout.card_width, layout.card_height)
			card.custom_minimum_size = card.size

## シグナルハンドラ
func _on_card_drawn(_card_data: Dictionary):
	card_drawn.emit(_card_data)

func _on_card_used(_card_data: Dictionary):
	card_used.emit(_card_data)

func _on_hand_updated():
	# 現在のターンプレイヤーの手札を表示
	if player_system_ref:
		var current_player = player_system_ref.get_current_player()
		if current_player:
			update_hand_display(current_player.id)
	hand_updated.emit()

## 指定プレイヤーのカードノード取得
func get_player_card_nodes(player_id: int) -> Array:
	return player_card_nodes.get(player_id, [])

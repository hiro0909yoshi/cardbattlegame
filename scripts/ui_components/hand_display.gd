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

# カード表示定数（CardFrame.tscnの実際のサイズ）
const CARD_WIDTH = 220
const CARD_HEIGHT = 293
const CARD_SPACING = 30

# システム参照
var card_system_ref = null
var player_system_ref = null
var _card_selection_service = null  # CardSelectionService参照（フィルター取得用、Phase 8-M）
var _card_selection_ui_ref = null  # CardSelectionUI参照（カード参照注入用）
var _game_flow_manager_ref = null  # GameFlowManager参照（カード参照注入用）
var _on_card_button_pressed_cb: Callable  # カード確定時コールバック
var _on_card_info_requested_cb: Callable  # カード情報表示リクエストコールバック

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

## カードコールバックを設定（UIManagerから呼ばれる）
func set_card_callbacks(on_confirmed: Callable, on_info: Callable) -> void:
	_on_card_button_pressed_cb = on_confirmed
	_on_card_info_requested_cb = on_info

## CardSystemのシグナルに接続
func connect_card_system_signals():
	if not card_system_ref:
		return

	if card_system_ref.has_signal("card_drawn"):
		if not card_system_ref.card_drawn.is_connected(_on_card_drawn):
			card_system_ref.card_drawn.connect(_on_card_drawn)
	if card_system_ref.has_signal("card_used"):
		if not card_system_ref.card_used.is_connected(_on_card_used):
			card_system_ref.card_used.connect(_on_card_used)
	if card_system_ref.has_signal("hand_updated"):
		if not card_system_ref.hand_updated.is_connected(_on_hand_updated):
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
		var card_node = create_card_node(card_data, i, player_id)
		if card_node:
			player_card_nodes[player_id].append(card_node)
	
	# 全カードを中央配置
	rearrange_hand(player_id)
	
	# 手札更新シグナルを発火（ボタン位置更新用）
	hand_updated.emit()


## カードインデックスからカードノードを取得
func get_card_node(card_index: int, player_id: int = 0) -> Node:
	if player_id not in player_card_nodes:
		return null
	
	var card_nodes = player_card_nodes[player_id]
	for card_node in card_nodes:
		if is_instance_valid(card_node) and card_node.card_index == card_index:
			return card_node
	return null


## カードノードを生成
func create_card_node(card_data: Dictionary, _index: int, player_id: int) -> Node:
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
	
	# カードフィルター適用（Phase 8-M: CardSelectionServiceから取得）
	var filter_mode = ""
	if _card_selection_service:
		filter_mode = _card_selection_service.card_selection_filter
	
	var card_type = card_data.get("type", "")
	var is_spell_card = card_type == "spell"
	var is_item_card = card_type == "item"
	var is_creature_card = card_type == "creature"
	

	# フィルターモードに応じてグレーアウトと選択不可設定
	var is_selectable_card = true  # デフォルトは選択可能
	
	if filter_mode == "spell":
		# スペルフェーズ中: スペルカード以外をグレーアウト＆選択不可
		if not is_spell_card:
			card.modulate = Color(0.5, 0.5, 0.5, 1.0)
			is_selectable_card = false
	elif filter_mode == "spell_disabled":
		# 禁呪刻印中: スペルカードをグレーアウト＆選択不可（アルカナアーツは使用可能）
		if is_spell_card:
			card.modulate = Color(0.5, 0.5, 0.5, 1.0)
			is_selectable_card = false
	elif filter_mode == "item":
		# アイテムフェーズ中: アイテムカード、レリック以外をグレーアウト＆選択不可
		var should_gray = true
		if is_item_card:
			should_gray = false
		elif is_creature_card:
			# レリック判定
			var keywords = card_data.get("ability_parsed", {}).get("keywords", [])
			if "レリック" in keywords:
				should_gray = false
		if should_gray:
			card.modulate = Color(0.5, 0.5, 0.5, 1.0)
			is_selectable_card = false
	elif filter_mode == "item_or_assist":
		# アイテムフェーズ（加勢あり）: アイテムカード、レリック、加勢対象クリーチャー以外をグレーアウト＆選択不可
		var should_gray_out = true
		
		# アイテムカードは常に選択可能
		if is_item_card:
			should_gray_out = false
		# クリーチャーカードの場合
		elif is_creature_card:
			# レリック判定
			var keywords = card_data.get("ability_parsed", {}).get("keywords", [])
			if "レリック" in keywords:
				should_gray_out = false
			else:
				# 加勢対象判定
				var assist_elements = []
				if _card_selection_service:
					assist_elements = _card_selection_service.assist_target_elements
				
				var card_element = card_data.get("element", "")
				# 全属性対象、または属性が一致する場合
				if "all" in assist_elements or card_element in assist_elements:
					should_gray_out = false
		
		if should_gray_out:
			card.modulate = Color(0.5, 0.5, 0.5, 1.0)
			is_selectable_card = false
	elif filter_mode == "battle":
		# バトルフェーズ中: 堅守クリーチャーをグレーアウト＆選択不可
		var creature_type = card_data.get("creature_type", "normal")
		if creature_type == "defensive":
			card.modulate = Color(0.5, 0.5, 0.5, 1.0)
			is_selectable_card = false
	elif filter_mode == "destroy_item_spell":
		# シャッター用: アイテム/スペルのみ選択可、クリーチャーはグレーアウト
		if is_creature_card:
			card.modulate = Color(0.5, 0.5, 0.5, 1.0)
			is_selectable_card = false
	elif filter_mode == "item_or_spell":
		# メタモルフォシス用: アイテム/スペルのみ選択可、クリーチャーはグレーアウト
		if is_creature_card:
			card.modulate = Color(0.5, 0.5, 0.5, 1.0)
			is_selectable_card = false
	elif filter_mode == "destroy_any":
		# スクイーズ用: 全カード選択可
		is_selectable_card = true
	elif filter_mode == "destroy_spell":
		# セフト用: スペルのみ選択可
		if not is_spell_card:
			card.modulate = Color(0.5, 0.5, 0.5, 1.0)
			is_selectable_card = false
	elif filter_mode == "":
		# 通常フェーズ（召喚等）: スペルカードとアイテムカードをグレーアウト＆選択不可
		if is_spell_card or is_item_card:
			card.modulate = Color(0.5, 0.5, 0.5, 1.0)
			is_selectable_card = false
		
	hand_container.add_child(card)
	
	# 位置は後でrearrange_hand()で設定するので仮配置
	var viewport_size = get_viewport().get_visible_rect().size
	var card_y = viewport_size.y - CARD_HEIGHT - 20
	card.position = Vector2(0, card_y)
	
	# まず従来の方法でカードを表示
	if card.has_method("load_card_data"):
		card.load_card_data(card_data.get("id", 0))
	
	# 密命カード対応: card_dataを上書きして密命情報を含める
	card.card_data = card_data
	card.owner_player_id = player_id
	# 重要: 常にプレイヤー0（人間）が見ている
	card.viewing_player_id = 0
	
	# 密命カードの表示判定
	if card.has_method("update_secret_display"):
		card.update_secret_display()
	
	# フィルターモードに応じて選択可能/不可を設定
	card.is_selectable = is_selectable_card

	# Phase 10-B: 参照注入 + Signal接続（card.gd UIManager不要化）
	card.set_references(_card_selection_service, _card_selection_ui_ref, _game_flow_manager_ref)
	if _on_card_button_pressed_cb.is_valid():
		if not card.card_button_pressed.is_connected(_on_card_button_pressed_cb):
			card.card_button_pressed.connect(_on_card_button_pressed_cb)
	if _on_card_info_requested_cb.is_valid():
		if not card.card_info_requested.is_connected(_on_card_info_requested_cb):
			card.card_info_requested.connect(_on_card_info_requested_cb)

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
			# カードを通常サイズ(290x390)で配置し、スケールで縮小
			var x_pos = layout.start_x + i * (layout.card_width + layout.spacing)
			
			card.position = Vector2(x_pos, layout.card_y)
			card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)  # 通常サイズ
			card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
			card.scale = Vector2(layout.scale, layout.scale)  # スケールで縮小
			


## シグナルハンドラ
func _on_card_drawn(_card_data: Dictionary):
	card_drawn.emit(_card_data)

func _on_card_used(_card_data: Dictionary):
	card_used.emit(_card_data)

## 敵手札選択中フラグ
var is_enemy_card_selection_active: bool = false

func _on_hand_updated():
	# 敵手札選択中は自動更新をスキップ
	if is_enemy_card_selection_active:
		return
	
	# 現在のターンプレイヤーの手札を表示
	if player_system_ref:
		var current_player = player_system_ref.get_current_player()
		if current_player:
			update_hand_display(current_player.id)
	hand_updated.emit()

## 指定プレイヤーのカードノード取得
func get_player_card_nodes(player_id: int) -> Array:
	return player_card_nodes.get(player_id, [])

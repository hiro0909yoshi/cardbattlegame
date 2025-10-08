extends Node
class_name CardSystem

# カード管理システム - ドロー処理修正版

signal card_drawn(card_data: Dictionary)
signal card_used(card_data: Dictionary)
signal hand_updated()

# 定数
const MAX_PLAYERS = 4
const MAX_HAND_SIZE = 6
const INITIAL_HAND_SIZE = 5
const CARD_COST_MULTIPLIER = 10
const CARDS_PER_TYPE = 3
const CARD_WIDTH = 240      # カードの幅
const CARD_HEIGHT = 350     # カードの高さ
const CARD_SPACING = 20     # カード間の間隔

# カード管理
var card_scene = preload("res://scenes/Card.tscn")
var deck = []
var discard = []
var player_hands = {}

func _ready():
	_initialize_deck()
	_initialize_player_hands()

func _initialize_deck():
	# GameDataから選択中のブックを取得
	var deck_data = GameData.get_current_deck()["cards"]
	
	# 空チェック
	if deck_data.is_empty():
		print("WARNING: デッキが空です。デフォルトデッキで開始")
		# 旧処理で仮デッキ作成
		for i in range(1, 13):
			for j in range(CARDS_PER_TYPE):
				deck.append(i)
	else:
		# 辞書 {card_id: count} を配列に変換
		# 例: {1: 3, 5: 2} → [1,1,1,5,5]
		for card_id in deck_data.keys():
			var count = deck_data[card_id]
			for i in range(count):
				deck.append(card_id)
		print("✅ ブック", GameData.selected_deck_index + 1, "のデッキを読み込み")
	
	deck.shuffle()
	print("デッキ初期化: ", deck.size(), "枚")

func _initialize_player_hands():
	for i in range(MAX_PLAYERS):
		player_hands[i] = {
			"data": [],
			"nodes": []
		}

func draw_card_data() -> Dictionary:
	if deck.is_empty():
		if discard.is_empty():
			print("WARNING: デッキも捨て札も空です")
			return {}
		# 捨て札をシャッフルしてデッキに戻す
		print("捨て札をシャッフルしてデッキに戻します")
		deck = discard.duplicate()
		discard.clear()
		deck.shuffle()
	
	var card_id = deck.pop_front()
	return _load_card_data(card_id)

func _load_card_data(card_id: int) -> Dictionary:
	# CardLoaderを使用してカードデータを取得
	if CardLoader:
		var card_data = CardLoader.get_card_by_id(card_id)
		if card_data.is_empty():
			print("WARNING: カードID ", card_id, " が見つかりません")
			return {}
		
		# costを正規化（辞書形式 {"mp": 2} を整数に変換）
		if card_data.has("cost"):
			if typeof(card_data.cost) == TYPE_DICTIONARY:
				if card_data.cost.has("mp"):
					card_data.cost = card_data.cost.mp
				else:
					card_data.cost = 1  # デフォルト値
		else:
			card_data.cost = 1  # costがない場合
		
		return card_data
	else:
		print("ERROR: CardLoaderが見つかりません")
		return {}

func _get_hand_parent() -> Node:
	var possible_paths = [
		"/root/Main/UILayer/Hand",
		"/root/Game3D/UILayer/Hand",
		"/root/Game/UILayer/Hand",
		"/root/Game/Hand"
	]
	
	for path in possible_paths:
		var node = get_node_or_null(path)
		if node:
			return node
	
	var ui_layer = get_tree().get_root().find_child("UILayer", true, false)
	if ui_layer:
		var hand_node = ui_layer.get_node_or_null("Hand")
		if hand_node:
			return hand_node
		hand_node = Node2D.new()
		hand_node.name = "Hand"
		ui_layer.add_child(hand_node)
		return hand_node
	
	return null

# メインのドロー関数（完全修正版）
func draw_card_for_player(player_id: int) -> Dictionary:
	var card_data = draw_card_data()
	if not card_data.is_empty():
		# データ追加
		player_hands[player_id]["data"].append(card_data)
		
		# プレイヤー1のみ表示ノード作成
		if player_id == 0:
			var hand_parent = _get_hand_parent()
			if hand_parent:
				var card_index = player_hands[player_id]["data"].size() - 1
				var card_node = _create_card_node(card_data, hand_parent, card_index)
				if card_node:
					player_hands[player_id]["nodes"].append(card_node)
					_rearrange_player_hand(player_id)
		
		emit_signal("card_drawn", card_data)
		emit_signal("hand_updated")
	
	return card_data

func draw_cards_for_player(player_id: int, count: int) -> Array:
	print("複数カードドロー: Player", player_id + 1, " x", count, "枚")
	var drawn_cards = []
	for i in range(count):
		if get_hand_size_for_player(player_id) >= MAX_HAND_SIZE:
			print("  手札上限に達しました")
			break
		var card = draw_card_for_player(player_id)
		if not card.is_empty():
			drawn_cards.append(card)
	return drawn_cards

func deal_initial_hands_all_players(player_count: int):
	for player_id in range(player_count):
		player_hands[player_id]["data"].clear()
		player_hands[player_id]["nodes"].clear()
		
		for i in range(INITIAL_HAND_SIZE):
			var card_data = draw_card_data()
			if not card_data.is_empty():
				player_hands[player_id]["data"].append(card_data)
				
				if player_id == 0:
					var hand_parent = _get_hand_parent()
					if hand_parent:
						var card_node = _create_card_node(card_data, hand_parent, i)
						if card_node:
							player_hands[player_id]["nodes"].append(card_node)
	
	emit_signal("hand_updated")

func _create_card_node(card_data: Dictionary, parent: Node, index: int) -> Node:
	if not is_instance_valid(parent):
		print("ERROR: 親ノードが無効です")
		return null
	
	if not card_scene:
		print("ERROR: card_sceneがロードされていません")
		return null
		
	var card = card_scene.instantiate()
	if not card:
		print("ERROR: カードのインスタンス化に失敗")
		return null
	
	# カードサイズを明示的に設定
	card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		
	parent.add_child(card)
	
	# カード位置を設定
	var viewport_size = get_viewport().get_visible_rect().size
	var card_y = viewport_size.y - CARD_HEIGHT - 20  # 下から20px空ける
	
	# 画面中心から配置を計算
	var total_width = INITIAL_HAND_SIZE * (CARD_WIDTH + CARD_SPACING)
	var start_x = (viewport_size.x - total_width) / 2
	card.position = Vector2(start_x + index * (CARD_WIDTH + CARD_SPACING), card_y)
	
	if card.has_method("load_card_data"):
		card.load_card_data(card_data.id)
	else:
		print("WARNING: カードにload_card_dataメソッドがありません")
	
	return card

func use_card_for_player(player_id: int, card_index: int) -> Dictionary:
	print("\nカード使用: Player", player_id + 1, " Index", card_index)
	
	var player_hand_data = player_hands[player_id]["data"]
	
	if player_hand_data.size() == 0:
		print("  手札がありません")
		return {}
	
	if card_index < 0 or card_index >= player_hand_data.size():
		print("  不正なインデックス")
		return {}
	
	var card_data = player_hand_data[card_index]
	player_hand_data.remove_at(card_index)
	discard.append(card_data.id)
	
	print("  使用: ", card_data.get("name", "不明"))
	print("  残り手札: ", player_hand_data.size(), "枚")
	
	if player_id == 0:
		var player_nodes = player_hands[player_id]["nodes"]
		if card_index < player_nodes.size() and player_nodes[card_index] and is_instance_valid(player_nodes[card_index]):
			player_nodes[card_index].queue_free()
			player_nodes.remove_at(card_index)
			_rearrange_player_hand(player_id)
			print("  表示ノード削除完了")
	
	emit_signal("card_used", card_data)
	emit_signal("hand_updated")
	
	return card_data

func _rearrange_player_hand(player_id: int):
	if player_id != 0:
		return
	
	var player_nodes = player_hands[player_id]["nodes"]
	var viewport_size = get_viewport().get_visible_rect().size
	var card_y = viewport_size.y - CARD_HEIGHT - 20  # 下から20px空ける
	
	# 現在の手札枚数に応じて中心から再配置
	var hand_size = player_nodes.size()
	var total_width = hand_size * (CARD_WIDTH + CARD_SPACING)
	var start_x = (viewport_size.x - total_width) / 2
	
	for i in range(player_nodes.size()):
		var card = player_nodes[i]
		if card and is_instance_valid(card):
			card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)  # サイズを再設定
			card.position = Vector2(start_x + i * (CARD_WIDTH + CARD_SPACING), card_y)
			if card.has_method("set_selectable"):
				card.card_index = i

# 手札UIを更新（デバッグ用）
func update_hand_ui_for_player(player_id: int):
	if player_id != 0:
		return  # プレイヤー1以外はUI更新不要
	
	var hand_data = player_hands[player_id]["data"]
	var hand_nodes = player_hands[player_id]["nodes"]
	
	# ノード数がデータより少ない場合、不足分を作成
	if hand_nodes.size() < hand_data.size():
		var hand_parent = _get_hand_parent()
		if not hand_parent:
			print("ERROR: 手札の親ノードが見つかりません")
			return
		
		# 不足分のカードノードを作成
		for i in range(hand_nodes.size(), hand_data.size()):
			var card_data = hand_data[i]
			var card_node = _create_card_node(card_data, hand_parent, i)
			if card_node:
				hand_nodes.append(card_node)
	
	# 手札を再配置
	_rearrange_player_hand(player_id)
	
	emit_signal("hand_updated")
	print("手札UI更新完了: ", hand_data.size(), "枚")

func get_hand_size_for_player(player_id: int) -> int:
	if not player_hands.has(player_id):
		return 0
	return player_hands[player_id]["data"].size()

func get_deck_size() -> int:
	return deck.size()

func get_discard_size() -> int:
	return discard.size()

func get_card_data_for_player(player_id: int, index: int) -> Dictionary:
	if not player_hands.has(player_id):
		return {}
	
	var player_hand_data = player_hands[player_id]["data"]
	if index >= 0 and index < player_hand_data.size():
		return player_hand_data[index]
	return {}

func get_all_cards_for_player(player_id: int) -> Array:
	if not player_hands.has(player_id):
		return []
	return player_hands[player_id]["data"]

func find_cards_by_element_for_player(player_id: int, element: String) -> Array:
	var found_cards = []
	if not player_hands.has(player_id):
		return found_cards
	
	var player_hand_data = player_hands[player_id]["data"]
	for i in range(player_hand_data.size()):
		if player_hand_data[i].element == element:
			found_cards.append(i)
	return found_cards

func find_affordable_cards_for_player(player_id: int, available_magic: int) -> Array:
	var affordable = []
	if not player_hands.has(player_id):
		return affordable
	
	var player_hand_data = player_hands[player_id]["data"]
	for i in range(player_hand_data.size()):
		if player_hand_data[i].cost * CARD_COST_MULTIPLIER <= available_magic:
			affordable.append(i)
	return affordable

func get_cheapest_card_index_for_player(player_id: int) -> int:
	if not player_hands.has(player_id):
		return -1
	
	var player_hand_data = player_hands[player_id]["data"]
	if player_hand_data.is_empty():
		return -1
	
	var min_cost = 999
	var min_index = 0
	
	for i in range(player_hand_data.size()):
		var cost = player_hand_data[i].cost
		if cost < min_cost:
			min_cost = cost
			min_index = i
	
	return min_index

func set_cards_selectable(selectable: bool):
	var hand_nodes = player_hands[0]["nodes"]
	for i in range(hand_nodes.size()):
		var card_node = hand_nodes[i]
		if card_node and is_instance_valid(card_node):
			if card_node.has_method("set_selectable"):
				card_node.set_selectable(selectable, i)

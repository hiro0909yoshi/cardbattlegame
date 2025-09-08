extends Node
class_name CardSystem

# カード、手札、山札管理システム - 整理版

signal card_drawn(card_data: Dictionary)
signal card_used(card_data: Dictionary)
signal hand_updated()

# カード管理
var card_scene = preload("res://scenes/Card.tscn")
var deck = []        # 山札
var discard = []     # 捨て札

# プレイヤー別手札管理
var player_hands = {}  # player_id -> {data: [], nodes: []}
var max_players = 4

# 設定
var max_hand_size = 6  # 手札上限
var initial_hand_size = 5  # 初期手札枚数

func _ready():
	initialize_deck()
	initialize_player_hands()

# 山札を初期化
func initialize_deck():
	# 各カードを3枚ずつ山札に追加
	for i in range(1, 13):  # カードID 1-12
		for j in range(3):  # 3枚ずつ
			deck.append(i)
	
	shuffle_deck()

# プレイヤー別手札を初期化
func initialize_player_hands():
	for i in range(max_players):
		player_hands[i] = {
			"data": [],
			"nodes": []
		}

# 山札をシャッフル
func shuffle_deck():
	deck.shuffle()

# カードを引く（データのみ）
func draw_card_data() -> Dictionary:
	if deck.is_empty():
		# 山札が空なら捨て札をシャッフルして山札に
		if discard.is_empty():
			return {}
		
		deck = discard.duplicate()
		discard.clear()
		shuffle_deck()
	
	var card_id = deck.pop_front()
	var card_data = load_card_data(card_id)
	
	if card_data.is_empty():
		return {}
	
	return card_data

# カードを引く（プレイヤー別）
func draw_card_for_player(player_id: int) -> Dictionary:
	var card_data = draw_card_data()
	if not card_data.is_empty():
		player_hands[player_id]["data"].append(card_data)
		
		# プレイヤー1の場合のみ表示ノードを作成
		if player_id == 0:
			var main_game = get_tree().get_root().get_node_or_null("Game")
			if main_game and main_game.has_node("Hand"):
				var hand_parent = main_game.get_node("Hand")
				var card_index = player_hands[player_id]["data"].size() - 1
				var card_node = create_card_node(card_data, hand_parent, card_index)
				player_hands[player_id]["nodes"].append(card_node)
				rearrange_player_hand(player_id)
		
		emit_signal("card_drawn", card_data)
		emit_signal("hand_updated")
	return card_data

# 複数枚カードを引く
func draw_cards_for_player(player_id: int, count: int) -> Array:
	var drawn_cards = []
	for i in range(count):
		if get_hand_size_for_player(player_id) >= max_hand_size:
			break
		var card = draw_card_for_player(player_id)
		if not card.is_empty():
			drawn_cards.append(card)
	return drawn_cards

# 初期手札を配る（全プレイヤー）
func deal_initial_hands_all_players(player_count: int):
	for player_id in range(player_count):
		player_hands[player_id]["data"].clear()
		player_hands[player_id]["nodes"].clear()
		
		for i in range(initial_hand_size):
			var card_data = draw_card_data()
			if not card_data.is_empty():
				player_hands[player_id]["data"].append(card_data)
				
				# プレイヤー1の場合のみ表示
				if player_id == 0:
					var main_game = get_tree().get_root().get_node_or_null("Game")
					if main_game and main_game.has_node("Hand"):
						var hand_parent = main_game.get_node("Hand")
						var card_node = create_card_node(card_data, hand_parent, i)
						player_hands[player_id]["nodes"].append(card_node)
	
	emit_signal("hand_updated")

# カードノードを作成
func create_card_node(card_data: Dictionary, parent: Node, index: int) -> Node:
	var card = card_scene.instantiate()
	parent.add_child(card)
	
	# カードをマップの下に横に並べる
	card.position = Vector2(100 + index * 120, 600)
	
	# カードデータを読み込み
	if card.has_method("load_card_data"):
		card.load_card_data(card_data.id)
	
	return card

# カードデータを読み込み（JSONから）
func load_card_data(card_id: int) -> Dictionary:
	var file = FileAccess.open("res://data/Cards.json", FileAccess.READ)
	if file == null:
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		return {}
	
	var data = json.data
	for card in data.cards:
		if card.id == card_id:
			return card
	
	return {}

# カードを使用
func use_card_for_player(player_id: int, card_index: int) -> Dictionary:
	var player_hand_data = player_hands[player_id]["data"]
	
	if player_hand_data.size() == 0:
		return {}
	
	if card_index < 0 or card_index >= player_hand_data.size():
		return {}
	
	var card_data = player_hand_data[card_index]
	
	# 手札データから削除
	player_hand_data.remove_at(card_index)
	
	# 捨て札に追加
	discard.append(card_data.id)
	
	# プレイヤー1の場合のみ表示ノードを処理
	if player_id == 0:
		var player_nodes = player_hands[player_id]["nodes"]
		if card_index < player_nodes.size() and player_nodes[card_index] and is_instance_valid(player_nodes[card_index]):
			player_nodes[card_index].queue_free()
			player_nodes.remove_at(card_index)
			
			# 残りのカードを左詰めで再配置
			for i in range(player_nodes.size()):
				if player_nodes[i] and is_instance_valid(player_nodes[i]):
					var new_position = Vector2(100 + i * 120, 600)
					player_nodes[i].position = new_position
					
					# カードのインデックスを更新
					if player_nodes[i].has_method("set_selectable"):
						player_nodes[i].card_index = i
	
	emit_signal("card_used", card_data)
	emit_signal("hand_updated")
	
	return card_data

# 手札を整列（プレイヤー別）
func rearrange_player_hand(player_id: int):
	if player_id != 0:  # プレイヤー1以外は表示しない
		return
	
	var player_nodes = player_hands[player_id]["nodes"]
	for i in range(player_nodes.size()):
		var card = player_nodes[i]
		if card and is_instance_valid(card):
			card.position = Vector2(100 + i * 120, 600)

# 手札の枚数を取得
func get_hand_size_for_player(player_id: int) -> int:
	if not player_hands.has(player_id):
		return 0
	return player_hands[player_id]["data"].size()

# 山札の枚数を取得
func get_deck_size() -> int:
	return deck.size()

# 捨て札の枚数を取得
func get_discard_size() -> int:
	return discard.size()

# 手札のカードデータを取得
func get_card_data_for_player(player_id: int, index: int) -> Dictionary:
	if not player_hands.has(player_id):
		return {}
	
	var player_hand_data = player_hands[player_id]["data"]
	if index >= 0 and index < player_hand_data.size():
		return player_hand_data[index]
	return {}

# プレイヤーの全手札データを取得
func get_all_cards_for_player(player_id: int) -> Array:
	if not player_hands.has(player_id):
		return []
	return player_hands[player_id]["data"]

# 特定の属性のカードを検索
func find_cards_by_element_for_player(player_id: int, element: String) -> Array:
	var found_cards = []
	if not player_hands.has(player_id):
		return found_cards
	
	var player_hand_data = player_hands[player_id]["data"]
	for i in range(player_hand_data.size()):
		if player_hand_data[i].element == element:
			found_cards.append(i)
	return found_cards

# コストが支払えるカードを検索
func find_affordable_cards_for_player(player_id: int, available_magic: int) -> Array:
	var affordable = []
	if not player_hands.has(player_id):
		return affordable
	
	var player_hand_data = player_hands[player_id]["data"]
	for i in range(player_hand_data.size()):
		if player_hand_data[i].cost * 10 <= available_magic:
			affordable.append(i)
	return affordable

# CPU用：最も安いカードを選択
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

# カード選択モードを設定（プレイヤー1の手札）
func set_cards_selectable(selectable: bool):
	var hand_nodes = player_hands[0]["nodes"]
	for i in range(hand_nodes.size()):
		var card_node = hand_nodes[i]
		if card_node and is_instance_valid(card_node):
			if card_node.has_method("set_selectable"):
				card_node.set_selectable(selectable, i)

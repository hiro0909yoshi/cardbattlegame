extends Node
class_name CardSystem

# カード管理システム

signal card_drawn(card_data: Dictionary)
signal card_used(card_data: Dictionary)
signal hand_updated()

# 定数
const MAX_PLAYERS = 4
const MAX_HAND_SIZE = 6
const INITIAL_HAND_SIZE = 5
const CARD_COST_MULTIPLIER = 10
const CARDS_PER_TYPE = 3
const CARD_WIDTH = 100      # カードの幅
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
	for i in range(1, 13):
		for j in range(CARDS_PER_TYPE):
			deck.append(i)
	deck.shuffle()

func _initialize_player_hands():
	for i in range(MAX_PLAYERS):
		player_hands[i] = {
			"data": [],
			"nodes": []
		}

func draw_card_data() -> Dictionary:
	if deck.is_empty():
		if discard.is_empty():
			return {}
		deck = discard.duplicate()
		discard.clear()
		deck.shuffle()
	
	var card_id = deck.pop_front()
	return _load_card_data(card_id)

func _load_card_data(card_id: int) -> Dictionary:
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

func _get_hand_parent() -> Node:
	var main_game = get_tree().get_root().get_node_or_null("Game")
	if not main_game:
		return null
	
	var hand_parent = main_game.get_node_or_null("UILayer/Hand")
	if hand_parent:
		return hand_parent
	
	if main_game.has_node("Hand"):
		return main_game.get_node("Hand")
	
	return null

func draw_card_for_player(player_id: int) -> Dictionary:
	var card_data = draw_card_data()
	if not card_data.is_empty():
		player_hands[player_id]["data"].append(card_data)
		
		if player_id == 0:
			var hand_parent = _get_hand_parent()
			if hand_parent:
				var card_index = player_hands[player_id]["data"].size() - 1
				var card_node = _create_card_node(card_data, hand_parent, card_index)
				player_hands[player_id]["nodes"].append(card_node)
				_rearrange_player_hand(player_id)
		
		emit_signal("card_drawn", card_data)
		emit_signal("hand_updated")
	return card_data

func draw_cards_for_player(player_id: int, count: int) -> Array:
	var drawn_cards = []
	for i in range(count):
		if get_hand_size_for_player(player_id) >= MAX_HAND_SIZE:
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
						player_hands[player_id]["nodes"].append(card_node)
	
	emit_signal("hand_updated")

func _create_card_node(card_data: Dictionary, parent: Node, index: int) -> Node:
	var card = card_scene.instantiate()
	parent.add_child(card)
	
	var viewport_size = get_viewport().get_visible_rect().size
	var card_y = viewport_size.y - 170
	
	# 画面中心から配置を計算
	var total_width = INITIAL_HAND_SIZE * (CARD_WIDTH + CARD_SPACING)
	var start_x = (viewport_size.x - total_width) / 2
	card.position = Vector2(start_x + index * (CARD_WIDTH + CARD_SPACING), card_y)
	
	if card.has_method("load_card_data"):
		card.load_card_data(card_data.id)
	
	return card

func use_card_for_player(player_id: int, card_index: int) -> Dictionary:
	var player_hand_data = player_hands[player_id]["data"]
	
	if player_hand_data.size() == 0:
		return {}
	
	if card_index < 0 or card_index >= player_hand_data.size():
		return {}
	
	var card_data = player_hand_data[card_index]
	player_hand_data.remove_at(card_index)
	discard.append(card_data.id)
	
	if player_id == 0:
		var player_nodes = player_hands[player_id]["nodes"]
		if card_index < player_nodes.size() and player_nodes[card_index] and is_instance_valid(player_nodes[card_index]):
			player_nodes[card_index].queue_free()
			player_nodes.remove_at(card_index)
			_rearrange_player_hand(player_id)
	
	emit_signal("card_used", card_data)
	emit_signal("hand_updated")
	
	return card_data

func _rearrange_player_hand(player_id: int):
	if player_id != 0:
		return
	
	var player_nodes = player_hands[player_id]["nodes"]
	var viewport_size = get_viewport().get_visible_rect().size
	var card_y = viewport_size.y - 170
	
	# 現在の手札枚数に応じて中心から再配置
	var hand_size = player_nodes.size()
	var total_width = hand_size * (CARD_WIDTH + CARD_SPACING)
	var start_x = (viewport_size.x - total_width) / 2
	
	for i in range(player_nodes.size()):
		var card = player_nodes[i]
		if card and is_instance_valid(card):
			card.position = Vector2(start_x + i * (CARD_WIDTH + CARD_SPACING), card_y)
			if card.has_method("set_selectable"):
				card.card_index = i

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

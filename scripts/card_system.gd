extends Node
class_name CardSystem

# カード、手札、山札管理システム - プレイヤー別手札対応版

signal card_drawn(card_data: Dictionary)
signal card_used(card_data: Dictionary)
signal hand_updated()

# カード管理
var card_scene = preload("res://scenes/Card.tscn")
var deck = []        # 山札
var hand_cards = []  # 手札（ノード） - 後方互換性のため残す
var hand_data = []   # 手札のデータ - 後方互換性のため残す
var discard = []     # 捨て札

# プレイヤー別手札管理
var player_hands = {}  # player_id -> {data: [], nodes: []}
var max_players = 4

# 設定
var max_hand_size = 6  # 手札上限
var initial_hand_size = 5  # 初期手札枚数

func _ready():
	print("CardSystem: 初期化")
	initialize_deck()
	initialize_player_hands()

# 山札を初期化
func initialize_deck():
	# 各カードを3枚ずつ山札に追加（仮）
	for i in range(1, 13):  # カードID 1-12
		for j in range(3):  # 3枚ずつ
			deck.append(i)
	
	shuffle_deck()
	print("CardSystem: 山札初期化完了 (", deck.size(), "枚)")

# プレイヤー別手札を初期化
func initialize_player_hands():
	for i in range(max_players):
		player_hands[i] = {
			"data": [],
			"nodes": []
		}
	print("CardSystem: プレイヤー手札初期化完了")

# 山札をシャッフル
func shuffle_deck():
	deck.shuffle()

# カードを引く（データのみ）
func draw_card_data() -> Dictionary:
	if deck.is_empty():
		# 山札が空なら捨て札をシャッフルして山札に
		if discard.is_empty():
			print("カードが引けません（山札と捨て札が空）")
			return {}
		
		deck = discard.duplicate()
		discard.clear()
		shuffle_deck()
		print("捨て札をシャッフルして山札に戻しました")
	
	var card_id = deck.pop_front()
	var card_data = load_card_data(card_id)
	
	if card_data.is_empty():
		print("カードデータの読み込みに失敗: ID ", card_id)
		return {}
	
	return card_data

# カードを引く（プレイヤー別対応）
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

# カードを引く（後方互換性のため残す）
func draw_card() -> Dictionary:
	# デフォルトでプレイヤー1のカードを引く
	var card_data = draw_card_for_player(0)
	if not card_data.is_empty():
		# 後方互換性のため旧変数も更新
		hand_data = player_hands[0]["data"]
		hand_cards = player_hands[0]["nodes"]
	return card_data

# 複数枚カードを引く（プレイヤー別対応）
func draw_cards_for_player(player_id: int, count: int) -> Array:
	var drawn_cards = []
	for i in range(count):
		if get_hand_size_for_player(player_id) >= max_hand_size:
			print("プレイヤー", player_id + 1, "の手札が上限に達しています")
			break
		var card = draw_card_for_player(player_id)
		if not card.is_empty():
			drawn_cards.append(card)
	return drawn_cards

# 複数枚カードを引く（後方互換性）
func draw_cards(count: int) -> Array:
	return draw_cards_for_player(0, count)

# 初期手札を配る（全プレイヤー対応）
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
		
		print("プレイヤー", player_id + 1, "に初期手札", initial_hand_size, "枚を配布")
	
	# 後方互換性のため旧変数も更新
	hand_data = player_hands[0]["data"]
	hand_cards = player_hands[0]["nodes"]
	emit_signal("hand_updated")

# 初期手札を配る（後方互換性）
func deal_initial_hand(hand_parent: Node) -> Array:
	# プレイヤー1のみ配る（旧実装の互換性）
	player_hands[0]["data"].clear()
	player_hands[0]["nodes"].clear()
	
	for i in range(initial_hand_size):
		var card_data = draw_card_data()
		if not card_data.is_empty():
			player_hands[0]["data"].append(card_data)
			var card_node = create_card_node(card_data, hand_parent, i)
			player_hands[0]["nodes"].append(card_node)
	
	hand_data = player_hands[0]["data"]
	hand_cards = player_hands[0]["nodes"]
	emit_signal("hand_updated")
	return hand_cards

# カードノードを作成
func create_card_node(card_data: Dictionary, parent: Node, index: int) -> Node:
	var card = card_scene.instantiate()
	parent.add_child(card)
	
	# カードをマップの下に横に並べる（確定位置）
	card.position = Vector2(100 + index * 120, 600)
	
	# カードデータを読み込み
	if card.has_method("load_card_data"):
		card.load_card_data(card_data.id)
	
	return card

# カードデータを読み込み（JSONから）
func load_card_data(card_id: int) -> Dictionary:
	var file = FileAccess.open("res://data/Cards.json", FileAccess.READ)
	if file == null:
		print("CardSystem: JSONファイルが開けません")
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("CardSystem: JSONパースエラー")
		return {}
	
	var data = json.data
	for card in data.cards:
		if card.id == card_id:
			return card
	
	return {}

# カードを使用（プレイヤー別対応）
func use_card_for_player(player_id: int, card_index: int) -> Dictionary:
	var player_hand_data = player_hands[player_id]["data"]
	
	if player_hand_data.size() == 0:
		print("ERROR: プレイヤー", player_id + 1, "の手札が空です")
		return {}
	
	if card_index < 0 or card_index >= player_hand_data.size():
		print("ERROR: 無効なインデックス: ", card_index, " / ", player_hand_data.size())
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
			
			# 残りのカードを左詰めで再配置（アニメーションなし）
			for i in range(player_nodes.size()):
				if player_nodes[i] and is_instance_valid(player_nodes[i]):
					var new_position = Vector2(100 + i * 120, 600)
					player_nodes[i].position = new_position
					
					# カードのインデックスを更新
					if player_nodes[i].has_method("set_selectable"):
						player_nodes[i].card_index = i
	
	# 後方互換性のため旧変数も更新
	if player_id == 0:
		hand_data = player_hands[0]["data"]
		hand_cards = player_hands[0]["nodes"]
	
	emit_signal("card_used", card_data)
	emit_signal("hand_updated")
	
	return card_data

# カードを使用（後方互換性）
func use_card(card_index: int) -> Dictionary:
	return use_card_for_player(0, card_index)

# 手札を整列（プレイヤー別）
func rearrange_player_hand(player_id: int):
	if player_id != 0:  # プレイヤー1以外は表示しない
		return
	
	var player_nodes = player_hands[player_id]["nodes"]
	for i in range(player_nodes.size()):
		var card = player_nodes[i]
		if card and is_instance_valid(card):
			card.position = Vector2(100 + i * 120, 600)

# 手札を整列（後方互換性）
func rearrange_hand():
	rearrange_player_hand(0)

# 手札の枚数を取得（プレイヤー別）
func get_hand_size_for_player(player_id: int) -> int:
	if not player_hands.has(player_id):
		print("WARNING: プレイヤー", player_id + 1, "の手札が存在しません")
		return 0
	return player_hands[player_id]["data"].size()

# 手札の枚数を取得（後方互換性）
func get_hand_size() -> int:
	return get_hand_size_for_player(0)

# 山札の枚数を取得
func get_deck_size() -> int:
	return deck.size()

# 捨て札の枚数を取得
func get_discard_size() -> int:
	return discard.size()

# 手札のカードデータを取得（プレイヤー別）
func get_card_data_for_player(player_id: int, index: int) -> Dictionary:
	if not player_hands.has(player_id):
		return {}
	
	var player_hand_data = player_hands[player_id]["data"]
	if index >= 0 and index < player_hand_data.size():
		return player_hand_data[index]
	return {}

# 手札のカードデータを取得（後方互換性）
func get_card_data(index: int) -> Dictionary:
	return get_card_data_for_player(0, index)

# プレイヤーの全手札データを取得
func get_all_cards_for_player(player_id: int) -> Array:
	if not player_hands.has(player_id):
		return []
	return player_hands[player_id]["data"]

# 特定の属性のカードを検索（プレイヤー別）
func find_cards_by_element_for_player(player_id: int, element: String) -> Array:
	var found_cards = []
	if not player_hands.has(player_id):
		return found_cards
	
	var player_hand_data = player_hands[player_id]["data"]
	for i in range(player_hand_data.size()):
		if player_hand_data[i].element == element:
			found_cards.append(i)
	return found_cards

# 特定の属性のカードを検索（後方互換性）
func find_cards_by_element(element: String) -> Array:
	return find_cards_by_element_for_player(0, element)

# コストが支払えるカードを検索（プレイヤー別）
func find_affordable_cards_for_player(player_id: int, available_magic: int) -> Array:
	var affordable = []
	if not player_hands.has(player_id):
		return affordable
	
	var player_hand_data = player_hands[player_id]["data"]
	for i in range(player_hand_data.size()):
		if player_hand_data[i].cost * 10 <= available_magic:
			affordable.append(i)
	return affordable

# コストが支払えるカードを検索（後方互換性）
func find_affordable_cards(available_magic: int) -> Array:
	return find_affordable_cards_for_player(0, available_magic)

# CPU用：ランダムにカードを選択
func get_random_card_index_for_player(player_id: int) -> int:
	var hand_size = get_hand_size_for_player(player_id)
	if hand_size == 0:
		return -1
	return randi() % hand_size

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
func sync_hand_display():
	# プレイヤー1の手札のみ同期
	var player_nodes = player_hands[0]["nodes"]
	
	# 古い表示をクリア
	for card in player_nodes:
		if card and is_instance_valid(card):
			card.queue_free()
	player_nodes.clear()
	
	# データに基づいて表示を再作成
	var main_game = get_tree().get_root().get_node_or_null("Game")
	if main_game:
		var hand_parent = main_game.get_node_or_null("Hand")
		if hand_parent:
			var player_hand_data = player_hands[0]["data"]
			for i in range(player_hand_data.size()):
				var card_node = create_card_node(player_hand_data[i], hand_parent, i)
				player_nodes.append(card_node)
			rearrange_player_hand(0)
		else:
			print("ERROR: Handノードが見つかりません")
	else:
		print("ERROR: Gameノードが見つかりません")
	
	# 後方互換性のため旧変数も更新
	hand_data = player_hands[0]["data"]
	hand_cards = player_hands[0]["nodes"]

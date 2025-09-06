extends Node
class_name CardSystem

# カード、手札、山札管理システム

signal card_drawn(card_data: Dictionary)
signal card_used(card_data: Dictionary)
signal hand_updated()

# カード管理
var card_scene = preload("res://scenes/Card.tscn")
var deck = []        # 山札
var hand_cards = []  # 手札（ノード）
var hand_data = []   # 手札のデータ
var discard = []     # 捨て札

# 設定
var max_hand_size = 6  # 手札上限
var initial_hand_size = 5  # 初期手札枚数

func _ready():
	print("CardSystem: 初期化")
	initialize_deck()

# 山札を初期化
func initialize_deck():
	# 各カードを3枚ずつ山札に追加（仮）
	for i in range(1, 13):  # カードID 1-12
		for j in range(3):  # 3枚ずつ
			deck.append(i)
	
	shuffle_deck()
	print("CardSystem: 山札初期化完了 (", deck.size(), "枚)")

# 山札をシャッフル
func shuffle_deck():
	deck.shuffle()

# カードを引く
func draw_card() -> Dictionary:
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
	
	hand_data.append(card_data)
	
	emit_signal("card_drawn", card_data)
	return card_data

# 複数枚カードを引く
func draw_cards(count: int) -> Array:
	var drawn_cards = []
	for i in range(count):
		if hand_data.size() >= max_hand_size:
			print("手札が上限に達しています")
			break
		var card = draw_card()
		if not card.is_empty():
			drawn_cards.append(card)
	return drawn_cards

# 初期手札を配る
func deal_initial_hand(hand_parent: Node) -> Array:
	hand_cards.clear()
	hand_data.clear()
	
	for i in range(initial_hand_size):
		var card_data = draw_card()
		if not card_data.is_empty():
			var card_node = create_card_node(card_data, hand_parent, i)
			hand_cards.append(card_node)
	
	emit_signal("hand_updated")
	return hand_cards

# カードノードを作成
func create_card_node(card_data: Dictionary, parent: Node, index: int) -> Node:
	var card = card_scene.instantiate()
	parent.add_child(card)
	
	# カードを横に並べる
	card.position = Vector2(50 + index * 120, 200)
	
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

# カードを使用
func use_card(card_index: int) -> Dictionary:
	if card_index < 0 or card_index >= hand_data.size():
		print("無効なカードインデックス")
		return {}
	
	var card_data = hand_data[card_index]
	var card_node = hand_cards[card_index]
	
	# 手札から削除
	hand_data.remove_at(card_index)
	hand_cards.remove_at(card_index)
	
	# 捨て札に追加
	discard.append(card_data.id)
	
	# ノードを削除
	if card_node:
		card_node.queue_free()
	
	# 手札を詰める
	rearrange_hand()
	
	emit_signal("card_used", card_data)
	emit_signal("hand_updated")
	
	return card_data

# 手札を整列
func rearrange_hand():
	for i in range(hand_cards.size()):
		var card = hand_cards[i]
		if card:
			# アニメーション付きで移動（後で実装）
			card.position = Vector2(50 + i * 120, 200)

# 手札の枚数を取得
func get_hand_size() -> int:
	return hand_data.size()

# 山札の枚数を取得
func get_deck_size() -> int:
	return deck.size()

# 捨て札の枚数を取得
func get_discard_size() -> int:
	return discard.size()

# 手札のカードデータを取得（読み取り専用）
func get_card_data(index: int) -> Dictionary:
	print("DEBUG get_card_data: index=", index, " hand_data.size()=", hand_data.size())
	if index >= 0 and index < hand_data.size():
		return hand_data[index]
	print("ERROR: get_card_data範囲外アクセス")
	return {}

# 特定の属性のカードを検索
func find_cards_by_element(element: String) -> Array:
	var found_cards = []
	for i in range(hand_data.size()):
		if hand_data[i].element == element:
			found_cards.append(i)
	return found_cards

# コストが支払えるカードを検索
func find_affordable_cards(available_magic: int) -> Array:
	var affordable = []
	for i in range(hand_data.size()):
		if hand_data[i].cost <= available_magic:
			affordable.append(i)
	return affordable

extends Node
class_name CardSystem

# カード管理システム - 3D専用版

signal card_drawn(card_data: Dictionary)
signal card_used(card_data: Dictionary)
signal hand_updated()

# 定数
const MAX_PLAYERS = 4
const MAX_HAND_SIZE = 6
const INITIAL_HAND_SIZE = 5
const CARD_COST_MULTIPLIER = 1
const CARDS_PER_TYPE = 3

# カード管理
var deck = []
var discard = []
var player_hands = {}  # player_id -> {"data": [card_data]}

func _ready():
	_initialize_deck()
	_initialize_player_hands()

func _initialize_deck():
	# GameDataから選択中のブックを取得
	var deck_data = GameData.get_current_deck()["cards"]
	
	# 空チェック
	if deck_data.is_empty():
		print("WARNING: デッキが空です。デフォルトデッキで開始")
		for i in range(1, 13):
			for j in range(CARDS_PER_TYPE):
				deck.append(i)
	else:
		# 辞書 {card_id: count} を配列に変換
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
			"data": []
		}

func draw_card_data() -> Dictionary:
	if deck.is_empty():
		if discard.is_empty():
			print("WARNING: デッキも捨て札も空です")
			return {}
		print("捨て札をシャッフルしてデッキに戻します")
		deck = discard.duplicate()
		discard.clear()
		deck.shuffle()
	
	var card_id = deck.pop_front()
	return _load_card_data(card_id)

func _load_card_data(card_id: int) -> Dictionary:
	if CardLoader:
		var card_data = CardLoader.get_card_by_id(card_id)
		if card_data.is_empty():
			print("WARNING: カードID ", card_id, " が見つかりません")
			return {}
		
		# costを正規化
		if card_data.has("cost"):
			if typeof(card_data.cost) == TYPE_DICTIONARY:
				if card_data.cost.has("mp"):
					card_data.cost = card_data.cost.mp
				else:
					card_data.cost = 1
		else:
			card_data.cost = 1
		
		return card_data
	else:
		print("ERROR: CardLoaderが見つかりません")
		return {}

func draw_card_for_player(player_id: int) -> Dictionary:
	var card_data = draw_card_data()
	if not card_data.is_empty():
		player_hands[player_id]["data"].append(card_data)
		
		emit_signal("card_drawn", card_data)
		emit_signal("hand_updated")
	
	return card_data

func draw_cards_for_player(player_id: int, count: int) -> Array:
	print("複数カードドロー: Player", player_id + 1, " x", count, "枚")
	var drawn_cards = []
	for i in range(count):
		var card = draw_card_for_player(player_id)
		if not card.is_empty():
			drawn_cards.append(card)
	return drawn_cards

func deal_initial_hands_all_players(player_count: int):
	for player_id in range(player_count):
		player_hands[player_id]["data"].clear()
		
		for i in range(INITIAL_HAND_SIZE):
			var card_data = draw_card_data()
			if not card_data.is_empty():
				player_hands[player_id]["data"].append(card_data)
	
	emit_signal("hand_updated")

func use_card_for_player(player_id: int, card_index: int) -> Dictionary:
	# discard_card()を使用（理由: "use"）
	return discard_card(player_id, card_index, "use")

# 統一された捨て札処理
func discard_card(player_id: int, card_index: int, reason: String = "discard") -> Dictionary:
	print("
カード捨て札: Player", player_id + 1, " Index", card_index, " (理由: ", reason, ")")
	
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
	
	# 理由に応じたメッセージ
	match reason:
		"use":
			print("  使用: ", card_data.get("name", "不明"))
		"discard":
			print("  捨て札: ", card_data.get("name", "不明"))
		"forced":
			print("  強制捨て札: ", card_data.get("name", "不明"))
		"destroy":
			print("  破壊: ", card_data.get("name", "不明"))
		_:
			print("  捨て札: ", card_data.get("name", "不明"))
	
	print("  残り手札: ", player_hand_data.size(), "枚")
	
	# 適切なシグナルを発行
	if reason == "use":
		emit_signal("card_used", card_data)
	
	emit_signal("hand_updated")
	
	return card_data

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

# 手札を指定枚数まで減らす（ターン終了時用）
# CPU用の自動捨て札処理（後ろから捨てる）
func discard_excess_cards_auto(player_id: int, max_cards: int = 6) -> int:
	var hand_size = get_hand_size_for_player(player_id)
	if hand_size <= max_cards:
		return 0  # 捨てる必要なし
	
	var cards_to_discard = hand_size - max_cards
	print("手札調整（自動）: ", hand_size, "枚 → ", max_cards, "枚（", cards_to_discard, "枚捨てる）")
	
	# 後ろから捨てる
	for i in range(cards_to_discard):
		var hand_data = player_hands[player_id]["data"]
		if hand_data.size() > max_cards:
			# 最後のカードのインデックス
			var last_index = hand_data.size() - 1
			discard_card(player_id, last_index, "discard")
	
	return cards_to_discard

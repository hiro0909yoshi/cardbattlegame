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

# カードを引く（手札に追加）- 修正版
func draw_card() -> Dictionary:
	var card_data = draw_card_data()
	if not card_data.is_empty():
		hand_data.append(card_data)
		
		# 表示ノードを作成（追加部分）
		var main_game = get_tree().get_root().get_node_or_null("Game")
		if main_game and main_game.has_node("Hand"):
			var hand_parent = main_game.get_node("Hand")
			var card_node = create_card_node(card_data, hand_parent, hand_data.size() - 1)
			hand_cards.append(card_node)
			rearrange_hand()
			print("表示ノード作成完了: データ=", hand_data.size(), " 表示=", hand_cards.size())
		else:
			print("WARNING: Handノードが見つからないため表示ノードを作成できません")
		
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
		# draw_card_dataを使って、手動で管理
		var card_data = draw_card_data()
		if not card_data.is_empty():
			hand_data.append(card_data)
			var card_node = create_card_node(card_data, hand_parent, i)
			hand_cards.append(card_node)
	
	emit_signal("hand_updated")
	print("初期手札配布完了: データ=", hand_data.size(), " 表示=", hand_cards.size())
	return hand_cards

# カードノードを作成
func create_card_node(card_data: Dictionary, parent: Node, index: int) -> Node:
	print("DEBUG: create_card_node開始 - カード:", card_data.get("name", "不明"), " ID:", card_data.get("id", "なし"))
	
	var card = card_scene.instantiate()
	print("DEBUG: カードインスタンス作成成功")
	
	parent.add_child(card)
	print("DEBUG: 親ノードに追加成功")
	
	# カードをマップの下に横に並べる（Y座標を下に移動）
	card.position = Vector2(100 + index * 120, 600)  # 600に変更（マップの下）
	
	# カードデータを読み込み
	if card.has_method("load_card_data"):
		print("DEBUG: load_card_dataメソッド発見 - ID:", card_data.id, "で呼び出し")
		card.load_card_data(card_data.id)
		print("DEBUG: load_card_data呼び出し完了")
	else:
		print("ERROR: load_card_dataメソッドが見つかりません")
	
	print("DEBUG: create_card_node完了")
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

# カードを使用（修正版）
func use_card(card_index: int) -> Dictionary:
	# 範囲チェックを強化
	if hand_data.size() == 0:
		print("ERROR: use_card - hand_dataが空です")
		return {}
		
	if card_index < 0 or card_index >= hand_data.size():
		print("ERROR: use_card - 無効なインデックス: ", card_index, " / ", hand_data.size())
		return {}
	
	var card_data = hand_data[card_index]
	
	# 手札データから削除
	hand_data.remove_at(card_index)
	
	# 捨て札に追加
	discard.append(card_data.id)
	
	# 表示ノードの処理（範囲チェック追加）
	if card_index < hand_cards.size() and hand_cards[card_index] and is_instance_valid(hand_cards[card_index]):
		hand_cards[card_index].queue_free()
		hand_cards.remove_at(card_index)
		rearrange_hand()
	else:
		print("WARNING: 表示ノードの削除でインデックス不整合")
	
	emit_signal("card_used", card_data)
	emit_signal("hand_updated")
	
	print("カード使用: ", card_data.name, " (残り手札: データ=", hand_data.size(), " 表示=", hand_cards.size(), ")")
	
	return card_data

# 手札を整列（表示ノードがある場合のみ）
func rearrange_hand():
	for i in range(hand_cards.size()):
		var card = hand_cards[i]
		if card and is_instance_valid(card):
			card.position = Vector2(100 + i * 120, 600)  # ドキュメントと同じ数値に修正

# 手札の枚数を取得
func get_hand_size() -> int:
	if hand_data == null:
		print("WARNING: hand_dataがnullです")
		return 0
	return hand_data.size()

# 山札の枚数を取得
func get_deck_size() -> int:
	return deck.size()

# 捨て札の枚数を取得
func get_discard_size() -> int:
	return discard.size()

# 手札のカードデータを取得（読み取り専用）
func get_card_data(index: int) -> Dictionary:
	if index >= 0 and index < hand_data.size():
		return hand_data[index]
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

# 手札の表示を同期（デバッグ用）
func sync_hand_display():
	print("手札同期開始: データ=", hand_data.size(), " 表示=", hand_cards.size())
	
	# 古い表示をクリア
	for card in hand_cards:
		if card and is_instance_valid(card):
			card.queue_free()
	hand_cards.clear()
	
	# データに基づいて表示を再作成
	var main_game = get_tree().get_root().get_node_or_null("Game")
	if main_game:
		var hand_parent = main_game.get_node_or_null("Hand")
		if hand_parent:
			for i in range(hand_data.size()):
				var card_node = create_card_node(hand_data[i], hand_parent, i)
				hand_cards.append(card_node)
			rearrange_hand()
			print("手札同期完了: データ=", hand_data.size(), " 表示=", hand_cards.size())
		else:
			print("ERROR: Handノードが見つかりません")
	else:
		print("ERROR: Gameノードが見つかりません")

# デバッグ用: 手札状態を表示
func debug_hand_status():
	print("=== 手札状態 ===")
	print("データ枚数: ", hand_data.size())
	print("表示枚数: ", hand_cards.size())
	print("山札枚数: ", deck.size())
	print("捨て札枚数: ", discard.size())
	
	for i in range(hand_data.size()):
		var card_name = hand_data[i].get("name", "不明")
		var has_display = i < hand_cards.size() and hand_cards[i] != null
		print("  [", i, "] ", card_name, " (表示: ", has_display, ")")
	print("===============")

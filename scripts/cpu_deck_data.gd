extends Node

# CPUデッキデータ管理
# プレイヤーのカードプールとは独立して、全カード4枚ずつから選択可能

const SAVE_FILE_PATH = "res://data/master/decks/cpu_decks.json"
const MAX_DECKS = 50
const MAX_CARDS_PER_DECK = 50
const MAX_COPIES_PER_CARD = 4

# デッキデータ
var decks: Array = []

# 選択中のデッキインデックス
var selected_deck_index: int = 0

func _ready():
	load_from_file()

# ==========================================
# セーブ/ロード
# ==========================================

func save_to_file() -> bool:
	# 保存用にカード名を追加したデータを作成
	var save_decks = []
	for deck in decks:
		var save_deck = {
			"name": deck.get("name", ""),
			"cards": {}
		}
		var cards = deck.get("cards", {})
		for card_id in cards.keys():
			var count = cards[card_id]
			var card_name = _get_card_name(card_id)
			# "ID // カード名": 枚数 の形式で保存
			var key_with_name = "%d // %s" % [card_id, card_name]
			save_deck["cards"][key_with_name] = count
		save_decks.append(save_deck)
	
	var save_data = {
		"version": 1,
		"decks": save_decks
	}
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		print("[CpuDeckData] ERROR: セーブファイルを開けませんでした")
		return false
	
	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("[CpuDeckData] セーブ完了: ", SAVE_FILE_PATH)
	return true

## カードIDから名前を取得
func _get_card_name(card_id: int) -> String:
	var card = CardLoader.get_card_by_id(card_id)
	if card.is_empty():
		return "不明"
	return card.get("name", "不明")

func load_from_file():
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("[CpuDeckData] セーブファイルなし、新規作成")
		_initialize_empty_decks()
		return
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		print("[CpuDeckData] ERROR: セーブファイルを開けませんでした")
		_initialize_empty_decks()
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		print("[CpuDeckData] ERROR: JSONパースエラー")
		_initialize_empty_decks()
		return
	
	var data = json.data
	decks = data.get("decks", [])
	
	# キーを整数に変換
	_convert_card_keys()
	
	# デッキ数が足りない場合は追加
	while decks.size() < MAX_DECKS:
		decks.append(_create_empty_deck(decks.size()))
	
	print("[CpuDeckData] ロード完了: %d デッキ" % decks.size())

func _initialize_empty_decks():
	decks.clear()
	for i in range(MAX_DECKS):
		decks.append(_create_empty_deck(i))
	save_to_file()

func _create_empty_deck(index: int) -> Dictionary:
	return {
		"name": "CPUデッキ%d" % (index + 1),
		"cards": {}
	}

func _convert_card_keys():
	"""JSONから読み込んだ文字列キーを整数に変換
	   "414 // カード名" 形式のキーからIDを抽出"""
	for deck in decks:
		if deck.has("cards"):
			var new_cards = {}
			for key in deck["cards"].keys():
				var int_key: int
				if typeof(key) == TYPE_STRING:
					# "414 // カード名" 形式の場合、"//" より前の数字を取得
					if " // " in key:
						int_key = int(key.split(" // ")[0])
					else:
						int_key = int(key)
				else:
					int_key = key
				var value = deck["cards"][key]
				var int_value = int(value) if typeof(value) == TYPE_FLOAT else value
				new_cards[int_key] = int_value
			deck["cards"] = new_cards

# ==========================================
# デッキ操作
# ==========================================

func get_deck(index: int) -> Dictionary:
	if index < 0 or index >= decks.size():
		return {"name": "", "cards": {}}
	return decks[index]

func get_current_deck() -> Dictionary:
	return get_deck(selected_deck_index)

func save_deck(index: int, cards: Dictionary):
	if index < 0 or index >= decks.size():
		print("[CpuDeckData] ERROR: 不正なデッキ番号")
		return
	
	decks[index]["cards"] = cards.duplicate()
	save_to_file()
	print("[CpuDeckData] デッキ%d を保存" % (index + 1))

func rename_deck(index: int, new_name: String):
	if index < 0 or index >= decks.size():
		return
	
	decks[index]["name"] = new_name
	save_to_file()
	print("[CpuDeckData] デッキ%d を「%s」にリネーム" % [index + 1, new_name])

func reset_deck(index: int):
	if index < 0 or index >= decks.size():
		return
	
	decks[index]["cards"] = {}
	save_to_file()
	print("[CpuDeckData] デッキ%d をリセット" % (index + 1))

func get_deck_card_count(index: int) -> int:
	if index < 0 or index >= decks.size():
		return 0
	
	var total = 0
	for count in decks[index]["cards"].values():
		total += count
	return total

# ==========================================
# カード枚数（全カード4枚ずつ）
# ==========================================

func get_card_count(_card_id: int) -> int:
	# CPUデッキは全カード4枚ずつ使える
	return MAX_COPIES_PER_CARD

# ==========================================
# ステージローダー用
# ==========================================

## デッキIDからカードリストを取得（ステージで使用）
## deck_id: "cpu_deck_1" ～ "cpu_deck_50" の形式
func get_deck_cards_by_id(deck_id: String) -> Array:
	# "cpu_deck_XX" からインデックスを抽出
	if not deck_id.begins_with("cpu_deck_"):
		return []
	
	var index_str = deck_id.substr(9)  # "cpu_deck_" の後ろ
	var index = int(index_str) - 1  # 1始まり → 0始まり
	
	if index < 0 or index >= decks.size():
		return []
	
	var deck = decks[index]
	var cards = deck.get("cards", {})
	
	# {card_id: count} → [{id: card_id, count: count}, ...] に変換
	var result = []
	for card_id in cards.keys():
		var count = cards[card_id]
		if count > 0:
			result.append({"id": card_id, "count": count})
	
	return result

## デッキIDが有効かチェック
func is_valid_deck_id(deck_id: String) -> bool:
	if not deck_id.begins_with("cpu_deck_"):
		return false
	
	var index_str = deck_id.substr(9)
	var index = int(index_str) - 1
	
	return index >= 0 and index < decks.size()

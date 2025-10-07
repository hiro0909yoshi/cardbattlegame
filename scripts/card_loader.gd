extends Node

var all_cards = []

func _ready():
	print("=== CardLoader起動 ===")
	load_all_cards()
	print("=== 読み込み終了 ===")

func load_all_cards():
	print("ファイル読み込み開始")
	var files = [
		"res://data/neutral.json",
		"res://data/fire.json",
		"res://data/water.json",
		"res://data/earth.json",
		"res://data/wind.json",
		"res://data/item.json",
		"res://data/spell_1.json",
		"res://data/spell_2.json"
	]
	
	for file_path in files:
		print("読み込み中: ", file_path)
		var cards = load_json_file(file_path)
		print("  取得枚数: ", cards.size())
		if cards.size() > 0:
			all_cards.append_array(cards)
	
	print("カード読み込み完了: ", all_cards.size(), "枚")
	
func load_json_file(path: String) -> Array:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("ファイルが開けません: ", path)
		return []
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("JSONパースエラー: ", path)
		return []
	
	var data = json.data
	if data.has("cards"):
		return data.cards
	return []

func get_card_by_id(card_id: int) -> Dictionary:
	for card in all_cards:
		if card.id == card_id:
			return card
	return {}

func get_cards_by_element(element: String) -> Array:
	var result = []
	for card in all_cards:
		if card.has("element") and card.element == element:
			result.append(card)
	return result

func get_cards_by_type(card_type: String) -> Array:
	var result = []
	for card in all_cards:
		if card.type == card_type:
			result.append(card)
	return result

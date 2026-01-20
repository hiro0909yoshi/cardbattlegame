extends Node

var all_cards = []
var mystic_arts_data = []  # 秘術専用データ（カードではない）

func _ready():
	print("=== CardLoader起動 ===")
	load_all_cards()
	load_mystic_arts_data()
	print("=== 読み込み終了 ===")

func load_all_cards():
	print("ファイル読み込み開始")
	var files = [
		"res://data/neutral_1.json",
		"res://data/neutral_2.json",
		"res://data/fire_1.json",
		"res://data/fire_2.json",
		"res://data/water_1.json",
		"res://data/water_2.json",
		"res://data/earth_1.json",
		"res://data/earth_2.json",
		"res://data/wind_1.json",
		"res://data/wind_2.json",
		"res://data/item.json",
		"res://data/spell_1.json",
		"res://data/spell_2.json"
		# spell_mystic.jsonはミスティックアーツ専用（all_cardsには含めない）
	]
	
	for file_path in files:
		print("読み込み中: ", file_path)
		var cards = load_json_file(file_path)
		print("  取得枚数: ", cards.size())
		if cards.size() > 0:
			all_cards.append_array(cards)
	
	print("カード読み込み完了: ", all_cards.size(), "枚")
	
	# 🔍 属性別カード数をデバッグ出力
	var element_counts = {
		"fire": 0,
		"water": 0,
		"earth": 0,
		"wind": 0,
		"neutral": 0,
		"item": 0,
		"spell": 0
	}
	
	for card in all_cards:
		if card.has("type") and card.type == "item":
			element_counts["item"] += 1
		elif card.has("type") and card.type == "spell":
			element_counts["spell"] += 1
		elif card.has("element"):
			var elem = card.element
			if element_counts.has(elem):
				element_counts[elem] += 1
	
	print("📊 属性別カード数:")
	print("  🔥 火: ", element_counts["fire"])
	print("  💧 水: ", element_counts["water"])
	print("  🪨 地: ", element_counts["earth"])
	print("  🌪️ 風: ", element_counts["wind"])
	print("  ⚪ 無: ", element_counts["neutral"])
	print("  📦 アイテム: ", element_counts["item"])
	print("  📜 スペル: ", element_counts["spell"])

## 秘術専用データを読み込む（カードではない）
func load_mystic_arts_data():
	var path = "res://data/spell_mystic.json"
	print("秘術データ読み込み中: ", path)
	mystic_arts_data = load_json_file(path)
	print("秘術データ読み込み完了: ", mystic_arts_data.size(), "件")
	
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
		var cards = data.cards
		# ⚠️ ここで全カードのIDと数値データをint型に変換
		for card in cards:
			if card.has("id"):
				card.id = int(card.id)
			# costのmpもintに変換
			if card.has("cost") and card.cost.has("mp"):
				card.cost.mp = int(card.cost.mp)
			# apとhpもintに変換
			if card.has("ap"):
				card.ap = int(card.ap)
			if card.has("hp"):
				card.hp = int(card.hp)
		return cards
	return []

func get_card_by_id(card_id: int) -> Dictionary:
	# 通常カードから検索
	for card in all_cards:
		# IDを整数に変換して比較（念のため）
		var check_id = int(card.id) if typeof(card.id) != TYPE_INT else card.id
		if check_id == card_id:
			# マスターデータを変更しないよう、常にコピーを返す
			return card.duplicate(true)
	
	# 秘術データからも検索（spell_id参照用）
	for data in mystic_arts_data:
		var check_id = int(data.id) if typeof(data.id) != TYPE_INT else data.id
		if check_id == card_id:
			return data.duplicate(true)
	
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

## 全クリーチャーカードを取得（バルダンダースのランダム変身用）
func get_all_creatures() -> Array:
	return get_cards_by_type("creature")

## アイテムをIDで取得
func get_item_by_id(item_id: int) -> Dictionary:
	for card in all_cards:
		if card.get("type") == "item":
			var check_id = int(card.id) if typeof(card.id) != TYPE_INT else card.id
			if check_id == item_id:
				return card
	return {}

## スペルをIDで取得
func get_spell_by_id(spell_id: int) -> Dictionary:
	for card in all_cards:
		if card.get("type") == "spell":
			var check_id = int(card.id) if typeof(card.id) != TYPE_INT else card.id
			if check_id == spell_id:
				return card
	return {}

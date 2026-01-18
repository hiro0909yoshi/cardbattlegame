## ユーザーカードデータベース管理
## カード所持数・レベル・図鑑フラグをSQLiteで管理
extends Node

var db = null
var db_path: String = "user://user_cards.db"

func _ready():
	_initialize_database()
	
	# 開発用：全カード所持状態にする場合はコメント解除
	#_setup_dev_mode()

## 開発用：全カード4枚ずつ登録
func _setup_dev_mode():
	var cards = get_all_cards()
	if cards.size() == 0:
		print("[UserCardDB] 開発モード：全カードを登録します")
		import_all_cards_from_json()

## データベース初期化
func _initialize_database() -> bool:
	db = SQLite.new()
	db.path = db_path
	
	if not db.open_db():
		push_error("[UserCardDB] データベースを開けませんでした: " + db_path)
		return false
	
	# テーブル作成
	var create_table_query = """
		CREATE TABLE IF NOT EXISTS user_cards (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id TEXT NOT NULL DEFAULT 'player1',
			card_id INTEGER NOT NULL,
			count INTEGER DEFAULT 0,
			level INTEGER DEFAULT 1,
			obtained INTEGER DEFAULT 0,
			UNIQUE(user_id, card_id)
		);
	"""
	
	if not db.query(create_table_query):
		push_error("[UserCardDB] テーブル作成に失敗しました")
		return false
	
	print("[UserCardDB] データベース初期化完了: " + db_path)
	return true

## DBをフラッシュ（変更を確実に保存）
func flush():
	if db:
		db.close_db()
		db.open_db()

## カード情報を取得
func get_card(card_id: int, user_id: String = "player1") -> Dictionary:
	if not db:
		return {}
	
	db.query_with_bindings(
		"SELECT * FROM user_cards WHERE user_id = ? AND card_id = ?",
		[user_id, card_id]
	)
	
	if db.query_result.size() > 0:
		return db.query_result[0]
	return {}

## カード所持数を取得
func get_card_count(card_id: int, user_id: String = "player1") -> int:
	var card = get_card(card_id, user_id)
	return card.get("count", 0)

## カードレベルを取得
func get_card_level(card_id: int, user_id: String = "player1") -> int:
	var card = get_card(card_id, user_id)
	return card.get("level", 1)

## カードが図鑑に登録済みか
func is_card_obtained(card_id: int, user_id: String = "player1") -> bool:
	var card = get_card(card_id, user_id)
	return card.get("obtained", 0) == 1

## カードを追加（入手）
func add_card(card_id: int, amount: int = 1, user_id: String = "player1") -> bool:
	if not db:
		print("[UserCardDB] add_card: dbがnull")
		return false
	
	var existing = get_card(card_id, user_id)
	
	if existing.is_empty():
		# 新規登録
		var result = db.query_with_bindings(
			"INSERT INTO user_cards (user_id, card_id, count, level, obtained) VALUES (?, ?, ?, 1, 1)",
			[user_id, card_id, amount]
		)
		if not result:
			print("[UserCardDB] INSERT失敗: %s" % db.error_message)
		return result
	else:
		# 既存カードの所持数を増加
		var new_count = existing.get("count", 0) + amount
		var result = db.query_with_bindings(
			"UPDATE user_cards SET count = ?, obtained = 1 WHERE user_id = ? AND card_id = ?",
			[new_count, user_id, card_id]
		)
		if not result:
			print("[UserCardDB] UPDATE失敗: %s" % db.error_message)
		return result

## カードを減らす（売却等）
func remove_card(card_id: int, amount: int = 1, user_id: String = "player1") -> bool:
	if not db:
		return false
	
	var existing = get_card(card_id, user_id)
	if existing.is_empty():
		return false
	
	var current_count = existing.get("count", 0)
	var new_count = max(0, current_count - amount)
	
	# countは0になってもレコードは残す（level, obtainedを維持）
	return db.query_with_bindings(
		"UPDATE user_cards SET count = ? WHERE user_id = ? AND card_id = ?",
		[new_count, user_id, card_id]
	)

## カードを売却（ゴールド取得は別処理）
func sell_card(card_id: int, amount: int = 1, user_id: String = "player1") -> bool:
	return remove_card(card_id, amount, user_id)

## カードレベルを設定
func set_card_level(card_id: int, level: int, user_id: String = "player1") -> bool:
	if not db:
		return false
	
	var existing = get_card(card_id, user_id)
	if existing.is_empty():
		# レコードがなければ作成（count=0, obtained=0）
		return db.query_with_bindings(
			"INSERT INTO user_cards (user_id, card_id, count, level, obtained) VALUES (?, ?, 0, ?, 0)",
			[user_id, card_id, level]
		)
	else:
		return db.query_with_bindings(
			"UPDATE user_cards SET level = ? WHERE user_id = ? AND card_id = ?",
			[level, user_id, card_id]
		)

## 全所持カードを取得
func get_all_cards(user_id: String = "player1") -> Array:
	if not db:
		return []
	
	db.query_with_bindings(
		"SELECT * FROM user_cards WHERE user_id = ? AND count > 0",
		[user_id]
	)
	
	return db.query_result

## 図鑑登録済みカードを全取得
func get_all_obtained_cards(user_id: String = "player1") -> Array:
	if not db:
		return []
	
	db.query_with_bindings(
		"SELECT * FROM user_cards WHERE user_id = ? AND obtained = 1",
		[user_id]
	)
	
	return db.query_result

## JSONのcollectionからDBにインポート
func import_from_collection(collection: Dictionary, user_id: String = "player1") -> bool:
	if not db:
		return false
	
	var success_count = 0
	for card_id_key in collection.keys():
		var card_id = int(card_id_key)
		var count = int(collection[card_id_key])
		
		if add_card(card_id, count, user_id):
			success_count += 1
	
	print("[UserCardDB] インポート完了: %d件" % success_count)
	return true

## DBからDictionary形式でエクスポート（collection互換）
func export_to_collection(user_id: String = "player1") -> Dictionary:
	var result = {}
	var cards = get_all_cards(user_id)
	
	for card in cards:
		result[card.card_id] = card.count
	
	return result

## データベースを閉じる
func close():
	if db:
		db.close_db()
		db = null

func _exit_tree():
	close()

## 全カードをDBにインポート（初回セットアップ用）
func import_all_cards_from_json():
	print("[UserCardDB] === 全カードインポート開始 ===")
	
	var json_files = [
		"res://data/fire_1.json",
		"res://data/fire_2.json",
		"res://data/water_1.json",
		"res://data/water_2.json",
		"res://data/earth_1.json",
		"res://data/earth_2.json",
		"res://data/wind_1.json",
		"res://data/wind_2.json",
		"res://data/neutral_1.json",
		"res://data/neutral_2.json",
		"res://data/item.json",
		"res://data/spell_1.json",
		"res://data/spell_2.json",
		"res://data/spell_mystic.json"
	]
	
	var total_count = 0
	
	for file_path in json_files:
		var count = _import_from_json_file(file_path)
		total_count += count
	
	print("[UserCardDB] === 全カードインポート完了: %d種類 ===" % total_count)
	
	# 登録結果サマリー
	var all_cards = get_all_cards()
	print("[UserCardDB] DB登録済みカード: %d種類" % all_cards.size())

## JSONファイルからカードをインポート
func _import_from_json_file(file_path: String) -> int:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[UserCardDB] %s を開けませんでした" % file_path)
		return 0
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		print("[UserCardDB] %s パースエラー" % file_path)
		return 0
	
	var data = json.data
	var cards = data.get("cards", [])
	
	var success_count = 0
	for card in cards:
		var card_id = card.get("id", 0)
		if card_id > 0 and add_card(card_id, 4):
			success_count += 1
	
	print("  %s: %d種類登録" % [file_path.get_file(), success_count])
	return success_count

## DBをリセット（テスト用）
func reset_database():
	if not db:
		return
	db.query("DELETE FROM user_cards")
	print("[UserCardDB] データベースをリセットしました")

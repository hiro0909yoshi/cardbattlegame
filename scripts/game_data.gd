extends Node

# グローバルデータ管理 - 修正版

const SAVE_FILE_PATH = "user://player_save.json"

# 選択中のブック番号（0〜5、課金で拡張可能）
var selected_deck_index = 0

# 選択中のステージID（クエストモード用）
var selected_stage_id = "stage_1_1"

# プレイヤーデータの構造
var player_data = {
	# === 基本情報 ===
	"user_id": "player1",
	"profile": {
		"name": "プレイヤー",
		"level": 1,
		"exp": 0,
		"gold": 100000,
		"created_at": "",
		"last_played": ""
	},
	
	# === カード関連 ===
	# collection → UserCardDB（SQLite）に移行済み
	# unlocks.cards → UserCardDB.obtained に移行済み
	"decks": [],           # デッキ構成（最大6個、課金で増加可能）
	"max_decks": 6,
	
	# === 進行状況 ===
	"story_progress": {
		"current_stage": 1,           # 現在挑戦中のステージ
		"cleared_stages": [],         # クリア済みステージID配列
		"stage_stars": {}             # {stage_id: 星数(1-3)}
	},
	
	# === アンロック情報 ===
	"unlocks": {
		"stages": [1],    # アンロック済みステージ（最初は1だけ）
		"modes": ["story"] # アンロック済みモード
	},
	
	# === 統計情報 ===
	"stats": {
		"total_battles": 0,
		"wins": 0,
		"losses": 0,
		"play_time_seconds": 0,
		"story_cleared": 0,      # クリアしたストーリー数
		"gacha_count": 0,        # ガチャを引いた回数
		"cards_obtained": 0      # 入手したカード総数
	},
	
	# === 設定 ===
	"settings": {
		"master_volume": 1.0,
		"bgm_volume": 0.8,
		"se_volume": 1.0,
		"language": "ja",
		"auto_save": true
	}
}

func _ready():
	load_from_file()
	
	# デッキ検証（所持していないカードを削除）
	call_deferred("_validate_decks") 

# ==========================================
# セーブ/ロード
# ==========================================

func save_to_file() -> bool:
	# 最終プレイ時刻を更新
	player_data.profile.last_played = Time.get_datetime_string_from_system()
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		print("ERROR: セーブファイルを開けませんでした")
		return false
	
	var json_string = JSON.stringify(player_data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("✅ セーブ完了: ", SAVE_FILE_PATH)
	return true

const DEFAULT_SAVE_PATH = "res://data/default_save.json"

func load_from_file():
	# まずuser://を試す
	var loaded_from_user = false
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				var data = json.data
				# デッキが有効かチェック
				if _has_valid_deck(data):
					player_data = data
					loaded_from_user = true
				else:
					print("[GameData] user://のデッキが空、default_save.jsonを試行")
	
	# user://がない or デッキが空の場合、default_save.jsonを試す
	if not loaded_from_user:
		var file = FileAccess.open(DEFAULT_SAVE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				player_data = json.data
				print("[GameData] default_save.jsonから読み込み成功")
			else:
				print("[GameData] default_save.json パースエラー、新規作成")
				_initialize_new_save()
				return
		else:
			print("[GameData] default_save.json 開けず、新規作成")
			_initialize_new_save()
			return
	
	# 🔧 修正: JSONの文字列キーを整数に変換
	_convert_collection_keys()
	
	_validate_save_data()  # データの整合性チェック
	print("✅ ロード完了: Lv.", player_data.profile.level, " / ゴールド: ", player_data.profile.gold)

func _initialize_new_save():
	# 作成日時を設定
	player_data.profile.created_at = Time.get_datetime_string_from_system()
	player_data.profile.last_played = player_data.profile.created_at
	
	# 6個の空ブックを作成
	player_data.decks.clear()
	for i in range(player_data.max_decks):
		player_data.decks.append({
			"name": "ブック" + str(i + 1),
			"cards": {}
		})
	
	# テスト用データ
	_initialize_test_data()

func _initialize_test_data():
	await get_tree().process_frame
	
	print("\n=== テストデータ初期化 ===")
	
	# DBに全カードを登録
	if UserCardDB:
		UserCardDB.reset_database()
		UserCardDB.import_all_cards_from_json()
		print("✅ テストデータ: DBに全カード登録完了")
	else:
		print("❌ UserCardDBが見つかりません")
	
	print("=========================\n")

## デッキに有効なカードがあるかチェック
func _has_valid_deck(data: Dictionary) -> bool:
	if not data.has("decks"):
		return false
	var decks = data.get("decks", [])
	for deck in decks:
		var cards = deck.get("cards", {})
		if not cards.is_empty():
			print("[GameData] 有効なデッキ発見: %d種類のカード" % cards.size())
			return true
	return false

func _convert_collection_keys():
	"""JSONから読み込んだ文字列キーを整数に、値も整数に変換"""
	# decksのcardsのキーと値も変換
	for deck in player_data.decks:
		if deck.has("cards"):
			var new_cards = {}
			for key in deck["cards"].keys():
				var int_key = int(key) if typeof(key) == TYPE_STRING else key
				# ⚠️ 値もintに変換
				var value = deck["cards"][key]
				var int_value = int(value) if typeof(value) == TYPE_FLOAT else value
				new_cards[int_key] = int_value
			deck["cards"] = new_cards

	# profileのgold, level, expも整数に変換
	if player_data.has("profile"):
		if player_data.profile.has("gold"):
			player_data.profile.gold = int(player_data.profile.gold)
		if player_data.profile.has("level"):
			player_data.profile.level = int(player_data.profile.level)
		if player_data.profile.has("exp"):
			player_data.profile.exp = int(player_data.profile.exp)

func _validate_save_data():
	# 古いバージョンとの互換性チェック
	if not player_data.has("max_decks"):
		player_data["max_decks"] = 6
	if not player_data.has("story_progress"):
		player_data["story_progress"] = {
			"current_stage": 1,
			"cleared_stages": [],
			"stage_stars": {}
		}
	if not player_data.has("stats"):
		player_data["stats"] = {
			"total_battles": 0,
			"wins": 0,
			"losses": 0,
			"play_time_seconds": 0,
			"story_cleared": 0,
			"gacha_count": 0,
			"cards_obtained": 0
		}

# ==========================================
# デッキ操作
# ==========================================

## デッキ検証：所持していないカードを削除
func _validate_decks():
	if not UserCardDB:
		return
	
	var modified = false
	
	for deck_index in range(player_data.decks.size()):
		var deck = player_data.decks[deck_index]
		var cards = deck.get("cards", {})
		var cards_to_remove = []
		
		for card_id in cards.keys():
			var owned = UserCardDB.get_card_count(card_id)
			var in_deck = cards[card_id]
			
			if owned == 0:
				# 所持0枚 → デッキから完全削除
				cards_to_remove.append(card_id)
				print("[GameData] デッキ%d: カードID %d を削除（所持0枚）" % [deck_index + 1, card_id])
				modified = true
			elif in_deck > owned:
				# デッキ枚数 > 所持枚数 → 所持数に合わせる
				cards[card_id] = owned
				print("[GameData] デッキ%d: カードID %d を%d枚に調整（所持%d枚）" % [deck_index + 1, card_id, owned, owned])
				modified = true
		
		for card_id in cards_to_remove:
			cards.erase(card_id)
	
	if modified:
		save_to_file()
		push_warning("[GameData] デッキ検証完了：修正あり")

## カードが全デッキで使用されている合計枚数を取得
func get_card_usage_in_decks(card_id: int) -> int:
	var total = 0
	for deck in player_data.decks:
		var cards = deck.get("cards", {})
		total += cards.get(card_id, 0)
	return total

func get_current_deck() -> Dictionary:
	if selected_deck_index < 0 or selected_deck_index >= player_data.decks.size():
		return {"name": "", "cards": {}}
	return player_data.decks[selected_deck_index]

func save_deck(deck_index: int, cards: Dictionary):
	if deck_index < 0 or deck_index >= player_data.decks.size():
		print("ERROR: 不正なブック番号")
		return
	
	player_data.decks[deck_index]["cards"] = cards.duplicate()
	save_to_file()
	print("✅ ブック", deck_index + 1, "を保存")

# ==========================================
# カードコレクション操作（DB連携）
# ==========================================

func add_card(card_id: int, count: int = 1):
	# DBに追加
	UserCardDB.add_card(card_id, count)
	
	# 統計更新
	player_data.stats.cards_obtained += count
	
	if player_data.settings.auto_save:
		save_to_file()
	
	print("✅ カード入手: ID=", card_id, " +", count, "枚")

func remove_card(card_id: int, count: int = 1):
	# DBから削除
	UserCardDB.remove_card(card_id, count)
	
	if player_data.settings.auto_save:
		save_to_file()

func get_card_count(card_id: int) -> int:
	# DBから取得
	return UserCardDB.get_card_count(card_id)

## カードレベルを取得（DB連携）
func get_card_level(card_id: int) -> int:
	return UserCardDB.get_card_level(card_id)

## カードが図鑑に登録済みか（DB連携）
func is_card_obtained(card_id: int) -> bool:
	return UserCardDB.is_card_obtained(card_id)

## 所持カード一覧を取得（DB連携）
func get_all_owned_cards() -> Array:
	return UserCardDB.get_all_cards()

# ==========================================
# 進行状況管理
# ==========================================

func unlock_stage(stage_id: int):
	if not player_data.unlocks.stages.has(stage_id):
		player_data.unlocks.stages.append(stage_id)
		save_to_file()
		print("✅ ステージ", stage_id, "をアンロック")

func clear_stage(stage_id: int, stars: int = 1):
	if not player_data.story_progress.cleared_stages.has(stage_id):
		player_data.story_progress.cleared_stages.append(stage_id)
		player_data.stats.story_cleared += 1
	
	# 星評価を更新（より高い評価のみ）
	var current_stars = player_data.story_progress.stage_stars.get(stage_id, 0)
	if stars > current_stars:
		player_data.story_progress.stage_stars[stage_id] = stars
	
	# 次のステージをアンロック
	unlock_stage(stage_id + 1)
	
	save_to_file()
	print("✅ ステージ", stage_id, "クリア (★", stars, ")")

func is_stage_unlocked(stage_id: int) -> bool:
	return player_data.unlocks.stages.has(stage_id)

func is_stage_cleared(stage_id: int) -> bool:
	return player_data.story_progress.cleared_stages.has(stage_id)

# ==========================================
# プレイヤーステータス
# ==========================================

func add_exp(amount: int):
	player_data.profile.exp += amount
	
	# レベルアップチェック（100EXPごとにレベルアップの例）
	var level_up_exp = player_data.profile.level * 100
	if player_data.profile.exp >= level_up_exp:
		player_data.profile.exp -= level_up_exp
		player_data.profile.level += 1
		print("🎉 レベルアップ！ Lv.", player_data.profile.level)
	
	save_to_file()

func add_gold(amount: int):
	player_data.profile.gold += amount
	save_to_file()
	print("💰 ゴールド +", amount, " (合計: ", player_data.profile.gold, ")")

func spend_gold(amount: int) -> bool:
	if player_data.profile.gold < amount:
		print("❌ ゴールド不足")
		return false
	
	player_data.profile.gold -= amount
	save_to_file()
	print("💸 ゴールド -", amount, " (残り: ", player_data.profile.gold, ")")
	return true

# ==========================================
# 統計情報
# ==========================================

func record_battle_result(won: bool):
	player_data.stats.total_battles += 1
	if won:
		player_data.stats.wins += 1
	else:
		player_data.stats.losses += 1
	
	save_to_file()

func add_play_time(seconds: int):
	player_data.stats.play_time_seconds += seconds
	save_to_file()

func record_gacha():
	player_data.stats.gacha_count += 1

# ==========================================
# 課金機能（将来実装）
# ==========================================

func unlock_deck_slot() -> bool:
	if player_data.decks.size() >= 20:
		print("❌ デッキスロット上限")
		return false
	
	var new_index = player_data.decks.size() + 1
	player_data.decks.append({
		"name": "ブック" + str(new_index),
		"cards": {}
	})
	player_data.max_decks += 1
	
	save_to_file()
	print("✅ 新しいブックスロット追加")
	return true

# ==========================================
# デバッグ用
# ==========================================

func reset_save():
	_initialize_new_save()
	print("✅ セーブデータリセット")

func print_save_info():
	print("\n========== セーブ情報 ==========")
	print("プレイヤー: ", player_data.profile.name)
	print("レベル: ", player_data.profile.level, " (EXP: ", player_data.profile.exp, ")")
	print("ゴールド: ", player_data.profile.gold)
	print("所持カード種類: ", UserCardDB.get_all_cards().size())
	print("デッキ数: ", player_data.decks.size())
	print("ストーリー進行: ", player_data.story_progress.current_stage)
	print("勝率: ", _calculate_win_rate(), "%")
	print("プレイ時間: ", _format_play_time())
	print("================================\n")

func _calculate_win_rate() -> float:
	if player_data.stats.total_battles == 0:
		return 0.0
	return (float(player_data.stats.wins) / player_data.stats.total_battles) * 100.0

func _format_play_time() -> String:
	var seconds = player_data.stats.play_time_seconds
	var hours = int(seconds / 3600.0)
	var minutes = int((seconds % 3600) / 60.0)
	return str(hours) + "時間" + str(minutes) + "分"

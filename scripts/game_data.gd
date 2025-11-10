extends Node

# グローバルデータ管理 - 修正版

const SAVE_FILE_PATH = "user://player_save.json"

# 選択中のブック番号（0〜5、課金で拡張可能）
var selected_deck_index = 0

# プレイヤーデータの構造
var player_data = {
	# === 基本情報 ===
	"user_id": "player1",
	"profile": {
		"name": "プレイヤー",
		"level": 1,
		"exp": 0,
		"gold": 1000,
		"created_at": "",
		"last_played": ""
	},
	
	# === カード関連 ===
	"collection": {},      # 所持カード {card_id: count}
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
		"cards": [],      # アンロック済みカードID配列
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

func load_from_file():
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("セーブファイルがありません。新規作成します。")
		_initialize_new_save()
		return
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		print("ERROR: セーブファイルを読み込めませんでした")
		_initialize_new_save()
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("ERROR: JSONパースエラー")
		_initialize_new_save()
		return
	
	player_data = json.data
	
	# 🔧 修正: JSONの文字列キーを整数に変換
	_convert_collection_keys()
	
	_validate_save_data()  # データの整合性チェック
	print("✅ ロード完了: Lv.", player_data.profile.level, " / ゴールド: ", player_data.profile.gold)
	print("所持カード種類: ", player_data.collection.size())

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
	
	print("
=== テストデータ初期化 ===")
	print("CardLoaderは存在する？: ", CardLoader != null)
	
	if CardLoader:
		print("CardLoader.all_cardsのサイズ: ", CardLoader.all_cards.size())
		
		if CardLoader.all_cards.size() > 0:
			# 🎯 開発用：全カードを4枚ずつ所持
			var test_card_count = 0
			var element_counts = {"fire": 0, "water": 0, "earth": 0, "wind": 0, "neutral": 0}
			var type_counts = {"item": 0, "spell": 0, "creature": 0}
			
			for card in CardLoader.all_cards:
				player_data.collection[card.id] = 4  # 各4枚ずつ
				if not player_data.unlocks.cards.has(card.id):
					player_data.unlocks.cards.append(card.id)
				test_card_count += 1
				
				# 統計用カウント
				if card.type == "creature" and card.has("element"):
					var elem = card.element
					if element_counts.has(elem):
						element_counts[elem] += 1
					type_counts["creature"] += 1
				elif card.type == "item":
					type_counts["item"] += 1
				elif card.type == "spell":
					type_counts["spell"] += 1
			
			print("✅ テストデータ: ", test_card_count, "種類のカードを追加")
			print("  🔥 火: ", element_counts["fire"])
			print("  💧 水: ", element_counts["water"])
			print("  🪨 地: ", element_counts["earth"])
			print("  🌪️ 風: ", element_counts["wind"])
			print("  ⚪ 無: ", element_counts["neutral"])
			print("  🎭 クリーチャー合計: ", type_counts["creature"])
			print("  📦 アイテム: ", type_counts["item"])
			print("  📜 スペル: ", type_counts["spell"])
			print("collection登録完了: ", player_data.collection.size(), "種類")
			
			# 🔧 修正: ここでセーブ！
			save_to_file()
		else:
			print("❌ CardLoader.all_cardsが空です")
	else:
		print("❌ CardLoaderが見つかりません")
	print("=========================
")

func _convert_collection_keys():
	"""JSONから読み込んだ文字列キーを整数に、値も整数に変換"""
	# collectionのキーと値を変換
	var new_collection = {}
	for key in player_data.collection.keys():
		var int_key = int(key) if typeof(key) == TYPE_STRING else key
		# ⚠️ 値もintに変換
		var value = player_data.collection[key]
		var int_value = int(value) if typeof(value) == TYPE_FLOAT else value
		new_collection[int_key] = int_value
	player_data.collection = new_collection
	
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
	
	# unlocksのcardsも整数に変換
	if player_data.has("unlocks") and player_data.unlocks.has("cards"):
		var new_unlocks = []
		for card_id in player_data.unlocks.cards:
			var int_id = int(card_id) if typeof(card_id) == TYPE_STRING else card_id
			new_unlocks.append(int_id)
		player_data.unlocks.cards = new_unlocks
	
	# profileのgold, level, expも整数に変換
	if player_data.has("profile"):
		if player_data.profile.has("gold"):
			player_data.profile.gold = int(player_data.profile.gold)
		if player_data.profile.has("level"):
			player_data.profile.level = int(player_data.profile.level)
		if player_data.profile.has("exp"):
			player_data.profile.exp = int(player_data.profile.exp)
	
	print("✅ 型変換完了")

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
# カードコレクション操作
# ==========================================

func add_card(card_id: int, count: int = 1):
	if not player_data.collection.has(card_id):
		player_data.collection[card_id] = 0
	
	player_data.collection[card_id] += count
	player_data.stats.cards_obtained += count
	
	# 初入手ならアンロックリストに追加
	if not player_data.unlocks.cards.has(card_id):
		player_data.unlocks.cards.append(card_id)
	
	if player_data.settings.auto_save:
		save_to_file()
	
	print("✅ カード入手: ID=", card_id, " +", count, "枚")

func remove_card(card_id: int, count: int = 1):
	if not player_data.collection.has(card_id):
		return
	
	player_data.collection[card_id] -= count
	if player_data.collection[card_id] <= 0:
		player_data.collection.erase(card_id)
	
	if player_data.settings.auto_save:
		save_to_file()

func get_card_count(card_id: int) -> int:
	return player_data.collection.get(card_id, 0)

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
	print("所持カード種類: ", player_data.collection.size())
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

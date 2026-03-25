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
		"stone": 0,
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
	
	# === スタミナ ===
	"stamina": {
		"current": 50,
		"max": 50,
		"updated_at": ""
	},

	# === インベントリ（倉庫アイテム） ===
	"inventory": {},  # {アイテムID(int): 所持数(int)}

	# === ログインボーナス ===
	"login_bonus": {
		"claimed_campaigns": [],      # 受取済みキャンペーンID
		"last_daily_date": "",        # 最後にデイリーボーナスを受け取った日付
		"login_streak": 0,            # 連続ログイン日数
		"last_login_date": "",        # 最後のログイン日付（連続判定用）
		"total_login_days": 0         # 累計ログイン日数
	},

	# === キャラクター ===
	"character": {
		"selected_id": "hero",           # 現在選択中のキャラクターID
		"unlocked": ["hero"]             # 解放済みキャラクターIDリスト
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

# プレイアブルキャラクターマスターデータ
const PLAYABLE_CHARACTERS: Dictionary = {
	"hero": {
		"name": "ヒーロー",
		"model_path": "res://scenes/Characters/Hero.tscn",
		"portrait_path": "",
	},
	"necromancer": {
		"name": "マリオン",
		"model_path": "res://scenes/Characters/Necromancer.tscn",
		"portrait_path": "res://assets/images/characters/marion.png",
	},
	"goblin": {
		"name": "ゴブリン",
		"model_path": "res://scenes/Characters/Goblin.tscn",
		"portrait_path": "",
	},
	"fighter": {
		"name": "ファイター",
		"model_path": "res://scenes/Characters/Fighter.tscn",
		"portrait_path": "",
	},
	"thief": {
		"name": "シーフ",
		"model_path": "res://scenes/Characters/Thief.tscn",
		"portrait_path": "",
	},
	"clown": {
		"name": "クラウン",
		"model_path": "res://scenes/Characters/Clown.tscn",
		"portrait_path": "",
	},
	"undead_monk": {
		"name": "アンデッドモンク",
		"model_path": "res://scenes/Characters/UndeadMonk.tscn",
		"portrait_path": "",
	},
	"old_sage": {
		"name": "オールドセージ",
		"model_path": "res://scenes/Characters/OldSage.tscn",
		"portrait_path": "",
	},
	"witch": {
		"name": "ウィッチ",
		"model_path": "res://scenes/Characters/Witch.tscn",
		"portrait_path": "",
	},
	"elf": {
		"name": "エルフ",
		"model_path": "res://scenes/Characters/Elf.tscn",
		"portrait_path": "",
	},
	"dark_elf": {
		"name": "ダークエルフ",
		"model_path": "res://scenes/Characters/DarkElf.tscn",
		"portrait_path": "",
	},
	"golem": {
		"name": "ゴーレム",
		"model_path": "res://scenes/Characters/Golem.tscn",
		"portrait_path": "",
	},
	"orc": {
		"name": "オーク",
		"model_path": "res://scenes/Characters/Orc.tscn",
		"portrait_path": "",
	},
}


## 選択中キャラクターのデータを取得
func get_selected_character() -> Dictionary:
	var char_id = player_data.character.selected_id
	if PLAYABLE_CHARACTERS.has(char_id):
		return PLAYABLE_CHARACTERS[char_id]
	return PLAYABLE_CHARACTERS["hero"]


## 選択中キャラクターのモデルパスを取得
func get_selected_character_model_path() -> String:
	return get_selected_character().model_path


## 選択中キャラクターのポートレートパスを取得
func get_selected_character_portrait() -> String:
	return get_selected_character().portrait_path


## キャラクターが解放済みか
func is_character_unlocked(char_id: String) -> bool:
	return char_id in player_data.character.unlocked


## キャラクターを解放
func unlock_character(char_id: String) -> void:
	if not is_character_unlocked(char_id):
		player_data.character.unlocked.append(char_id)
		save_to_file()


## キャラクターを選択
func select_character(char_id: String) -> bool:
	if not is_character_unlocked(char_id):
		return false
	player_data.character.selected_id = char_id
	save_to_file()
	return true


func _ready():
	load_from_file()
	
	# デッキ検証（所持していないカードを削除）
	call_deferred("_validate_decks") 

# ==========================================
# セーブ/ロード
# ==========================================

func save_to_file() -> bool:
	# 最終プレイ時刻を更新
	player_data.profile.last_played = Time.get_datetime_string_from_unix_time(GameClock.get_now())
	
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
	player_data.profile.created_at = Time.get_datetime_string_from_unix_time(GameClock.get_now())
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

	# inventoryの値を整数に変換
	if player_data.has("inventory"):
		var new_inv = {}
		for key in player_data.inventory.keys():
			var str_key = str(key)
			new_inv[str_key] = int(player_data.inventory[key])
		player_data.inventory = new_inv

	# profileのgold, level, expも整数に変換
	if player_data.has("profile"):
		if player_data.profile.has("gold"):
			player_data.profile.gold = int(player_data.profile.gold)
		if player_data.profile.has("level"):
			player_data.profile.level = int(player_data.profile.level)
		if player_data.profile.has("exp"):
			player_data.profile.exp = int(player_data.profile.exp)
		if player_data.profile.has("stone"):
			player_data.profile.stone = int(player_data.profile.stone)
		if not player_data.profile.has("stone"):
			player_data.profile["stone"] = 0

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
	if not player_data.has("stamina"):
		player_data["stamina"] = {
			"current": 50,
			"max": 50,
			"updated_at": ""
		}
	if not player_data.has("inventory"):
		player_data["inventory"] = {}
	if not player_data.has("character"):
		player_data["character"] = {
			"selected_id": "hero",
			"unlocked": ["hero"]
		}
	if not player_data.has("login_bonus"):
		player_data["login_bonus"] = {
			"claimed_campaigns": [],
			"last_daily_date": "",
			"login_streak": 0,
			"last_login_date": "",
			"total_login_days": 0
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
		GameLogger.warn("Data", "デッキ検証完了：修正あり（validate_all_decks）")

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
		# レベルアップ時スタミナ全回復（最大値分加算）
		recover_stamina_full()

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


func add_stone(amount: int):
	player_data.profile.stone += amount
	save_to_file()
	print("💎 課金石 +", amount, " (合計: ", player_data.profile.stone, ")")


func spend_stone(amount: int) -> bool:
	if player_data.profile.stone < amount:
		print("❌ 課金石不足")
		return false

	player_data.profile.stone -= amount
	save_to_file()
	print("💎 課金石 -", amount, " (残り: ", player_data.profile.stone, ")")
	return true


func get_stone() -> int:
	return int(player_data.profile.get("stone", 0))

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
# ログインボーナス
# ==========================================

# キャンペーンボーナス定義（後で削除・変更可能）
const LOGIN_CAMPAIGNS: Array[Dictionary] = [
	{"id": "launch_202603", "gold": 100000, "stone": 3000, "label": "リリース記念ボーナス"},
]

# 連続ログインボーナス定義（日数: 報酬）
const STREAK_REWARDS: Array[Dictionary] = [
	{"day": 1, "gold": 500, "stone": 0, "label": "1日目"},
	{"day": 2, "gold": 500, "stone": 0, "label": "2日目"},
	{"day": 3, "gold": 1000, "stone": 0, "label": "3日目"},
	{"day": 4, "gold": 500, "stone": 0, "label": "4日目"},
	{"day": 5, "gold": 1000, "stone": 100, "label": "5日目"},
	{"day": 6, "gold": 500, "stone": 0, "label": "6日目"},
	{"day": 7, "gold": 2000, "stone": 200, "label": "7日目ボーナス"},
]


## ログインボーナスをチェックして付与（戻り値: 付与された報酬の配列）
func check_login_bonus() -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var today = GameClock.get_today()
	var login_bonus = player_data.login_bonus

	# === キャンペーンボーナス ===
	var claimed = login_bonus.get("claimed_campaigns", [])
	for campaign in LOGIN_CAMPAIGNS:
		if campaign.id not in claimed:
			player_data.profile.gold += int(campaign.get("gold", 0))
			player_data.profile.stone += int(campaign.get("stone", 0))
			claimed.append(campaign.id)
			rewards.append({
				"type": "campaign",
				"label": campaign.get("label", "キャンペーン"),
				"gold": int(campaign.get("gold", 0)),
				"stone": int(campaign.get("stone", 0)),
			})
	login_bonus.claimed_campaigns = claimed

	# === デイリー＆連続ログインボーナス ===
	var last_daily = login_bonus.get("last_daily_date", "")
	if last_daily == today:
		# 今日はもう受け取り済み
		if not rewards.is_empty():
			save_to_file()
		return rewards

	# 連続ログイン判定
	var last_login = login_bonus.get("last_login_date", "")
	var streak = int(login_bonus.get("login_streak", 0))

	if _is_yesterday(last_login, today):
		streak += 1
	else:
		streak = 1  # 連続途切れ or 初回

	login_bonus.login_streak = streak
	login_bonus.last_login_date = today
	login_bonus.last_daily_date = today
	login_bonus.total_login_days = int(login_bonus.get("total_login_days", 0)) + 1

	# 連続ログイン報酬を決定（7日サイクル）
	var cycle_day = ((streak - 1) % STREAK_REWARDS.size()) + 1
	var streak_reward = null
	for r in STREAK_REWARDS:
		if int(r.day) == cycle_day:
			streak_reward = r
			break

	if streak_reward:
		var gold = int(streak_reward.get("gold", 0))
		var stone = int(streak_reward.get("stone", 0))
		player_data.profile.gold += gold
		player_data.profile.stone += stone
		rewards.append({
			"type": "daily",
			"label": "連続ログイン %d日目" % streak,
			"gold": gold,
			"stone": stone,
			"streak": streak,
		})

	save_to_file()
	return rewards


## 昨日かどうかを判定
func _is_yesterday(last_date: String, today: String) -> bool:
	if last_date.is_empty():
		return false
	# 日付文字列をUnix時間に変換して比較
	var last_dict = Time.get_datetime_dict_from_datetime_string(last_date + "T00:00:00", false)
	var today_dict = Time.get_datetime_dict_from_datetime_string(today + "T00:00:00", false)
	var last_unix = Time.get_unix_time_from_datetime_dict(last_dict)
	var today_unix = Time.get_unix_time_from_datetime_dict(today_dict)
	var diff = today_unix - last_unix
	return diff >= 86400 and diff < 172800  # 1日以上2日未満


# ==========================================
# スタミナ管理
# ==========================================

const STAMINA_RECOVERY_SECONDS: int = 300  # 5分で1回復
const STAMINA_COST_QUEST: int = 10

## updated_atからUnix時間を取得（文字列・数値両対応）
func _get_stamina_updated_unix() -> int:
	var updated_at = player_data.stamina.get("updated_at", "")
	if updated_at is int or updated_at is float:
		return int(updated_at)
	if updated_at is String and not updated_at.is_empty():
		# 旧形式の日時文字列からの変換を試みる
		var unix = Time.get_unix_time_from_datetime_string(updated_at)
		if unix > 0:
			return int(unix)
	return 0

## 時間経過によるスタミナ回復を計算・適用
func update_stamina_by_time():
	var stamina = player_data.stamina
	var current = int(stamina.get("current", 50))
	var max_val = int(stamina.get("max", 50))
	var now = GameClock.get_now()

	# 最大値以上なら時間回復しない
	if current >= max_val:
		stamina.updated_at = now
		return

	var last_time = _get_stamina_updated_unix()
	if last_time <= 0:
		stamina.updated_at = now
		return

	var elapsed: int = int(now - last_time)

	if elapsed <= 0:
		return

	@warning_ignore("integer_division")
	var recovery: int = elapsed / STAMINA_RECOVERY_SECONDS
	if recovery > 0:
		stamina.current = mini(current + recovery, max_val)
		# 余りの秒数を考慮して更新時刻を調整
		var used_seconds = recovery * STAMINA_RECOVERY_SECONDS
		stamina.updated_at = last_time + used_seconds
	# recoveryが0の場合はupdated_atを変更しない

## スタミナを消費する（不足時はfalseを返す）
func consume_stamina(amount: int = STAMINA_COST_QUEST) -> bool:
	update_stamina_by_time()
	var current = int(player_data.stamina.get("current", 0))
	if current < amount:
		return false

	player_data.stamina.current = current - amount
	# 消費時はupdated_atを変更しない（回復カウントを継続）
	save_to_file()
	return true

## スタミナを回復する（最大値を超えてOK）
func recover_stamina(amount: int):
	update_stamina_by_time()
	var current = int(player_data.stamina.get("current", 0))
	player_data.stamina.current = current + amount
	player_data.stamina.updated_at = GameClock.get_now()
	save_to_file()

## スタミナを全回復する（最大値分を加算、超過OK）
func recover_stamina_full():
	update_stamina_by_time()
	var current = int(player_data.stamina.get("current", 0))
	var max_val = int(player_data.stamina.get("max", 50))
	player_data.stamina.current = current + max_val
	player_data.stamina.updated_at = GameClock.get_now()
	save_to_file()

## 現在のスタミナを取得（時間回復適用済み）
func get_stamina() -> int:
	update_stamina_by_time()
	return int(player_data.stamina.get("current", 50))

## 最大スタミナを取得
func get_stamina_max() -> int:
	return int(player_data.stamina.get("max", 50))

## 次の回復までの残り秒数を取得
func get_stamina_recovery_remaining_seconds() -> int:
	var current = int(player_data.stamina.get("current", 50))
	var max_val = int(player_data.stamina.get("max", 50))
	if current >= max_val:
		return 0

	var last_time = _get_stamina_updated_unix()
	if last_time <= 0:
		return STAMINA_RECOVERY_SECONDS

	var now = GameClock.get_now()
	var elapsed = now - last_time
	var remaining = STAMINA_RECOVERY_SECONDS - (elapsed % STAMINA_RECOVERY_SECONDS)
	return remaining

# ==========================================
# インベントリ（倉庫アイテム）管理
# ==========================================

const INVENTORY_ITEMS_PATH = "res://data/inventory_items.json"
var _inventory_item_defs: Array[Dictionary] = []

## アイテム定義を読み込む
func _load_inventory_item_defs():
	if not _inventory_item_defs.is_empty():
		return
	var file = FileAccess.open(INVENTORY_ITEMS_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			for item in json.data:
				_inventory_item_defs.append(item)
		file.close()

## アイテム定義を取得
func get_inventory_item_def(item_id: int) -> Dictionary:
	_load_inventory_item_defs()
	for item in _inventory_item_defs:
		if int(item.get("id", 0)) == item_id:
			return item
	return {}

## 全アイテム定義を取得
func get_all_inventory_item_defs() -> Array[Dictionary]:
	_load_inventory_item_defs()
	return _inventory_item_defs

## アイテムを追加
func add_inventory_item(item_id: int, count: int = 1):
	var key = str(item_id)
	var current = int(player_data.inventory.get(key, 0))
	var item_def = get_inventory_item_def(item_id)
	var max_stack = int(item_def.get("max_stack", 99))
	player_data.inventory[key] = mini(current + count, max_stack)
	save_to_file()

## アイテムの所持数を取得
func get_inventory_item_count(item_id: int) -> int:
	var key = str(item_id)
	return int(player_data.inventory.get(key, 0))

## アイテムを使用する（成功時true）
func use_inventory_item(item_id: int) -> bool:
	var count = get_inventory_item_count(item_id)
	if count <= 0:
		return false

	var item_def = get_inventory_item_def(item_id)
	if item_def.is_empty():
		return false

	# 効果を適用
	var effect_type = item_def.get("effect_type", "")
	var value = int(item_def.get("value", 0))

	match effect_type:
		"stamina_recover":
			recover_stamina(value)
		"stamina_recover_full":
			recover_stamina_full()
		_:
			print("[GameData] 未知のeffect_type: ", effect_type)
			return false

	# 消費
	var key = str(item_id)
	player_data.inventory[key] = count - 1
	if player_data.inventory[key] <= 0:
		player_data.inventory.erase(key)
	save_to_file()
	return true

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

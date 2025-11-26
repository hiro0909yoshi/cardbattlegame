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
# 旧システム(下位互換のため一時的に残す)
var deck = []  # DEPRECATED - player_decks[0] を参照
var discard = []  # DEPRECATED - player_discards[0] を参照

# 新システム(マルチデッキ対応)
var player_decks = {}  # player_id -> Array[int] (card_ids)
var player_discards = {}  # player_id -> Array[int] (card_ids)
var player_hands = {}  # player_id -> {"data": [card_data]}

func _ready():
	# 新システム初期化(プレイヤー数は後で動的に設定可能)
	_initialize_decks(2)  # デフォルト: 2人プレイ
	
	# 下位互換: 旧変数に参照を設定
	deck = player_decks[0]
	discard = player_discards[0]

func _initialize_deck():
	# DEPRECATED - _initialize_decks() を使用してください
	# 下位互換のため残しています
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
		print("ブック", GameData.selected_deck_index + 1, "のデッキを読み込み")
	
	deck.shuffle()
	print("デッキ初期化: ", deck.size(), "枚")

# 新システム: 複数プレイヤーのデッキを初期化
func _initialize_decks(player_count: int):
	print("\n=== マルチデッキ初期化開始 ===")
	print("プレイヤー数: ", player_count)
	
	# 全プレイヤーのデータ構造を初期化
	for player_id in range(player_count):
		player_decks[player_id] = []
		player_discards[player_id] = []
		player_hands[player_id] = {"data": []}
	
	# プレイヤー0: GameDataから読み込み
	_load_deck_from_game_data(0)
	
	# プレイヤー1: 手動操作CPU用(暫定: プレイヤー0と同じデッキ)
	if player_count >= 2:
		_load_manual_cpu_deck(1)
	
	# プレイヤー2-3: デフォルトデッキ(将来のCPU用)
	for player_id in range(2, player_count):
		_load_default_deck(player_id)
	
	print("=== マルチデッキ初期化完了 ===\n")

func _initialize_player_hands():
	for i in range(MAX_PLAYERS):
		player_hands[i] = {
			"data": []
		}

# Phase 4: プレイヤー0用 - GameDataからデッキ読み込み
func _load_deck_from_game_data(player_id: int):
	var deck_data = GameData.get_current_deck()["cards"]
	
	if deck_data.is_empty():
		push_warning("Player 0: デッキが空、デフォルトデッキ使用")
		_load_default_deck(player_id)
		return
	
	# 辞書 {card_id: count} を配列に変換
	for card_id in deck_data.keys():
		var count = deck_data[card_id]
		for i in range(count):
			player_decks[player_id].append(card_id)
	
	player_decks[player_id].shuffle()
	print("Player 0: ブック", GameData.selected_deck_index + 1, "読み込み (", player_decks[player_id].size(), "枚)")

# Phase 4: プレイヤー1用 - 手動操作CPU用デッキ
func _load_manual_cpu_deck(player_id: int):
	# 暫定: プレイヤー0と同じデッキを使用
	# TODO: 将来的には専用のCPUデッキファイルから読み込む
	var deck_data = GameData.get_current_deck()["cards"]
	
	for card_id in deck_data.keys():
		var count = deck_data[card_id]
		for i in range(count):
			player_decks[player_id].append(card_id)
	
	player_decks[player_id].shuffle()
	print("Player 1: 手動操作CPU用デッキ読み込み (", player_decks[player_id].size(), "枚)")

# Phase 4: デフォルトデッキ(プレイヤー2-3用)
func _load_default_deck(player_id: int):
	# デフォルトデッキ: ID 1-12 を各3枚
	for card_id in range(1, 13):
		for j in range(3):
			player_decks[player_id].append(card_id)
	
	player_decks[player_id].shuffle()
	print("Player ", player_id, ": デフォルトデッキ読み込み (", player_decks[player_id].size(), "枚)")

func draw_card_data() -> Dictionary:
	# DEPRECATED - draw_card_data_v2(player_id) を使用してください
	# 下位互換: player_id = 0 固定
	return draw_card_data_v2(0)

# 新システム: プレイヤーIDを指定してドロー
func draw_card_data_v2(player_id: int) -> Dictionary:
	if not player_decks.has(player_id):
		push_error("Invalid player_id: " + str(player_id))
		return {}
	
	if player_decks[player_id].is_empty():
		if player_discards[player_id].is_empty():
			print("Player ", player_id, ": デッキも捨て札も空")
			return {}
		
		# 捨て札をシャッフルしてデッキに戻す
		print("Player ", player_id, ": 捨て札をシャッフルしてデッキに戻します")
		player_decks[player_id] = player_discards[player_id].duplicate()
		player_discards[player_id].clear()
		player_decks[player_id].shuffle()
	
	var card_id = player_decks[player_id].pop_front()
	var card_data = _load_card_data(card_id)
	print("[ドロー] プレイヤー%d: %s (ID: %d) をデッキから引きました" % [player_id + 1, card_data.get("name", "?"), card_id])
	return card_data

func _load_card_data(card_id: int) -> Dictionary:
	if CardLoader:
		var card_data = CardLoader.get_card_by_id(card_id)
		if card_data.is_empty():
			print("WARNING: カードID ", card_id, " が見つかりません")
			return {}
		
		# マスターデータの参照汚染を防ぐため、独立したコピーを作成
		card_data = card_data.duplicate(true)
		
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
	# 新システムを使用
	var card_data = draw_card_data_v2(player_id)
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
			# 新システムを使用
			var card_data = draw_card_data_v2(player_id)
			if not card_data.is_empty():
				player_hands[player_id]["data"].append(card_data)
	
	emit_signal("hand_updated")

func use_card_for_player(player_id: int, card_index: int) -> Dictionary:
	# discard_card()を使用(理由: "use")
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
	# 新システム: プレイヤーの捨て札に追加
	player_discards[player_id].append(card_data.id)
	
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
	# DEPRECATED - get_deck_size_for_player(player_id) を使用してください
	# 下位互換: player_id = 0 のデッキサイズを返す
	return player_decks.get(0, []).size()

func get_discard_size() -> int:
	# DEPRECATED - get_discard_size_for_player(player_id) を使用してください
	# 下位互換: player_id = 0 の捨て札サイズを返す
	return player_discards.get(0, []).size()

# 新システム: プレイヤー別デッキサイズ
func get_deck_size_for_player(player_id: int) -> int:
	return player_decks.get(player_id, []).size()

# 新システム: プレイヤー別捨て札サイズ
func get_discard_size_for_player(player_id: int) -> int:
	return player_discards.get(player_id, []).size()

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

# 手札を指定枚数まで減らす(ターン終了時用)
# CPU用の自動捨て札処理(後ろから捨てる)
func discard_excess_cards_auto(player_id: int, max_cards: int = 6) -> int:
	var hand_size = get_hand_size_for_player(player_id)
	if hand_size <= max_cards:
		return 0  # 捨てる必要なし
	
	var cards_to_discard = hand_size - max_cards
	print("手札調整(自動): ", hand_size, "枚 → ", max_cards, "枚(", cards_to_discard, "枚捨てる)")
	
	# 後ろから捨てる
	for i in range(cards_to_discard):
		var hand_data = player_hands[player_id]["data"]
		if hand_data.size() > max_cards:
			# 最後のカードのインデックス
			var last_index = hand_data.size() - 1
			discard_card(player_id, last_index, "discard")
	
	return cards_to_discard

# カードを手札に戻す(バトル失敗時の処理)
func return_card_to_hand(player_id: int, card_data: Dictionary) -> bool:
	if not player_hands.has(player_id):
		push_error("return_card_to_hand: 不正なplayer_id " + str(player_id))
		return false
	
	# 捨て札から該当カードを削除
	var card_id = card_data.get("id", -1)
	# 新システム: プレイヤーの捨て札から削除
	if card_id in player_discards[player_id]:
		player_discards[player_id].erase(card_id)
	
	# 🔧 クリーンなカードデータを作成(バトル中の変更をリセット)
	var clean_card_data = _get_clean_card_data(card_id)
	if clean_card_data.is_empty():
		# 元データが見つからない場合は渡されたデータをそのまま使う
		clean_card_data = card_data.duplicate()
		# 少なくともバトル用フィールドは削除
		clean_card_data.erase("base_up_hp")
		clean_card_data.erase("base_up_ap")
		clean_card_data.erase("permanent_effects")
		clean_card_data.erase("temporary_effects")
		clean_card_data.erase("map_lap_count")
		clean_card_data.erase("items")
		clean_card_data.erase("current_hp")
	
	# 手札に追加
	player_hands[player_id]["data"].append(clean_card_data)
	
	print("【カード復帰】", clean_card_data.get("name", "不明"), " が手札に戻りました(クリーン状態)")
	emit_signal("hand_updated")
	
	return true

## カードIDから元のクリーンなデータを取得
func _get_clean_card_data(card_id: int) -> Dictionary:
	if CardLoader and CardLoader.has_method("get_card_by_id"):
		return CardLoader.get_card_by_id(card_id)
	return {}

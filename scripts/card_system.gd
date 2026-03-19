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
var player_decks: Dictionary = {}  # player_id -> Array[int] (card_ids)
var player_discards: Dictionary = {}  # player_id -> Array[int] (card_ids)
var player_hands: Dictionary = {}  # player_id -> {"data": [card_data]}

func _ready():
	# デッキ初期化はgame_system_managerのPhase3でinitialize_decks(player_count)を呼ぶ
	# _ready()では行わない（二重初期化防止）
	pass

func _initialize_deck():
	# DEPRECATED - initialize_decks() を使用してください
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
	deck.shuffle()

# 新システム: 複数プレイヤーのデッキを初期化
func initialize_decks(player_count: int):
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

func _initialize_player_hands():
	for i in range(MAX_PLAYERS):
		player_hands[i] = {
			"data": []
		}

# Phase 4: プレイヤー0用 - GameDataからデッキ読み込み
func _load_deck_from_game_data(player_id: int):
	var deck_data = GameData.get_current_deck()["cards"]

	# 辞書 {card_id: count} を配列に変換
	for card_id in deck_data.keys():
		var count = deck_data[card_id]
		for i in range(count):
			player_decks[player_id].append(card_id)

	player_decks[player_id].shuffle()

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

# Phase 4: デフォルトデッキ(プレイヤー2-3用)
func _load_default_deck(player_id: int):
	# デフォルトデッキ: ID 1-12 を各3枚
	for card_id in range(1, 13):
		for j in range(3):
			player_decks[player_id].append(card_id)

	player_decks[player_id].shuffle()

func draw_card_data() -> Dictionary:
	# DEPRECATED - draw_card_data_v2(player_id) を使用してください
	# 下位互換: player_id = 0 固定
	return draw_card_data_v2(0)

# 新システム: プレイヤーIDを指定してドロー
func draw_card_data_v2(player_id: int) -> Dictionary:
	# クエストモード: デッキプールを使用
	if player_deck_pools.has(player_id):
		# デッキプールが空の場合、捨て札プールから補充
		if player_deck_pools[player_id].is_empty():
			if player_discard_pools.has(player_id) and not player_discard_pools[player_id].is_empty():
				print("Player ", player_id + 1, ": 捨て札をシャッフルしてデッキに戻します（クエストモード）")
				player_deck_pools[player_id] = player_discard_pools[player_id].duplicate()
				player_discard_pools[player_id].clear()
				player_deck_pools[player_id].shuffle()
			else:
				print("Player ", player_id + 1, ": デッキも捨て札も空（クエストモード）")
				return {}
		
		var pool_card = player_deck_pools[player_id].pop_front()
		return pool_card
	
	# 通常モード: player_decks/player_discards を使用
	if not player_decks.has(player_id):
		GameLogger.error("Card", "CardSystem: Invalid player_id: %d (player_decks keys=%d)" % [player_id, player_decks.size()])
		return {}
	
	if player_decks[player_id].is_empty():
		if player_discards[player_id].is_empty():
			print("Player ", player_id + 1, ": デッキも捨て札も空")
			return {}
		
		# 捨て札をシャッフルしてデッキに戻す
		print("Player ", player_id + 1, ": 捨て札をシャッフルしてデッキに戻します")
		player_decks[player_id] = player_discards[player_id].duplicate()
		player_discards[player_id].clear()
		player_decks[player_id].shuffle()
	
	var card_id = player_decks[player_id].pop_front()
	var card_data = load_card_data(card_id)
	return card_data

func load_card_data(card_id: int) -> Dictionary:
	if CardLoader:
		var card_data = CardLoader.get_card_by_id(card_id)
		if card_data.is_empty():
			print("WARNING: カードID ", card_id, " が見つかりません")
			return {}
		
		# マスターデータの参照汚染を防ぐため、独立したコピーを作成
		card_data = card_data.duplicate(true)
		
		# costを正規化（召喚条件は別フィールドに保存）
		if card_data.has("cost"):
			if typeof(card_data.cost) == TYPE_DICTIONARY:
				# 召喚条件を別フィールドに保存
				if card_data.cost.has("lands_required"):
					card_data["cost_lands_required"] = card_data.cost.lands_required
				if card_data.cost.has("cards_sacrifice"):
					card_data["cost_cards_sacrifice"] = card_data.cost.cards_sacrifice
				# mpをcostに変換
				if card_data.cost.has("ep"):
					card_data.cost = card_data.cost.ep
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
		# player_handsが未初期化の場合は初期化
		if not player_hands.has(player_id):
			player_hands[player_id] = {"data": []}
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
		# player_handsが未初期化の場合は初期化
		if not player_hands.has(player_id):
			player_hands[player_id] = {"data": []}
		player_hands[player_id]["data"].clear()
		
		for i in range(INITIAL_HAND_SIZE):
			# 新システムを使用
			var card_data = draw_card_data_v2(player_id)
			if not card_data.is_empty():
				player_hands[player_id]["data"].append(card_data)
	
	emit_signal("hand_updated")

## チュートリアル用: 特定のカードIDで手札を設定
func set_fixed_hand_for_player(player_id: int, card_ids: Array):
	if not player_hands.has(player_id):
		player_hands[player_id] = {"data": []}
	player_hands[player_id]["data"].clear()
	
	for card_id in card_ids:
		var card_data = CardLoader.get_card_by_id(card_id)
		if not card_data.is_empty():
			# 複製して追加（同じカードでも独立したデータにする）
			player_hands[player_id]["data"].append(card_data.duplicate(true))
		else:
			print("[CardSystem] WARNING: カードID %d が見つかりません" % card_id)
	
	print("[CardSystem] プレイヤー%d: 固定手札設定完了 (%d枚)" % [player_id + 1, player_hands[player_id]["data"].size()])
	emit_signal("hand_updated")

## チュートリアル用: 特定のカードIDで固定順序デッキを設定（シャッフルなし）
func set_fixed_deck_for_player(player_id: int, card_ids: Array):
	var deck_pool = []
	
	for card_id in card_ids:
		var card_data = CardLoader.get_card_by_id(card_id)
		if not card_data.is_empty():
			deck_pool.append(card_data.duplicate(true))
		else:
			print("[CardSystem] WARNING: カードID %d が見つかりません" % card_id)
	
	if not player_deck_pools.has(player_id):
		player_deck_pools[player_id] = []
	player_deck_pools[player_id] = deck_pool
	
	print("[CardSystem] プレイヤー%d: 固定デッキ設定完了 (%d枚)" % [player_id + 1, deck_pool.size()])

## 特定プレイヤーにデッキを設定（クエストモード用）
## deck_data: {"cards": [{"id": card_id, "count": 枚数}, ...]}
func set_deck_for_player(player_id: int, deck_data: Dictionary):
	if deck_data.is_empty():
		print("[CardSystem] プレイヤー%d: ランダムデッキ使用" % (player_id + 1))
		return
	
	# プレイヤー用のデッキプールを作成
	var deck_pool = []
	var card_entries = deck_data.get("cards", [])
	
	for entry in card_entries:
		var card_id = entry.get("id", 0)
		var count = entry.get("count", 1)
		
		# カードデータを取得
		var card_data = CardLoader.get_card_by_id(card_id)
		if card_data.is_empty():
			GameLogger.warn("Card", "CardSystem: カードID %d が見つかりません" % card_id)
			continue
		
		# 指定枚数分デッキプールに追加
		for _i in range(count):
			deck_pool.append(card_data.duplicate())
	
	if deck_pool.is_empty():
		GameLogger.error("Card", "CardSystem: デッキが空です (player=%d)" % player_id)
		return
	
	# デッキプールをシャッフル
	deck_pool.shuffle()
	
	# プレイヤーのデッキプールとして保存
	if not player_deck_pools.has(player_id):
		player_deck_pools[player_id] = []
	player_deck_pools[player_id] = deck_pool
	
	print("[CardSystem] プレイヤー%d: デッキ設定完了 (%d枚)" % [player_id + 1, deck_pool.size()])

## プレイヤーごとのデッキプール（クエストモード用）
var player_deck_pools: Dictionary = {}  # player_id -> [card_data, ...]
var player_discard_pools: Dictionary = {}  # player_id -> [card_data, ...] クエストモード用捨て札

## デッキプールからカードを引く（クエストモード用）
## 注: draw_card_data_v2() がデッキプールを自動処理するため、このメソッドは直接呼び出さないでください
func draw_from_deck_pool(player_id: int) -> Dictionary:
	# draw_card_data_v2 に処理を委譲（捨て札からの補充も含む）
	return draw_card_data_v2(player_id)

## 特定プレイヤーに初期手札を配布（デッキプールから）
func deal_initial_hand_for_player(player_id: int):
	player_hands[player_id]["data"].clear()
	
	for i in range(INITIAL_HAND_SIZE):
		var card_data = draw_from_deck_pool(player_id)
		if not card_data.is_empty():
			player_hands[player_id]["data"].append(card_data)
	
	print("[CardSystem] プレイヤー%d: 初期手札配布完了 (%d枚)" % [player_id + 1, player_hands[player_id]["data"].size()])

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
	
	# 捨て札に追加（クエストモードとそれ以外で分岐）
	if player_deck_pools.has(player_id):
		# クエストモード: player_discard_pools に card_data を追加
		if not player_discard_pools.has(player_id):
			player_discard_pools[player_id] = []
		player_discard_pools[player_id].append(card_data.duplicate())
	else:
		# 通常モード: player_discards に card_id を追加
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
		GameLogger.error("Card", "CardSystem: return_card_to_hand - 不正なplayer_id %d (player_hands keys=%d)" % [player_id, player_hands.size()])
		return false
	
	# 捨て札から該当カードを削除
	var card_id = card_data.get("id", -1)
	
	# クエストモードとそれ以外で分岐
	if player_deck_pools.has(player_id):
		# クエストモード: player_discard_pools から削除
		if player_discard_pools.has(player_id):
			for i in range(player_discard_pools[player_id].size() - 1, -1, -1):
				if player_discard_pools[player_id][i].get("id", -1) == card_id:
					player_discard_pools[player_id].remove_at(i)
					break
	else:
		# 通常モード: player_discards から削除
		if card_id in player_discards[player_id]:
			player_discards[player_id].erase(card_id)
	
	# 🔧 合成処理による分岐
	var clean_card_data: Dictionary
	var synthesis_type = card_data.get("synthesis_type", "")
	
	if synthesis_type == "transform":
		# 変身型合成：変身後のカードをそのまま返す（バトル用フィールドのみ除去）
		clean_card_data = get_clean_card_data(card_id)
		if clean_card_data.is_empty():
			clean_card_data = card_data.duplicate()
		# バトル用フィールドを削除
		_clean_battle_fields(clean_card_data)
		print("【カード復帰】", clean_card_data.get("name", "不明"), " が手札に戻りました(変身型合成)")
	elif synthesis_type == "stat_boost":
		# ステータスアップ型合成：元のカードをクリーンで返す
		var original_id = card_data.get("original_card_id", card_id)
		clean_card_data = get_clean_card_data(original_id)
		if clean_card_data.is_empty():
			clean_card_data = card_data.duplicate()
			_clean_battle_fields(clean_card_data)
			# 合成関連フィールドも削除
			clean_card_data.erase("is_synthesized")
			clean_card_data.erase("synthesis_type")
			clean_card_data.erase("original_card_id")
			clean_card_data.erase("base_ap")
			clean_card_data.erase("base_hp")
		print("【カード復帰】", clean_card_data.get("name", "不明"), " が手札に戻りました(ステータス合成リセット)")
	else:
		# 通常：クリーンなカードデータを作成
		clean_card_data = get_clean_card_data(card_id)
		if clean_card_data.is_empty():
			clean_card_data = card_data.duplicate()
			_clean_battle_fields(clean_card_data)
		print("【カード復帰】", clean_card_data.get("name", "不明"), " が手札に戻りました(クリーン状態)")
	
	# 手札に追加
	player_hands[player_id]["data"].append(clean_card_data)
	emit_signal("hand_updated")
	
	return true


## バトル用フィールドを削除
func _clean_battle_fields(card_data: Dictionary) -> void:
	card_data.erase("base_up_hp")
	card_data.erase("base_up_ap")
	card_data.erase("permanent_effects")
	card_data.erase("temporary_effects")
	card_data.erase("map_lap_count")
	card_data.erase("items")
	card_data.erase("current_hp")

## カードIDから元のクリーンなデータを取得
func get_clean_card_data(card_id: int) -> Dictionary:
	if CardLoader and CardLoader.has_method("get_card_by_id"):
		return CardLoader.get_card_by_id(card_id)
	return {}


## 手札から指定インデックスのカードを削除
func remove_card_from_hand(player_id: int, index: int) -> bool:
	if not player_hands.has(player_id):
		return false
	var hand = player_hands[player_id]["data"]
	if index < 0 or index >= hand.size():
		return false
	hand.remove_at(index)
	emit_signal("hand_updated")
	return true


## デッキから指定インデックスのカードを削除
func remove_card_from_deck(player_id: int, index: int) -> bool:
	if not player_decks.has(player_id):
		return false
	var deck_arr = player_decks[player_id]
	if index < 0 or index >= deck_arr.size():
		return false
	deck_arr.remove_at(index)
	return true


## 手札の配列を取得（参照）
func get_hand(player_id: int) -> Array:
	if not player_hands.has(player_id):
		return []
	return player_hands[player_id]["data"]


## デッキの配列を取得（参照）
func get_deck(player_id: int) -> Array:
	if not player_decks.has(player_id):
		return []
	return player_decks[player_id]

# === カード譲渡タイル用 ===

## 山札から特定タイプのカードID一覧を取得
func get_deck_cards_by_type(player_id: int, card_type: String) -> Array:
	if not player_decks.has(player_id):
		return []
	
	var result = []
	for card_id in player_decks[player_id]:
		var card_data = CardLoader.get_card_by_id(card_id)
		if not card_data.is_empty() and card_data.get("type", "") == card_type:
			result.append(card_id)
	return result

## 山札に特定タイプのカードがあるかチェック
func has_deck_card_type(player_id: int, card_type: String) -> bool:
	return get_deck_cards_by_type(player_id, card_type).size() > 0

## 山札から特定カードを引いて手札に追加
func draw_specific_card_from_deck(player_id: int, card_id: int) -> Dictionary:
	if not player_decks.has(player_id):
		return {}
	
	var player_deck = player_decks[player_id]
	var index = player_deck.find(card_id)
	if index == -1:
		return {}
	
	# 山札から削除
	player_deck.remove_at(index)
	
	# カードデータを取得
	var card_data = CardLoader.get_card_by_id(card_id)
	if card_data.is_empty():
		return {}
	
	# 手札に追加
	player_hands[player_id]["data"].append(card_data.duplicate())
	
	emit_signal("card_drawn", card_data)
	emit_signal("hand_updated")
	
	print("[CardSystem] カード譲渡: Player%d が %s を取得" % [player_id + 1, card_data.get("name", "?")])
	return card_data

## 山札から特定タイプのカードをランダムで1枚引く
func draw_random_card_by_type(player_id: int, card_type: String) -> Dictionary:
	var type_cards = get_deck_cards_by_type(player_id, card_type)
	if type_cards.is_empty():
		return {}
	
	# ランダムで1枚選択
	var random_card_id = type_cards[randi() % type_cards.size()]
	return draw_specific_card_from_deck(player_id, random_card_id)

# === カード購入タイル用 ===

## 外部カードを手札に追加（購入・魔法タイル等で使用）
func add_card_to_hand(player_id: int, card_data: Dictionary) -> bool:
	if not player_hands.has(player_id):
		return false

	if card_data.is_empty():
		return false

	# カードデータをコピーして追加
	var clean_card = card_data.duplicate()
	_clean_battle_fields(clean_card)

	player_hands[player_id]["data"].append(clean_card)

	emit_signal("hand_updated")
	print("[CardSystem] カード追加: Player%d が %s を手札に追加" % [player_id + 1, card_data.get("name", "?")])
	return true

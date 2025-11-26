extends Node
class_name SpellDraw

## ドロー処理の汎用化モジュール
## バトル外のマップ効果として使用する

var card_system_ref: CardSystem = null

func setup(card_system: CardSystem):
	card_system_ref = card_system
	print("SpellDraw: セットアップ完了")

## 統合エントリポイント - effect辞書から適切な処理を実行
## 戻り値: Dictionary（結果情報、next_effectがある場合は再帰適用が必要）
func apply_effect(effect: Dictionary, player_id: int, context: Dictionary = {}) -> Dictionary:
	var effect_type = effect.get("effect_type", "")
	var result = {}
	
	match effect_type:
		"draw", "draw_cards":
			var count = effect.get("count", 1)
			result["drawn"] = draw_cards(player_id, count)
		
		"draw_by_rank":
			var rank = context.get("rank", 1)
			result["drawn"] = draw_by_rank(player_id, rank)
		
		"discard_and_draw_plus":
			result["drawn"] = discard_and_draw_plus(player_id)
		
		"check_hand_elements":
			# 密命：手札属性チェック（条件分岐）
			var required_elements = effect.get("required_elements", ["fire", "water", "wind", "earth"])
			var success_effect = effect.get("success_effect", {})
			var fail_effect = effect.get("fail_effect", {})
			
			var hand_elements = get_hand_creature_elements(player_id)
			var has_all = has_all_elements(player_id, required_elements)
			
			if has_all:
				print("[密命成功] 手札に4属性あり: %s" % str(hand_elements))
				result["next_effect"] = success_effect
			else:
				print("[密命失敗] 手札の属性: %s（必要: %s）" % [str(hand_elements), str(required_elements)])
				result["next_effect"] = fail_effect
		
		"destroy_curse_cards":
			# 全プレイヤーの呪いカード破壊（レイオブパージ用）
			result = destroy_curse_cards()
		
		"destroy_expensive_cards":
			# 全プレイヤーの高コストカード破壊（レイオブロウ用）
			var cost_threshold = effect.get("cost_threshold", 100)
			result = destroy_expensive_cards(cost_threshold)
		
		"destroy_duplicate_cards":
			# 対象プレイヤーの重複カード破壊（エロージョン用）
			var target_player_id = context.get("target_player_id", player_id)
			result = destroy_duplicate_cards(target_player_id)
		
		_:
			print("[SpellDraw] 未対応の効果タイプ: ", effect_type)
	
	return result

## 1枚ドロー（ターン開始用）
func draw_one(player_id: int) -> Dictionary:
	"""
	ターン開始時の1枚ドロー
	
	戻り値: Dictionary（引いたカードデータ、引けなかった場合は空の辞書）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {}
	
	var card = card_system_ref.draw_card_for_player(player_id)
	
	if not card.is_empty():
		print("[ドロー] プレイヤー", player_id + 1, "が1枚引きました: ", card.get("name", "不明"))
	else:
		print("[ドロー] プレイヤー", player_id + 1, "はカードを引けませんでした")
	
	return card

## 固定枚数ドロー
func draw_cards(player_id: int, count: int) -> Array:
	"""
	指定枚数カードを引く
	
	用途: 「2枚引く」「3枚引く」などの固定ドロースペル
	
	引数:
	  player_id: プレイヤーID（0-3）
	  count: 引く枚数
	
	戻り値: Array（引いたカードデータの配列）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return []
	
	if count <= 0:
		print("[ドロー] プレイヤー", player_id + 1, "は0枚指定のため何も引きません")
		return []
	
	var drawn = card_system_ref.draw_cards_for_player(player_id, count)
	print("[ドロー] プレイヤー", player_id + 1, "が", drawn.size(), "枚引きました（要求: ", count, "枚）")
	
	return drawn

## 上限までドロー（手札補充）
func draw_until(player_id: int, target_hand_size: int) -> Array:
	"""
	手札が指定枚数になるまで引く
	
	例:
	  - 現在手札2枚、target=6 → 4枚引く
	  - 現在手札5枚、target=6 → 1枚引く
	  - 現在手札6枚、target=6 → 0枚引く（引かない）
	  - 現在手札7枚、target=6 → 0枚引く（引かない）
	
	用途:
	  - トゥームストーン（1038）: draw_until(player_id, 6)  # 6枚まで引く
	  - 5枚までドロースペル: draw_until(player_id, 5)
	
	引数:
	  player_id: プレイヤーID（0-3）
	  target_hand_size: 目標手札枚数
	
	戻り値: Array（引いたカードデータの配列）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return []
	
	var current_hand_size = card_system_ref.get_hand_size_for_player(player_id)
	var needed = target_hand_size - current_hand_size
	
	if needed <= 0:
		print("[ドロー] プレイヤー", player_id + 1, "は既に", current_hand_size, 
			  "枚持っているため引きません（目標: ", target_hand_size, "枚）")
		return []
	
	var drawn = card_system_ref.draw_cards_for_player(player_id, needed)
	print("[ドロー] プレイヤー", player_id + 1, "が手札", target_hand_size, 
		  "枚まで補充（", drawn.size(), "枚引いた）")
	
	return drawn

## 手札全交換
func exchange_all_hand(player_id: int) -> Array:
	"""
	手札を全て捨てて同じ枚数引き直す
	
	例: 手札4枚 → 4枚捨てて4枚引く
	
	引数:
	  player_id: プレイヤーID（0-3）
	
	戻り値: Array（新しく引いたカードデータの配列）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return []
	
	var hand_size = card_system_ref.get_hand_size_for_player(player_id)
	
	if hand_size == 0:
		print("[手札交換] プレイヤー", player_id + 1, "は手札が0枚のため交換しません")
		return []
	
	print("[手札交換] プレイヤー", player_id + 1, "が", hand_size, "枚の手札を交換します")
	
	# 全て捨てる（常にindex 0を捨てる、配列が縮むため）
	for i in range(hand_size):
		card_system_ref.discard_card(player_id, 0, "exchange")
	
	# 同じ枚数引く
	var drawn = card_system_ref.draw_cards_for_player(player_id, hand_size)
	print("[手札交換] プレイヤー", player_id + 1, "が", drawn.size(), "枚の新しい手札を引きました")
	
	return drawn

## 手札全捨て+元枚数ドロー（リンカネーション用）
func discard_and_draw_plus(player_id: int) -> Array:
	"""
	手札を全て捨て、その枚数分のカードを引く
	
	注: -1（使用カード）と+1（ボーナス）が相殺するため、元の手札枚数分引く
	
	引数:
	  player_id: プレイヤーID（0-3）
	
	戻り値: Array（引いたカードデータの配列）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return []
	
	var hand_size = card_system_ref.get_hand_size_for_player(player_id)
	
	# 手札を全て捨てる
	for i in range(hand_size):
		card_system_ref.discard_card(player_id, 0, "reincarnation")
	
	# 元の手札枚数分引く
	var drawn = card_system_ref.draw_cards_for_player(player_id, hand_size)
	print("[リンカネーション] プレイヤー", player_id + 1, ": 手札入替 → ", drawn.size(), "枚ドロー")
	
	return drawn

## 順位に応じたドロー（ギフト用）
func draw_by_rank(player_id: int, rank: int) -> Array:
	"""
	順位と同じ枚数のカードを引く
	
	引数:
	  player_id: プレイヤーID（0-3）
	  rank: プレイヤーの順位（1位=1, 2位=2...）
	
	戻り値: Array（引いたカードデータの配列）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return []
	
	if rank <= 0:
		return []
	
	var drawn = card_system_ref.draw_cards_for_player(player_id, rank)
	print("[順位ドロー] プレイヤー", player_id + 1, ": ", rank, "位 → ", drawn.size(), "枚ドロー")
	
	return drawn

## 手札のクリーチャー属性を取得
func get_hand_creature_elements(player_id: int) -> Array:
	"""
	手札のクリーチャーカードから属性を収集
	
	引数:
	  player_id: プレイヤーID（0-3）
	
	戻り値: Array（属性文字列の配列、重複なし）
	"""
	var elements = []
	if not card_system_ref:
		return elements
	
	var hand = card_system_ref.get_all_cards_for_player(player_id)
	for card in hand:
		if card.get("type", "") == "creature":
			var elem = card.get("element", "")
			if elem != "" and elem not in elements:
				elements.append(elem)
	
	return elements

## 手札に指定属性が全てあるかチェック
func has_all_elements(player_id: int, required_elements: Array) -> bool:
	"""
	手札のクリーチャーに指定された全属性が揃っているかチェック
	
	引数:
	  player_id: プレイヤーID（0-3）
	  required_elements: 必要な属性の配列（例: ["fire", "water", "wind", "earth"]）
	
	戻り値: bool
	"""
	var hand_elements = get_hand_creature_elements(player_id)
	
	for elem in required_elements:
		if elem not in hand_elements:
			return false
	
	return true

# ========================================
# 手札破壊系
# ========================================

## 呪いカードのspell_type一覧
const CURSE_SPELL_TYPES = [
	"複数特殊能力付与",
	"世界呪い",
	"単体特殊能力付与"
]

## 呪いカードかどうか判定
func is_curse_card(card: Dictionary) -> bool:
	"""
	カードが呪いスペルかどうかを判定
	
	判定基準: spell_typeが呪い系（複数特殊能力付与、世界呪い、単体特殊能力付与）
	
	引数:
	  card: カードデータ
	
	戻り値: bool
	"""
	if card.get("type") != "spell":
		return false
	return card.get("spell_type", "") in CURSE_SPELL_TYPES

## 全プレイヤーの手札から呪いカードを破壊
func destroy_curse_cards() -> Dictionary:
	"""
	全プレイヤーの手札から呪いカードを破壊する（レイオブパージ用）
	
	戻り値: Dictionary
	  - total_destroyed: int（破壊した総枚数）
	  - by_player: Array（プレイヤーごとの破壊枚数）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {"total_destroyed": 0, "by_player": []}
	
	var total_destroyed = 0
	var by_player = []
	
	# 全プレイヤーの手札をチェック
	for player_id in range(4):
		var destroyed_count = 0
		var hand = card_system_ref.get_all_cards_for_player(player_id)
		
		# 逆順でチェック（削除時にインデックスがずれないように）
		for i in range(hand.size() - 1, -1, -1):
			var card = hand[i]
			if is_curse_card(card):
				card_system_ref.discard_card(player_id, i, "destroy")
				print("[呪いカード破壊] プレイヤー%d: %s" % [player_id + 1, card.get("name", "?")])
				destroyed_count += 1
		
		by_player.append(destroyed_count)
		total_destroyed += destroyed_count
	
	print("[レイオブパージ] 合計 %d 枚の呪いカードを破壊" % total_destroyed)
	
	return {
		"total_destroyed": total_destroyed,
		"by_player": by_player
	}

## 全プレイヤーの手札から高コストカードを破壊
func destroy_expensive_cards(cost_threshold: int) -> Dictionary:
	"""
	全プレイヤーの手札から指定コスト以上のカードを破壊する（レイオブロウ用）
	
	引数:
	  cost_threshold: コスト閾値（この値以上のカードを破壊）
	
	戻り値: Dictionary
	  - total_destroyed: int（破壊した総枚数）
	  - by_player: Array（プレイヤーごとの破壊枚数）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {"total_destroyed": 0, "by_player": []}
	
	var total_destroyed = 0
	var by_player = []
	
	# 全プレイヤーの手札をチェック
	for player_id in range(4):
		var destroyed_count = 0
		var hand = card_system_ref.get_all_cards_for_player(player_id)
		
		# 逆順でチェック（削除時にインデックスがずれないように）
		for i in range(hand.size() - 1, -1, -1):
			var card = hand[i]
			# costがintの場合と辞書の場合の両方に対応
			var cost_data = card.get("cost", 0)
			var card_cost = 0
			if cost_data is Dictionary:
				card_cost = cost_data.get("mp", 0)
			else:
				card_cost = cost_data
			
			if card_cost >= cost_threshold:
				card_system_ref.discard_card(player_id, i, "destroy")
				print("[高コストカード破壊] プレイヤー%d: %s (G%d)" % [player_id + 1, card.get("name", "?"), card_cost])
				destroyed_count += 1
		
		by_player.append(destroyed_count)
		total_destroyed += destroyed_count
	
	print("[レイオブロウ] 合計 %d 枚のG%d以上カードを破壊" % [total_destroyed, cost_threshold])
	
	return {
		"total_destroyed": total_destroyed,
		"by_player": by_player
	}

## 対象プレイヤーの手札から重複カードを破壊
func destroy_duplicate_cards(target_player_id: int) -> Dictionary:
	"""
	対象プレイヤーの手札から重複カード（同名カードが2枚以上）を全て破壊する（エロージョン用）
	
	引数:
	  target_player_id: 対象プレイヤーID
	
	戻り値: Dictionary
	  - total_destroyed: int（破壊した総枚数）
	  - duplicates: Array（破壊したカード名のリスト）
	"""
	if not card_system_ref:
		push_error("SpellDraw: CardSystemが設定されていません")
		return {"total_destroyed": 0, "duplicates": []}
	
	var hand = card_system_ref.get_all_cards_for_player(target_player_id)
	
	# カード名ごとの出現回数をカウント
	var name_count = {}
	for card in hand:
		var card_name = card.get("name", "")
		if card_name != "":
			name_count[card_name] = name_count.get(card_name, 0) + 1
	
	# 重複しているカード名を特定
	var duplicate_names = []
	for card_name in name_count.keys():
		if name_count[card_name] >= 2:
			duplicate_names.append(card_name)
	
	if duplicate_names.is_empty():
		print("[エロージョン] プレイヤー%d: 重複カードなし" % [target_player_id + 1])
		return {"total_destroyed": 0, "duplicates": []}
	
	# 逆順で重複カードを破壊
	var destroyed_count = 0
	for i in range(hand.size() - 1, -1, -1):
		var card = hand[i]
		var card_name = card.get("name", "")
		if card_name in duplicate_names:
			card_system_ref.discard_card(target_player_id, i, "destroy")
			print("[重複カード破壊] プレイヤー%d: %s" % [target_player_id + 1, card_name])
			destroyed_count += 1
	
	print("[エロージョン] プレイヤー%d: %d 枚の重複カードを破壊（%s）" % [target_player_id + 1, destroyed_count, str(duplicate_names)])
	
	return {
		"total_destroyed": destroyed_count,
		"duplicates": duplicate_names
	}

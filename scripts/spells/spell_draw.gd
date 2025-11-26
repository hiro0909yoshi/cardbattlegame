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

# CardSacrificeHelper - カード犠牲システム共通ヘルパー
# スペル合成・クリーチャー合成スキルの両方で使用
class_name CardSacrificeHelper


# ============ 参照 ============

var card_system_ref: Object
var player_system_ref: Object
var ui_manager_ref: Object


# ============ 状態 ============

var _selected_card: Dictionary = {}
var _selected_index: int = -1


# ============ 初期化 ============

func _init(card_sys: Object, player_sys: Object, ui_manager: Object = null) -> void:
	card_system_ref = card_sys
	player_system_ref = player_sys
	ui_manager_ref = ui_manager


func set_ui_manager(ui_manager: Object) -> void:
	ui_manager_ref = ui_manager


# ============ 手札選択 ============

## 手札選択UIを表示し、選択されたカードを返す
## filter: "creature", "spell", "item", "" (全て)
func show_hand_selection(player_id: int, filter: String = "", message: String = "犠牲にするカードを選択") -> Dictionary:
	_selected_card = {}
	_selected_index = -1
	
	if not card_system_ref:
		push_error("[CardSacrificeHelper] card_system_ref が未設定")
		return {}
	
	var hand = card_system_ref.get_all_cards_for_player(player_id)
	if hand.is_empty():
		print("[CardSacrificeHelper] 手札が空です")
		return {}
	
	# UIManagerがない場合はフォールバック
	if not ui_manager_ref:
		print("[CardSacrificeHelper] UIManager未設定、最初のカードを使用")
		return _fallback_selection(hand, filter)
	
	# メッセージ表示
	if ui_manager_ref.has_method("set_message"):
		ui_manager_ref.set_message(message)
	
	# カード選択UIを表示
	if player_system_ref:
		var player = player_system_ref.players[player_id]
		# フィルターをクリア（全カード選択可能にする）
		ui_manager_ref.card_selection_filter = ""
		# sacrifice モードで表示
		ui_manager_ref.show_card_selection_ui_mode(player, "sacrifice")
	
	# カード選択を待つ
	var selected_index = await ui_manager_ref.card_selected
	
	# UIを閉じる
	ui_manager_ref.hide_card_selection_ui()
	
	# 選択されたカードを取得
	if selected_index >= 0 and selected_index < hand.size():
		_selected_card = hand[selected_index]
		_selected_index = selected_index
		print("[CardSacrificeHelper] カード選択: %s" % _selected_card.get("name", "不明"))
		return _selected_card
	
	print("[CardSacrificeHelper] カード選択キャンセル")
	return {}


## 選択されたカードを取得
func get_selected_card() -> Dictionary:
	return _selected_card


## 選択されたカードのインデックスを取得
func get_selected_index() -> int:
	return _selected_index


# ============ カード破棄 ============

## 手札からカードを破棄（犠牲にする）
func consume_card(player_id: int, card: Dictionary) -> bool:
	if not card_system_ref:
		push_error("[CardSacrificeHelper] card_system_ref が未設定")
		return false
	
	if card.is_empty():
		push_error("[CardSacrificeHelper] 破棄するカードが空です")
		return false
	
	var hand = card_system_ref.get_all_cards_for_player(player_id)
	var card_id = card.get("id", -1)
	var card_name = card.get("name", "不明")
	
	# カードを探して削除
	for i in range(hand.size()):
		if hand[i].get("id") == card_id:
			card_system_ref.player_hands[player_id]["data"].remove_at(i)
			print("[CardSacrificeHelper] %s を犠牲にしました" % card_name)
			
			# hand_updatedシグナルを発行
			if card_system_ref.has_signal("hand_updated"):
				card_system_ref.emit_signal("hand_updated")
			
			return true
	
	push_error("[CardSacrificeHelper] カード %s が手札に見つかりません" % card_name)
	return false


## 選択中のカードを破棄
func consume_selected_card(player_id: int) -> bool:
	return consume_card(player_id, _selected_card)


# ============ ユーティリティ ============

## フィルタに合うカードがあるか確認
func has_valid_cards(player_id: int, filter: String = "") -> bool:
	if not card_system_ref:
		return false
	
	var hand = card_system_ref.get_all_cards_for_player(player_id)
	
	if filter.is_empty():
		return hand.size() > 0
	
	for card in hand:
		if card.get("type") == filter:
			return true
	
	return false


## フィルタに合うカード一覧を取得
func get_valid_cards(player_id: int, filter: String = "") -> Array:
	var result: Array = []
	
	if not card_system_ref:
		return result
	
	var hand = card_system_ref.get_all_cards_for_player(player_id)
	
	for card in hand:
		if filter.is_empty() or card.get("type") == filter:
			result.append(card)
	
	return result


# ============ 内部処理 ============

## UIがない場合のフォールバック選択
func _fallback_selection(hand: Array, filter: String) -> Dictionary:
	for card in hand:
		if filter.is_empty() or card.get("type") == filter:
			_selected_card = card
			_selected_index = hand.find(card)
			return card
	return {}

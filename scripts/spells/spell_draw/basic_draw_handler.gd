class_name BasicDrawHandler
extends RefCounted
## 基本ドロー処理ハンドラー
##
## 担当effect_type:
## - draw, draw_cards: 固定枚数ドロー
## - draw_by_rank: 順位に応じたドロー
## - draw_by_type: タイプ指定ドロー（プロフェシー）
## - discard_and_draw_plus: 手札入替（リンカネーション）
## - add_specific_card: 特定カード生成（ハイプクイーン）
## - draw_and_place: ドロー＋配置（ワイルドセンス）
## - draw_until: 上限までドロー


# ============================================================
# システム参照
# ============================================================

var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null
var ui_manager_ref = null
var spell_creature_place_ref = null
var board_system_ref = null
var _message_service = null
var _card_selection_service = null


# ============================================================
# 初期化
# ============================================================

func setup(card_system: CardSystem, player_system = null) -> void:
	card_system_ref = card_system
	player_system_ref = player_system


func set_ui_manager(ui_manager) -> void:
	ui_manager_ref = ui_manager
	if ui_manager:
		_message_service = ui_manager.message_service if ui_manager.get("message_service") else null
		_card_selection_service = ui_manager.card_selection_service if ui_manager.get("card_selection_service") else null


func set_board_system(board_system) -> void:
	board_system_ref = board_system


func set_spell_creature_place(spell_creature_place) -> void:
	spell_creature_place_ref = spell_creature_place


# ============================================================
# メイン処理
# ============================================================

## effect_typeに応じた処理を実行
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
		
		"draw_by_type":
			var card_type = effect.get("card_type", "")
			if card_type != "":
				result = draw_card_by_type(player_id, card_type)
			else:
				_start_type_selection_draw(player_id)
				result["async"] = true
		
		"discard_and_draw_plus":
			result["drawn"] = discard_and_draw_plus(player_id)
		
		"add_specific_card":
			var card_id = effect.get("card_id", -1)
			result = add_specific_card_to_hand(player_id, card_id)
		
		"draw_and_place":
			result = _apply_draw_and_place(effect, player_id)
		
		"draw_until":
			var target_size = effect.get("target_hand_size", 6)
			result["drawn"] = draw_until(player_id, target_size)
		
		_:
			return {}  # 未対応
	
	return result


## このハンドラーが処理可能なeffect_typeか判定
func can_handle(effect_type: String) -> bool:
	return effect_type in [
		"draw", "draw_cards", "draw_by_rank", "draw_by_type",
		"discard_and_draw_plus", "add_specific_card", "draw_and_place", "draw_until"
	]


# ============================================================
# ドロー処理
# ============================================================

## 1枚ドロー（ターン開始用）
func draw_one(player_id: int) -> Dictionary:
	if not card_system_ref:
		push_error("BasicDrawHandler: CardSystemが設定されていません")
		return {}
	
	var card = card_system_ref.draw_card_for_player(player_id)
	
	if not card.is_empty():
		print("[ドロー] プレイヤー", player_id + 1, "が1枚引きました: ", card.get("name", "不明"))
	else:
		print("[ドロー] プレイヤー", player_id + 1, "はカードを引けませんでした")
	
	return card


## 固定枚数ドロー
func draw_cards(player_id: int, count: int) -> Array:
	if not card_system_ref:
		push_error("BasicDrawHandler: CardSystemが設定されていません")
		return []
	
	if count <= 0:
		print("[ドロー] プレイヤー", player_id + 1, "は0枚指定のため何も引きません")
		return []
	
	var drawn = card_system_ref.draw_cards_for_player(player_id, count)
	print("[ドロー] プレイヤー", player_id + 1, "が", drawn.size(), "枚引きました（要求: ", count, "枚）")
	
	return drawn


## 上限までドロー
func draw_until(player_id: int, target_hand_size: int) -> Array:
	if not card_system_ref:
		push_error("BasicDrawHandler: CardSystemが設定されていません")
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


## 順位に応じたドロー（ギフト用）
func draw_by_rank(player_id: int, rank: int) -> Array:
	if not card_system_ref:
		push_error("BasicDrawHandler: CardSystemが設定されていません")
		return []
	
	if rank <= 0:
		return []
	
	var drawn = card_system_ref.draw_cards_for_player(player_id, rank)
	print("[順位ドロー] プレイヤー", player_id + 1, ": ", rank, "位 → ", drawn.size(), "枚ドロー")
	
	return drawn


## タイプ指定ドロー（プロフェシー用）
func draw_card_by_type(player_id: int, card_type: String) -> Dictionary:
	if not card_system_ref:
		push_error("BasicDrawHandler: CardSystemが設定されていません")
		return {"drawn": false, "card_name": "", "card_data": {}}
	
	var deck = card_system_ref.player_decks.get(player_id, [])
	
	for i in range(deck.size()):
		var card_id = deck[i]
		var card_data = CardLoader.get_card_by_id(card_id)
		if card_data and card_data.get("type", "") == card_type:
			card_system_ref.player_decks[player_id].remove_at(i)
			card_system_ref.return_card_to_hand(player_id, card_data.duplicate(true))
			var card_name = card_data.get("name", "?")
			print("[プロフェシー] プレイヤー%d: デッキから『%s』（%s）を引きました" % [player_id + 1, card_name, card_type])
			return {"drawn": true, "card_name": card_name, "card_data": card_data}
	
	print("[プロフェシー] プレイヤー%d: デッキに%sがありません" % [player_id + 1, card_type])
	return {"drawn": false, "card_name": "", "card_data": {}}


## 手札全捨て+元枚数ドロー（リンカネーション用）
func discard_and_draw_plus(player_id: int) -> Array:
	if not card_system_ref:
		push_error("BasicDrawHandler: CardSystemが設定されていません")
		return []
	
	var hand_size = card_system_ref.get_hand_size_for_player(player_id)
	
	for i in range(hand_size):
		card_system_ref.discard_card(player_id, 0, "reincarnation")
	
	var drawn = card_system_ref.draw_cards_for_player(player_id, hand_size)
	print("[リンカネーション] プレイヤー", player_id + 1, ": 手札入替 → ", drawn.size(), "枚ドロー")
	
	return drawn


## 手札全交換
func exchange_all_hand(player_id: int) -> Array:
	if not card_system_ref:
		push_error("BasicDrawHandler: CardSystemが設定されていません")
		return []
	
	var hand_size = card_system_ref.get_hand_size_for_player(player_id)
	
	if hand_size == 0:
		print("[手札交換] プレイヤー", player_id + 1, "は手札が0枚のため交換しません")
		return []
	
	print("[手札交換] プレイヤー", player_id + 1, "が", hand_size, "枚の手札を交換します")
	
	for i in range(hand_size):
		card_system_ref.discard_card(player_id, 0, "exchange")
	
	var drawn = card_system_ref.draw_cards_for_player(player_id, hand_size)
	print("[手札交換] プレイヤー", player_id + 1, "が", drawn.size(), "枚の新しい手札を引きました")
	
	return drawn


## 特定カードを手札に生成（ハイプクイーン用）
func add_specific_card_to_hand(player_id: int, card_id: int) -> Dictionary:
	if not card_system_ref:
		push_error("BasicDrawHandler: card_system_refが未設定")
		return {"success": false, "card_name": ""}
	
	var card_data = CardLoader.get_card_by_id(card_id)
	if card_data.is_empty():
		push_error("BasicDrawHandler: カードID %d が見つかりません" % card_id)
		return {"success": false, "card_name": ""}
	
	card_system_ref.return_card_to_hand(player_id, card_data.duplicate(true))
	var card_name = card_data.get("name", "?")
	print("[カード生成] プレイヤー%d: 『%s』を手札に追加" % [player_id + 1, card_name])
	
	if _card_selection_service:
		_card_selection_service.update_hand_display(player_id)

	return {"success": true, "card_name": card_name}


# ============================================================
# タイプ選択UI処理
# ============================================================

## タイプ選択ドロー開始（callback方式・プロフェシー用）
func _start_type_selection_draw(player_id: int) -> void:
	if not ui_manager_ref:
		push_error("BasicDrawHandler: UIManagerが設定されていません")
		return
	
	var spell_and_mystic_ui = ui_manager_ref.get_node_or_null("SpellAndMysticUI")
	if not spell_and_mystic_ui:
		var SpellAndMysticUIClass = load("res://scripts/ui_components/spell_and_mystic_ui.gd")
		if not SpellAndMysticUIClass:
			return
		spell_and_mystic_ui = SpellAndMysticUIClass.new()
		spell_and_mystic_ui.name = "SpellAndMysticUI"
		spell_and_mystic_ui.set_ui_manager(ui_manager_ref)
		ui_manager_ref.add_child(spell_and_mystic_ui)
	
	if _message_service:
		_message_service.show_action_prompt("引くカードのタイプを選択してください")
	
	spell_and_mystic_ui.show_type_selection()
	
	if spell_and_mystic_ui.is_connected("type_selected", _on_type_selected):
		spell_and_mystic_ui.disconnect("type_selected", _on_type_selected)
	spell_and_mystic_ui.type_selected.connect(_on_type_selected.bind(player_id, spell_and_mystic_ui), CONNECT_ONE_SHOT)


## タイプ選択完了時のコールバック
func _on_type_selected(selected_type: String, player_id: int, spell_ui: Node) -> void:
	spell_ui.hide_all()
	
	var result = draw_card_by_type(player_id, selected_type)
	
	if result.get("drawn", false):
		if _message_service:
			await _message_service.show_comment_and_wait("『%s』を引きました" % result.get("card_name", "?"))
	else:
		if _message_service:
			_message_service.show_toast("デッキに該当タイプがありません")
	
	if _card_selection_service:
		_card_selection_service.update_hand_display(player_id)


# ============================================================
# ドロー＋配置処理
# ============================================================

## draw_and_place効果を適用（ワイルドセンス用）
func _apply_draw_and_place(effect: Dictionary, player_id: int) -> Dictionary:
	var draw_count = effect.get("draw_count", 1)
	var placement_mode = effect.get("placement_mode", "random")
	var card_type_filter = effect.get("card_type_filter", "creature")
	var result = {"success": false, "placed": []}
	
	if not card_system_ref:
		print("[draw_and_place] CardSystemがありません")
		return result
	
	var drawn_cards = card_system_ref.draw_cards_for_player(player_id, draw_count)
	
	if drawn_cards.is_empty():
		print("[draw_and_place] カードを引けませんでした")
		return result
	
	for card in drawn_cards:
		var card_type = card.get("type", "")
		var card_name = card.get("name", "?")
		var card_id = card.get("id", -1)
		
		print("[draw_and_place] 引いたカード: %s (type: %s)" % [card_name, card_type])
		
		if card_type_filter == "creature" and card_type == "creature":
			var hand = card_system_ref.get_all_cards_for_player(player_id)
			if hand.size() > 0:
				var card_index = -1
				for i in range(hand.size() - 1, -1, -1):
					if hand[i].get("id", -1) == card_id:
						card_index = i
						break
				
				if card_index >= 0:
					card_system_ref.use_card_for_player(player_id, card_index)
					print("[draw_and_place] 手札からカードを消費: index=%d" % card_index)
			
			if placement_mode == "random" and spell_creature_place_ref and board_system_ref:
				var success = spell_creature_place_ref.place_creature_random(
					board_system_ref, player_id, card_id, CardLoader, true
				)
				if success:
					print("[draw_and_place] %s をランダムな空地に配置しました" % card_name)
					result["placed"].append(card_name)
					result["success"] = true
				else:
					print("[draw_and_place] 配置失敗 - 空地がありません")
		else:
			print("[draw_and_place] %s はクリーチャーではないため手札に残ります" % card_name)
	
	return result

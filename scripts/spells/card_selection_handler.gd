extends Node
class_name CardSelectionHandler
## カード選択ハンドラー
## 敵手札選択、デッキカード選択などのカード選択UIを管理

## 選択完了シグナル
signal selection_completed()

## 状態
enum State {
	INACTIVE,
	SELECTING_ENEMY_CARD,  # 敵手札からカード選択中
	SELECTING_DECK_CARD,   # デッキ上部からカード選択中
	SELECTING_TRANSFORM_CARD  # カード変換用選択中（メタモルフォシス）
}

var current_state: State = State.INACTIVE

## 敵手札選択用変数
var enemy_card_selection_target_id: int = -1
var enemy_card_selection_filter_mode: String = ""
var enemy_card_selection_callback: Callable
var enemy_card_selection_is_steal: bool = false

## カード変換用変数（メタモルフォシス）
var transform_target_player_id: int = -1
var transform_to_card_id: int = -1

## デッキカード選択用変数
var deck_card_selection_target_id: int = -1
var deck_card_selection_cards: Array = []
var deck_card_selection_callback: Callable
var deck_card_selection_is_draw: bool = false  # true = ドロー、false = 破壊

## 参照
var ui_manager = null
var player_system = null
var card_system = null
var spell_draw = null
var spell_phase_ui_manager = null
var current_player_id: int = -1

## セットアップ
func setup(p_ui_manager, p_player_system, p_card_system, p_spell_draw, p_spell_phase_ui_manager):
	ui_manager = p_ui_manager
	player_system = p_player_system
	card_system = p_card_system
	spell_draw = p_spell_draw
	spell_phase_ui_manager = p_spell_phase_ui_manager

## 現在のプレイヤーIDを設定
func set_current_player(player_id: int):
	current_player_id = player_id

## 選択中かどうか
func is_selecting() -> bool:
	return current_state != State.INACTIVE

## 敵手札選択中かどうか
func is_selecting_enemy_card() -> bool:
	return current_state == State.SELECTING_ENEMY_CARD

## デッキカード選択中かどうか
func is_selecting_deck_card() -> bool:
	return current_state == State.SELECTING_DECK_CARD

## カード変換選択中かどうか
func is_selecting_transform_card() -> bool:
	return current_state == State.SELECTING_TRANSFORM_CARD

# ============ 敵手札選択システム ============

## 敵手札選択を開始
func start_enemy_card_selection(target_player_id: int, filter_mode: String, callback: Callable, is_steal: bool = false):
	"""
	敵プレイヤーの手札からカードを選択するUIを開始
	
	引数:
	  target_player_id: 対象プレイヤーID
	  filter_mode: フィルターモード（"destroy_item_spell", "destroy_any", "destroy_spell"）
	  callback: 選択完了時のコールバック（card_index: int を引数に取る）
	  is_steal: 奪取モードか（false=破壊、true=奪取）
	"""
	enemy_card_selection_target_id = target_player_id
	enemy_card_selection_filter_mode = filter_mode
	enemy_card_selection_callback = callback
	enemy_card_selection_is_steal = is_steal
	current_state = State.SELECTING_ENEMY_CARD
	
	# 秘術ボタンは非表示（敵手札選択中は使用不可）
	if ui_manager:
		ui_manager.hide_mystic_button()
	
	# 対象の手札を確認
	if not spell_draw:
		_cancel_enemy_card_selection("システムエラー")
		return
	
	var has_valid_cards = spell_draw.has_cards_matching_filter(target_player_id, filter_mode)
	
	if not has_valid_cards:
		# 条件に合うカードがない場合
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "破壊できるカードがありません"
		# コールバックを呼び出して処理を続行（ペナルティとして魔力は消費済み）
		await get_tree().create_timer(1.0).timeout
		callback.call(-1)
		_finish_enemy_card_selection()
		return
	
	# フィルターモードを設定
	if ui_manager:
		ui_manager.card_selection_filter = filter_mode
	
	# 対象プレイヤーの手札を表示
	if ui_manager and ui_manager.hand_display:
		# 自動更新を無効化
		ui_manager.hand_display.is_enemy_card_selection_active = true
		ui_manager.hand_display.update_hand_display(target_player_id)
	
	# 選択UIを有効化
	if ui_manager and ui_manager.card_selection_ui and card_system:
		var hand_data = card_system.get_all_cards_for_player(target_player_id)
		var magic = 999999  # 魔力チェック不要
		ui_manager.card_selection_ui.enable_card_selection(hand_data, magic, target_player_id)
	
	# ガイド表示
	var player_name = "プレイヤー%d" % (target_player_id + 1)
	if player_system and target_player_id < player_system.players.size():
		player_name = player_system.players[target_player_id].name
	
	if ui_manager and ui_manager.phase_label:
		if enemy_card_selection_is_steal:
			ui_manager.phase_label.text = "%sの手札から奪うカードを選択してください" % player_name
		else:
			ui_manager.phase_label.text = "%sの手札から破壊するカードを選択してください" % player_name

## 敵手札からカードが選択された
func on_enemy_card_selected(card_index: int):
	"""
	敵手札選択でカードが選択された時のコールバック
	GameFlowManager.on_card_selected から呼び出される
	"""
	if current_state != State.SELECTING_ENEMY_CARD:
		return
	
	if spell_draw:
		if enemy_card_selection_is_steal:
			# 奪取モード（セフト）
			var result = spell_draw.steal_card_at_index(
				enemy_card_selection_target_id, current_player_id, card_index
			)
			if result.get("stolen", false):
				if ui_manager and ui_manager.phase_label:
					ui_manager.phase_label.text = "『%s』を奪いました" % result.get("card_name", "?")
		else:
			# 破壊モード（シャッター、スクイーズ）
			var result = spell_draw.destroy_card_at_index(enemy_card_selection_target_id, card_index)
			if result.get("destroyed", false):
				if ui_manager and ui_manager.phase_label:
					ui_manager.phase_label.text = "『%s』を破壊しました" % result.get("card_name", "?")
	
	# コールバックを呼び出し
	if enemy_card_selection_callback:
		enemy_card_selection_callback.call(card_index)
	
	# 選択終了
	_finish_enemy_card_selection()

## 敵手札選択をキャンセル
func _cancel_enemy_card_selection(message: String = ""):
	if message != "" and ui_manager and ui_manager.phase_label:
		ui_manager.phase_label.text = message
	
	# コールバックを呼び出し（-1 = 選択なし）
	if enemy_card_selection_callback:
		enemy_card_selection_callback.call(-1)
	
	_finish_enemy_card_selection()

## 敵手札選択を終了
func _finish_enemy_card_selection():
	enemy_card_selection_target_id = -1
	enemy_card_selection_filter_mode = ""
	enemy_card_selection_is_steal = false
	
	# 元の手札表示に戻す
	if ui_manager:
		ui_manager.card_selection_filter = ""
		if ui_manager.hand_display and player_system:
			# 自動更新を再有効化
			ui_manager.hand_display.is_enemy_card_selection_active = false
			
			var current_player = player_system.get_current_player()
			if current_player:
				ui_manager.hand_display.update_hand_display(current_player.id)
	
	current_state = State.INACTIVE
	
	# 少し待機してから完了シグナル発火
	await get_tree().create_timer(0.5).timeout
	selection_completed.emit()

# ============ デッキカード選択システム（ポイズンマインド等） ============

## デッキカード選択を開始
func start_deck_card_selection(target_player_id: int, look_count: int, callback: Callable):
	"""
	対象プレイヤーのデッキ上部からカードを選択するUIを開始
	
	引数:
	  target_player_id: 対象プレイヤーID
	  look_count: 見る枚数
	  callback: 選択完了時のコールバック（card_index: int を引数に取る）
	"""
	deck_card_selection_target_id = target_player_id
	deck_card_selection_callback = callback
	current_state = State.SELECTING_DECK_CARD
	
	# スペルフェーズボタンを非表示
	# 秘術ボタンは非表示
	if ui_manager:
		ui_manager.hide_mystic_button()
	
	# デッキ上部のカードを取得
	if not spell_draw:
		_cancel_deck_card_selection("システムエラー")
		return
	
	deck_card_selection_cards = spell_draw.get_top_cards_from_deck(target_player_id, look_count)
	
	if deck_card_selection_cards.is_empty():
		# デッキが空の場合
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "デッキにカードがありません"
		await get_tree().create_timer(1.0).timeout
		callback.call(-1)
		_finish_deck_card_selection()
		return
	
	# フィルターモードを設定（全カード選択可）
	if ui_manager:
		ui_manager.card_selection_filter = "destroy_any"
	
	# デッキカードを一時的に画面下部に表示
	if ui_manager and ui_manager.hand_display:
		ui_manager.hand_display.is_enemy_card_selection_active = true
		# デッキカードを一時的な手札として表示
		_display_deck_cards_as_hand(deck_card_selection_cards, target_player_id)
	
	# 選択UIを有効化（player_id = -1 はデッキカード表示用）
	if ui_manager and ui_manager.card_selection_ui:
		var magic = 999999  # 魔力チェック不要
		ui_manager.card_selection_ui.enable_card_selection(deck_card_selection_cards, magic, -1)
	
	# ガイド表示
	var player_name = "プレイヤー%d" % (target_player_id + 1)
	if player_system and target_player_id < player_system.players.size():
		player_name = player_system.players[target_player_id].name
	
	if ui_manager and ui_manager.phase_label:
		ui_manager.phase_label.text = "%sのデッキから破壊するカードを選択してください" % player_name

## デッキカード選択を開始（ドローモード：選んだカードを手札に加える）
func start_deck_draw_selection(player_id: int, look_count: int, callback: Callable):
	"""
	自分のデッキ上部からカードを選んで手札に加えるUIを開始（フォーサイト用）
	
	引数:
	  player_id: プレイヤーID（自分）
	  look_count: 見る枚数
	  callback: 選択完了時のコールバック（card_index: int を引数に取る）
	"""
	deck_card_selection_target_id = player_id
	deck_card_selection_callback = callback
	deck_card_selection_is_draw = true  # ドローモード
	current_state = State.SELECTING_DECK_CARD
	
	# スペルフェーズボタンを非表示
	# 秘術ボタンは非表示
	if ui_manager:
		ui_manager.hide_mystic_button()
	
	# デッキ上部のカードを取得
	if not spell_draw:
		_cancel_deck_card_selection("システムエラー")
		return
	
	deck_card_selection_cards = spell_draw.get_top_cards_from_deck(player_id, look_count)
	
	if deck_card_selection_cards.is_empty():
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "デッキにカードがありません"
		await get_tree().create_timer(1.0).timeout
		callback.call(-1)
		_finish_deck_card_selection()
		return
	
	# フィルターモードを設定（全カード選択可）
	if ui_manager:
		ui_manager.card_selection_filter = "destroy_any"
	
	# デッキカードを一時的に画面下部に表示
	if ui_manager and ui_manager.hand_display:
		ui_manager.hand_display.is_enemy_card_selection_active = true
		_display_deck_cards_as_hand(deck_card_selection_cards, player_id)
	
	# 選択UIを有効化
	if ui_manager and ui_manager.card_selection_ui:
		var magic = 999999
		ui_manager.card_selection_ui.enable_card_selection(deck_card_selection_cards, magic, -1)
	
	# ガイド表示
	if ui_manager and ui_manager.phase_label:
		ui_manager.phase_label.text = "デッキから引くカードを選択してください"

## デッキカードを一時的に画面下部に表示
func _display_deck_cards_as_hand(cards: Array, _owner_player_id: int):
	"""デッキカードを一時的に手札表示エリアに表示"""
	if not ui_manager or not ui_manager.hand_display:
		return
	
	var hand_display = ui_manager.hand_display
	var hand_container = hand_display.hand_container
	
	if not hand_container:
		return
	
	# 既存のカードノードをクリア
	for pid in hand_display.player_card_nodes.keys():
		for card_node in hand_display.player_card_nodes[pid]:
			if is_instance_valid(card_node):
				card_node.queue_free()
		hand_display.player_card_nodes[pid].clear()
	
	# デッキカードを表示（特別なプレイヤーID = -1 を使用）
	hand_display.player_card_nodes[-1] = []
	
	for i in range(cards.size()):
		var card_data = cards[i]
		var card_node = hand_display.create_card_node(card_data, i, -1)
		if card_node:
			hand_display.player_card_nodes[-1].append(card_node)
	
	# カードを中央配置
	hand_display.rearrange_hand(-1)

## デッキカードが選択された
func on_deck_card_selected(card_index: int):
	"""
	デッキカード選択でカードが選択された時のコールバック
	GameFlowManager.on_card_selected から呼び出される
	"""
	if current_state != State.SELECTING_DECK_CARD:
		return
	
	if spell_draw:
		if deck_card_selection_is_draw:
			# ドローモード：選んだカードを手札に加える
			var result = spell_draw.draw_from_deck_at_index(deck_card_selection_target_id, card_index)
			if result.get("drawn", false):
				if ui_manager and ui_manager.phase_label:
					ui_manager.phase_label.text = "『%s』を引きました" % result.get("card_name", "?")
		else:
			# 破壊モード
			var result = spell_draw.destroy_deck_card_at_index(deck_card_selection_target_id, card_index)
			if result.get("destroyed", false):
				if ui_manager and ui_manager.phase_label:
					ui_manager.phase_label.text = "『%s』を破壊しました" % result.get("card_name", "?")
	
	# コールバックを呼び出し
	if deck_card_selection_callback:
		deck_card_selection_callback.call(card_index)
	
	# 選択終了
	_finish_deck_card_selection()

## デッキカード選択をキャンセル
func _cancel_deck_card_selection(message: String = ""):
	if message != "" and ui_manager and ui_manager.phase_label:
		ui_manager.phase_label.text = message
	
	# コールバックを呼び出し（-1 = 選択なし）
	if deck_card_selection_callback:
		deck_card_selection_callback.call(-1)
	
	_finish_deck_card_selection()

## デッキカード選択を終了
func _finish_deck_card_selection():
	deck_card_selection_target_id = -1
	deck_card_selection_cards.clear()
	deck_card_selection_is_draw = false  # フラグリセット
	
	# 一時表示したカードノードをクリア
	if ui_manager and ui_manager.hand_display:
		var hand_display = ui_manager.hand_display
		if hand_display.player_card_nodes.has(-1):
			for card_node in hand_display.player_card_nodes[-1]:
				if is_instance_valid(card_node):
					card_node.queue_free()
			hand_display.player_card_nodes[-1].clear()
			hand_display.player_card_nodes.erase(-1)
	
	# 元の手札表示に戻す
	if ui_manager:
		ui_manager.card_selection_filter = ""
		if ui_manager.hand_display and player_system:
			ui_manager.hand_display.is_enemy_card_selection_active = false
			
			var current_player = player_system.get_current_player()
			if current_player:
				ui_manager.hand_display.update_hand_display(current_player.id)
	
	current_state = State.INACTIVE
	
	# 少し待機してから完了シグナル発火
	await get_tree().create_timer(0.5).timeout
	selection_completed.emit()

# ============ カード変換選択システム（メタモルフォシス） ============

## カード変換用の敵手札選択を開始
func start_transform_card_selection(target_player_id: int, filter_mode: String, transform_to_id: int):
	"""
	敵プレイヤーの手札からカードを選択し、同名カードを全て変換するUIを開始
	
	引数:
	  target_player_id: 対象プレイヤーID
	  filter_mode: フィルターモード（"item_or_spell"）
	  transform_to_id: 変換先カードID（ホーリーワード6 = 2100）
	"""
	transform_target_player_id = target_player_id
	transform_to_card_id = transform_to_id
	enemy_card_selection_filter_mode = filter_mode
	current_state = State.SELECTING_TRANSFORM_CARD
	
	# 秘術ボタンは非表示
	if ui_manager:
		ui_manager.hide_mystic_button()
	
	# 対象の手札を確認
	if not spell_draw:
		_cancel_transform_card_selection("システムエラー")
		return
	
	var has_valid_cards = spell_draw.has_item_or_spell_in_hand(target_player_id)
	
	if not has_valid_cards:
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "変換できるカードがありません"
		await get_tree().create_timer(1.0).timeout
		_finish_transform_card_selection()
		return
	
	# フィルターモードを設定
	if ui_manager:
		ui_manager.card_selection_filter = filter_mode
	
	# 対象プレイヤーの手札を表示
	if ui_manager and ui_manager.hand_display:
		ui_manager.hand_display.is_enemy_card_selection_active = true
		ui_manager.hand_display.update_hand_display(target_player_id)
	
	# 選択UIを有効化
	if ui_manager and ui_manager.card_selection_ui and card_system:
		var hand_data = card_system.get_all_cards_for_player(target_player_id)
		var magic = 999999
		ui_manager.card_selection_ui.enable_card_selection(hand_data, magic, target_player_id)
	
	# ガイド表示
	var player_name = "プレイヤー%d" % (target_player_id + 1)
	if player_system and target_player_id < player_system.players.size():
		player_name = player_system.players[target_player_id].name
	
	if ui_manager and ui_manager.phase_label:
		ui_manager.phase_label.text = "%sの手札から変換するアイテムかスペルを選択" % player_name

## カード変換用にカードが選択された
func on_transform_card_selected(card_index: int):
	"""
	カード変換選択でカードが選択された時のコールバック
	GameFlowManager.on_card_selected から呼び出される
	"""
	if current_state != State.SELECTING_TRANSFORM_CARD:
		return
	
	if card_system and spell_draw:
		var hand = card_system.get_all_cards_for_player(transform_target_player_id)
		if card_index >= 0 and card_index < hand.size():
			var selected_card = hand[card_index]
			var selected_name = selected_card.get("name", "")
			var selected_id = selected_card.get("id", -1)
			
			# 同名カードを全て変換（手札＋デッキ）
			var result = spell_draw.transform_cards_to_specific(
				transform_target_player_id,
				selected_name,
				selected_id,
				transform_to_card_id
			)
			
			if result.get("transformed_count", 0) > 0:
				if ui_manager and ui_manager.phase_label:
					ui_manager.phase_label.text = "『%s』%d枚を『%s』に変換" % [
						result.get("original_name", "?"),
						result.get("transformed_count", 0),
						result.get("new_name", "?")
					]
	
	# 選択終了
	_finish_transform_card_selection()

## カード変換選択をキャンセル
func _cancel_transform_card_selection(message: String = ""):
	if message != "" and ui_manager and ui_manager.phase_label:
		ui_manager.phase_label.text = message
	
	_finish_transform_card_selection()

## カード変換選択を終了
func _finish_transform_card_selection():
	transform_target_player_id = -1
	transform_to_card_id = -1
	enemy_card_selection_filter_mode = ""
	
	# 元の手札表示に戻す
	if ui_manager:
		ui_manager.card_selection_filter = ""
		if ui_manager.hand_display and player_system:
			ui_manager.hand_display.is_enemy_card_selection_active = false
			
			var current_player = player_system.get_current_player()
			if current_player:
				ui_manager.hand_display.update_hand_display(current_player.id)
	
	current_state = State.INACTIVE
	
	# 少し待機してから完了シグナル発火
	await get_tree().create_timer(0.5).timeout
	selection_completed.emit()

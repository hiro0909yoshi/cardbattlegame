extends Node
class_name CardSelectionHandler
## カード選択ハンドラー
## 敵手札選択、デッキカード選択などのカード選択UIを管理

const CardRateEvaluator = preload("res://scripts/cpu_ai/card_rate_evaluator.gd")

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

## 共通：インフォパネル確認待ち情報
var pending_confirmation: Dictionary = {}
# {
#   "card_index": int,
#   "card_data": Dictionary,
#   "action_type": String,  # "destroy", "steal", "swap", "draw", "transform"
#   "on_confirmed": Callable,
#   "on_cancelled": Callable
# }

## インフォパネルシグナル接続フラグ
var _info_panel_signals_connected: bool = false

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
	_connect_info_panel_signals()

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
	
	# アルカナアーツボタンは非表示（敵手札選択中は使用不可）
	if ui_manager:
		ui_manager.hide_mystic_button()
	
	# 対象の手札を確認
	if not spell_draw:
		_cancel_enemy_card_selection("システムエラー")
		return
	
	var has_valid_cards = spell_draw.has_cards_matching_filter(target_player_id, filter_mode)
	
	if not has_valid_cards:
		# 条件に合うカードがない場合
		if ui_manager and ui_manager.phase_display:
			ui_manager.phase_display.show_toast("破壊できるカードがありません")
		# コールバックを呼び出して処理を続行（ペナルティとしてEPは消費済み）
		await get_tree().create_timer(1.0).timeout
		callback.call(-1)
		_finish_enemy_card_selection()
		return
	
	# CPUの場合は自動選択
	if _is_cpu_player(current_player_id):
		# 自分に使う場合（スクイーズ等）は低レートを選択
		var is_self_target = (target_player_id == current_player_id)
		await _cpu_auto_select_enemy_card(target_player_id, filter_mode, callback, is_steal, is_self_target)
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
		var magic = 999999  # EPチェック不要
		ui_manager.card_selection_ui.enable_card_selection(hand_data, magic, target_player_id)
	
	# 入力ロックを解除（グローバルボタン対応）
	if ui_manager and ui_manager.game_flow_manager_ref:
		ui_manager.game_flow_manager_ref.unlock_input()
	
	# ガイド表示
	var player_name = "プレイヤー%d" % (target_player_id + 1)
	if player_system and target_player_id < player_system.players.size():
		player_name = player_system.players[target_player_id].name
	
	if ui_manager and ui_manager.phase_display:
		var message = ""
		if enemy_card_selection_is_steal:
			message = "%sの手札から奪うカードを選択" % player_name
		else:
			message = "%sの手札から破壊するカードを選択" % player_name
		ui_manager.phase_display.show_action_prompt(message)
	
	# 戻るボタンを登録（キャンセル可能に）
	if ui_manager:
		ui_manager.enable_navigation(
			Callable(),  # 決定なし
			func(): _cancel_enemy_card_selection("キャンセルしました")
		)

## CPUプレイヤーかどうか判定
func _is_cpu_player(player_id: int) -> bool:
	# プレイヤー0は人間、1以降はCPU
	return player_id > 0

## CPU用: 手札から自動でカードを選択
func _cpu_auto_select_enemy_card(target_player_id: int, filter_mode: String, callback: Callable, is_steal: bool, is_self_target: bool = false):
	"""CPUが自動で手札からカードを選択（敵の場合は高レート、自分の場合は低レート）"""
	await get_tree().create_timer(0.5).timeout  # 思考時間
	
	if not card_system:
		callback.call(-1)
		_finish_enemy_card_selection()
		return
	
	var hand = card_system.get_all_cards_for_player(target_player_id)
	var valid_indices = []
	
	# フィルターに合うカードを探す
	for i in range(hand.size()):
		var card = hand[i]
		if _card_matches_filter(card, filter_mode):
			valid_indices.append(i)
	
	if valid_indices.is_empty():
		callback.call(-1)
		_finish_enemy_card_selection()
		return
	
	# 対象手札一覧をログ出力
	var target_name = "プレイヤー%d" % (target_player_id + 1)
	if player_system and target_player_id < player_system.players.size():
		target_name = player_system.players[target_player_id].name
	print("[手札確認] %s の対象カード%d枚:" % [target_name, valid_indices.size()])
	for idx in valid_indices:
		var card = hand[idx]
		var rate = CardRateEvaluator.get_rate(card)
		print("  [%d] %s (レート: %d)" % [idx, card.get("name", "?"), rate])
	
	# 自分が対象の場合は低レート、敵が対象の場合は高レートを選択
	var best_index = valid_indices[0]
	var best_rate = CardRateEvaluator.get_rate(hand[best_index])
	for idx in valid_indices:
		var card = hand[idx]
		var rate = CardRateEvaluator.get_rate(card)
		if is_self_target:
			# 自分に使う場合は低レートを選択
			if rate < best_rate:
				best_rate = rate
				best_index = idx
		else:
			# 敵に使う場合は高レートを選択
			if rate > best_rate:
				best_rate = rate
				best_index = idx
	
	# カードを破壊/奪取
	var card_data = hand[best_index]
	var action = "奪取" if is_steal else "破壊"
	var select_reason = "低レート" if is_self_target else "高レート"
	print("[CPU自動選択] %s: %s を%s (%s: %d)" % [target_name, card_data.get("name", "?"), action, select_reason, best_rate])
	
	if is_steal:
		# 奪取: 対象の手札から自分の手札へ
		card_system.discard_card(target_player_id, best_index, "steal")
		card_system.add_card_to_hand(current_player_id, card_data)
		print("[手札奪取] プレイヤー%d: %s を奪取" % [current_player_id + 1, card_data.get("name", "?")])
		if ui_manager and ui_manager.global_comment_ui:
			await ui_manager.global_comment_ui.show_and_wait("『%s』を奪いました" % card_data.get("name", "?"))
	else:
		# 破壊
		card_system.discard_card(target_player_id, best_index, "destroy")
		print("[手札破壊] プレイヤー%d: %s を破壊" % [target_player_id + 1, card_data.get("name", "?")])
		if ui_manager and ui_manager.global_comment_ui:
			await ui_manager.global_comment_ui.show_and_wait("『%s』を破壊しました" % card_data.get("name", "?"))
	
	callback.call(best_index)
	_finish_enemy_card_selection()

## カードがフィルターに合致するか
func _card_matches_filter(card: Dictionary, filter_mode: String) -> bool:
	var card_type = card.get("type", "")
	match filter_mode:
		"destroy_item_spell":
			return card_type == "item" or card_type == "spell"
		"destroy_spell":
			return card_type == "spell"
		"destroy_any":
			return true
		_:
			return true

## 敵手札からカードが選択された
func on_enemy_card_selected(card_index: int):
	"""
	敵手札選択でカードが選択された時のコールバック
	GameFlowManager.on_card_selected から呼び出される
	"""
	if current_state != State.SELECTING_ENEMY_CARD:
		return
	
	# カードデータを取得
	var card_data = _get_enemy_card_data(card_index)
	if card_data.is_empty():
		return
	
	# アクションタイプを決定
	var action_type = "steal" if enemy_card_selection_is_steal else "destroy"
	
	# 共通の確認システムを使用
	_request_card_confirmation(
		card_index,
		card_data,
		action_type,
		func(): _execute_enemy_card_action(card_index),  # 確認時
		func(): _on_enemy_selection_cancelled()  # キャンセル時
	)

## 敵手札のカードデータを取得
func _get_enemy_card_data(card_index: int) -> Dictionary:
	if not card_system:
		return {}
	
	var hand = card_system.get_all_cards_for_player(enemy_card_selection_target_id)
	if card_index < 0 or card_index >= hand.size():
		return {}
	
	return hand[card_index]

## 敵手札選択キャンセル時（選択画面に戻る）
func _on_enemy_selection_cancelled():
	# 選択画面に戻る
	if ui_manager and ui_manager.phase_display:
		var player_name = "プレイヤー%d" % (enemy_card_selection_target_id + 1)
		if player_system and enemy_card_selection_target_id < player_system.players.size():
			player_name = player_system.players[enemy_card_selection_target_id].name
		
		var message = ""
		if enemy_card_selection_is_steal:
			message = "%sの手札から奪うカードを選択" % player_name
		else:
			message = "%sの手札から破壊するカードを選択" % player_name
		ui_manager.phase_display.show_action_prompt(message)
	
	# 戻るボタンを再登録
	if ui_manager:
		ui_manager.enable_navigation(
			Callable(),  # 決定なし
			func(): _cancel_enemy_card_selection("キャンセルしました")
		)

## 敵手札アクションを実行（破壊 or 奪取）
func _execute_enemy_card_action(card_index: int):
	if spell_draw:
		if enemy_card_selection_is_steal:
			# 奪取モード（セフト）
			var result = spell_draw.steal_card_at_index(
				enemy_card_selection_target_id, current_player_id, card_index
			)
			if result.get("stolen", false):
				if ui_manager and ui_manager.global_comment_ui:
					await ui_manager.global_comment_ui.show_and_wait("『%s』を奪いました" % result.get("card_name", "?"))
		else:
			# 破壊モード（シャッター、スクイーズ）
			var result = spell_draw.destroy_card_at_index(enemy_card_selection_target_id, card_index)
			if result.get("destroyed", false):
				if ui_manager and ui_manager.global_comment_ui:
					await ui_manager.global_comment_ui.show_and_wait("『%s』を破壊しました" % result.get("card_name", "?"))
	
	# コールバックを呼び出し
	if enemy_card_selection_callback:
		enemy_card_selection_callback.call(card_index)
	
	# 選択終了
	_finish_enemy_card_selection()

## 敵手札選択をキャンセル
func _cancel_enemy_card_selection(message: String = ""):
	if message != "" and ui_manager and ui_manager.phase_display:
		ui_manager.phase_display.show_toast(message)
	
	# コールバックを呼び出し（-1 = 選択なし）
	if enemy_card_selection_callback:
		enemy_card_selection_callback.call(-1)
	
	_finish_enemy_card_selection()

## 敵手札選択を終了
func _finish_enemy_card_selection():
	enemy_card_selection_target_id = -1
	enemy_card_selection_filter_mode = ""
	enemy_card_selection_is_steal = false
	pending_confirmation.clear()  # 確認待ち情報クリア
	
	# カメラを現在のプレイヤーに戻す
	_restore_camera_to_current_player()
	
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
	# アルカナアーツボタンは非表示
	if ui_manager:
		ui_manager.hide_mystic_button()
	
	# デッキ上部のカードを取得
	if not spell_draw:
		_cancel_deck_card_selection("システムエラー")
		return
	
	deck_card_selection_cards = spell_draw.get_top_cards_from_deck(target_player_id, look_count)
	
	if deck_card_selection_cards.is_empty():
		# デッキが空の場合
		if ui_manager and ui_manager.phase_display:
			ui_manager.phase_display.show_toast("デッキにカードがありません")
		await get_tree().create_timer(1.0).timeout
		callback.call(-1)
		_finish_deck_card_selection()
		return
	
	# CPUの場合は自動選択
	if _is_cpu_player(current_player_id):
		await _cpu_auto_select_deck_card(target_player_id, callback)
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
		var magic = 999999  # EPチェック不要
		ui_manager.card_selection_ui.enable_card_selection(deck_card_selection_cards, magic, -1)
	
	# 入力ロックを解除（グローバルボタン対応）
	if ui_manager and ui_manager.game_flow_manager_ref:
		ui_manager.game_flow_manager_ref.unlock_input()
	
	# ガイド表示
	var player_name = "プレイヤー%d" % (target_player_id + 1)
	if player_system and target_player_id < player_system.players.size():
		player_name = player_system.players[target_player_id].name
	
	if ui_manager and ui_manager.phase_display:
		ui_manager.phase_display.show_action_prompt("%sのデッキから破壊するカードを選択" % player_name)
	
	# 戻るボタンを登録（キャンセル可能に）
	if ui_manager:
		ui_manager.enable_navigation(
			Callable(),  # 決定なし
			func(): _cancel_deck_card_selection("キャンセルしました")
		)

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
	# アルカナアーツボタンは非表示
	if ui_manager:
		ui_manager.hide_mystic_button()
	
	# デッキ上部のカードを取得
	if not spell_draw:
		_cancel_deck_card_selection("システムエラー")
		return
	
	deck_card_selection_cards = spell_draw.get_top_cards_from_deck(player_id, look_count)
	
	if deck_card_selection_cards.is_empty():
		if ui_manager and ui_manager.phase_display:
			ui_manager.phase_display.show_toast("デッキにカードがありません")
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
	
	# 入力ロックを解除（グローバルボタン対応）
	if ui_manager and ui_manager.game_flow_manager_ref:
		ui_manager.game_flow_manager_ref.unlock_input()
	
	# ガイド表示
	if ui_manager and ui_manager.phase_display:
		ui_manager.phase_display.show_action_prompt("デッキから引くカードを選択")
	
	# 戻るボタンを登録（キャンセル可能に）
	if ui_manager:
		ui_manager.enable_navigation(
			Callable(),  # 決定なし
			func(): _cancel_deck_card_selection("キャンセルしました")
		)

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
	
	# カードデータを取得
	if card_index < 0 or card_index >= deck_card_selection_cards.size():
		return
	
	var card_data = deck_card_selection_cards[card_index]
	var action_type = "draw" if deck_card_selection_is_draw else "destroy"
	
	# 共通の確認システムを使用
	_request_card_confirmation(
		card_index,
		card_data,
		action_type,
		func(): _execute_deck_card_action(card_index),  # 確認時
		func(): _on_deck_selection_cancelled()  # キャンセル時
	)

## デッキカード選択キャンセル時（選択画面に戻る）
func _on_deck_selection_cancelled():
	# 選択画面に戻る（何もせずそのまま再選択可能）
	if ui_manager and ui_manager.phase_display:
		var message = ""
		if deck_card_selection_is_draw:
			message = "デッキから引くカードを選択"
		else:
			var player_name = "プレイヤー%d" % (deck_card_selection_target_id + 1)
			if player_system and deck_card_selection_target_id < player_system.players.size():
				player_name = player_system.players[deck_card_selection_target_id].name
			message = "%sのデッキから破壊するカードを選択" % player_name
		ui_manager.phase_display.show_action_prompt(message)
	
	# 戻るボタンを再登録
	if ui_manager:
		ui_manager.enable_navigation(
			Callable(),  # 決定なし
			func(): _cancel_deck_card_selection("キャンセルしました")
		)

## デッキカードアクションを実行（ドロー or 破壊）
func _execute_deck_card_action(card_index: int):
	if spell_draw:
		if deck_card_selection_is_draw:
			# ドローモード：選んだカードを手札に加える
			var result = spell_draw.draw_from_deck_at_index(deck_card_selection_target_id, card_index)
			if result.get("drawn", false):
				if ui_manager and ui_manager.global_comment_ui:
					await ui_manager.global_comment_ui.show_and_wait("『%s』を引きました" % result.get("card_name", "?"))
		else:
			# 破壊モード
			var result = spell_draw.destroy_deck_card_at_index(deck_card_selection_target_id, card_index)
			if result.get("destroyed", false):
				if ui_manager and ui_manager.global_comment_ui:
					await ui_manager.global_comment_ui.show_and_wait("『%s』を破壊しました" % result.get("card_name", "?"))
	
	# コールバックを呼び出し
	if deck_card_selection_callback:
		deck_card_selection_callback.call(card_index)
	
	# 選択終了
	_finish_deck_card_selection()

## デッキカード選択をキャンセル
func _cancel_deck_card_selection(message: String = ""):
	if message != "" and ui_manager and ui_manager.phase_display:
		ui_manager.phase_display.show_toast(message)
	
	# コールバックを呼び出し（-1 = 選択なし）
	if deck_card_selection_callback:
		deck_card_selection_callback.call(-1)
	
	_finish_deck_card_selection()

## デッキカード選択を終了
func _finish_deck_card_selection():
	deck_card_selection_target_id = -1
	deck_card_selection_cards.clear()
	deck_card_selection_is_draw = false  # フラグリセット
	pending_confirmation.clear()  # 確認待ち情報クリア
	
	# カメラを現在のプレイヤーに戻す
	_restore_camera_to_current_player()
	
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
	
	# アルカナアーツボタンは非表示
	if ui_manager:
		ui_manager.hide_mystic_button()
	
	# 対象の手札を確認
	if not spell_draw:
		_cancel_transform_card_selection("システムエラー")
		return
	
	var has_valid_cards = spell_draw.has_item_or_spell_in_hand(target_player_id)
	
	if not has_valid_cards:
		if ui_manager and ui_manager.phase_display:
			ui_manager.phase_display.show_toast("変換できるカードがありません")
		await get_tree().create_timer(1.0).timeout
		_finish_transform_card_selection()
		return
	
	# CPUの場合は自動選択
	if _is_cpu_player(current_player_id):
		await _cpu_auto_select_transform_card(target_player_id, filter_mode)
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
	
	# 入力ロックを解除（グローバルボタン対応）
	if ui_manager and ui_manager.game_flow_manager_ref:
		ui_manager.game_flow_manager_ref.unlock_input()
	
	# ガイド表示
	var player_name = "プレイヤー%d" % (target_player_id + 1)
	if player_system and target_player_id < player_system.players.size():
		player_name = player_system.players[target_player_id].name
	
	if ui_manager and ui_manager.phase_display:
		ui_manager.phase_display.show_action_prompt("%sの手札から変換するアイテムかスペルを選択" % player_name)
	
	# 戻るボタンを登録（キャンセル可能に）
	if ui_manager:
		ui_manager.enable_navigation(
			Callable(),  # 決定なし
			func(): _cancel_transform_card_selection("キャンセルしました")
		)

## カード変換用にカードが選択された
func on_transform_card_selected(card_index: int):
	"""
	カード変換選択でカードが選択された時のコールバック
	GameFlowManager.on_card_selected から呼び出される
	"""
	if current_state != State.SELECTING_TRANSFORM_CARD:
		return
	
	# カードデータを取得
	var card_data = _get_transform_card_data(card_index)
	if card_data.is_empty():
		return
	
	# 共通の確認システムを使用
	_request_card_confirmation(
		card_index,
		card_data,
		"transform",
		func(): _execute_transform_card_action(card_index),  # 確認時
		func(): _on_transform_selection_cancelled()  # キャンセル時
	)

## カード変換対象のカードデータを取得
func _get_transform_card_data(card_index: int) -> Dictionary:
	if not card_system:
		return {}
	
	var hand = card_system.get_all_cards_for_player(transform_target_player_id)
	if card_index < 0 or card_index >= hand.size():
		return {}
	
	return hand[card_index]

## カード変換選択キャンセル時（選択画面に戻る）
func _on_transform_selection_cancelled():
	# 選択画面に戻る
	if ui_manager and ui_manager.phase_display:
		var player_name = "プレイヤー%d" % (transform_target_player_id + 1)
		if player_system and transform_target_player_id < player_system.players.size():
			player_name = player_system.players[transform_target_player_id].name
		ui_manager.phase_display.show_action_prompt("%sの手札から変換するカードを選択" % player_name)
	
	# 戻るボタンを再登録
	if ui_manager:
		ui_manager.enable_navigation(
			Callable(),  # 決定なし
			func(): _cancel_transform_card_selection("キャンセルしました")
		)

## カード変換アクションを実行
func _execute_transform_card_action(card_index: int):
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
				if ui_manager and ui_manager.global_comment_ui:
					await ui_manager.global_comment_ui.show_and_wait("『%s』%d枚を『%s』に変換" % [
						result.get("original_name", "?"),
						result.get("transformed_count", 0),
						result.get("new_name", "?")
					])
	
	# 選択終了
	_finish_transform_card_selection()

## カード変換選択をキャンセル
func _cancel_transform_card_selection(message: String = ""):
	if message != "" and ui_manager and ui_manager.phase_display:
		ui_manager.phase_display.show_toast(message)
	
	_finish_transform_card_selection()

## カード変換選択を終了
func _finish_transform_card_selection():
	transform_target_player_id = -1
	transform_to_card_id = -1
	enemy_card_selection_filter_mode = ""
	pending_confirmation.clear()  # 確認待ち情報クリア
	
	# カメラを現在のプレイヤーに戻す
	_restore_camera_to_current_player()
	
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


# ============ 共通：インフォパネル確認システム ============

## インフォパネルのシグナルを接続（setup時に1回だけ）
func _connect_info_panel_signals():
	if _info_panel_signals_connected or not ui_manager:
		return
	
	if ui_manager.creature_info_panel_ui:
		ui_manager.creature_info_panel_ui.selection_confirmed.connect(_on_info_panel_confirmed)
		ui_manager.creature_info_panel_ui.selection_cancelled.connect(_on_info_panel_cancelled)
	if ui_manager.spell_info_panel_ui:
		ui_manager.spell_info_panel_ui.selection_confirmed.connect(_on_info_panel_confirmed)
		ui_manager.spell_info_panel_ui.selection_cancelled.connect(_on_info_panel_cancelled)
	if ui_manager.item_info_panel_ui:
		ui_manager.item_info_panel_ui.selection_confirmed.connect(_on_info_panel_confirmed)
		ui_manager.item_info_panel_ui.selection_cancelled.connect(_on_info_panel_cancelled)
	
	_info_panel_signals_connected = true

## カード選択後、インフォパネルで確認を要求
func _request_card_confirmation(card_index: int, card_data: Dictionary, action_type: String, on_confirmed: Callable, on_cancelled: Callable):
	# ダブルクリック検出：同じカードを再度クリックした場合は即確定
	var prev_card_index = pending_confirmation.get("card_index", -1)
	var is_panel_visible = _is_any_info_panel_visible()
	
	if prev_card_index == card_index and is_panel_visible:
		_hide_all_info_panels()
		on_confirmed.call()
		return
	
	# 異なるカードを選択した場合、既存のパネルを閉じる
	if is_panel_visible:
		_hide_all_info_panels(false)
	
	# 確認情報を設定
	pending_confirmation = {
		"card_index": card_index,
		"card_data": card_data,
		"action_type": action_type,
		"on_confirmed": on_confirmed,
		"on_cancelled": on_cancelled
	}
	
	_show_info_panel_for_card(card_data, action_type)

## いずれかのインフォパネルが表示中か確認
func _is_any_info_panel_visible() -> bool:
	if not ui_manager:
		return false
	return ui_manager.is_any_info_panel_visible()

## カードタイプに応じたインフォパネルを表示
func _show_info_panel_for_card(card_data: Dictionary, action_type: String):
	if not ui_manager:
		_on_info_panel_confirmed({})
		return
	
	var card_type = card_data.get("type", "")
	var card_index = pending_confirmation.get("card_index", -1)
	var card_name = card_data.get("name", "?")
	
	# アクションタイプに応じた確認テキスト
	var confirmation_text = ""
	match action_type:
		"destroy": confirmation_text = "『%s』を破壊" % card_name
		"steal": confirmation_text = "『%s』を奪う" % card_name
		"swap": confirmation_text = "『%s』と交換" % card_name
		"draw": confirmation_text = "『%s』を引く" % card_name
		"transform": confirmation_text = "『%s』を変換" % card_name
		_: confirmation_text = "『%s』を選択" % card_name
	
	if card_type in ["creature", "spell", "item"]:
		var prompt = confirmation_text if card_type == "creature" else "『%s』に使用しますか？" % card_name
		ui_manager.show_card_selection(card_data, card_index, prompt, "", card_type)
	else:
		_on_info_panel_confirmed({})

## インフォパネル確認時のコールバック
func _on_info_panel_confirmed(_card_data: Dictionary):
	if pending_confirmation.is_empty():
		return  # このハンドラーの処理ではない
	
	_hide_all_info_panels()
	
	if pending_confirmation.has("on_confirmed"):
		var callback = pending_confirmation.get("on_confirmed")
		pending_confirmation.clear()
		callback.call()
	else:
		pending_confirmation.clear()

## インフォパネルキャンセル時のコールバック
func _on_info_panel_cancelled():
	if pending_confirmation.is_empty():
		return  # このハンドラーの処理ではない
	
	_hide_all_info_panels()
	
	if pending_confirmation.has("on_cancelled"):
		var callback = pending_confirmation.get("on_cancelled")
		pending_confirmation.clear()
		callback.call()
	else:
		pending_confirmation.clear()

## 全インフォパネルを非表示
func _hide_all_info_panels(clear_buttons: bool = true):
	if not ui_manager:
		return
	ui_manager.hide_all_info_panels(clear_buttons)

## カメラを現在のプレイヤーに戻す
func _restore_camera_to_current_player():
	if not ui_manager or not ui_manager.board_system_ref:
		return
	
	var camera_ctrl = ui_manager.board_system_ref.camera_controller
	if camera_ctrl:
		camera_ctrl.enable_follow_mode()
		camera_ctrl.return_to_player()


# ============ CPU自動選択（追加） ============

## CPU用: デッキカードから自動でカードを選択（ポイズンマインド用）
func _cpu_auto_select_deck_card(target_player_id: int, callback: Callable):
	"""CPUが自動でデッキ上部からカードを選択して破壊"""
	await get_tree().create_timer(0.5).timeout  # 思考時間
	
	if deck_card_selection_cards.is_empty():
		callback.call(-1)
		_finish_deck_card_selection()
		return
	
	# レートが最も高いカードを選択
	var best_index = 0
	var best_rate = CardRateEvaluator.get_rate(deck_card_selection_cards[0])
	for i in range(1, deck_card_selection_cards.size()):
		var card = deck_card_selection_cards[i]
		var rate = CardRateEvaluator.get_rate(card)
		if rate > best_rate:
			best_rate = rate
			best_index = i
	
	var card_data = deck_card_selection_cards[best_index]
	var target_name = "プレイヤー%d" % (target_player_id + 1)
	if player_system and target_player_id < player_system.players.size():
		target_name = player_system.players[target_player_id].name
	print("[CPU自動選択] %sのデッキから: %s を破壊 (レート: %d)" % [target_name, card_data.get("name", "?"), best_rate])
	
	# デッキからカードを破壊
	if spell_draw:
		spell_draw.destroy_deck_card_at_index(target_player_id, best_index)
	
	if ui_manager and ui_manager.global_comment_ui:
		await ui_manager.global_comment_ui.show_and_wait("『%s』を破壊しました" % card_data.get("name", "?"))
	
	callback.call(best_index)
	_finish_deck_card_selection()


## CPU用: カード変換用の自動選択（メタモルフォシス用）
func _cpu_auto_select_transform_card(target_player_id: int, filter_mode: String):
	"""CPUが自動で敵手札からカードを選択して変換"""
	await get_tree().create_timer(0.5).timeout  # 思考時間
	
	if not card_system:
		_finish_transform_card_selection()
		return
	
	var hand = card_system.get_all_cards_for_player(target_player_id)
	var valid_indices = []
	
	# フィルターに合うカードを探す
	for i in range(hand.size()):
		var card = hand[i]
		if _card_matches_filter(card, filter_mode):
			valid_indices.append(i)
	
	if valid_indices.is_empty():
		_finish_transform_card_selection()
		return
	
	# レートが最も高いカードを選択
	var best_index = valid_indices[0]
	var best_rate = CardRateEvaluator.get_rate(hand[best_index])
	for idx in valid_indices:
		var card = hand[idx]
		var rate = CardRateEvaluator.get_rate(card)
		if rate > best_rate:
			best_rate = rate
			best_index = idx
	
	var card_data = hand[best_index]
	var target_name = "プレイヤー%d" % (target_player_id + 1)
	if player_system and target_player_id < player_system.players.size():
		target_name = player_system.players[target_player_id].name
	print("[CPU自動選択] %sの手札から: %s を変換 (レート: %d)" % [target_name, card_data.get("name", "?"), best_rate])
	
	# 同名カードを全て変換
	if spell_draw:
		var card_name_str = card_data.get("name", "")
		var card_id = card_data.get("id", -1)
		var result = spell_draw.transform_cards_to_specific(target_player_id, card_name_str, card_id, transform_to_card_id)
		if result.get("transformed_count", 0) > 0 and ui_manager and ui_manager.global_comment_ui:
			await ui_manager.global_comment_ui.show_and_wait("『%s』%d枚を『%s』に変換" % [
				result.get("original_name", "?"),
				result.get("transformed_count", 0),
				result.get("new_name", "?")
			])
	
	_finish_transform_card_selection()

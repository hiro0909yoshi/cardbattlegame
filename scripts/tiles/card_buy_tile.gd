extends BaseTile

# カード購入タイル
# 停止時にスペル・アイテムから3枚表示、1枚選択して購入

signal card_buy_completed(player_id: int, card_bought: bool)

# UI
var card_buy_ui = null

# システム参照（handle_special_actionで渡される）
var _player_system = null
var _card_system = null
var _ui_manager = null
var _game_flow_manager = null
var _board_system = null

func _ready():
	tile_type = "card_buy"
	super._ready()

## 特殊タイルアクション実行（special_tile_systemから呼び出される）
func handle_special_action(player_id: int, context: Dictionary) -> Dictionary:
	print("[CardBuyTile] カード購入タイル処理開始 - Player%d" % (player_id + 1))
	
	# コンテキストからシステム参照を取得
	_player_system = context.get("player_system")
	_card_system = context.get("card_system")
	_ui_manager = context.get("ui_manager")
	_game_flow_manager = context.get("game_flow_manager")
	_board_system = context.get("board_system")
	
	# CPUの場合はスキップ
	if _is_cpu_player(player_id):
		print("[CardBuyTile] CPU - スキップ")
		return {"success": true, "card_bought": false}
	
	# プレイヤーの場合はUI表示
	var result = await _show_card_buy_selection(player_id)
	return result

## CPU判定
func _is_cpu_player(player_id: int) -> bool:
	if _board_system and "player_is_cpu" in _board_system:
		var cpu_flags = _board_system.player_is_cpu
		if player_id < cpu_flags.size():
			return cpu_flags[player_id]
	return player_id != 0

## カード購入UI表示
func _show_card_buy_selection(player_id: int) -> Dictionary:
	if not _ui_manager or not _ui_manager.ui_layer:
		push_error("[CardBuyTile] UIManagerまたはui_layerがありません")
		return {"success": false, "card_bought": false}
	
	# スペル・アイテムからランダム3枚を取得
	var available_cards = _get_random_cards(3)
	
	if available_cards.is_empty():
		print("[CardBuyTile] 購入可能なカードがありません")
		if _ui_manager.global_comment_ui:
			await _ui_manager.global_comment_ui.show_and_wait("購入可能なカードがありません", player_id)
		return {"success": true, "card_bought": false}
	
	# UIがなければ作成
	if not card_buy_ui:
		var CardBuyUIScript = load("res://scripts/ui_components/card_buy_ui.gd")
		if CardBuyUIScript:
			card_buy_ui = Control.new()
			card_buy_ui.set_script(CardBuyUIScript)
			_ui_manager.ui_layer.add_child(card_buy_ui)
			if card_buy_ui.has_method("_setup_ui"):
				card_buy_ui._setup_ui()
	
	# プレイヤーの魔力を取得
	var player_magic = 0
	if _player_system and player_id < _player_system.players.size():
		player_magic = _player_system.players[player_id].magic_power
	
	# UIをセットアップして表示
	card_buy_ui.setup(player_id, player_magic)
	card_buy_ui.show_selection(available_cards)
	
	# UIからの応答を待つ
	var selection_result = await _wait_for_selection()
	
	if selection_result.is_empty():
		# 「買わない」ボタンでキャンセル
		print("[CardBuyTile] カード購入キャンセル")
		return {"success": true, "card_bought": false}
	
	# カード購入
	var card_data = selection_result.get("card", {})
	var price = _get_card_price(card_data)
	
	print("[CardBuyTile] カード購入: %s（価格: %dG）" % [card_data.get("name", "?"), price])
	
	# 購入処理
	var success = await _purchase_card(card_data, player_id, price)
	
	if success:
		# 購入完了メッセージ
		if _ui_manager and _ui_manager.global_comment_ui:
			await _ui_manager.global_comment_ui.show_and_wait("%sを購入した！" % card_data.get("name", "カード"), player_id)
		return {"success": true, "card_bought": true, "card_name": card_data.get("name", "")}
	else:
		return {"success": true, "card_bought": false}

## スペル・アイテムからランダム取得
func _get_random_cards(count: int) -> Array:
	var all_spells = CardLoader.get_cards_by_type("spell")
	var all_items = CardLoader.get_cards_by_type("item")
	
	var all_cards = all_spells + all_items
	
	if all_cards.is_empty():
		return []
	
	# シャッフルしてcount枚選択
	all_cards.shuffle()
	var selected = []
	for i in range(min(count, all_cards.size())):
		selected.append(all_cards[i])
	
	return selected

## カード購入価格取得（コストの50%、切り上げ）
func _get_card_price(card_data: Dictionary) -> int:
	var cost_data = card_data.get("cost", {})
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	else:
		cost = int(cost_data)
	return int(ceil(cost / 2.0))

## UIからの選択結果を待つ
func _wait_for_selection() -> Dictionary:
	var state = {"completed": false, "result": {}}
	
	var on_card_purchased = func(card_data: Dictionary):
		state.result = {"card": card_data}
		state.completed = true
	
	var on_cancelled = func():
		state.result = {}
		state.completed = true
	
	card_buy_ui.card_purchased.connect(on_card_purchased, CONNECT_ONE_SHOT)
	card_buy_ui.cancelled.connect(on_cancelled, CONNECT_ONE_SHOT)
	
	# 完了を待つ
	while not state.completed:
		await get_tree().process_frame
	
	return state.result

## カード購入処理
func _purchase_card(card_data: Dictionary, player_id: int, price: int) -> bool:
	# 魔力を支払う
	if _player_system and player_id < _player_system.players.size():
		_player_system.players[player_id].magic_power -= price
	
	# カードを手札に追加
	if _card_system:
		_card_system.add_card_to_hand(player_id, card_data)
	
	# UI更新
	if _ui_manager:
		if _ui_manager.has_method("update_player_info_panels"):
			_ui_manager.update_player_info_panels()
		if _ui_manager.hand_display:
			_ui_manager.hand_display.update_hand_display(player_id)
	
	print("[CardBuyTile] プレイヤー%d: %dG支払い、%sを手札に追加" % [player_id + 1, price, card_data.get("name", "?")])
	return true

extends BaseTile

# カード譲渡タイル
# 停止時にカードタイプを選択、山札から1枚引く

# シグナルは将来の拡張用（現在はDictionary返却で対応）

# UI
var card_give_ui = null

# システム参照（handle_special_actionで渡される）
var _player_system = null
var _card_system = null
var _ui_manager = null
var _game_flow_manager = null
var _board_system = null

func _ready():
	tile_type = "card_give"
	super._ready()

## 特殊タイルアクション実行（special_tile_systemから呼び出される）
func handle_special_action(player_id: int, context: Dictionary) -> Dictionary:
	print("[CardGiveTile] カード譲渡タイル処理開始 - Player%d" % (player_id + 1))
	
	# コンテキストからシステム参照を取得
	_player_system = context.get("player_system")
	_card_system = context.get("card_system")
	_ui_manager = context.get("ui_manager")
	_game_flow_manager = context.get("game_flow_manager")
	_board_system = context.get("board_system")
	
	# CPUの場合はスキップ
	if _is_cpu_player(player_id):
		print("[CardGiveTile] CPU - スキップ")
		return {"success": true, "card_received": false}
	
	# プレイヤーの場合はUI表示
	var result = await _show_card_give_selection(player_id)
	return result

## CPU判定
func _is_cpu_player(player_id: int) -> bool:
	if _board_system and "player_is_cpu" in _board_system:
		var cpu_flags = _board_system.player_is_cpu
		if player_id < cpu_flags.size():
			return cpu_flags[player_id]
	return player_id != 0

## カード譲渡UI表示
func _show_card_give_selection(player_id: int) -> Dictionary:
	if not _ui_manager or not _ui_manager.ui_layer:
		push_error("[CardGiveTile] UIManagerまたはui_layerがありません")
		return {"success": false, "card_received": false}
	
	# UIがなければ作成
	if not card_give_ui:
		var CardGiveUIScript = load("res://scripts/ui_components/card_give_ui.gd")
		if CardGiveUIScript:
			card_give_ui = Control.new()
			card_give_ui.set_script(CardGiveUIScript)
			_ui_manager.ui_layer.add_child(card_give_ui)
			if card_give_ui.has_method("_setup_ui"):
				card_give_ui._setup_ui()
	
	# UIをセットアップして表示
	card_give_ui.setup(_card_system, player_id)
	card_give_ui.show_selection()
	
	# UIからの応答を待つ
	var selection_result = await _wait_for_selection()
	
	if selection_result.is_empty():
		# キャンセルされた
		print("[CardGiveTile] カード譲渡キャンセル")
		return {"success": true, "card_received": false}
	
	# タイプ選択された
	var card_type = selection_result.get("type", "")
	print("[CardGiveTile] カード種類選択: %s" % card_type)
	
	# 山札から該当タイプのカードをランダム取得
	var card_data = {}
	if _card_system:
		card_data = _card_system.draw_random_card_by_type(player_id, card_type)
	
	if card_data.is_empty():
		print("[CardGiveTile] 山札に%sがありません" % card_type)
		if _ui_manager and _ui_manager.global_comment_ui:
			await _ui_manager.global_comment_ui.show_and_wait("山札に%sがありません" % _get_type_name(card_type), player_id)
		return {"success": true, "card_received": false}
	
	print("[CardGiveTile] %sを取得: %s" % [card_type, card_data.get("name", "?")])
	
	# UI更新
	if _ui_manager:
		if _ui_manager.hand_display:
			_ui_manager.hand_display.update_hand_display(player_id)
		if _ui_manager.global_comment_ui:
			await _ui_manager.global_comment_ui.show_and_wait("%sを手に入れた！" % card_data.get("name", "カード"), player_id)
	
	return {"success": true, "card_received": true, "card_name": card_data.get("name", "")}

## UIからの選択結果を待つ
func _wait_for_selection() -> Dictionary:
	var state = {"completed": false, "result": {}}
	
	var on_type_selected = func(card_type: String):
		state.result = {"type": card_type}
		state.completed = true
	
	var on_cancelled = func():
		state.result = {}
		state.completed = true
	
	card_give_ui.type_selected.connect(on_type_selected, CONNECT_ONE_SHOT)
	card_give_ui.cancelled.connect(on_cancelled, CONNECT_ONE_SHOT)
	
	# 完了を待つ
	while not state.completed:
		await get_tree().process_frame
	
	return state.result

## タイプ名を日本語で取得
func _get_type_name(card_type: String) -> String:
	match card_type:
		"creature":
			return "クリーチャー"
		"item":
			return "アイテム"
		"spell":
			return "スペル"
		_:
			return card_type

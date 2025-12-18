extends BaseTile

# 魔法石タイル
# 通過時・停止時に発動、石の売買が可能

# UI
var magic_stone_ui = null

# システム参照（handle_special_actionで渡される）
var _player_system = null
var _card_system = null
var _ui_manager = null
var _game_flow_manager = null
var _board_system = null

func _ready():
	tile_type = "magic_stone"
	super._ready()

## 特殊タイルアクション実行（special_tile_systemから呼び出される）
func handle_special_action(player_id: int, context: Dictionary) -> Dictionary:
	print("[MagicStoneTile] 魔法石タイル処理開始 - Player%d" % (player_id + 1))
	
	# コンテキストからシステム参照を取得
	_player_system = context.get("player_system")
	_card_system = context.get("card_system")
	_ui_manager = context.get("ui_manager")
	_game_flow_manager = context.get("game_flow_manager")
	_board_system = context.get("board_system")
	
	# CPUの場合はスキップ
	if _is_cpu_player(player_id):
		print("[MagicStoneTile] CPU - スキップ")
		return {"success": true, "transaction_done": false}
	
	# プレイヤーの場合はUI表示
	var result = await _show_magic_stone_shop(player_id)
	return result

## CPU判定
func _is_cpu_player(player_id: int) -> bool:
	if _game_flow_manager and "player_is_cpu" in _game_flow_manager:
		var cpu_flags = _game_flow_manager.player_is_cpu
		if player_id < cpu_flags.size():
			return cpu_flags[player_id]
	return player_id != 0

## 魔法石ショップUI表示
func _show_magic_stone_shop(player_id: int) -> Dictionary:
	if not _ui_manager or not _ui_manager.ui_layer:
		push_error("[MagicStoneTile] UIManagerまたはui_layerがありません")
		return {"success": false, "transaction_done": false}
	
	# MagicStoneSystemを取得
	var stone_system = null
	if _game_flow_manager and _game_flow_manager.magic_stone_system:
		stone_system = _game_flow_manager.magic_stone_system
	
	if not stone_system:
		push_error("[MagicStoneTile] MagicStoneSystemが初期化されていません")
		if _ui_manager.global_comment_ui:
			await _ui_manager.global_comment_ui.show_and_wait("魔法石ショップは準備中です", player_id)
		return {"success": true, "transaction_done": false}
	
	# UIがなければ作成
	if not magic_stone_ui:
		var MagicStoneUIScript = load("res://scripts/ui_components/magic_stone_ui.gd")
		if MagicStoneUIScript:
			magic_stone_ui = Control.new()
			magic_stone_ui.set_script(MagicStoneUIScript)
			_ui_manager.ui_layer.add_child(magic_stone_ui)
			if magic_stone_ui.has_method("_setup_ui"):
				magic_stone_ui._setup_ui()
	
	if not magic_stone_ui:
		push_error("[MagicStoneTile] MagicStoneUIの作成に失敗")
		return {"success": false, "transaction_done": false}
	
	# プレイヤー情報を取得
	var player_magic = 0
	var player_stones = {"fire": 0, "water": 0, "earth": 0, "wind": 0}
	if _player_system and player_id < _player_system.players.size():
		player_magic = _player_system.players[player_id].magic_power
		player_stones = _player_system.players[player_id].magic_stones.duplicate()
	
	# 石の価値を取得
	var stone_values = stone_system.get_all_stone_values()
	
	# UIをセットアップして表示
	magic_stone_ui.setup(player_id, player_magic, player_stones, stone_values, stone_system, _player_system)
	magic_stone_ui.show_shop()
	
	# UIからの応答を待つ
	var shop_result = await _wait_for_shop_close()
	
	# UI更新
	if _ui_manager:
		if _ui_manager.has_method("update_player_info_panels"):
			_ui_manager.update_player_info_panels()
	
	return {"success": true, "transaction_done": shop_result.get("transaction_done", false)}

## ショップ終了を待つ
func _wait_for_shop_close() -> Dictionary:
	var state = {"completed": false, "result": {}}
	
	var on_shop_closed = func(transaction_done: bool):
		state.result = {"transaction_done": transaction_done}
		state.completed = true
	
	magic_stone_ui.shop_closed.connect(on_shop_closed, CONNECT_ONE_SHOT)
	
	# 完了を待つ
	while not state.completed:
		await get_tree().process_frame
	
	return state.result

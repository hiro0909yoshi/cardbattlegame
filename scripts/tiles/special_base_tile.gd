extends BaseTile

# ベースタイル（遠隔配置タイル）
# 停止時に空き地を選択し、その後通常の召喚フローで配置

# シグナルは将来の拡張用（現在はDictionary返却で対応）

# システム参照（handle_special_actionで渡される）
var _player_system = null
var _card_system = null
var _ui_manager = null
var _game_flow_manager = null
var _board_system = null

func _ready():
	tile_type = "base"
	super._ready()

## 特殊タイルアクション実行（special_tile_systemから呼び出される）
## 空き地選択のみを行い、選択したタイルインデックスを返す
func handle_special_action(player_id: int, context: Dictionary) -> Dictionary:
	# コンテキストからシステム参照を取得
	_player_system = context.get("player_system")
	_card_system = context.get("card_system")
	_ui_manager = context.get("ui_manager")
	_game_flow_manager = context.get("game_flow_manager")
	_board_system = context.get("board_system")
	
	# CPUの場合はAI判断
	if _is_cpu_player(player_id):
		return _handle_cpu_base_tile(player_id)
	
	# プレイヤーの場合は空き地選択UI
	return await _handle_player_base_tile(player_id)

## CPU用指令タイル処理
func _handle_cpu_base_tile(player_id: int) -> Dictionary:
	var cpu_ai = _get_cpu_special_tile_ai()
	if not cpu_ai:
		print("[SpecialBaseTile] CPU AI なし - スキップ")
		return {"success": true, "selected_tile": -1}
	
	# 空き地を取得
	var spell_creature_place = _get_spell_creature_place()
	if not spell_creature_place:
		return {"success": true, "selected_tile": -1}
	
	var empty_tiles = spell_creature_place.get_empty_tiles(_board_system)
	if empty_tiles.is_empty():
		return {"success": true, "selected_tile": -1}
	
	var selected_tile = cpu_ai.decide_base_tile(player_id, empty_tiles)
	return {"success": true, "selected_tile": selected_tile}

## プレイヤー用指令タイル処理
func _handle_player_base_tile(player_id: int) -> Dictionary:
	print("[SpecialBaseTile] プレイヤー用処理開始 - Player%d" % (player_id + 1))
	print("[SpecialBaseTile] _game_flow_manager: %s" % (_game_flow_manager != null))
	print("[SpecialBaseTile] _board_system: %s" % (_board_system != null))
	
	# 空き地を取得
	var spell_creature_place = _get_spell_creature_place()
	print("[SpecialBaseTile] spell_creature_place: %s" % (spell_creature_place != null))
	if not spell_creature_place:
		print("[SpecialBaseTile] spell_creature_place なし - スキップ")
		return {"success": true, "selected_tile": -1}
	
	var empty_tiles = spell_creature_place.get_empty_tiles(_board_system)
	print("[SpecialBaseTile] empty_tiles: %d個" % empty_tiles.size())
	if empty_tiles.is_empty():
		print("[SpecialBaseTile] 空き地なし")
		if _ui_manager and _ui_manager.global_comment_ui:
			await _ui_manager.show_comment_and_wait("配置できる空き地がありません", player_id, true)
		return {"success": true, "selected_tile": -1}
	
	# 配置するかどうかの確認
	print("[SpecialBaseTile] 確認ダイアログ表示")
	print("[SpecialBaseTile] _ui_manager: %s, global_comment_ui: %s" % [_ui_manager != null, _ui_manager.global_comment_ui != null if _ui_manager else false])
	if _ui_manager and _ui_manager.global_comment_ui:
		var do_place = await _ui_manager.show_choice_and_wait(
			"空き地にクリーチャーを配置しますか？",
			player_id,
			"配置する",
			"しない"
		)
		print("[SpecialBaseTile] 確認結果: %s" % do_place)
		if not do_place:
			return {"success": true, "selected_tile": -1}
	
	# 空き地選択UI表示
	var target_selection_helper = _get_target_selection_helper()
	print("[SpecialBaseTile] target_selection_helper: %s" % (target_selection_helper != null))
	if not target_selection_helper:
		print("[SpecialBaseTile] target_selection_helper なし - スキップ")
		return {"success": true, "selected_tile": -1}
	
	print("[SpecialBaseTile] 空き地選択UI表示")
	var selected_tile = await target_selection_helper.select_tile_from_list(
		empty_tiles,
		"配置先の空き地を選択（←→で切替、決定で選択、キャンセルでスキップ）"
	)
	
	print("[SpecialBaseTile] 選択結果: %d" % selected_tile)
	if selected_tile < 0:
		return {"success": true, "selected_tile": -1}
	
	return {"success": true, "selected_tile": selected_tile}

## CPUSpecialTileAIを取得
func _get_cpu_special_tile_ai():
	if _game_flow_manager and "cpu_special_tile_ai" in _game_flow_manager:
		return _game_flow_manager.cpu_special_tile_ai
	return null

## CPU判定
func _is_cpu_player(player_id: int) -> bool:
	if _board_system and "player_is_cpu" in _board_system:
		var cpu_flags = _board_system.player_is_cpu
		if player_id < cpu_flags.size():
			return cpu_flags[player_id]
	return player_id != 0

## SpellCreaturePlaceを取得
func _get_spell_creature_place():
	if _game_flow_manager and "spell_phase_handler" in _game_flow_manager:
		var handler = _game_flow_manager.spell_phase_handler
		if handler and handler.spell_creature_place:
			return handler.spell_creature_place
	return null

## TargetSelectionHelperを取得
func _get_target_selection_helper():
	if _game_flow_manager and "target_selection_helper" in _game_flow_manager:
		return _game_flow_manager.target_selection_helper
	return null

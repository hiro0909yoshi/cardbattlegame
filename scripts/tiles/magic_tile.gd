extends BaseTile

# 魔法タイル
# 停止時に全スペルから3枚表示、1枚選択して使用

# シグナルは将来の拡張用（現在はDictionary返却で対応）

# UI
var magic_tile_ui = null

# システム参照（handle_special_actionで渡される）
var _player_system = null
var _card_system = null
var _ui_manager = null
var _game_flow_manager = null
var _board_system = null

func _ready():
	tile_type = "magic"
	super._ready()

## 特殊タイルアクション実行（special_tile_systemから呼び出される）
func handle_special_action(player_id: int, context: Dictionary) -> Dictionary:
	print("[MagicTile] 魔法タイル処理開始 - Player%d" % (player_id + 1))
	
	# コンテキストからシステム参照を取得
	_player_system = context.get("player_system")
	_card_system = context.get("card_system")
	_ui_manager = context.get("ui_manager")
	_game_flow_manager = context.get("game_flow_manager")
	_board_system = context.get("board_system")
	
	# CPUの場合はAI判断
	if _is_cpu_player(player_id):
		return await _handle_cpu_magic_tile(player_id)
	
	# プレイヤーの場合はUI表示
	var result = await _show_magic_selection(player_id)
	return result

## CPU用魔法タイル処理
func _handle_cpu_magic_tile(player_id: int) -> Dictionary:
	var cpu_ai = _get_cpu_special_tile_ai()
	if not cpu_ai:
		print("[MagicTile] CPU AI なし - スキップ")
		return {"success": true, "spell_used": false}
	
	# 全スペルからランダム3枚を取得
	var available_spells = _get_random_spells(3)
	if available_spells.is_empty():
		print("[MagicTile] CPU: 使用可能なスペルがありません")
		return {"success": true, "spell_used": false}
	
	# 提示されたスペルをログ出力
	print("[MagicTile] 提示スペル3枚:")
	for i in range(available_spells.size()):
		var spell = available_spells[i]
		var cost = spell.get("cost", {}).get("ep", 0) if typeof(spell.get("cost")) == TYPE_DICTIONARY else spell.get("cost", 0)
		print("  %d. %s (コスト: %dEP)" % [i + 1, spell.get("name", "?"), cost])
	
	var spell_data = cpu_ai.decide_magic_tile_spell(player_id, available_spells)
	if spell_data.is_empty():
		return {"success": true, "spell_used": false}
	
	print("[MagicTile] CPU: %sを使用" % spell_data.get("name", "?"))
	
	# スペル実行
	var spell_result = await _execute_spell(spell_data, player_id)
	
	if spell_result.get("status") == "success":
		return {
			"success": true,
			"spell_used": true,
			"spell_name": spell_data.get("name", ""),
			"warped": spell_result.get("warped", false)
		}
	else:
		return {"success": true, "spell_used": false, "warped": false}

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

## スペル選択UI表示
func _show_magic_selection(player_id: int) -> Dictionary:
	if not _ui_manager or not _ui_manager.ui_layer:
		push_error("[MagicTile] UIManagerまたはui_layerがありません")
		return {"success": false, "spell_used": false}
	
	# 全スペルからランダム3枚を取得（選択ループ中は同じカードを使い続ける）
	var available_spells = _get_random_spells(3)
	
	if available_spells.is_empty():
		print("[MagicTile] 使用可能なスペルがありません")
		if _ui_manager.global_comment_ui:
			await _ui_manager.global_comment_ui.show_and_wait("使用可能なスペルがありません", player_id)
		return {"success": true, "spell_used": false}
	
	# UIがなければ作成
	if not magic_tile_ui:
		var MagicTileUIScript = load("res://scripts/ui_components/magic_tile_ui.gd")
		if MagicTileUIScript:
			magic_tile_ui = Control.new()
			magic_tile_ui.set_script(MagicTileUIScript)
			_ui_manager.ui_layer.add_child(magic_tile_ui)
			if magic_tile_ui.has_method("_setup_ui"):
				magic_tile_ui._setup_ui()
	
	# 選択ループ（キャンセル時は再度選択画面に戻る）
	while true:
		# プレイヤーのEPを取得（ループ毎に更新）
		var player_magic = 0
		if _player_system and player_id < _player_system.players.size():
			player_magic = _player_system.players[player_id].magic_power
		
		# UIをセットアップして表示
		magic_tile_ui.setup(player_id, player_magic)
		magic_tile_ui.show_selection(available_spells)
		
		# UIからの応答を待つ
		var selection_result = await _wait_for_selection()
		
		if selection_result.is_empty():
			# 「使わない」ボタンでキャンセル
			print("[MagicTile] 魔法使用キャンセル")
			return {"success": true, "spell_used": false}
		
		# スペル使用
		var spell_data = selection_result.get("spell", {})
		
		print("[MagicTile] 魔法使用: %s" % spell_data.get("name", "?"))
		
		# SpellPhaseHandlerを使ってスペル実行（コスト支払いも含む）
		var spell_result = await _execute_spell(spell_data, player_id)
		
		var result_status = spell_result.get("status", "cancelled")
		var was_warped = spell_result.get("warped", false)
		
		match result_status:
			"success":
				# 使用成功 → ループ終了（発動通知はSpellEffectExecutorで表示済み）
				return {
					"success": true,
					"spell_used": true,
					"spell_name": spell_data.get("name", ""),
					"warped": was_warped
				}
			"no_target":
				# 対象不在 → 魔法タイル処理終了（選択画面には戻らない）
				print("[MagicTile] 対象不在 - 魔法タイル処理終了")
				return {"success": true, "spell_used": false, "warped": false}
			"cancelled":
				# 手動キャンセル → 再度選択画面に戻る（ループ継続）
				print("[MagicTile] スペルキャンセル - 選択画面に戻る")
				continue
	
	# ここには到達しないはず
	return {"success": true, "spell_used": false, "warped": false}

## デバッグ用：固定スペルID（空配列で通常のランダム）
var debug_fixed_spell_ids: Array = [2033, 2014, 2104]  # シャイニングガイザー、エスケープ、マジカルリープ

## 全スペルからランダム取得
func _get_random_spells(count: int) -> Array:
	# デバッグ: 固定スペルIDが設定されている場合はそれを使用
	if not debug_fixed_spell_ids.is_empty():
		var fixed_spells = []
		for spell_id in debug_fixed_spell_ids:
			var spell = CardLoader.get_card_by_id(spell_id)
			if spell and not spell.is_empty():
				fixed_spells.append(spell)
		if not fixed_spells.is_empty():
			print("[MagicTile] デバッグ: 固定スペル使用 %s" % debug_fixed_spell_ids)
			return fixed_spells
	
	var all_spells = CardLoader.get_cards_by_type("spell")
	
	if all_spells.is_empty():
		return []
	
	# シャッフルしてcount枚選択
	all_spells.shuffle()
	var selected = []
	for i in range(min(count, all_spells.size())):
		selected.append(all_spells[i])
	
	return selected

## スペルコスト取得
func _get_spell_cost(spell_data: Dictionary) -> int:
	var cost_data = spell_data.get("cost", {})
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("ep", 0)
	return int(cost_data)

## UIからの選択結果を待つ
func _wait_for_selection() -> Dictionary:
	var state = {"completed": false, "result": {}}
	
	var on_spell_selected = func(spell_data: Dictionary):
		state.result = {"spell": spell_data}
		state.completed = true
	
	var on_cancelled = func():
		state.result = {}
		state.completed = true
	
	magic_tile_ui.spell_selected.connect(on_spell_selected, CONNECT_ONE_SHOT)
	magic_tile_ui.cancelled.connect(on_cancelled, CONNECT_ONE_SHOT)
	
	# 完了を待つ
	while not state.completed:
		await get_tree().process_frame
	
	return state.result

## スペル実行（SpellPhaseHandlerに全て委譲）
## 戻り値: Dictionary {status: String, warped: bool}
##   status: "success"=成功, "cancelled"=手動キャンセル, "no_target"=対象不在
##   warped: ワープ系スペルを使用したか
func _execute_spell(spell_data: Dictionary, player_id: int) -> Dictionary:
	# SpellPhaseHandlerを取得
	var spell_phase_handler = null
	if _game_flow_manager and "spell_phase_handler" in _game_flow_manager:
		spell_phase_handler = _game_flow_manager.spell_phase_handler
	
	if not spell_phase_handler:
		print("[MagicTile] SpellPhaseHandlerが見つかりません - 効果実行スキップ")
		return {"status": "cancelled", "warped": false}
	
	# 外部スペル実行（対象選択UIなど全てSpellPhaseHandlerが処理）
	# 戻り値: Dictionary {status: String, warped: bool}
	# 第3引数: マジックタイル経由フラグ（呪いduration調整用）
	var result = await spell_phase_handler.execute_external_spell(spell_data, player_id, true)
	print("[MagicTile] スペル実行結果: %s" % result)
	return result

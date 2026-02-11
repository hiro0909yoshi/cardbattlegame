extends RefCounted
class_name TileSummonExecutor

## 召喚処理を担当するクラス
## TileActionProcessorから召喚関連のロジックを分離

# システム参照
var board_system: BoardSystem3D
var player_system: PlayerSystem
var card_system: CardSystem
var ui_manager: UIManager
var game_flow_manager = null
var card_sacrifice_helper: CardSacrificeHelper = null
var creature_synthesis: CreatureSynthesis = null
var sacrifice_selector: CPUSacrificeSelector = null
var cpu_tile_action_executor: CPUTileActionExecutor = null

# 犠牲選択中フラグ（TileActionProcessorから参照される）
var is_sacrifice_selecting: bool = false


func initialize(b_system: BoardSystem3D, p_system: PlayerSystem, c_system: CardSystem,
		ui: UIManager, gf_manager = null):
	board_system = b_system
	player_system = p_system
	card_system = c_system
	ui_manager = ui
	game_flow_manager = gf_manager
	
	# クリーチャー合成システムを初期化
	if CardLoader:
		creature_synthesis = CreatureSynthesis.new(CardLoader)


## 召喚実行
func execute_summon(card_index: int, complete_callback: Callable, show_summon_ui_callback: Callable):
	print("[TileSummonExecutor] execute_summon開始: card_index=%d" % card_index)
	var tap = _get_tile_action_processor()
	var remote_placement_tile = tap.remote_placement_tile if tap else -1
	
	if card_index < 0:
		complete_callback.call()
		return
	
	var current_player_index = board_system.current_player_index
	var card_data = card_system.get_card_data_for_player(current_player_index, card_index)
	print("[TileSummonExecutor] カード取得: %s" % card_data.get("name", "?"))
	
	if card_data.is_empty():
		complete_callback.call()
		return
	
	# 配置先タイルを決定（遠隔配置モードならremote_placement_tile、通常はcurrent_tile）
	var target_tile: int
	var is_remote_placement = remote_placement_tile >= 0
	if is_remote_placement:
		target_tile = remote_placement_tile
		print("[TileSummonExecutor] 遠隔配置モード: タイル%d に配置" % target_tile)
	else:
		target_tile = board_system.movement_controller.get_player_tile(current_player_index)
	
	var tile = board_system.tile_nodes.get(target_tile)
	
	# 配置可能タイルかチェック
	if tile and not tile.can_place_creature():
		print("[TileSummonExecutor] このタイルには配置できません: %s" % tile.tile_type)
		if ui_manager and ui_manager.phase_display:
			ui_manager.phase_display.show_toast("このタイルには配置できません")
		complete_callback.call()
		return
	
	# 防御型チェック: 空き地以外には召喚できない
	var creature_type = card_data.get("creature_type", "normal")
	if creature_type == "defensive":
		var tile_info = board_system.get_tile_info(target_tile)
		if tile_info["owner"] != -1:
			print("[TileSummonExecutor] 防御型クリーチャーは空き地にのみ召喚できます")
			if ui_manager and ui_manager.phase_display:
				ui_manager.phase_display.show_toast("防御型は空き地にのみ召喚可能です")
			complete_callback.call()
			return
	
	# 土地条件チェック（lands_required）
	if not DebugSettings.disable_lands_required and not _is_summon_condition_ignored():
		var check_result = SummonConditionChecker.check_lands_required(card_data, current_player_index, board_system)
		if not check_result.passed:
			print("[TileSummonExecutor] 土地条件未達: %s" % check_result.message)
			if ui_manager and ui_manager.phase_display:
				ui_manager.phase_display.show_toast(check_result.message)
			complete_callback.call()
			return
	
	# 配置制限チェック（cannot_summon）
	if not DebugSettings.disable_cannot_summon and not _is_summon_condition_ignored():
		var tile_element_for_check = tile.tile_type if tile and "tile_type" in tile else ""
		var cannot_result = SummonConditionChecker.check_cannot_summon(card_data, tile_element_for_check)
		if not cannot_result.passed:
			print("[TileSummonExecutor] 配置制限: %s" % cannot_result.message)
			if ui_manager and ui_manager.phase_display:
				ui_manager.phase_display.show_toast(cannot_result.message)
			complete_callback.call()
			return
	
	# カード犠牲処理（クリーチャー合成用）
	var sacrifice_card = {}
	var sacrifice_index = -1
	var tile_element_for_sacrifice = tile.tile_type if tile and "tile_type" in tile else ""
	if SummonConditionChecker.requires_card_sacrifice(card_data) and not DebugSettings.disable_card_sacrifice and not _is_summon_condition_ignored():
		var sacrifice_result = await _process_card_sacrifice(current_player_index, card_index, card_data, tile_element_for_sacrifice)
		sacrifice_card = sacrifice_result.get("card", {})
		sacrifice_index = sacrifice_result.get("index", -1)
		if sacrifice_card.is_empty() and SummonConditionChecker.requires_card_sacrifice(card_data):
			if ui_manager and ui_manager.phase_display:
				ui_manager.phase_display.show_toast("召喚をキャンセルしました")
			show_summon_ui_callback.call()
			return
		
		# 犠牲カードが召喚カードより前のインデックスにあった場合、インデックスを調整
		if sacrifice_index >= 0 and sacrifice_index < card_index:
			card_index -= 1
			print("[TileSummonExecutor] 犠牲カード破棄によりcard_indexを調整: %d" % card_index)
	
	# クリーチャー合成処理
	var is_synthesized = false
	if not sacrifice_card.is_empty() and creature_synthesis:
		is_synthesized = creature_synthesis.check_condition(card_data, sacrifice_card)
		if is_synthesized:
			card_data = creature_synthesis.apply_synthesis(card_data, sacrifice_card, true)
			print("[TileSummonExecutor] 合成成立: %s" % card_data.get("name", "?"))
	
	var cost_data = card_data.get("cost", 1)
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("ep", 0)
	else:
		cost = cost_data
	
	# ライフフォース呪いチェック（クリーチャーコスト0化）
	if game_flow_manager and game_flow_manager.spell_cost_modifier:
		cost = game_flow_manager.spell_cost_modifier.get_modified_cost(current_player_index, card_data)
	
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power >= cost:
		# カード使用とEP消費
		card_system.use_card_for_player(current_player_index, card_index)
		player_system.add_magic(current_player_index, -cost)
		
		# 土地取得とクリーチャー配置
		board_system.set_tile_owner(target_tile, current_player_index)
		board_system.place_creature(target_tile, card_data)
		
		# 召喚後にダウン状態を設定（不屈チェック）
		if tile and tile.has_method("set_down_state"):
			if not PlayerBuffSystem.has_unyielding(card_data):
				tile.set_down_state(true)
			else:
				print("[TileSummonExecutor] 不屈により召喚後もダウンしません: タイル", target_tile)
		
		if is_remote_placement:
			print("遠隔召喚成功！タイル%dを取得しました" % target_tile)
		else:
			print("召喚成功！土地を取得しました")
		
		# UI更新
		if ui_manager:
			ui_manager.hide_card_selection_ui()
			ui_manager.update_player_info_panels()
		print("[TileSummonExecutor] execute_summon完了")
		complete_callback.call()
	else:
		print("EP不足で召喚できません")
		if ui_manager and ui_manager.phase_display:
			ui_manager.phase_display.show_toast("EPが足りません（必要: %dEP）" % cost)
		show_summon_ui_callback.call()


## CPU用召喚実行
func execute_summon_for_cpu(card_index: int, complete_callback: Callable) -> bool:
	print("[TileSummonExecutor] CPU召喚開始: card_index=%d" % card_index)
	
	# CPUTileActionExecutorを初期化
	if not cpu_tile_action_executor:
		cpu_tile_action_executor = CPUTileActionExecutor.new()
		cpu_tile_action_executor.initialize(_get_tile_action_processor())
	
	var current_player_index = board_system.current_player_index
	
	# 準備処理
	var prep = cpu_tile_action_executor.prepare_summon(card_index, current_player_index)
	if not prep.get("success", false):
		var reason = prep.get("reason", "unknown")
		print("[TileSummonExecutor] CPU: 召喚準備失敗: %s" % reason)
		return false
	
	# 召喚実行
	var success = cpu_tile_action_executor.execute_summon(prep, current_player_index)
	if not success:
		return false
	
	print("[TileSummonExecutor] CPU召喚成功: %s" % prep.get("card_data", {}).get("name", "?"))
	
	# UI更新
	if ui_manager:
		ui_manager.hide_card_selection_ui()
		ui_manager.update_player_info_panels()
	
	complete_callback.call()
	return true


## カード犠牲処理（手札選択UI表示→カード破棄）
func _process_card_sacrifice(player_id: int, summon_card_index: int, creature_card: Dictionary = {}, tile_element: String = "") -> Dictionary:
	# CPUの場合は自動選択
	if _is_cpu_player(player_id):
		return _process_card_sacrifice_cpu(player_id, creature_card, tile_element)
	
	# CardSacrificeHelperを初期化
	if not card_sacrifice_helper:
		card_sacrifice_helper = CardSacrificeHelper.new(card_system, player_system, ui_manager)
	
	# 犠牲選択モードに入る
	is_sacrifice_selecting = true
	
	# 手札選択UIを表示（召喚するカード以外を選択可能）
	if ui_manager:
		if ui_manager.phase_display:
			ui_manager.phase_display.show_action_prompt("犠牲にするカードを選択")
		ui_manager.card_selection_filter = ""
		ui_manager.excluded_card_index = summon_card_index
		var player = player_system.players[player_id]
		ui_manager.show_card_selection_ui_mode(player, "sacrifice")
	
	# カード選択を待つ
	var selected_index = await ui_manager.card_selected
	
	# 犠牲選択モードを終了
	is_sacrifice_selecting = false
	
	# UIを閉じる
	ui_manager.hide_card_selection_ui()
	
	# 除外インデックスをリセット
	if ui_manager:
		ui_manager.excluded_card_index = -1
	
	# 選択されたカードを取得
	if selected_index < 0:
		return {"card": {}, "index": -1}
	
	# 召喚するカードと同じインデックスは選択不可
	if selected_index == summon_card_index:
		if ui_manager and ui_manager.phase_display:
			ui_manager.phase_display.show_toast("召喚するカードは犠牲にできません")
		return {"card": {}, "index": -1}
	
	var hand = card_system.get_all_cards_for_player(player_id)
	if selected_index >= hand.size():
		return {"card": {}, "index": -1}
	
	var sacrifice_card = hand[selected_index]
	
	# カードを破棄
	card_system.discard_card(player_id, selected_index, "sacrifice")
	print("[TileSummonExecutor] %s を犠牲にしました" % sacrifice_card.get("name", "?"))
	
	return {"card": sacrifice_card, "index": selected_index}


## CPU用カード犠牲処理（自動選択）
func _process_card_sacrifice_cpu(player_id: int, creature_card: Dictionary, tile_element: String) -> Dictionary:
	# CPUSacrificeSelectorを初期化
	if not sacrifice_selector:
		sacrifice_selector = CPUSacrificeSelector.new()
		sacrifice_selector.initialize(card_system, board_system)
		if creature_synthesis:
			sacrifice_selector.creature_synthesis = creature_synthesis
	
	# 犠牲カードを選択
	var result = sacrifice_selector.select_sacrifice_for_creature(creature_card, player_id, tile_element)
	var sacrifice_card = result.get("card", {})
	
	if sacrifice_card.is_empty():
		print("[TileSummonExecutor] CPU: 犠牲カードが選択できませんでした")
		return {"card": {}, "index": -1}
	
	# カードを破棄
	var hand = card_system.get_all_cards_for_player(player_id)
	var sacrifice_index = -1
	for i in range(hand.size()):
		if hand[i].get("id") == sacrifice_card.get("id"):
			card_system.discard_card(player_id, i, "sacrifice")
			sacrifice_index = i
			print("[TileSummonExecutor] CPU: %s を犠牲にしました" % sacrifice_card.get("name", "?"))
			break
	
	return {"card": sacrifice_card, "index": sacrifice_index}


## CPU用犠牲カード自動選択（CPUSacrificeSelector使用）
func select_sacrifice_card_for_cpu(player_id: int, creature_card: Dictionary, tile_element: String = "") -> Dictionary:
	if not cpu_tile_action_executor:
		cpu_tile_action_executor = CPUTileActionExecutor.new()
		cpu_tile_action_executor.initialize(_get_tile_action_processor())
	
	return cpu_tile_action_executor.select_sacrifice_card(player_id, creature_card, tile_element)


## 召喚条件が解除されているか
func _is_summon_condition_ignored(player_id: int = -1) -> bool:
	return SummonConditionChecker.is_summon_condition_ignored(player_id, game_flow_manager, board_system)


## CPUプレイヤーかどうか判定
func _is_cpu_player(player_id: int) -> bool:
	if not game_flow_manager:
		return false
	var cpu_settings = game_flow_manager.player_is_cpu
	var debug_mode = game_flow_manager.debug_manual_control_all
	if debug_mode:
		return false
	return player_id < cpu_settings.size() and cpu_settings[player_id]


## TileActionProcessorへの参照を取得
func _get_tile_action_processor() -> TileActionProcessor:
	if board_system and board_system.tile_action_processor:
		return board_system.tile_action_processor
	return null

extends RefCounted
class_name TileBattleExecutor

## バトル（侵略）処理を担当するクラス
## TileActionProcessorからバトル関連のロジックを分離

signal invasion_completed(success: bool, tile_index: int)

# システム参照
var board_system: BoardSystem3D
var player_system: PlayerSystem
var card_system: CardSystem
var battle_system: BattleSystem
var ui_manager: UIManager
var game_flow_manager = null
var _item_phase_handler = null  # gfm.item_phase_handler参照（遅延取得）

# === 直接参照（GFM経由を廃止） ===
var spell_cost_modifier = null  # SpellCostModifier: コスト計算
var battle_status_overlay = null  # BattleStatusOverlay: バトルステータス表示

func set_battle_status_overlay(overlay) -> void:
	battle_status_overlay = overlay
	print("[TileBattleExecutor] battle_status_overlay 直接参照を設定")

## item_phase_handlerの遅延取得
func _get_item_phase_handler():
	if not _item_phase_handler and game_flow_manager and game_flow_manager.get("item_phase_handler"):
		_item_phase_handler = game_flow_manager.item_phase_handler
	return _item_phase_handler

# バトル情報の一時保存
var pending_battle_card_index: int = -1
var pending_battle_card_data: Dictionary = {}
var pending_battle_tile_info: Dictionary = {}
var pending_attacker_item: Dictionary = {}
var pending_defender_item: Dictionary = {}
var is_waiting_for_defender_item: bool = false

# 完了コールバック
var _complete_callback: Callable
var _show_battle_ui_callback: Callable

# 召喚エグゼキュータ（合成処理で使用）
var _summon_executor: TileSummonExecutor


func initialize(b_system: BoardSystem3D, p_system: PlayerSystem, c_system: CardSystem,
		bt_system: BattleSystem, ui: UIManager, gf_manager = null, summon_exec: TileSummonExecutor = null):
	board_system = b_system
	player_system = p_system
	card_system = c_system
	battle_system = bt_system
	ui_manager = ui
	game_flow_manager = gf_manager
	_summon_executor = summon_exec

## 直接参照を設定（GFM経由を廃止）
func set_spell_cost_modifier(cost_modifier) -> void:
	spell_cost_modifier = cost_modifier

## バトル（侵略）実行
func execute_battle(card_index: int, tile_info: Dictionary, complete_callback: Callable, show_battle_ui_callback: Callable):
	_complete_callback = complete_callback
	_show_battle_ui_callback = show_battle_ui_callback
	
	if card_index < 0:
		complete_callback.call()
		return
	
	var current_player_index = board_system.current_player_index
	var card_data = card_system.get_card_data_for_player(current_player_index, card_index)
	
	if card_data.is_empty():
		complete_callback.call()
		return
	
	# 土地条件チェック（lands_required）
	if not DebugSettings.disable_lands_required and not _is_summon_condition_ignored():
		var check_result = SummonConditionChecker.check_lands_required(card_data, current_player_index, board_system)
		if not check_result.passed:
			print("[TileBattleExecutor] 土地条件未達（バトル）: %s" % check_result.message)
			if ui_manager and ui_manager.phase_display:
				ui_manager.show_toast(check_result.message)
			complete_callback.call()
			return
	
	# 配置制限チェック（cannot_summon）
	if not DebugSettings.disable_cannot_summon and not _is_summon_condition_ignored():
		var tile_element_for_check = tile_info.get("element", "")
		var cannot_result = SummonConditionChecker.check_cannot_summon(card_data, tile_element_for_check)
		if not cannot_result.passed:
			print("[TileBattleExecutor] 配置制限（バトル）: %s" % cannot_result.message)
			if ui_manager and ui_manager.phase_display:
				ui_manager.show_toast(cannot_result.message)
			complete_callback.call()
			return
	
	# カード犠牲処理（クリーチャー合成用）
	var sacrifice_card = {}
	var tile_element_for_sacrifice = tile_info.get("element", "")
	if SummonConditionChecker.requires_card_sacrifice(card_data) and not DebugSettings.disable_card_sacrifice and not _is_summon_condition_ignored():
		# カード選択UIを一度閉じる
		if ui_manager:
			ui_manager.hide_card_selection_ui()
		if _summon_executor:
			sacrifice_card = await _summon_executor.process_card_sacrifice(current_player_index, card_index, card_data, tile_element_for_sacrifice)
		if sacrifice_card.get("card", {}).is_empty() and SummonConditionChecker.requires_card_sacrifice(card_data):
			if ui_manager and ui_manager.phase_display:
				ui_manager.show_toast("バトルをキャンセルしました")
			show_battle_ui_callback.call()
			return
	
	# クリーチャー合成処理
	var is_synthesized = false
	var sacrifice_card_data = sacrifice_card.get("card", {})
	if not sacrifice_card_data.is_empty() and _summon_executor and _summon_executor.creature_synthesis:
		is_synthesized = _summon_executor.creature_synthesis.check_condition(card_data, sacrifice_card_data)
		if is_synthesized:
			card_data = _summon_executor.creature_synthesis.apply_synthesis(card_data, sacrifice_card_data, true)
			print("[TileBattleExecutor] 合成成立（バトル）: %s" % card_data.get("name", "?"))
	
	# バトル情報を保存
	pending_battle_card_index = card_index
	pending_battle_card_data = card_data
	pending_battle_tile_info = tile_info
	
	# コスト計算
	var cost_data = card_data.get("cost", 1)
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("ep", 0)
	else:
		cost = cost_data
	
	# ライフフォース呪いチェック
	if spell_cost_modifier:
		cost = spell_cost_modifier.get_modified_cost(current_player_index, pending_battle_card_data)
	
	var current_player = player_system.get_current_player()
	if current_player.magic_power < cost:
		print("[TileBattleExecutor] EP不足でバトルできません")
		if ui_manager and ui_manager.phase_display:
			ui_manager.show_toast("EPが足りません（必要: %dEP）" % cost)
		show_battle_ui_callback.call()
		return
	
	# カードを使用してEP消費
	card_system.use_card_for_player(current_player_index, card_index)
	player_system.add_magic(current_player_index, -cost)
	print("[TileBattleExecutor] バトルカード消費: ", pending_battle_card_data.get("name", "???"))
	
	# バトルステータスオーバーレイ表示
	var defender_creature = pending_battle_tile_info.get("creature", {})
	if battle_status_overlay:
		var attacker_display = pending_battle_card_data.duplicate()
		attacker_display["land_bonus_hp"] = 0
		var defender_display = defender_creature.duplicate()
		defender_display["land_bonus_hp"] = calculate_land_bonus_for_display(defender_creature, pending_battle_tile_info)
		battle_status_overlay.show_battle_status(
			attacker_display, defender_display, "attacker")
	
	# CPU攻撃側の合体処理をチェック
	if _is_cpu_player(current_player_index):
		var merge_executed = _check_and_execute_cpu_attacker_merge(current_player_index)
		if merge_executed:
			if battle_status_overlay:
				var attacker_display = pending_battle_card_data.duplicate()
				attacker_display["land_bonus_hp"] = 0
				var defender_display = defender_creature.duplicate()
				defender_display["land_bonus_hp"] = calculate_land_bonus_for_display(defender_creature, pending_battle_tile_info)
				battle_status_overlay.show_battle_status(
					attacker_display, defender_display, "attacker")
	
	# アイテムフェーズ開始
	if _get_item_phase_handler():
		if not _get_item_phase_handler().item_phase_completed.is_connected(_on_item_phase_completed):
			_get_item_phase_handler().item_phase_completed.connect(_on_item_phase_completed, CONNECT_ONE_SHOT)
		_get_item_phase_handler().start_item_phase(
			current_player_index,
			pending_battle_card_data,
			pending_battle_tile_info
		)
	else:
		_execute_pending_battle()


## CPU用バトル実行
func execute_battle_for_cpu(card_index: int, tile_info: Dictionary, item_index: int, complete_callback: Callable) -> bool:
	print("[TileBattleExecutor] CPUバトル開始: card_index=%d, item_index=%d" % [card_index, item_index])
	_complete_callback = complete_callback
	
	# CPUTileActionExecutorを初期化
	var tap = _get_tile_action_processor()
	var cpu_tile_action_executor = tap.cpu_tile_action_executor if tap else null
	if not cpu_tile_action_executor:
		cpu_tile_action_executor = CPUTileActionExecutor.new()
		cpu_tile_action_executor.initialize(tap)
		if tap:
			tap.cpu_tile_action_executor = cpu_tile_action_executor
	
	var current_player_index = board_system.current_player_index
	
	# 準備処理
	var prep = cpu_tile_action_executor.prepare_battle(card_index, tile_info, item_index, current_player_index)
	if not prep.get("success", false):
		var reason = prep.get("reason", "unknown")
		print("[TileBattleExecutor] CPU: バトル準備失敗: %s" % reason)
		return false
	
	var card_data = prep.get("card_data", {})
	var cost = prep.get("cost", 0)
	var item_data = prep.get("item_data", {})
	
	# バトル情報を保存
	pending_battle_card_index = card_index
	pending_battle_card_data = card_data
	pending_battle_tile_info = tile_info
	
	# CPUが選択したアイテムを保存
	pending_attacker_item = item_data
	if not item_data.is_empty():
		print("[TileBattleExecutor] CPU: 攻撃側アイテム保存: %s (index=%d)" % [item_data.get("name", "?"), item_data.get("_hand_index", -1)])
	
	# カードを使用してEP消費
	card_system.use_card_for_player(current_player_index, card_index)
	player_system.add_magic(current_player_index, -cost)
	print("[TileBattleExecutor] CPU: バトルカード消費: %s" % pending_battle_card_data.get("name", "?"))
	
	# バトルステータスオーバーレイ表示
	var defender_creature = pending_battle_tile_info.get("creature", {})
	if battle_status_overlay:
		var attacker_display = pending_battle_card_data.duplicate()
		attacker_display["land_bonus_hp"] = 0
		var defender_display = defender_creature.duplicate()
		defender_display["land_bonus_hp"] = calculate_land_bonus_for_display(defender_creature, pending_battle_tile_info)
		battle_status_overlay.show_battle_status(
			attacker_display, defender_display, "attacker")
	
	# CPU攻撃側の合体処理をチェック
	var merge_executed = _check_and_execute_cpu_attacker_merge(current_player_index)
	if merge_executed:
		if battle_status_overlay:
			var attacker_display = pending_battle_card_data.duplicate()
			attacker_display["land_bonus_hp"] = 0
			var defender_display = defender_creature.duplicate()
			defender_display["land_bonus_hp"] = calculate_land_bonus_for_display(defender_creature, pending_battle_tile_info)
			battle_status_overlay.show_battle_status(
				attacker_display, defender_display, "attacker")
	
	# アイテムフェーズ開始
	if _get_item_phase_handler():
		if not _get_item_phase_handler().item_phase_completed.is_connected(_on_item_phase_completed):
			_get_item_phase_handler().item_phase_completed.connect(_on_item_phase_completed, CONNECT_ONE_SHOT)
		
		# CPU攻撃側の事前選択アイテムを設定
		if not pending_attacker_item.is_empty():
			_get_item_phase_handler().set_preselected_attacker_item(pending_attacker_item)
		
		_get_item_phase_handler().start_item_phase(
			current_player_index,
			pending_battle_card_data,
			pending_battle_tile_info
		)
	else:
		_execute_pending_battle()
	
	return true


## アイテムフェーズ完了後のコールバック
func _on_item_phase_completed():
	if not is_waiting_for_defender_item:
		# 攻撃側のアイテムフェーズ完了 → 防御側のアイテムフェーズ開始
		print("[TileBattleExecutor] 攻撃側アイテムフェーズ完了")
		
		# 合体が発生した場合、バトルカードデータを更新
		if _get_item_phase_handler():
			if _get_item_phase_handler().was_merged():
				pending_battle_card_data = _get_item_phase_handler().get_merged_creature()
				print("[TileBattleExecutor] 合体発生: %s" % pending_battle_card_data.get("name", "?"))
		
		# 攻撃側のアイテムを保存
		if _get_item_phase_handler():
			pending_attacker_item = _get_item_phase_handler().get_selected_item()
		
		# 防御側のアイテムフェーズを開始
		var defender_owner = pending_battle_tile_info.get("owner", -1)
		if defender_owner >= 0:
			is_waiting_for_defender_item = true
			
			# 防御側を強調表示に切り替え
			if battle_status_overlay:
				battle_status_overlay.highlight_side("defender")
			
			# 防御側のアイテムフェーズ開始
			if _get_item_phase_handler():
				if not _get_item_phase_handler().item_phase_completed.is_connected(_on_item_phase_completed):
					_get_item_phase_handler().item_phase_completed.connect(_on_item_phase_completed, CONNECT_ONE_SHOT)
				
				print("[TileBattleExecutor] 防御側アイテムフェーズ開始: プレイヤー ", defender_owner + 1)
				var defender_creature = pending_battle_tile_info.get("creature", {})
				_get_item_phase_handler().set_opponent_creature(pending_battle_card_data)
				_get_item_phase_handler().set_defense_tile_info(pending_battle_tile_info)
				_get_item_phase_handler().start_item_phase(defender_owner, defender_creature)
			else:
				_execute_pending_battle()
		else:
			_execute_pending_battle()
	else:
		# 防御側のアイテムフェーズ完了 → バトル開始
		print("[TileBattleExecutor] 防御側アイテムフェーズ完了、バトル開始")
		
		# 防御側の合体が発生した場合
		if _get_item_phase_handler():
			if _get_item_phase_handler().was_merged():
				var merged_data = _get_item_phase_handler().get_merged_creature()
				pending_battle_tile_info["creature"] = merged_data
				print("[TileBattleExecutor] 防御側合体発生: %s" % merged_data.get("name", "?"))
				
				# タイルのクリーチャーデータも永続更新
				var tile_index = pending_battle_tile_info.get("index", -1)
				if tile_index >= 0 and board_system.tile_nodes.has(tile_index):
					var tile = board_system.tile_nodes[tile_index]
					tile.creature_data = merged_data
					print("[TileBattleExecutor] タイル%d のクリーチャーデータを更新（永続化）" % tile_index)
		
		# 防御側のアイテムを保存
		if _get_item_phase_handler():
			pending_defender_item = _get_item_phase_handler().get_selected_item()
		
		is_waiting_for_defender_item = false
		_execute_pending_battle()


## 保留中のバトルを実行
func _execute_pending_battle():
	if pending_battle_card_index < 0 or pending_battle_card_data.is_empty():
		print("[TileBattleExecutor] エラー: バトル情報が保存されていません")
		_complete_callback.call()
		return
	
	# バトルステータスオーバーレイを非表示
	if battle_status_overlay:
		battle_status_overlay.hide_battle_status()
	
	var current_player_index = board_system.current_player_index
	
	# バトル完了シグナルに接続
	var callable = Callable(self, "_on_battle_completed")
	if not battle_system.invasion_completed.is_connected(callable):
		battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
	
	# バトル実行
	await battle_system.execute_3d_battle_with_data(current_player_index, pending_battle_card_data, pending_battle_tile_info, pending_attacker_item, pending_defender_item)
	
	# バトル情報をクリア
	pending_battle_card_index = -1
	pending_battle_card_data = {}
	pending_battle_tile_info = {}
	pending_attacker_item = {}
	pending_defender_item = {}
	is_waiting_for_defender_item = false


## バトル完了時
func _on_battle_completed(success: bool, tile_index: int):
	print("バトル結果受信: success=", success, " tile=", tile_index)

	if ui_manager:
		ui_manager.hide_card_selection_ui()
		ui_manager.update_player_info_panels()

	emit_signal("invasion_completed", success, tile_index)
	# _complete_callback.call()  ← Phase 2: invasion_completed relay chain で完了処理されるため不要


## アイテムフェーズ表示用の土地ボーナス計算
func calculate_land_bonus_for_display(creature_data: Dictionary, tile_info: Dictionary) -> int:
	var creature_element = creature_data.get("element", "")
	var tile_element = tile_info.get("element", "")
	var tile_level = tile_info.get("level", 1)
	
	# 無属性タイルは全クリーチャーにボーナス
	if tile_element == "neutral":
		return tile_level * 10
	
	# 属性が一致すれば土地ボーナス
	if creature_element != "" and creature_element == tile_element:
		return tile_level * 10
	
	return 0


## CPU攻撃側の合体処理をチェック・実行
func _check_and_execute_cpu_attacker_merge(player_index: int) -> bool:
	if not board_system or not board_system.cpu_turn_processor:
		return false
	
	var cpu_handler = board_system.cpu_turn_processor.cpu_ai_handler
	if not cpu_handler:
		return false
	
	if not cpu_handler.has_pending_merge():
		return false
	
	var merge_data = cpu_handler.get_pending_merge_data()
	print("[TileBattleExecutor] CPU攻撃側合体実行: %s → %s" % [
		pending_battle_card_data.get("name", "?"),
		merge_data.get("result_name", "?")
	])
	
	var partner_index = merge_data.get("partner_index", -1)
	if partner_index < 0:
		cpu_handler.clear_pending_merge_data()
		return false
	
	var skill_merge_result = SkillMerge.execute_merge(
		pending_battle_card_data,
		partner_index,
		player_index,
		card_system,
		player_system,
		spell_cost_modifier
	)
	
	if not skill_merge_result.get("success", false):
		print("[TileBattleExecutor] CPU合体失敗")
		cpu_handler.clear_pending_merge_data()
		return false
	
	pending_battle_card_data = skill_merge_result.get("result_creature", {})
	print("[TileBattleExecutor] CPU合体完了: %s" % pending_battle_card_data.get("name", "?"))
	cpu_handler.clear_pending_merge_data()
	return true


## 召喚条件が解除されているか
func _is_summon_condition_ignored(player_id: int = -1) -> bool:
	return SummonConditionChecker.is_summon_condition_ignored(player_id, game_flow_manager, board_system)


## CPUプレイヤーかどうか判定
func _is_cpu_player(player_id: int) -> bool:
	if not game_flow_manager:
		return false
	var cpu_settings = game_flow_manager.player_is_cpu
	if DebugSettings.manual_control_all:
		return false
	return player_id < cpu_settings.size() and cpu_settings[player_id]


## TileActionProcessorへの参照を取得
func _get_tile_action_processor() -> TileActionProcessor:
	if board_system and board_system.tile_action_processor:
		return board_system.tile_action_processor
	return null

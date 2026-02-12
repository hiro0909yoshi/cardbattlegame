extends Node
class_name TileActionProcessor

## タイルアクション処理クラス
## タイル到着時の各種アクション処理を管理
## 召喚処理は TileSummonExecutor、バトル処理は TileBattleExecutor に委譲

signal action_completed()
signal invasion_completed(success: bool, tile_index: int)

# システム参照
var board_system: BoardSystem3D
var player_system: PlayerSystem
var card_system: CardSystem
var battle_system: BattleSystem
var special_tile_system: SpecialTileSystem
var ui_manager: UIManager
var game_flow_manager = null
var cpu_turn_processor = null
var cpu_tile_action_executor: CPUTileActionExecutor = null

# サブシステム
var summon_executor: TileSummonExecutor = null
var battle_executor: TileBattleExecutor = null

# デバッグフラグ（DebugSettingsに移行済み、後方互換プロパティ）
var debug_disable_card_sacrifice: bool:
	get: return DebugSettings.disable_card_sacrifice
	set(v): DebugSettings.disable_card_sacrifice = v
var debug_disable_lands_required: bool:
	get: return DebugSettings.disable_lands_required
	set(v): DebugSettings.disable_lands_required = v
var debug_disable_cannot_summon: bool:
	get: return DebugSettings.disable_cannot_summon
	set(v): DebugSettings.disable_cannot_summon = v
var debug_disable_cannot_use: bool:
	get: return DebugSettings.disable_cannot_use
	set(v): DebugSettings.disable_cannot_use = v

# 状態管理
var is_action_processing = false

## アクション処理状態を開始
func begin_action_processing():
	is_action_processing = true

## アクション処理状態をリセット
func reset_action_processing():
	is_action_processing = false

# 遠隔配置モード（ベースタイル用）
var remote_placement_tile: int = -1

# コメント表示用
var pending_comment: String = ""
var pending_comment_player_id: int = -1
var pending_comment_force_click: bool = true

## 遠隔配置モードを設定（ベースタイルから呼び出し）
func set_remote_placement(tile_index: int):
	remote_placement_tile = tile_index
	print("[TileActionProcessor] 遠隔配置モード設定: タイル%d" % tile_index)

## 遠隔配置モードをクリア
func clear_remote_placement():
	remote_placement_tile = -1

func _ready():
	pass

# 初期化
func setup(b_system: BoardSystem3D, p_system: PlayerSystem, c_system: CardSystem,
		   bt_system: BattleSystem, st_system: SpecialTileSystem, ui: UIManager, gf_manager = null):
	board_system = b_system
	player_system = p_system
	card_system = c_system
	battle_system = bt_system
	special_tile_system = st_system
	ui_manager = ui
	game_flow_manager = gf_manager
	
	# サブシステム初期化
	summon_executor = TileSummonExecutor.new()
	summon_executor.initialize(b_system, p_system, c_system, ui, gf_manager)
	
	battle_executor = TileBattleExecutor.new()
	battle_executor.initialize(b_system, p_system, c_system, bt_system, ui, gf_manager, summon_executor)
	battle_executor.invasion_completed.connect(_on_invasion_completed)

# CPUプロセッサーを設定
func set_cpu_processor(cpu_processor):
	cpu_turn_processor = cpu_processor
	if cpu_turn_processor:
		cpu_turn_processor.cpu_action_completed.connect(_on_cpu_action_completed)

# === タイル到着処理 ===

# タイル到着時のメイン処理
func process_tile_landing(tile_index: int, current_player_index: int, player_is_cpu: Array, debug_manual_control_all: bool = false):
	print("[TileActionProcessor] process_tile_landing: tile=%d, is_action_processing=%s" % [tile_index, is_action_processing])
	if is_action_processing:
		print("Warning: Already processing tile action")
		return
	
	if not board_system.tile_nodes.has(tile_index):
		emit_signal("action_completed")
		return
	
	is_action_processing = true
	
	var tile = board_system.tile_nodes[tile_index]
	var tile_info = board_system.get_tile_info(tile_index)
	
	# 特殊マス処理
	if _is_special_tile(tile.tile_type):
		if special_tile_system:
			await special_tile_system.process_special_tile_3d(tile.tile_type, tile_index, current_player_index)
	
	# CPUかプレイヤーかで分岐
	var is_cpu_turn = player_is_cpu[current_player_index] and not debug_manual_control_all
	if is_cpu_turn:
		_process_cpu_tile(tile, tile_info, current_player_index)
	else:
		_process_player_tile(tile, tile_info, current_player_index)

# プレイヤーのタイル処理
func _process_player_tile(tile: BaseTile, tile_info: Dictionary, player_index: int):
	# カメラを手動モードに
	if board_system:
		board_system.enable_manual_camera()
		board_system.set_camera_player(player_index)
	
	# 特殊タイルかチェック
	var is_special = _is_special_tile(tile.tile_type)
	if is_special:
		return
	
	if tile_info["owner"] == -1:
		show_summon_ui()
	elif tile_info["owner"] == player_index:
		show_summon_ui_disabled()
	else:
		# 敵の土地
		var spell_curse_toll = null
		if board_system.has_meta("spell_curse_toll"):
			spell_curse_toll = board_system.get_meta("spell_curse_toll")
		
		var current_tile_index = board_system.get_player_tile(player_index)
		
		if spell_curse_toll and spell_curse_toll.has_peace_curse(current_tile_index):
			show_battle_ui_disabled()
		elif spell_curse_toll and spell_curse_toll.is_player_invasion_disabled(player_index):
			show_battle_ui_disabled()
		elif game_flow_manager and game_flow_manager.spell_world_curse and game_flow_manager.spell_world_curse.check_invasion_blocked(player_index, tile_info.get("owner", -1), false):
			show_battle_ui_disabled()
		else:
			show_battle_ui("battle")

# CPUのタイル処理
func _process_cpu_tile(tile: BaseTile, tile_info: Dictionary, player_index: int):
	if cpu_turn_processor:
		cpu_turn_processor.process_cpu_turn(tile, tile_info, player_index)
	else:
		print("Warning: CPU turn processor not set")
		_complete_action()

# === UI表示 ===

func show_summon_ui():
	if ui_manager:
		ui_manager.card_selection_filter = ""
		if ui_manager.phase_display:
			ui_manager.show_action_prompt("召喚するクリーチャーを選択")
		ui_manager.show_card_selection_ui(player_system.get_current_player())

func show_summon_ui_disabled():
	if ui_manager:
		if ui_manager.phase_display:
			ui_manager.show_action_prompt("自分の土地: 召喚不可（×でパス）")
		ui_manager.card_selection_filter = "disabled"
		ui_manager.show_card_selection_ui(player_system.get_current_player())

func show_level_up_ui(tile_info: Dictionary):
	if ui_manager:
		var current_player_index = board_system.current_player_index
		var current_magic = player_system.get_magic(current_player_index)
		ui_manager.show_level_up_ui(tile_info, current_magic)

func show_battle_ui(_mode: String = "battle"):
	if ui_manager:
		ui_manager.card_selection_filter = "battle"
		if ui_manager.phase_display:
			ui_manager.show_action_prompt("バトルするクリーチャーを選択、または×でパス")
		ui_manager.show_card_selection_ui(player_system.get_current_player())

func show_battle_ui_disabled():
	if ui_manager:
		if ui_manager.phase_display:
			ui_manager.show_action_prompt("peace呪い: 侵略不可（×でパス）")
		ui_manager.card_selection_filter = "disabled"
		ui_manager.show_card_selection_ui(player_system.get_current_player())

# === アクション処理 ===

func on_card_selected(card_index: int):
	if not is_action_processing:
		return
	
	# カード犠牲選択中は通常のカード選択を無視
	if summon_executor and summon_executor.is_sacrifice_selecting:
		return
	
	var current_player_index = board_system.current_player_index
	var current_tile = board_system.get_player_tile(current_player_index)
	var tile_info = board_system.get_tile_info(current_tile)
	
	# 特殊タイル上ではカード選択を無視（遠隔配置モード除く）
	var tile = board_system.tile_nodes.get(current_tile)
	if tile and _is_special_tile(tile.tile_type) and remote_placement_tile < 0:
		print("[TileActionProcessor] 特殊タイル上ではカードを使用できません")
		if ui_manager and ui_manager.phase_display:
			ui_manager.show_toast("特殊タイル上では召喚できません")
		return
	
	# 遠隔配置モードの場合は無条件で召喚処理
	if remote_placement_tile >= 0:
		print("[TileActionProcessor] 遠隔配置モードで召喚実行: card_index=%d" % card_index)
		await summon_executor.execute_summon(card_index, _complete_action, show_summon_ui)
		return
	elif tile_info["owner"] == -1 or tile_info["owner"] == current_player_index:
		# 召喚処理
		summon_executor.execute_summon(card_index, _complete_action, show_summon_ui)
	else:
		# バトル処理
		battle_executor.execute_battle(card_index, tile_info, _complete_action, show_battle_ui)

# パス処理
func on_action_pass():
	if not is_action_processing:
		return
	print("[パス処理] タイルアクション完了")
	_complete_action()

# レベルアップ選択時の処理
func on_level_up_selected(target_level: int, cost: int):
	if not is_action_processing:
		return
	
	if target_level == 0 or cost == 0:
		_complete_action()
		return
	
	var current_player_index = board_system.current_player_index
	var current_tile = board_system.get_player_tile(current_player_index)
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power >= cost:
		var tile = board_system.tile_nodes[current_tile]
		tile.set_level(target_level)
		player_system.add_magic(current_player_index, -cost)
		
		if board_system.tile_info_display:
			board_system.tile_info_display.update_display(current_tile, board_system.get_tile_info(current_tile))
		
		if ui_manager:
			ui_manager.update_player_info_panels()
			ui_manager.hide_level_up_ui()
		
		print("土地をレベル", target_level, "にアップグレード！（コスト: ", cost, "EP）")
	
	_complete_action()

# === コールバック ===

func _on_cpu_action_completed():
	_complete_action()

func _on_invasion_completed(success: bool, tile_index: int):
	invasion_completed.emit(success, tile_index)

# === ヘルパー関数 ===

func _is_special_tile(tile_type: String) -> bool:
	return TileHelper.is_special_type(tile_type)

# 外部からアクション完了を通知するための公開メソッド
func complete_action():
	_complete_action()

# クリーチャー交換処理
func execute_swap(tile_index: int, card_index: int, _old_creature_data: Dictionary):
	if not is_action_processing:
		print("Warning: Not processing any action")
		return
	
	if card_index < 0:
		print("[TileActionProcessor] 交換キャンセル")
		_complete_action()
		return
	
	var current_player_index = board_system.current_player_index
	var card_data = card_system.get_card_data_for_player(current_player_index, card_index)
	
	if card_data.is_empty():
		print("[TileActionProcessor] カードデータが取得できません")
		_complete_action()
		return
	
	# 最新のタイルデータを再取得
	var tile_info = board_system.get_tile_info(tile_index)
	var actual_creature_data = tile_info.get("creature", {})
	
	print("[デバッグ] タイルデータ再取得:")
	print("  tile_info.has_creature: ", tile_info.get("has_creature", false))
	print("  creature.name: ", actual_creature_data.get("name", "なし"))
	print("  creature.id: ", actual_creature_data.get("id", "なし"))
	
	if actual_creature_data.is_empty():
		print("[TileActionProcessor] エラー: タイルにクリーチャーがいません")
		_complete_action()
		return
	
	# コストチェック
	var cost_data = card_data.get("cost", 1)
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("ep", 0)
	else:
		cost = cost_data
	
	# ライフフォース呪いチェック
	if game_flow_manager and game_flow_manager.spell_cost_modifier:
		cost = game_flow_manager.spell_cost_modifier.get_modified_cost(current_player_index, card_data)
	
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power < cost:
		print("[TileActionProcessor] EP不足で交換できません")
		_complete_action()
		return
	
	print("[TileActionProcessor] クリーチャー交換開始")
	print("  対象土地: タイル", tile_index)
	print("  元のクリーチャー: ", actual_creature_data.get("name", "不明"))
	print("  新しいクリーチャー: ", card_data.get("name", "不明"))
	
	card_system.return_card_to_hand(current_player_index, actual_creature_data)
	card_system.use_card_for_player(current_player_index, card_index)
	player_system.add_magic(current_player_index, -cost)
	board_system.place_creature(tile_index, card_data)
	
	# ダウン状態を設定（不屈チェック）
	if board_system.tile_nodes.has(tile_index):
		var tile = board_system.tile_nodes[tile_index]
		if tile and tile.has_method("set_down_state"):
			if not PlayerBuffSystem.has_unyielding(card_data):
				tile.set_down_state(true)
			else:
				print("[TileActionProcessor] 不屈により交換後もダウンしません: タイル", tile_index)
	
	if ui_manager:
		ui_manager.hide_card_selection_ui()
		ui_manager.update_player_info_panels()
	
	var player_name = _get_current_player_name()
	set_pending_comment("%s がドミニオコマンド：交換" % player_name)
	
	print("[TileActionProcessor] クリーチャー交換完了")
	_complete_action()

# コメントを設定（complete_action時に表示）
func set_pending_comment(message: String, player_id: int = -1, force_click_wait: bool = true):
	pending_comment = message
	pending_comment_player_id = player_id
	pending_comment_force_click = force_click_wait

# アクション完了（内部用）
func _complete_action():
	print("[TileActionProcessor] _complete_action開始")
	
	if not is_action_processing:
		print("[TileActionProcessor] 既に完了済み、スキップ")
		return
	
	is_action_processing = false
	
	# コメント表示
	if not pending_comment.is_empty():
		await _show_pending_comment()
	
	# カメラを追従モードに戻す（人間プレイヤーのみ）
	var current_idx = board_system.current_player_index if board_system else 0
	var cpu_flags = game_flow_manager.player_is_cpu if game_flow_manager else []
	var is_cpu = cpu_flags[current_idx] if current_idx < cpu_flags.size() else false
	if board_system and not is_cpu:
		board_system.enable_follow_camera()
		board_system.return_camera_to_player()
	
	remote_placement_tile = -1
	
	print("[TileActionProcessor] action_completedシグナル発火")
	emit_signal("action_completed")

func _show_pending_comment():
	if pending_comment.is_empty():
		return
	
	var player_id = pending_comment_player_id
	if player_id < 0 and board_system:
		player_id = board_system.current_player_index
	
	if ui_manager and ui_manager.global_comment_ui:
		await ui_manager.show_comment_and_wait(pending_comment, player_id, pending_comment_force_click)
	
	pending_comment = ""
	pending_comment_player_id = -1
	pending_comment_force_click = true

func _get_current_player_name() -> String:
	if not player_system or not board_system:
		return "プレイヤー"
	var player_id = board_system.current_player_index
	if player_id < player_system.players.size():
		var player = player_system.players[player_id]
		if player:
			return player.name
	return "プレイヤー"

# ============================================================
# CPU用インターフェース（サブシステムに委譲）
# ============================================================

## CPU用召喚実行
func execute_summon_for_cpu(card_index: int) -> bool:
	is_action_processing = true
	var success = await summon_executor.execute_summon_for_cpu(card_index, _complete_action)
	if not success:
		is_action_processing = false
	return success

## CPU用バトル実行
func execute_battle_for_cpu(card_index: int, tile_info: Dictionary, item_index: int = -1) -> bool:
	is_action_processing = true
	var success = await battle_executor.execute_battle_for_cpu(card_index, tile_info, item_index, _complete_action)
	if not success:
		is_action_processing = false
	return success

# ============================================================
# 後方互換（外部参照用の委譲メソッド）
# ============================================================

## 召喚実行（special_tile_systemから呼ばれる）
func execute_summon(card_index: int):
	await summon_executor.execute_summon(card_index, _complete_action, show_summon_ui)

## 土地条件チェック（SummonConditionCheckerに委譲）
func check_lands_required(card_data: Dictionary, player_id: int) -> Dictionary:
	return SummonConditionChecker.check_lands_required(card_data, player_id, board_system)

## 配置制限チェック（SummonConditionCheckerに委譲）
func check_cannot_summon(card_data: Dictionary, tile_element: String) -> Dictionary:
	return SummonConditionChecker.check_cannot_summon(card_data, tile_element)

## 犠牲選択中フラグ（後方互換）
var is_sacrifice_selecting: bool:
	get: return summon_executor.is_sacrifice_selecting if summon_executor else false

## creature_synthesis参照（後方互換）
var creature_synthesis: CreatureSynthesis:
	get: return summon_executor.creature_synthesis if summon_executor else null

## sacrifice_selector参照（後方互換）
var sacrifice_selector:
	get: return summon_executor.sacrifice_selector if summon_executor else null

## card_sacrifice_helper参照（後方互換）
var card_sacrifice_helper:
	get: return summon_executor.card_sacrifice_helper if summon_executor else null

extends Node
class_name TileActionProcessor

# タイルアクション処理クラス
# タイル到着時の各種アクション処理を管理

signal action_completed()
signal invasion_completed(success: bool, tile_index: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# システム参照
var board_system: BoardSystem3D
var player_system: PlayerSystem
var card_system: CardSystem
var battle_system: BattleSystem
var special_tile_system: SpecialTileSystem
var ui_manager: UIManager
var cpu_turn_processor: CPUTurnProcessor

# 状態管理
var is_action_processing = false

func _ready():
	pass

# 初期化
func setup(b_system: BoardSystem3D, p_system: PlayerSystem, c_system: CardSystem,
		   bt_system: BattleSystem, st_system: SpecialTileSystem, ui: UIManager):
	board_system = b_system
	player_system = p_system
	card_system = c_system
	battle_system = bt_system
	special_tile_system = st_system
	ui_manager = ui

# CPUプロセッサーを設定
func set_cpu_processor(cpu_processor: CPUTurnProcessor):
	cpu_turn_processor = cpu_processor
	if cpu_turn_processor:
		cpu_turn_processor.cpu_action_completed.connect(_on_cpu_action_completed)

# === タイル到着処理 ===

# タイル到着時のメイン処理
func process_tile_landing(tile_index: int, current_player_index: int, player_is_cpu: Array, debug_manual_control_all: bool = false):
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
	if _is_special_tile(tile.tile_type) and tile.tile_type != "neutral":
		if special_tile_system:
			special_tile_system.special_action_completed.connect(_on_special_action_completed, CONNECT_ONE_SHOT)
			special_tile_system.process_special_tile_3d(tile.tile_type, tile_index, current_player_index)
		else:
			_complete_action()
		return
	
	# CPUかプレイヤーかで分岐（デバッグモードでは全て手動）
	var is_cpu_turn = player_is_cpu[current_player_index] and not debug_manual_control_all
	if is_cpu_turn:
		_process_cpu_tile(tile, tile_info, current_player_index)
	else:
		_process_player_tile(tile, tile_info, current_player_index)

# プレイヤーのタイル処理
func _process_player_tile(tile: BaseTile, tile_info: Dictionary, player_index: int):
	if tile_info["owner"] == -1:
		# 空き地
		show_summon_ui()
	elif tile_info["owner"] == player_index:
		# 自分の土地
		if tile.level < GameConstants.MAX_LEVEL:
			show_level_up_ui(tile_info)
		else:
			# レベルMAXの自分の土地 - アクション不要
			print("レベルMAXの自分の土地 - アクション不要")
			_complete_action()
	else:
		# 敵の土地
		if tile_info.get("creature", {}).is_empty():
			show_battle_ui("invasion")
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

# 召喚UI表示
func show_summon_ui():
	if ui_manager:
		ui_manager.phase_label.text = "召喚するクリーチャーを選択"
		ui_manager.show_card_selection_ui(player_system.get_current_player())

# レベルアップUI表示
func show_level_up_ui(tile_info: Dictionary):
	if ui_manager:
		var current_player_index = board_system.current_player_index
		var current_magic = player_system.get_magic(current_player_index)
		ui_manager.show_level_up_ui(tile_info, current_magic)

# バトルUI表示
func show_battle_ui(mode: String):
	if ui_manager:
		if mode == "invasion":
			ui_manager.phase_label.text = "侵略するクリーチャーを選択"
		else:
			ui_manager.phase_label.text = "バトルするクリーチャーを選択"
		ui_manager.show_card_selection_ui(player_system.get_current_player())

# === アクション処理 ===

# カード選択時の処理
func on_card_selected(card_index: int):
	if not is_action_processing:
		print("Warning: Not processing any action")
		return
	
	var current_player_index = board_system.current_player_index
	var current_tile = board_system.movement_controller.get_player_tile(current_player_index)
	var tile_info = board_system.get_tile_info(current_tile)
	
	if tile_info["owner"] == -1 or tile_info["owner"] == current_player_index:
		# 召喚処理
		execute_summon(card_index)
	else:
		# バトル処理
		var callable = Callable(self, "_on_battle_completed")
		if not battle_system.invasion_completed.is_connected(callable):
			battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
		
		battle_system.execute_3d_battle(current_player_index, card_index, tile_info)

# 召喚実行
func execute_summon(card_index: int):
	if card_index < 0:
		_complete_action()
		return
	
	var current_player_index = board_system.current_player_index
	var card_data = card_system.get_card_data_for_player(current_player_index, card_index)
	
	if card_data.is_empty():
		_complete_action()
		return
	
	var cost = card_data.get("cost", 1) * GameConstants.CARD_COST_MULTIPLIER
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power >= cost:
		# カード使用と魔力消費
		card_system.use_card_for_player(current_player_index, card_index)
		player_system.add_magic(current_player_index, -cost)
		
		# 土地取得とクリーチャー配置
		var current_tile = board_system.movement_controller.get_player_tile(current_player_index)
		board_system.set_tile_owner(current_tile, current_player_index)
		board_system.place_creature(current_tile, card_data)
		
		# Phase 1-A: 召喚後にダウン状態を設定
		if board_system.tile_nodes.has(current_tile):
			var tile = board_system.tile_nodes[current_tile]
			if tile and tile.has_method("set_down_state"):
				tile.set_down_state(true)
				print("[TileActionProcessor] 召喚後ダウン状態設定: タイル", current_tile)
		
		print("召喚成功！土地を取得しました")
		
		# UI更新
		if ui_manager:
			ui_manager.hide_card_selection_ui()
			ui_manager.update_player_info_panels()
	else:
		print("魔力不足で召喚できません")
	
	_complete_action()

# パス処理（通行料支払い）
func on_action_pass():
	if not is_action_processing:
		return
	
	var current_player_index = board_system.current_player_index
	var current_tile = board_system.movement_controller.get_player_tile(current_player_index)
	var tile_info = board_system.get_tile_info(current_tile)
	
	if tile_info["owner"] != -1 and tile_info["owner"] != current_player_index:
		var toll = board_system.calculate_toll(tile_info["index"])
		player_system.pay_toll(current_player_index, tile_info["owner"], toll)
		print("通行料 ", toll, "G を支払いました")
	
	_complete_action()

# レベルアップ選択時の処理
func on_level_up_selected(target_level: int, cost: int):
	if not is_action_processing:
		return
	
	if target_level == 0 or cost == 0:
		# キャンセル
		_complete_action()
		return
	
	var current_player_index = board_system.current_player_index
	var current_tile = board_system.movement_controller.get_player_tile(current_player_index)
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power >= cost:
		# レベルアップ実行
		var tile = board_system.tile_nodes[current_tile]
		tile.set_level(target_level)
		player_system.add_magic(current_player_index, -cost)
		
		# 表示更新
		if board_system.tile_info_display:
			board_system.tile_info_display.update_display(current_tile, board_system.get_tile_info(current_tile))
		
		if ui_manager:
			ui_manager.update_player_info_panels()
			ui_manager.hide_level_up_ui()
		
		print("土地をレベル", target_level, "にアップグレード！（コスト: ", cost, "G）")
	
	_complete_action()

# === コールバック ===

# 特殊アクション完了時
func _on_special_action_completed():
	_complete_action()

# バトル完了時
func _on_battle_completed(success: bool, tile_index: int):
	print("バトル結果受信: success=", success, " tile=", tile_index)
	
	if ui_manager:
		ui_manager.hide_card_selection_ui()
		ui_manager.update_player_info_panels()
	
	emit_signal("invasion_completed", success, tile_index)
	_complete_action()

# CPUアクション完了時
func _on_cpu_action_completed():
	_complete_action()

# === ヘルパー関数 ===

# 特殊タイルかチェック
func _is_special_tile(tile_type: String) -> bool:
	return tile_type in ["warp", "card", "checkpoint", "neutral", "start"]

# アクション完了
func _complete_action():
	is_action_processing = false
	emit_signal("action_completed")

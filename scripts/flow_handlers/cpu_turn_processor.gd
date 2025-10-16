extends Node
class_name CPUTurnProcessor

# CPUターン処理管理クラス
# BoardSystem3DからCPU関連処理を分離

signal cpu_action_completed()

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# システム参照
var board_system: BoardSystem3D
var cpu_ai_handler: CPUAIHandler
var player_system: PlayerSystem
var card_system: CardSystem
var ui_manager: UIManager

# 定数
const CPU_THINKING_DELAY = 0.5

func _ready():
	pass

# 初期化
func setup(b_system: BoardSystem3D, ai_handler: CPUAIHandler, 
		   p_system: PlayerSystem, c_system: CardSystem, ui: UIManager):
	board_system = b_system
	cpu_ai_handler = ai_handler
	player_system = p_system
	card_system = c_system
	ui_manager = ui

# CPUターンを処理
func process_cpu_turn(tile: BaseTile, tile_info: Dictionary, player_index: int):
	var current_player = player_system.get_current_player()
	
	# CPU思考時間のシミュレート
	await get_tree().create_timer(CPU_THINKING_DELAY).timeout
	
	# 既存の接続をクリーンアップ
	_cleanup_connections()
	
	# タイル状況に応じて処理を分岐
	var situation = _analyze_tile_situation(tile_info, player_index)
	
	match situation:
		"empty_land":
			_process_empty_land(current_player)
		"own_land":
			_process_own_land(current_player, tile, tile_info)
		"enemy_land_empty":
			_process_enemy_land_empty(current_player, tile_info)
		"enemy_land_defended":
			_process_enemy_land_defended(current_player, tile_info)
		_:
			_complete_action()

# タイル状況を分析
func _analyze_tile_situation(tile_info: Dictionary, player_index: int) -> String:
	if tile_info["owner"] == -1:
		return "empty_land"
	elif tile_info["owner"] == player_index:
		return "own_land"
	elif tile_info.get("creature", {}).is_empty():
		return "enemy_land_empty"
	else:
		return "enemy_land_defended"

# === 各状況の処理 ===

# 空き地の処理
func _process_empty_land(current_player):
	if card_system.get_hand_size_for_player(current_player.id) > 0:
		cpu_ai_handler.summon_decided.connect(_on_cpu_summon_decided, CONNECT_ONE_SHOT)
		cpu_ai_handler.decide_summon(current_player)
	else:
		_complete_action()

# 自分の土地の処理
func _process_own_land(current_player, tile: BaseTile, tile_info: Dictionary):
	if tile.level < GameConstants.MAX_LEVEL:
		cpu_ai_handler.level_up_decided.connect(_on_cpu_level_up_decided, CONNECT_ONE_SHOT)
		cpu_ai_handler.decide_level_up(current_player, tile_info)
	else:
		# レベルMAXの場合は即座に完了
		print("CPU: レベルMAXの自分の土地")
		_complete_action()

# 敵の空き地（侵略可能）の処理
func _process_enemy_land_empty(current_player, tile_info: Dictionary):
	cpu_ai_handler.battle_decided.connect(_on_cpu_invasion_decided, CONNECT_ONE_SHOT)
	cpu_ai_handler.decide_invasion(current_player, tile_info)

# 敵の防御地の処理
func _process_enemy_land_defended(current_player, tile_info: Dictionary):
	cpu_ai_handler.battle_decided.connect(_on_cpu_battle_decided, CONNECT_ONE_SHOT)
	cpu_ai_handler.decide_battle(current_player, tile_info)

# === コールバック処理 ===

# CPU召喚決定後の処理
func _on_cpu_summon_decided(card_index: int):
	if card_index >= 0:
		_execute_summon(card_index)
	else:
		_complete_action()

# CPU侵略決定後の処理
func _on_cpu_invasion_decided(card_index: int):
	var current_player_index = board_system.current_player_index
	var current_tile = board_system.movement_controller.get_player_tile(current_player_index)
	var tile_info = board_system.get_tile_info(current_tile)
	
	# バトルシステムに処理を委譲
	if not board_system.battle_system.invasion_completed.is_connected(_on_invasion_completed):
		board_system.battle_system.invasion_completed.connect(_on_invasion_completed, CONNECT_ONE_SHOT)
	
	board_system.battle_system.execute_3d_battle(current_player_index, card_index, tile_info)

# CPUバトル決定後の処理
func _on_cpu_battle_decided(card_index: int):
	# 侵略と同じ処理
	_on_cpu_invasion_decided(card_index)

# CPUレベルアップ決定後の処理
func _on_cpu_level_up_decided(do_upgrade: bool):
	if do_upgrade:
		var current_player_index = board_system.current_player_index
		var current_tile = board_system.movement_controller.get_player_tile(current_player_index)
		var cost = board_system.get_upgrade_cost(current_tile)
		
		if player_system.get_current_player().magic_power >= cost:
			board_system.upgrade_tile_level(current_tile)
			player_system.add_magic(current_player_index, -cost)
			
			# 表示更新
			if board_system.tile_info_display:
				board_system.update_all_tile_displays()
			if ui_manager:
				ui_manager.update_player_info_panels()
			
			print("CPU: 土地をレベルアップ！")
	
	_complete_action()

# 侵略完了後の処理
func _on_invasion_completed(_success: bool, _tile_index: int):
	if ui_manager:
		ui_manager.hide_card_selection_ui()
		ui_manager.update_player_info_panels()
	
	_complete_action()

# === ヘルパー関数 ===

# 召喚を実行
func _execute_summon(card_index: int):
	var current_player_index = board_system.current_player_index
	var card_data = card_system.get_card_data_for_player(current_player_index, card_index)
	
	if card_data.is_empty():
		_complete_action()
		return
	
	var cost_data = card_data.get("cost", 1)
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0) * GameConstants.CARD_COST_MULTIPLIER
	else:
		cost = cost_data * GameConstants.CARD_COST_MULTIPLIER
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power >= cost:
		# カード使用と魔力消費
		card_system.use_card_for_player(current_player_index, card_index)
		player_system.add_magic(current_player_index, -cost)
		
		# 土地取得とクリーチャー配置
		var current_tile = board_system.movement_controller.get_player_tile(current_player_index)
		board_system.set_tile_owner(current_tile, current_player_index)
		board_system.place_creature(current_tile, card_data)
		
		print("CPU: 召喚成功！")
		
		# UI更新
		if ui_manager:
			ui_manager.hide_card_selection_ui()
			ui_manager.update_player_info_panels()
	
	_complete_action()

# 接続をクリーンアップ
func _cleanup_connections():
	if not cpu_ai_handler:
		return
	
	var callables = [
		Callable(self, "_on_cpu_summon_decided"),
		Callable(self, "_on_cpu_battle_decided"),
		Callable(self, "_on_cpu_invasion_decided"),
		Callable(self, "_on_cpu_level_up_decided")
	]
	
	# 各シグナルの接続を解除
	if cpu_ai_handler.summon_decided.is_connected(callables[0]):
		cpu_ai_handler.summon_decided.disconnect(callables[0])
	if cpu_ai_handler.battle_decided.is_connected(callables[1]):
		cpu_ai_handler.battle_decided.disconnect(callables[1])
	if cpu_ai_handler.battle_decided.is_connected(callables[2]):
		cpu_ai_handler.battle_decided.disconnect(callables[2])
	if cpu_ai_handler.level_up_decided.is_connected(callables[3]):
		cpu_ai_handler.level_up_decided.disconnect(callables[3])

# アクション完了
func _complete_action():
	# board_systemのフラグ管理は削除（board_system側で管理）
	emit_signal("cpu_action_completed")

# === 拡張用インターフェース ===

# 難易度設定（将来実装用）
func set_difficulty(_level: String):
	pass
	# TODO: 難易度に応じた処理変更

# CPU性格設定（将来実装用）
func set_personality(_type: String):
	pass
	# TODO: 性格に応じた戦略変更

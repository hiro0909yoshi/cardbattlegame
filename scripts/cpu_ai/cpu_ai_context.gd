class_name CPUAIContext
extends RefCounted
## CPU AI 共有コンテキスト
##
## 全CPU AIモジュールで共有するシステム参照とインスタンスを一元管理
## 各AIはこのcontextを受け取ることで、個別の初期化が不要になる

# ============================================================
# 必須システム参照
# ============================================================

var board_system: Node = null
var player_system: PlayerSystem = null
var card_system: CardSystem = null

# ============================================================
# オプションシステム参照
# ============================================================

var creature_manager: Node = null
var lap_system: Node = null
var game_flow_manager: Node = null
var battle_system: BattleSystem = null
var player_buff_system: PlayerBuffSystem = null
var tile_action_processor: Node = null

# ============================================================
# バトルポリシー（性格）参照
# ============================================================
const CPUBattlePolicyScript = preload("res://scripts/cpu_ai/cpu_battle_policy.gd")
var battle_policy: CPUBattlePolicyScript = null

# ============================================================
# 共有インスタンス（遅延初期化）
# ============================================================

var _battle_simulator: BattleSimulator = null
var _hand_utils: CPUHandUtils = null

# ============================================================
# 初期化
# ============================================================

## メインセットアップ（必須システムのみ）
func setup(
	p_board_system: Node,
	p_player_system: PlayerSystem,
	p_card_system: CardSystem
) -> void:
	board_system = p_board_system
	player_system = p_player_system
	card_system = p_card_system
	
	# TileActionProcessor参照を取得
	if board_system and board_system.has_node("TileActionProcessor"):
		tile_action_processor = board_system.get_node("TileActionProcessor")


## オプションシステムを設定
func setup_optional(
	p_creature_manager: Node = null,
	p_lap_system: Node = null,
	p_game_flow_manager: Node = null,
	p_battle_system: BattleSystem = null,
	p_player_buff_system: PlayerBuffSystem = null
) -> void:
	if p_creature_manager:
		creature_manager = p_creature_manager
	if p_lap_system:
		lap_system = p_lap_system
	if p_game_flow_manager:
		game_flow_manager = p_game_flow_manager
	if p_battle_system:
		battle_system = p_battle_system
	if p_player_buff_system:
		player_buff_system = p_player_buff_system


## GameFlowManagerを後から設定
func set_game_flow_manager(gf_manager: Node) -> void:
	game_flow_manager = gf_manager
	# BattleSimulatorにも反映
	if _battle_simulator:
		_battle_simulator.setup_systems(board_system, card_system, player_system, game_flow_manager)

# ============================================================
# 共有インスタンス取得（遅延初期化）
# ============================================================

## BattleSimulatorを取得（共有インスタンス）
func get_battle_simulator() -> BattleSimulator:
	if _battle_simulator == null:
		var BattleSimulatorScript = preload("res://scripts/cpu_ai/battle_simulator.gd")
		_battle_simulator = BattleSimulatorScript.new()
		_battle_simulator.setup_systems(board_system, card_system, player_system, game_flow_manager)
	return _battle_simulator


## CPUHandUtilsを取得（共有インスタンス）
func get_hand_utils() -> CPUHandUtils:
	if _hand_utils == null:
		_hand_utils = CPUHandUtils.new()
		_hand_utils.setup_systems(card_system, board_system, player_system, player_buff_system)
	return _hand_utils


## BattleSimulatorのログ出力を切り替え
func set_simulator_log_enabled(enabled: bool) -> void:
	if _battle_simulator:
		_battle_simulator.enable_log = enabled

# ============================================================
# バリデーション
# ============================================================

## 必須システムが設定されているかチェック
func is_valid() -> bool:
	return board_system != null and player_system != null and card_system != null


## デバッグ用：設定状況を出力
func debug_print_status() -> void:
	print("[CPUAIContext] === 設定状況 ===")
	print("  board_system: %s" % ("OK" if board_system else "未設定"))
	print("  player_system: %s" % ("OK" if player_system else "未設定"))
	print("  card_system: %s" % ("OK" if card_system else "未設定"))
	print("  creature_manager: %s" % ("OK" if creature_manager else "未設定"))
	print("  lap_system: %s" % ("OK" if lap_system else "未設定"))
	print("  game_flow_manager: %s" % ("OK" if game_flow_manager else "未設定"))
	print("  battle_simulator: %s" % ("初期化済み" if _battle_simulator else "未初期化"))
	print("  hand_utils: %s" % ("初期化済み" if _hand_utils else "未初期化"))

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
var game_flow_manager = null  # GameFlowManagerへの参照
var cpu_turn_processor  # CPUTurnProcessor型を一時的に削除

# 状態管理
var is_action_processing = false

# バトル情報の一時保存
var pending_battle_card_index: int = -1
var pending_battle_card_data: Dictionary = {}  # カードデータを保存
var pending_battle_tile_info: Dictionary = {}
var pending_attacker_item: Dictionary = {}
var pending_defender_item: Dictionary = {}
var is_waiting_for_defender_item: bool = false

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

# CPUプロセッサーを設定
func set_cpu_processor(cpu_processor):  # CPUTurnProcessor型を一時的に削除
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
		# スペルカードは召喚フェーズでは使えないので、フィルターは空（スペル以外が選択可能）
		ui_manager.card_selection_filter = ""
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
		# 防御型クリーチャーはバトルで使用不可
		ui_manager.card_selection_filter = "battle"
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
		# バトル処理 - アイテムフェーズを挟む
		pending_battle_card_index = card_index
		pending_battle_card_data = card_system.get_card_data_for_player(current_player_index, card_index)
		pending_battle_tile_info = tile_info
		
		# バトルカードを先に消費（アイテムフェーズ中に手札に表示されないようにする）
		var cost_data = pending_battle_card_data.get("cost", 1)
		var cost = 0
		if typeof(cost_data) == TYPE_DICTIONARY:
			cost = cost_data.get("mp", 0)  # 等倍
		else:
			cost = cost_data  # 等倍
		
		var current_player = player_system.get_current_player()
		if current_player.magic_power < cost:
			print("[TileActionProcessor] 魔力不足でバトルできません")
			_complete_action()
			return
		
		# カードを使用して魔力消費
		card_system.use_card_for_player(current_player_index, card_index)
		player_system.add_magic(current_player_index, -cost)
		print("[TileActionProcessor] バトルカード消費: ", pending_battle_card_data.get("name", "???"))
		
		# GameFlowManagerのitem_phase_handlerを通じてアイテムフェーズ開始
		if game_flow_manager and game_flow_manager.item_phase_handler:
			# アイテムフェーズ完了シグナルに接続
			if not game_flow_manager.item_phase_handler.item_phase_completed.is_connected(_on_item_phase_completed):
				game_flow_manager.item_phase_handler.item_phase_completed.connect(_on_item_phase_completed, CONNECT_ONE_SHOT)
			
			# アイテムフェーズ開始（バトル参加クリーチャーのデータを渡す）
			game_flow_manager.item_phase_handler.start_item_phase(current_player_index, pending_battle_card_data)
		else:
			# ItemPhaseHandlerがない場合は直接バトル
			_execute_pending_battle()

## アイテムフェーズ完了後のコールバック
func _on_item_phase_completed():
	if not is_waiting_for_defender_item:
		# 攻撃側のアイテムフェーズ完了 → 防御側のアイテムフェーズ開始
		print("[TileActionProcessor] 攻撃側アイテムフェーズ完了")
		
		# 攻撃側のアイテムを保存
		if game_flow_manager and game_flow_manager.item_phase_handler:
			pending_attacker_item = game_flow_manager.item_phase_handler.get_selected_item()
		
		# 防御側のアイテムフェーズを開始
		var defender_owner = pending_battle_tile_info.get("owner", -1)
		if defender_owner >= 0:
			is_waiting_for_defender_item = true
			
			# 防御側のアイテムフェーズ開始
			if game_flow_manager and game_flow_manager.item_phase_handler:
				# 再度シグナルに接続（ONE_SHOTなので再接続が必要）
				if not game_flow_manager.item_phase_handler.item_phase_completed.is_connected(_on_item_phase_completed):
					game_flow_manager.item_phase_handler.item_phase_completed.connect(_on_item_phase_completed, CONNECT_ONE_SHOT)
				
				print("[TileActionProcessor] 防御側アイテムフェーズ開始: プレイヤー ", defender_owner + 1)
				# 防御側クリーチャーのデータを取得して渡す
				var defender_creature = pending_battle_tile_info.get("creature", {})
				game_flow_manager.item_phase_handler.start_item_phase(defender_owner, defender_creature)
			else:
				# ItemPhaseHandlerがない場合は直接バトル
				_execute_pending_battle()
		else:
			# 防御側がいない場合（ありえないが念のため）
			_execute_pending_battle()
	else:
		# 防御側のアイテムフェーズ完了 → バトル開始
		print("[TileActionProcessor] 防御側アイテムフェーズ完了、バトル開始")
		
		# 防御側のアイテムを保存
		if game_flow_manager and game_flow_manager.item_phase_handler:
			pending_defender_item = game_flow_manager.item_phase_handler.get_selected_item()
		
		is_waiting_for_defender_item = false
		_execute_pending_battle()

## 保留中のバトルを実行
func _execute_pending_battle():
	if pending_battle_card_index < 0 or pending_battle_card_data.is_empty():
		print("[TileActionProcessor] エラー: バトル情報が保存されていません")
		_complete_action()
		return
	
	var current_player_index = board_system.current_player_index
	
	# バトルカードは既に on_card_selected() で消費済み
	
	# バトル完了シグナルに接続
	var callable = Callable(self, "_on_battle_completed")
	if not battle_system.invasion_completed.is_connected(callable):
		battle_system.invasion_completed.connect(callable, CONNECT_ONE_SHOT)
	
	# バトル実行（カードデータとアイテム情報を渡す）
	# card_indexには-1を渡して、BattleSystem内でカード使用処理をスキップさせる
	battle_system.execute_3d_battle_with_data(current_player_index, pending_battle_card_data, pending_battle_tile_info, pending_attacker_item, pending_defender_item)
	
	# バトル情報をクリア
	pending_battle_card_index = -1
	pending_battle_card_data = {}
	pending_battle_tile_info = {}
	pending_attacker_item = {}
	pending_defender_item = {}
	is_waiting_for_defender_item = false

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
	
	# 防御型チェック: 空き地以外には召喚できない
	var creature_type = card_data.get("creature_type", "normal")
	if creature_type == "defensive":
		var current_tile = board_system.movement_controller.get_player_tile(current_player_index)
		var tile_info = board_system.get_tile_info(current_tile)
		
		# 空き地（owner = -1）でなければ召喚不可
		if tile_info["owner"] != -1:
			print("[TileActionProcessor] 防御型クリーチャーは空き地にのみ召喚できます")
			if ui_manager:
				ui_manager.phase_label.text = "防御型は空き地にのみ召喚可能です"
			_complete_action()
			return
	
	var cost_data = card_data.get("cost", 1)
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)  # 等倍
	else:
		cost = cost_data  # 等倍
	
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power >= cost:
		# カード使用と魔力消費
		card_system.use_card_for_player(current_player_index, card_index)
		player_system.add_magic(current_player_index, -cost)
		
		# 土地取得とクリーチャー配置
		var current_tile = board_system.movement_controller.get_player_tile(current_player_index)
		board_system.set_tile_owner(current_tile, current_player_index)
		board_system.place_creature(current_tile, card_data)
		
		# Phase 1-A: 召喚後にダウン状態を設定（不屈チェック）
		if board_system.tile_nodes.has(current_tile):
			var tile = board_system.tile_nodes[current_tile]
			if tile and tile.has_method("set_down_state"):
				# 不屈持ちでなければダウン状態にする
				if not SkillSystem.has_unyielding(card_data):
					tile.set_down_state(true)
					print("[TileActionProcessor] 召喚後ダウン状態設定: タイル", current_tile)
				else:
					print("[TileActionProcessor] 不屈により召喚後もダウンしません: タイル", current_tile)
		
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

# 外部からアクション完了を通知するための公開メソッド
func complete_action():
	_complete_action()

# Phase 1-D: クリーチャー交換処理
func execute_swap(tile_index: int, card_index: int, old_creature_data: Dictionary):
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
	
	# 🔄 最新のタイルデータを再取得（死者復活などで変身している可能性があるため）
	var tile_info = board_system.get_tile_info(tile_index)
	var actual_creature_data = tile_info.get("creature", {})
	
	# デバッグ: タイルデータの内容を確認
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
		cost = cost_data.get("mp", 0)  # 等倍
	else:
		cost = cost_data  # 等倍
	
	var current_player = player_system.get_current_player()
	
	if current_player.magic_power < cost:
		print("[TileActionProcessor] 魔力不足で交換できません")
		_complete_action()
		return
	
	print("[TileActionProcessor] クリーチャー交換開始")
	print("  対象土地: タイル", tile_index)
	print("  元のクリーチャー: ", actual_creature_data.get("name", "不明"))
	print("  新しいクリーチャー: ", card_data.get("name", "不明"))
	
	# 1. 元のクリーチャーを手札に戻す（最新のデータを使用）
	card_system.return_card_to_hand(current_player_index, actual_creature_data)
	
	# 2. 選択したカードを使用（手札から削除）
	card_system.use_card_for_player(current_player_index, card_index)
	
	# 3. 魔力消費
	player_system.add_magic(current_player_index, -cost)
	
	# 4. 新しいクリーチャーを配置（土地レベル・属性は維持される）
	board_system.place_creature(tile_index, card_data)
	
	# 5. ダウン状態を設定（不屈チェック）
	if board_system.tile_nodes.has(tile_index):
		var tile = board_system.tile_nodes[tile_index]
		if tile and tile.has_method("set_down_state"):
			# 不屈持ちでなければダウン状態にする
			if not SkillSystem.has_unyielding(card_data):
				tile.set_down_state(true)
				print("[TileActionProcessor] 交換後ダウン状態設定: タイル", tile_index)
			else:
				print("[TileActionProcessor] 不屈により交換後もダウンしません: タイル", tile_index)
	
	# UI更新
	if ui_manager:
		ui_manager.hide_card_selection_ui()
		ui_manager.update_player_info_panels()
	
	print("[TileActionProcessor] クリーチャー交換完了")
	_complete_action()

# アクション完了（内部用）
func _complete_action():
	is_action_processing = false
	emit_signal("action_completed")

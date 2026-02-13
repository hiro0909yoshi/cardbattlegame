extends Node
class_name CPUTurnProcessor

# CPUターン処理管理クラス
# BoardSystem3DからCPU関連処理を分離

signal cpu_action_completed()

# 定数をpreload
# TileHelper はグローバルclass_nameとして定義済み

# システム参照
var board_system: BoardSystem3D
var cpu_ai_handler: CPUAIHandler
var player_system: PlayerSystem
var card_system: CardSystem
var ui_manager: UIManager
var battle_system: BattleSystem  # battle_system参照

# === 直接参照（GFM経由を廃止） ===
var battle_status_overlay = null  # BattleStatusOverlay: バトルステータス表示
var item_phase_handler = null  # ItemPhaseHandler: アイテムフェーズ処理
var dominio_command_handler = null  # DominioCommandHandler: ドミニオコマンド処理

func set_battle_status_overlay(overlay) -> void:
	battle_status_overlay = overlay
	print("[CPUTurnProcessor] battle_status_overlay 直接参照を設定")

func set_item_phase_handler(handler) -> void:
	item_phase_handler = handler
	print("[CPUTurnProcessor] item_phase_handler 直接参照を設定")

func set_dominio_command_handler(handler) -> void:
	dominio_command_handler = handler
	print("[CPUTurnProcessor] dominio_command_handler 直接参照を設定")

# バトル保留用変数（CPU攻撃 → 人間防御のアイテムフェーズ用）
var pending_cpu_battle_creature_index: int = -1
var pending_cpu_battle_card_data: Dictionary = {}
var pending_cpu_battle_tile_info: Dictionary = {}
var pending_cpu_attacker_item: Dictionary = {}
var pending_cpu_defender_item: Dictionary = {}

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
	if board_system and board_system.get("battle_system"):
		battle_system = board_system.battle_system

# CPUターンを処理
func process_cpu_turn(tile: BaseTile, tile_info: Dictionary, player_index: int):
	var current_player = player_system.get_current_player()
	
	# ターン開始時にポリシーキャッシュをリセット
	if cpu_ai_handler:
		cpu_ai_handler.reset_turn_cache()
	
	# 通知ポップアップ等の完了を待機
	await _wait_for_notifications()
	
	# CPU思考時間のシミュレート
	await get_tree().create_timer(CPU_THINKING_DELAY).timeout
	
	# 既存の接続をクリーンアップ
	_cleanup_connections()
	
	# タイル状況に応じて処理を分岐
	var situation = _analyze_tile_situation(tile_info, player_index)
	
	match situation:
		"special_tile":
			# 特殊タイル（チェックポイント等）ではドミニオコマンドを検討
			print("CPU: 特殊タイル - ドミニオコマンド検討")
			_process_special_tile(current_player, tile_info)
		"empty_land":
			_process_empty_land(current_player)
		"own_land":
			_process_own_land(current_player, tile, tile_info)
		"enemy_land_empty":
			_process_enemy_land_empty(current_player, tile_info)
		"enemy_land_defended":
			_process_enemy_land_defended(current_player, tile_info)
		_:
			print("CPU: 不明な状況")
			_complete_action()

## 通知ポップアップ等の完了を待機
func _wait_for_notifications():
	if not board_system:
		return
	
	# GameFlowManagerからLapSystemを取得
	var gfm = board_system.game_flow_manager
	var lap_system = gfm.lap_system if gfm else null
	
	# GlobalCommentUIを取得
	var global_comment = ui_manager.global_comment_ui if ui_manager else null
	
	# 通知処理が完了するまで待機
	while true:
		var is_busy = false
		
		# LapSystemの処理中チェック
		if lap_system and lap_system.is_showing_notification:
			is_busy = true
		
		# GlobalCommentUIのクリック待ちチェック
		if global_comment and global_comment.waiting_for_click:
			is_busy = true
		
		if not is_busy:
			break
		
		await board_system.get_tree().process_frame

# タイル状況を分析
func _analyze_tile_situation(tile_info: Dictionary, player_index: int) -> String:
	# 特殊タイル（チェックポイント、ワープ等）は召喚不可
	if tile_info.get("is_special", false):
		return "special_tile"
	
	if tile_info["owner"] == -1:
		return "empty_land"
	elif tile_info["owner"] == player_index:
		return "own_land"
	elif tile_info.get("creature", {}).is_empty():
		return "enemy_land_empty"
	else:
		return "enemy_land_defended"

# === 各状況の処理 ===

# 特殊タイルの処理（チェックポイント、カードタイル等）
func _process_special_tile(current_player, tile_info: Dictionary):
	# 特殊タイルでは召喚不可、ドミニオコマンドのみ検討
	cpu_ai_handler.territory_command_decided.connect(_on_territory_command_decided, CONNECT_ONE_SHOT)
	cpu_ai_handler.decide_territory_command(current_player, tile_info, "special_tile")

# 空き地の処理
func _process_empty_land(current_player):
	var current_tile = board_system.get_player_tile(current_player.id)
	var tile_info = board_system.get_tile_info(current_tile)
	var tile_element = tile_info.get("element", "")
	
	# 召喚 vs ドミニオコマンドを比較
	var decision = cpu_ai_handler.decide_summon_or_territory(current_player, tile_info)
	
	if decision.get("action") == "territory_command":
		var command = decision.get("command", {})
		print("[CPU] ドミニオコマンドを選択: %s (スコア: %d)" % [command.get("type", "?"), command.get("score", 0)])
		_execute_territory_command(current_player, command)
	elif card_system.get_hand_size_for_player(current_player.id) > 0:
		cpu_ai_handler.summon_decided.connect(_on_cpu_summon_decided, CONNECT_ONE_SHOT)
		cpu_ai_handler.decide_summon(current_player, tile_element)
	else:
		_complete_action()

# 自分の土地の処理
func _process_own_land(current_player, _tile: BaseTile, tile_info: Dictionary):
	# ドミニオコマンドを評価
	cpu_ai_handler.territory_command_decided.connect(_on_territory_command_decided, CONNECT_ONE_SHOT)
	cpu_ai_handler.decide_territory_command(current_player, tile_info, "own_land")

# 敵の空き地（侵略可能）の処理
func _process_enemy_land_empty(current_player, tile_info: Dictionary):
	cpu_ai_handler.battle_decided.connect(_on_cpu_invasion_decided, CONNECT_ONE_SHOT)
	cpu_ai_handler.decide_invasion(current_player, tile_info)

# 敵の防御地の処理
func _process_enemy_land_defended(current_player, tile_info: Dictionary):
	# 侵略 vs ドミニオコマンドを比較
	var decision = cpu_ai_handler.decide_invasion_or_territory(current_player, tile_info)
	
	if decision.get("action") == "territory_command":
		var command = decision.get("command", {})
		print("[CPU] 敵ドミニオでドミニオコマンドを選択: %s (スコア: %d)" % [command.get("type", "?"), command.get("score", 0)])
		_execute_territory_command(current_player, command)
	elif decision.get("action") == "battle":
		cpu_ai_handler.battle_decided.connect(_on_cpu_battle_decided, CONNECT_ONE_SHOT)
		cpu_ai_handler.decide_battle(current_player, tile_info)
	else:
		# skip: 倒せないし有効なドミニオコマンドもない
		print("[CPU] 通行料を支払います")
		_complete_action()

# === コールバック処理 ===

# ドミニオコマンド決定後の処理
func _on_territory_command_decided(command: Dictionary):
	if command.is_empty():
		print("[CPU] ドミニオコマンド: 有効なオプションなし")
		_complete_action()
		return
	
	var current_player = player_system.get_current_player()
	_execute_territory_command(current_player, command)

# CPU召喚決定後の処理（TileActionProcessor経由）
func _on_cpu_summon_decided(card_index: int):
	if card_index >= 0:
		# TileActionProcessor経由で召喚（土地条件・合成処理含む）
		var success = await board_system.tile_action_processor.execute_summon_for_cpu(card_index)
		if not success:
			print("[CPU] 召喚失敗 → パス")
			_complete_action()
	else:
		# 召喚しなかった場合、ドミニオコマンドを検討
		_try_territory_command_instead()


## 召喚しなかった場合にドミニオコマンドを検討
func _try_territory_command_instead():
	var current_player = player_system.get_current_player()
	if current_player == null:
		_complete_action()
		return
	
	var current_tile = board_system.get_player_tile(current_player.id)
	var tile_info = board_system.get_tile_info(current_tile)
	
	# ドミニオコマンドを評価
	cpu_ai_handler.territory_command_decided.connect(_on_territory_command_decided, CONNECT_ONE_SHOT)
	cpu_ai_handler.decide_territory_command(current_player, tile_info, "empty_land")


# CPU侵略決定後の処理（TileActionProcessor経由）
func _on_cpu_invasion_decided(creature_index: int, item_index: int = -1):
	if creature_index < 0:
		_complete_action()
		return
	
	var current_player_index = board_system.current_player_index
	var current_tile = board_system.get_player_tile(current_player_index)
	var tile_info = board_system.get_tile_info(current_tile)
	
	# TileActionProcessor経由でバトル（土地条件・合成処理含む）
	# アイテムフェーズもTileActionProcessor内で処理される
	var success = await board_system.tile_action_processor.execute_battle_for_cpu(creature_index, tile_info, item_index)
	if not success:
		print("[CPU] バトル実行失敗 → パス")
		_complete_action()

## 防御側アイテムフェーズ完了時のコールバック
func _on_defender_item_phase_completed():
	print("[CPUTurnProcessor] 防御側アイテムフェーズ完了、バトル開始")

	# 防御側のアイテムを保存
	if item_phase_handler:
		pending_cpu_defender_item = item_phase_handler.get_selected_item()

		# 合体が発生した場合、tile_infoのcreatureを更新
		if item_phase_handler.was_merged():
			var merged_data = item_phase_handler.get_merged_creature()
			pending_cpu_battle_tile_info["creature"] = merged_data
			print("[CPUTurnProcessor] 防御側合体発生: %s" % merged_data.get("name", "?"))

			# タイルのクリーチャーデータも永続更新
			var tile_index = pending_cpu_battle_tile_info.get("index", -1)
			if tile_index >= 0 and board_system.tile_nodes.has(tile_index):
				var tile = board_system.tile_nodes[tile_index]
				tile.creature_data = merged_data

	await _execute_cpu_pending_battle()

## 保留中のCPUバトルを実行
func _execute_cpu_pending_battle():
	# 🎬 バトルステータスオーバーレイを非表示
	if battle_status_overlay:
		battle_status_overlay.hide_battle_status()
	
	var current_player_index = board_system.current_player_index
	
	# バトルシステムに処理を委譲
	if not battle_system.invasion_completed.is_connected(_on_invasion_completed):
		battle_system.invasion_completed.connect(_on_invasion_completed, CONNECT_ONE_SHOT)
	
	await battle_system.execute_3d_battle_with_data(
		current_player_index, 
		pending_cpu_battle_card_data, 
		pending_cpu_battle_tile_info, 
		pending_cpu_attacker_item, 
		pending_cpu_defender_item
	)
	
	# バトル情報をクリア
	pending_cpu_battle_creature_index = -1
	pending_cpu_battle_card_data = {}
	pending_cpu_battle_tile_info = {}
	pending_cpu_attacker_item = {}
	pending_cpu_defender_item = {}

## プレイヤーがCPUかどうか判定
func _is_cpu_player(player_index: int) -> bool:
	if board_system and "player_is_cpu" in board_system:
		var cpu_flags = board_system.player_is_cpu
		if player_index >= 0 and player_index < cpu_flags.size():
			return cpu_flags[player_index]
	return false

## アイテムフェーズ表示用の土地ボーナス計算
func _calculate_land_bonus_for_display(creature_data: Dictionary, tile_info: Dictionary) -> int:
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

# CPUバトル決定後の処理
func _on_cpu_battle_decided(creature_index: int, item_index: int = -1):
	# 侵略と同じ処理
	_on_cpu_invasion_decided(creature_index, item_index)

# CPUレベルアップ決定後の処理
func _on_cpu_level_up_decided(do_upgrade: bool):
	if do_upgrade:
		var current_player_index = board_system.current_player_index
		var current_tile = board_system.get_player_tile(current_player_index)
		var cost = board_system.get_upgrade_cost(current_tile)
		
		if player_system.get_current_player().magic_power >= cost:
			board_system.upgrade_tile_level(current_tile)
			player_system.add_magic(current_player_index, -cost)
			
			# 表示更新
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

# 旧召喚実装は削除済み（TileActionProcessor.execute_summon_for_cpu経由に変更）

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

# === スペルフェーズCPU処理 ===

signal cpu_spell_completed(used_spell: bool)

## CPUのスペルフェーズ処理
func process_cpu_spell_turn(player_id: int) -> void:
	await get_tree().create_timer(CPU_THINKING_DELAY).timeout
	
	# 簡易AI: 30%の確率でスペルを使用
	if randf() < 0.3 and card_system:
		var spells = _get_available_spells(player_id)
		if not spells.is_empty():
			var spell = spells[randi() % spells.size()]
			if _can_afford_spell(spell, player_id):
				cpu_spell_completed.emit(true)
				return
	
	cpu_spell_completed.emit(false)

## 利用可能なスペルカードを取得
func _get_available_spells(player_id: int) -> Array:
	if not card_system:
		return []
	
	var hand = card_system.get_all_cards_for_player(player_id)
	var spells = []
	
	for card in hand:
		if card.get("type", "") == "spell":
			spells.append(card)
	
	return spells

## スペルが使用可能か（コスト的に）
func _can_afford_spell(spell_card: Dictionary, player_id: int) -> bool:
	if not player_system:
		return false
	
	var magic = player_system.get_magic(player_id)
	
	var cost_data = spell_card.get("cost", {})
	if cost_data == null:
		cost_data = {}
	
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("ep", 0)
	
	return magic >= cost

# ============================================================
# ドミニオコマンド実行
# ============================================================

## ドミニオコマンドを実行（DominioCommandHandler経由）
func _execute_territory_command(_current_player, command: Dictionary):
	var command_type = command.get("type", "")

	# 通常の侵略は別処理
	if command_type == "invasion":
		var tile_index = command.get("tile_index", -1)
		var tile_info = board_system.get_tile_info(tile_index)
		cpu_ai_handler.battle_decided.connect(_on_cpu_battle_decided, CONNECT_ONE_SHOT)
		cpu_ai_handler.decide_battle(_current_player, tile_info)
		return

	# DominioCommandHandlerを使用
	if dominio_command_handler == null:
		print("[CPU] DominioCommandHandler取得失敗")
		_complete_action()
		return

	# Handler経由で実行
	var success = dominio_command_handler.execute_for_cpu(command)
	
	if success:
		print("[CPU] ドミニオコマンド実行成功: %s" % command_type)
	else:
		print("[CPU] ドミニオコマンド実行失敗: %s" % command_type)
		_complete_action()

# 旧ドミニオコマンド実装は削除済み（DominioCommandHandler.execute_for_cpu経由に変更）

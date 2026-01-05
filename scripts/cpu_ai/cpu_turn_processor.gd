extends Node
class_name CPUTurnProcessor

# CPUターン処理管理クラス
# BoardSystem3DからCPU関連処理を分離

signal cpu_action_completed()

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")
# TileHelper はグローバルclass_nameとして定義済み

# システム参照
var board_system: BoardSystem3D
var cpu_ai_handler: CPUAIHandler
var player_system: PlayerSystem
var card_system: CardSystem
var ui_manager: UIManager

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

# CPUターンを処理
func process_cpu_turn(tile: BaseTile, tile_info: Dictionary, player_index: int):
	var current_player = player_system.get_current_player()
	
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
			# 特殊タイル（チェックポイント等）では何もせず完了
			print("CPU: 特殊タイル - アクションなし")
			_complete_action()
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
func _on_cpu_invasion_decided(creature_index: int, item_index: int = -1):
	if creature_index < 0:
		_complete_action()
		return
	
	var current_player_index = board_system.current_player_index
	var current_tile = board_system.movement_controller.get_player_tile(current_player_index)
	var tile_info = board_system.get_tile_info(current_tile)
	
	# クリーチャーデータを取得
	var card_data = card_system.get_card_data_for_player(current_player_index, creature_index)
	if card_data.is_empty():
		_complete_action()
		return
	
	# アイテムデータを先に取得（クリーチャー使用後はインデックスがずれるため）
	var attacker_item = {}
	var adjusted_item_index = item_index
	if item_index >= 0:
		attacker_item = card_system.get_card_data_for_player(current_player_index, item_index)
		# クリーチャーよりアイテムのインデックスが大きい場合、クリーチャー使用後に1つずれる
		if item_index > creature_index:
			adjusted_item_index = item_index - 1
	
	# コスト計算と支払い
	var cost_data = card_data.get("cost", 1)
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0) * GameConstants.CARD_COST_MULTIPLIER
	else:
		cost = cost_data * GameConstants.CARD_COST_MULTIPLIER
	
	var current_player = player_system.get_current_player()
	if current_player.magic_power < cost:
		print("[CPU] 魔力不足でバトルできません")
		_complete_action()
		return
	
	# カード使用
	card_system.use_card_for_player(current_player_index, creature_index)
	player_system.add_magic(current_player_index, -cost)
	print("[CPU] バトルカード消費: %s" % card_data.get("name", "?"))
	
	# アイテム使用処理（調整後のインデックスを使用）
	if item_index >= 0 and not attacker_item.is_empty():
		# アイテムコスト支払い
		var item_cost = attacker_item.get("cost", 0)
		if typeof(item_cost) == TYPE_DICTIONARY:
			item_cost = item_cost.get("mp", 0)
		player_system.add_magic(current_player_index, -item_cost)
		card_system.use_card_for_player(current_player_index, adjusted_item_index)
		print("[CPU] アイテム使用: %s" % attacker_item.get("name", "?"))
	
	# 防御側が人間プレイヤーかチェック
	var defender_owner = tile_info.get("owner", -1)
	var defender_creature = tile_info.get("creature", {})
	var defender_is_human = defender_owner >= 0 and not _is_cpu_player(defender_owner)
	
	# 防御側クリーチャーがいて、人間プレイヤーの場合はアイテムフェーズを開始
	if not defender_creature.is_empty() and defender_is_human:
		print("[CPUTurnProcessor] 防御側は人間プレイヤー → アイテムフェーズ開始")
		
		# バトル情報を保存
		pending_cpu_battle_creature_index = creature_index
		pending_cpu_battle_card_data = card_data
		pending_cpu_battle_tile_info = tile_info
		pending_cpu_attacker_item = attacker_item
		pending_cpu_defender_item = {}
		
		# 🎬 バトルステータスオーバーレイ表示
		if board_system.game_flow_manager and board_system.game_flow_manager.battle_status_overlay:
			var attacker_display = card_data.duplicate()
			attacker_display["land_bonus_hp"] = 0  # 侵略側は土地ボーナスなし
			
			var defender_display = defender_creature.duplicate()
			defender_display["land_bonus_hp"] = _calculate_land_bonus_for_display(defender_creature, tile_info)
			
			board_system.game_flow_manager.battle_status_overlay.show_battle_status(
				attacker_display, defender_display, "defender")  # 防御側を強調
		
		# 防御側のアイテムフェーズ開始
		if board_system.game_flow_manager and board_system.game_flow_manager.item_phase_handler:
			var item_handler = board_system.game_flow_manager.item_phase_handler
			
			# アイテムフェーズ完了シグナルに接続
			# 既存の接続があれば切断してから再接続（前回のバトルで残っている可能性があるため）
			if item_handler.item_phase_completed.is_connected(_on_defender_item_phase_completed):
				item_handler.item_phase_completed.disconnect(_on_defender_item_phase_completed)
			item_handler.item_phase_completed.connect(_on_defender_item_phase_completed, CONNECT_ONE_SHOT)
			
			# 攻撃側クリーチャーデータを設定（無効化判定用）
			item_handler.set_opponent_creature(card_data)
			# タイル情報を設定（シミュレーション用）
			item_handler.set_defense_tile_info(tile_info)
			# アイテムフェーズ開始
			item_handler.start_item_phase(defender_owner, defender_creature)
		else:
			# ItemPhaseHandlerがない場合は直接バトル
			await _execute_cpu_pending_battle()
	else:
		# 防御側がCPUまたは空き地の場合は直接バトル
		if not board_system.battle_system.invasion_completed.is_connected(_on_invasion_completed):
			board_system.battle_system.invasion_completed.connect(_on_invasion_completed, CONNECT_ONE_SHOT)
		
		await board_system.battle_system.execute_3d_battle_with_data(current_player_index, card_data, tile_info, attacker_item, {})

## 防御側アイテムフェーズ完了時のコールバック
func _on_defender_item_phase_completed():
	print("[CPUTurnProcessor] 防御側アイテムフェーズ完了、バトル開始")
	
	# 防御側のアイテムを保存
	if board_system.game_flow_manager and board_system.game_flow_manager.item_phase_handler:
		var item_handler = board_system.game_flow_manager.item_phase_handler
		pending_cpu_defender_item = item_handler.get_selected_item()
		
		# 合体が発生した場合、tile_infoのcreatureを更新
		if item_handler.was_merged():
			var merged_data = item_handler.get_merged_creature()
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
	if board_system.game_flow_manager and board_system.game_flow_manager.battle_status_overlay:
		board_system.game_flow_manager.battle_status_overlay.hide_battle_status()
	
	var current_player_index = board_system.current_player_index
	
	# バトルシステムに処理を委譲
	if not board_system.battle_system.invasion_completed.is_connected(_on_invasion_completed):
		board_system.battle_system.invasion_completed.connect(_on_invasion_completed, CONNECT_ONE_SHOT)
	
	await board_system.battle_system.execute_3d_battle_with_data(
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
	
	# ライフフォース呪いチェック（クリーチャーコスト0化）
	if board_system and board_system.game_flow_manager and board_system.game_flow_manager.spell_cost_modifier:
		cost = board_system.game_flow_manager.spell_cost_modifier.get_modified_cost(current_player_index, card_data)
	
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
		cost = cost_data.get("mp", 0)
	
	return magic >= cost


extends Node
class_name BoardSystem3D

# 3Dボード管理システム - スリム化版
# サブシステムへの処理委譲に特化

signal tile_action_completed()
signal terrain_changed(tile_index: int, old_element: String, new_element: String)
@warning_ignore("unused_signal")
signal level_up_completed(tile_index: int, new_level: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# タイルシーン
const TILE_SCENES = {
	"fire": preload("res://scenes/Tiles/FireTile.tscn"),
	"water": preload("res://scenes/Tiles/WaterTile.tscn"),
	"earth": preload("res://scenes/Tiles/EarthTile.tscn"),
	"wind": preload("res://scenes/Tiles/WindTile.tscn"),
	"neutral": preload("res://scenes/Tiles/NeutralTile.tscn")
}

# スキルインデックス（盤面効果スキルの高速検索用）
var skill_index: Dictionary = {
	"support": {},    # {tile_index: {creature_data, player_id, support_data}}
	"world_spell": {} # {tile_index: {creature_data, player_id, world_spell_data}}
}

# サブシステム
var movement_controller: MovementController3D
var tile_info_display: TileInfoDisplay
var tile_data_manager: TileDataManager
var tile_neighbor_system: TileNeighborSystem
var tile_action_processor: TileActionProcessor
var cpu_turn_processor  # CPUTurnProcessor（型指定を一時的に削除）

# ゲーム設定
var player_count = 2
var player_is_cpu = [false, true]
var current_player_index = 0
var debug_manual_control_all: bool = false  # GameFlowManagerから設定される

# 状態管理は TileActionProcessor に統一

# 3Dノード参照
var tile_nodes = {}        # tile_index -> BaseTile
var player_nodes = []      # 3D駒のノード配列
var camera = null
var camera_controller: CameraController = null

# システム参照
var player_system: PlayerSystem
var card_system: CardSystem
var battle_system: BattleSystem
var player_buff_system: PlayerBuffSystem
var special_tile_system: SpecialTileSystem
var ui_manager: UIManager
var cpu_ai_handler: CPUAIHandler
var game_flow_manager = null  # GameFlowManagerへの参照

# === 初期化 ===

func _ready():
	# CreatureManagerを最初に作成
	create_creature_manager()
	create_subsystems()

func create_creature_manager():
	"""CreatureManagerを作成してBaseTileに設定"""
	var cm = CreatureManager.new()
	cm.name = "CreatureManager"
	cm.board_system = self
	add_child(cm)
	
	# BaseTileの静的参照を設定
	BaseTile.creature_manager = cm
	
	print("[BoardSystem3D] CreatureManager統合完了")

func create_subsystems():
	# 既存のサブシステム
	tile_info_display = TileInfoDisplay.new()
	tile_info_display.name = "TileInfoDisplay"
	add_child(tile_info_display)
	
	# BaseTileの静的参照を設定（通行料ラベル自動更新用）
	BaseTile.tile_info_display = tile_info_display
	
	movement_controller = MovementController3D.new()
	movement_controller.name = "MovementController3D"
	add_child(movement_controller)
	
	# 新規サブシステム
	tile_data_manager = TileDataManager.new()
	tile_data_manager.name = "TileDataManager"
	add_child(tile_data_manager)
	
	tile_neighbor_system = TileNeighborSystem.new()
	tile_neighbor_system.name = "TileNeighborSystem"
	add_child(tile_neighbor_system)
	
	tile_action_processor = TileActionProcessor.new()
	tile_action_processor.name = "TileActionProcessor"
	add_child(tile_action_processor)
	
	# CPUTurnProcessorを動的にロード
	var CPUTurnProcessorClass = load("res://scripts/flow_handlers/cpu_turn_processor.gd")
	if CPUTurnProcessorClass:
		cpu_turn_processor = CPUTurnProcessorClass.new()
		cpu_turn_processor.name = "CPUTurnProcessor"
		add_child(cpu_turn_processor)
	else:
		print("ERROR: CPUTurnProcessorクラスが読み込めません")
	
	# シグナル接続
	movement_controller.movement_started.connect(_on_movement_started)
	movement_controller.movement_completed.connect(_on_movement_completed)
	tile_action_processor.action_completed.connect(_on_action_completed)
	cpu_turn_processor.cpu_action_completed.connect(_on_action_completed)

func setup_systems(p_system: PlayerSystem, c_system: CardSystem, b_system: BattleSystem, 
				   s_system: PlayerBuffSystem, st_system: SpecialTileSystem = null, gf_manager = null):
	player_system = p_system
	card_system = c_system
	battle_system = b_system
	player_buff_system = s_system
	special_tile_system = st_system
	game_flow_manager = gf_manager
	
	# CPUAIHandlerを先に設定（他のシステムが依存するため）
	setup_cpu_ai_handler()
	
	# BattleSystemに参照を設定
	if battle_system.has_method("setup_systems"):
		battle_system.setup_systems(self, card_system, player_system)
	
	# MovementControllerに参照を設定
	if movement_controller:
		# game_flow_managerは後で設定される
		movement_controller.setup_systems(player_system, special_tile_system)
	
	# TileDataManagerに参照を設定
	tile_data_manager.set_display_system(tile_info_display)
	tile_data_manager.set_game_flow_manager(game_flow_manager)
	
	# ui_managerが設定されてからサブシステムを初期化
	await get_tree().process_frame
	
	# TileActionProcessorに参照を設定（ui_manager必須）
	if ui_manager:
		tile_action_processor.setup(self, player_system, card_system, 
									battle_system, special_tile_system, ui_manager, game_flow_manager)
		tile_action_processor.set_cpu_processor(cpu_turn_processor)
		
		# CPUTurnProcessorに参照を設定
		cpu_turn_processor.setup(self, cpu_ai_handler, player_system, 
								card_system, ui_manager)

func setup_cpu_ai_handler():
	cpu_ai_handler = get_node_or_null("CPUAIHandler")
	if not cpu_ai_handler:
		cpu_ai_handler = CPUAIHandler.new()
		cpu_ai_handler.name = "CPUAIHandler"
		add_child(cpu_ai_handler)
	
	if cpu_ai_handler.has_method("setup_systems"):
		cpu_ai_handler.setup_systems(card_system, self, player_system, battle_system, player_buff_system)

# === 3Dノード収集 ===

func collect_tiles(tiles_container: Node):
	for child in tiles_container.get_children():
		if child is BaseTile:
			tile_nodes[child.tile_index] = child
	
	# サブシステムに渡す
	tile_data_manager.set_tile_nodes(tile_nodes)
	movement_controller.tile_nodes = tile_nodes
	
	if tile_info_display:
		tile_info_display.setup_labels(tile_nodes, self)
	
	# 隣接システムの初期化
	if tile_neighbor_system:
		tile_neighbor_system.setup(tile_nodes)
	
	tile_data_manager.update_all_displays()

func collect_players(players_container: Node):
	player_nodes = players_container.get_children()
	
	if movement_controller:
		movement_controller.initialize(tile_nodes, player_nodes, camera)
		
		# 初期配置
		for i in range(player_nodes.size()):
			movement_controller.place_player_at_tile(i, 0)

# === タイルデータ管理（TileDataManagerに委譲） ===

func get_tile_info(tile_index: int) -> Dictionary:
	return tile_data_manager.get_tile_info(tile_index)

func get_tile_type(tile_type_str: String) -> int:
	return tile_data_manager.get_tile_type(tile_type_str)

func is_special_tile_type(tile_type: String) -> bool:
	return tile_data_manager.is_special_tile_type(tile_type)

func set_tile_owner(tile_index: int, owner_id: int):
	tile_data_manager.set_tile_owner(tile_index, owner_id)

func place_creature(tile_index: int, creature_data: Dictionary, player_id: int = -1):
	"""クリーチャーを配置し、スキルインデックスを更新"""
	tile_data_manager.place_creature(tile_index, creature_data)
	
	# player_idが指定されていない場合、タイルの所有者から取得
	if player_id == -1:
		var tile_info = get_tile_info(tile_index)
		player_id = tile_info.get("owner", -1)
	
	# スキルインデックスを更新
	_update_skill_index_on_place(tile_index, creature_data, player_id)

func update_tile_creature(tile_index: int, new_creature_data: Dictionary):
	"""タイルのクリーチャーデータを更新（変身用）"""
	if not tile_nodes.has(tile_index):
		print("[警告] タイルが存在しません: ", tile_index)
		return
	
	var tile_info = get_tile_info(tile_index)
	if not tile_info.get("has_creature", false):
		print("[警告] クリーチャーが配置されていません: ", tile_index)
		return
	
	# 既存のクリーチャーを削除（スキルインデックスから）
	_update_skill_index_on_remove(tile_index)
	
	# 新しいクリーチャーデータで更新
	tile_data_manager.place_creature(tile_index, new_creature_data)
	
	# スキルインデックスを更新
	var player_id = tile_info.get("owner", -1)
	_update_skill_index_on_place(tile_index, new_creature_data, player_id)
	
	# ビジュアル更新
	var tile = tile_nodes[tile_index]
	if tile.has_method("update_visual"):
		tile.update_visual()
	
	# 3Dカード表示を更新
	if tile.has_method("update_creature_data"):
		tile.update_creature_data(new_creature_data)
	
	print("[BoardSystem3D] クリーチャー更新: タイル%d → %s" % [tile_index, new_creature_data.get("name", "?")])

func remove_creature(tile_index: int):
	"""クリーチャーを除去し、スキルインデックスを更新"""
	if not tile_nodes.has(tile_index):
		return
	
	# スキルインデックスから削除
	_update_skill_index_on_remove(tile_index)
	
	var tile = tile_nodes[tile_index]
	
	# BaseTileのremove_creature()を呼び出して3Dカードも削除
	# BaseTileのremove_creature()を呼び出して3Dカードも削除
	tile.remove_creature()
	
	print("[BoardSystem3D] クリーチャー除去: タイル%d" % tile_index)

func upgrade_tile_level(tile_index: int) -> bool:
	return tile_data_manager.upgrade_tile_level(tile_index)

func get_upgrade_cost(tile_index: int) -> int:
	return tile_data_manager.get_upgrade_cost(tile_index)

func calculate_toll(tile_index: int, map_id: String = "") -> int:
	return tile_data_manager.calculate_toll(tile_index, map_id)

func calculate_chain_bonus(tile_index: int, owner_id: int) -> float:
	return tile_data_manager.calculate_chain_bonus(tile_index, owner_id)

func get_element_chain_count(tile_index: int, owner_id: int) -> int:
	return tile_data_manager.get_element_chain_count(tile_index, owner_id)

func get_owner_land_count(owner_id: int) -> int:
	return tile_data_manager.get_owner_land_count(owner_id)

func get_player_lands_by_element(player_id: int) -> Dictionary:
	return tile_data_manager.get_owner_element_counts(player_id)

func update_all_tile_displays():
	tile_data_manager.update_all_displays()

func get_tile_data_array() -> Array:
	return tile_data_manager.get_tile_data_array()

# プレイヤーが所有している全タイルを取得
func get_player_tiles(player_id: int) -> Array:
	var player_tiles = []
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.owner_id == player_id:
			player_tiles.append(tile)
	return player_tiles

# プレイヤーが所有しているタイルのインデックスを取得
func get_player_owned_tiles(player_id: int) -> Array:
	var owned_tile_indices = []
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.owner_id == player_id:
			owned_tile_indices.append(tile_index)
	return owned_tile_indices

# === 地形変化システム ===



## タイルインスタンスを生成
func create_tile_instance(element: String, tile_index: int) -> BaseTile:
	if not TILE_SCENES.has(element):
		push_error("[BoardSystem3D] 不明な属性: " + element)
		return null
	
	var tile_scene = TILE_SCENES[element]
	var new_tile = tile_scene.instantiate()
	new_tile.tile_index = tile_index
	return new_tile

## 地形変化を実行（タイル交換）
func change_tile_terrain(tile_index: int, new_element: String) -> bool:
	if not tile_nodes.has(tile_index):
		print("[BoardSystem3D] エラー: タイルが存在しません: ", tile_index)
		return false
	
	var old_tile = tile_nodes[tile_index]
	var old_element = old_tile.tile_type  # tile_typeプロパティを使用
	
	# 同じ属性への変更は無視
	if old_element == new_element:
		print("[BoardSystem3D] 既に同じ属性です: ", new_element)
		return false
	
	# データ保存
	var old_position = old_tile.global_position
	var old_rotation = old_tile.rotation
	var old_level = old_tile.level
	var old_owner = old_tile.owner_id
	var old_creature = old_tile.creature_data.duplicate() if not old_tile.creature_data.is_empty() else {}
	var old_down_state = old_tile.is_down  # BaseTileには必ずis_downプロパティがある
	
	# 新しいタイル生成
	var new_tile = create_tile_instance(new_element, tile_index)
	if not new_tile:
		push_error("[BoardSystem3D] タイル生成失敗")
		return false
	
	# 先に新しいタイルをツリーに追加
	add_child(new_tile)
	
	# 古いタイルをスキルインデックスから除去
	_update_skill_index_on_remove(tile_index)
	
	# tile_nodesを新しいタイルに置き換え
	tile_nodes[tile_index] = new_tile
	
	# 古いタイルを削除（最後に実行）
	old_tile.queue_free()
	
	# データ引き継ぎ（ツリーに追加した後）
	new_tile.global_position = old_position
	new_tile.rotation = old_rotation
	new_tile.level = old_level
	new_tile.owner_id = old_owner
	# 【SSoT同期】古いタイルのクリーチャーを新しいタイルに引き継ぎ
	# この代入は自動的にCreatureManager.set_data(tile_index, old_creature)を呼び出し
	# 同じtile_indexのCreatureManager.creatures[tile_index]が更新される
	new_tile.creature_data = old_creature
	
	if old_down_state and new_tile.has_method("set_down_state"):
		new_tile.set_down_state(true)
	
	# TileDataManagerに通知
	if tile_data_manager:
		tile_data_manager.set_tile_nodes(tile_nodes)
	
	# クリーチャーがいる場合、3Dモデルを再生成
	if not old_creature.is_empty():
		# スキルインデックス更新
		_update_skill_index_on_place(tile_index, old_creature, old_owner)
		# クリーチャー3Dモデルを再配置
		if tile_data_manager:
			tile_data_manager.place_creature(tile_index, old_creature)
	
	# TileInfoDisplayに新しいタイルのラベルを追加
	if tile_info_display:
		# 古いラベルを削除
		if tile_info_display.tile_labels.has(tile_index):
			var old_label = tile_info_display.tile_labels[tile_index]
			if is_instance_valid(old_label):
				old_label.queue_free()
			tile_info_display.tile_labels.erase(tile_index)
		
		# 新しいラベルを作成
		var label = Label3D.new()
		label.name = "InfoLabel"
		label.text = ""
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = false
		label.pixel_size = 0.005
		label.position = Vector3(0, 0.5, 1.5)
		label.modulate = Color.WHITE
		label.font_size = 70
		label.outline_size = 8
		label.outline_modulate = Color.BLACK
		
		new_tile.add_child(label)
		tile_info_display.tile_labels[tile_index] = label
	
	# 全体表示更新
	if tile_data_manager:
		tile_data_manager.update_all_displays()
	
	print("[地形変化] タイル%d: %s → %s (Lv%d)" % [tile_index, old_element, new_element, old_level])
	
	# イベント発火（永続バフ更新用）
	terrain_changed.emit(tile_index, old_element, new_element)
	
	# クリーチャーがいる場合、永続バフを更新
	if not old_creature.is_empty():
		_apply_terrain_change_buff(old_creature)
	
	return true

## 地形変化時の永続バフ更新
func _apply_terrain_change_buff(creature_data: Dictionary):
	var creature_id = creature_data.get("id", -1)
	
	# アースズピリット（ID: 200）: MHP+10
	if creature_id == 200:
		EffectManager.apply_max_hp_effect(creature_data, 10)
		print("[アースズピリット] 地形変化 MHP+10 (合計: +%d)" % creature_data["base_up_hp"])
	
	# デュータイタン（ID: 328）: MHP-10
	if creature_id == 328:
		EffectManager.apply_max_hp_effect(creature_data, -10)
		print("[デュータイタン] 地形変化 MHP-10 (合計: %d)" % creature_data["base_up_hp"])

## 地形変化可能かチェック
func can_change_terrain(tile_index: int) -> bool:
	if not tile_nodes.has(tile_index):
		return false
	
	var tile = tile_nodes[tile_index]
	return TileHelper.can_change_terrain(tile)

## 地形変化コストを計算
func calculate_terrain_change_cost(tile_index: int) -> int:
	if not tile_nodes.has(tile_index):
		return -1
	
	# spell_landに委譲（アーキミミック、無属性タイル対応）
	if game_flow_manager and game_flow_manager.spell_land:
		return game_flow_manager.spell_land.calculate_terrain_change_cost(tile_index)
	
	# フォールバック：従来の計算
	var tile = tile_nodes[tile_index]
	var level = tile.level
	return 300 + (level * 100)

# === 移動処理（MovementController3Dに委譲） ===

func move_player_3d(player_id: int, steps: int, dice_value: int = 0):
	if movement_controller:
		movement_controller.move_player(player_id, steps, dice_value)

func _on_movement_started(_player_id: int):
	if ui_manager:
		ui_manager.phase_label.text = "移動中..."

func _on_movement_completed(_player_id: int, final_tile: int):
	# 土地呪いチェック（ブラストトラップ等）- 移動完了時に即発動
	if game_flow_manager and game_flow_manager.has_method("trigger_land_curse_on_stop"):
		game_flow_manager.trigger_land_curse_on_stop(final_tile, current_player_index)
	
	# 移動完了後、領地コマンドボタンを表示（人間プレイヤーのみ）
	var is_cpu = current_player_index < player_is_cpu.size() and player_is_cpu[current_player_index] and not debug_manual_control_all
	if not is_cpu and ui_manager:
		ui_manager.show_land_command_button()
	elif ui_manager:
		ui_manager.hide_land_command_button()
	
	process_tile_landing(final_tile)

# === タイルアクション処理（TileActionProcessorに委譲） ===

func process_tile_landing(tile_index: int):
	tile_action_processor.process_tile_landing(tile_index, current_player_index, player_is_cpu, debug_manual_control_all)

func on_card_selected(card_index: int):
	tile_action_processor.on_card_selected(card_index)

func on_action_pass():
	tile_action_processor.on_action_pass()

func on_level_up_selected(target_level: int, cost: int):
	tile_action_processor.on_level_up_selected(target_level, cost)

func _on_action_completed():
	# TileActionProcessorから通知を受けたらシグナルを転送
	emit_signal("tile_action_completed")

# === スキルインデックス管理 ===

## スキルインデックス更新（配置時）
func _update_skill_index_on_place(tile_index: int, creature_data: Dictionary, player_id: int) -> void:
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 応援スキルチェック
	if "応援" in keywords:
		skill_index["support"][tile_index] = {
			"creature_data": creature_data,
			"player_id": player_id,
			"tile_index": tile_index,
			"support_data": {}  # 将来実装
		}
		print("[スキルインデックス] 応援登録: タイル", tile_index, " - ", creature_data.get("name", "?"))
	
	# 世界呪チェック（将来実装）
	# if has_world_spell(ability_parsed): ...

## スキルインデックス更新（除去時）
func _update_skill_index_on_remove(tile_index: int) -> void:
	var had_skills = []
	
	if tile_index in skill_index["support"]:
		had_skills.append("応援")
		skill_index["support"].erase(tile_index)
	
	if tile_index in skill_index["world_spell"]:
		had_skills.append("世界呪")
		skill_index["world_spell"].erase(tile_index)
	
	if had_skills.size() > 0:
		print("[スキルインデックス] スキル削除: タイル", tile_index, " - ", had_skills)

## インデックスから応援持ちクリーチャーを取得
func get_support_creatures() -> Dictionary:
	return skill_index["support"]

## デバッグ用：インデックス状態を表示
func debug_print_skill_index() -> void:
	print("[スキルインデックス状態]")
	print("  応援: ", skill_index["support"].keys())
	print("  世界呪: ", skill_index["world_spell"].keys())

## Phase 3-B用: 自領地数をカウント（バーンタイタン用）
func get_player_owned_land_count(player_id: int) -> int:
	if not tile_data_manager:
		return 0
	# TileDataManagerの既存メソッドを使用
	return tile_data_manager.get_owner_land_count(player_id)

## Phase 3-B用: 特定の名前のクリーチャーをカウント
func count_creatures_by_name(player_id: int, creature_name: String) -> int:
	if not tile_data_manager:
		return 0
	
	var count = 0
	for tile_index in tile_data_manager.tile_nodes:
		var tile = tile_data_manager.tile_nodes[tile_index]
		if tile.owner_id == player_id and tile.creature_data != null and not tile.creature_data.is_empty():
			var tile_creature_name = tile.creature_data.get("name", "")
			if tile_creature_name == creature_name:
				count += 1
	return count

## Phase 3-B用: 特定の属性のクリーチャーをカウント
func count_creatures_by_element(player_id: int, element: String) -> int:
	if not tile_data_manager:
		return 0
	
	var count = 0
	for tile_index in tile_data_manager.tile_nodes:
		var tile = tile_data_manager.tile_nodes[tile_index]
		if tile.owner_id == player_id and tile.creature_data != null and not tile.creature_data.is_empty():
			var creature_element = tile.creature_data.get("element", "")
			if creature_element == element:
				count += 1
	return count

## 盤面全体（全プレイヤー）で特定の属性のクリーチャーをカウント
func count_all_creatures_by_element(element: String) -> int:
	if not tile_data_manager:
		return 0
	
	var count = 0
	for tile_index in tile_data_manager.tile_nodes:
		var tile = tile_data_manager.tile_nodes[tile_index]
		if tile.creature_data != null and not tile.creature_data.is_empty():
			var creature_element = tile.creature_data.get("element", "")
			if creature_element == element:
				count += 1
	return count

## 特定の種族（race）のクリーチャーをカウント
func count_creatures_by_race(player_id: int, race: String) -> int:
	if not tile_data_manager:
		return 0
	
	var count = 0
	for tile_index in tile_data_manager.tile_nodes:
		var tile = tile_data_manager.tile_nodes[tile_index]
		if tile.owner_id == player_id and tile.creature_data != null and not tile.creature_data.is_empty():
			var creature_race = tile.creature_data.get("race", "")
			if creature_race == race:
				count += 1
	return count

## 全プレイヤーを対象に特定のクリーチャー名をカウント（敵味方問わず）
func count_all_creatures_by_name(creature_name: String) -> int:
	if not tile_data_manager:
		return 0
	
	var count = 0
	for tile_index in tile_data_manager.tile_nodes:
		var tile = tile_data_manager.tile_nodes[tile_index]
		if tile.creature_data != null and not tile.creature_data.is_empty():
			var tile_creature_name = tile.creature_data.get("name", "")
			if tile_creature_name == creature_name:
				count += 1
	return count

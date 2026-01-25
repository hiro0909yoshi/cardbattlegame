extends Node
class_name StageLoader

# ステージ読み込み・マップ生成クラス
# JSONからステージデータを読み込み、動的にマップを生成する

const GameConstants = preload("res://scripts/game_constants.gd")

signal stage_loaded(stage_data: Dictionary)
signal map_generated()

# タイルシーンのマッピング
const TILE_SCENES = {
	"Checkpoint": preload("res://scenes/Tiles/CheckpointTile.tscn"),
	"Fire": preload("res://scenes/Tiles/FireTile.tscn"),
	"Water": preload("res://scenes/Tiles/WaterTile.tscn"),
	"Earth": preload("res://scenes/Tiles/EarthTile.tscn"),
	"Wind": preload("res://scenes/Tiles/WindTile.tscn"),
	"Neutral": preload("res://scenes/Tiles/NeutralTile.tscn"),
	"Warp": preload("res://scenes/Tiles/WarpTile.tscn"),
	"WarpStop": preload("res://scenes/Tiles/WarpStopTile.tscn"),
	"CardBuy": preload("res://scenes/Tiles/CardBuyTile.tscn"),
	"CardGive": preload("res://scenes/Tiles/CardGiveTile.tscn"),
	"MagicStone": preload("res://scenes/Tiles/MagicStoneTile.tscn"),
	"Magic": preload("res://scenes/Tiles/MagicTile.tscn"),
	"Base": preload("res://scenes/Tiles/SpecialBaseTile.tscn"),
	"Branch": preload("res://scenes/Tiles/BranchTile.tscn")
}

# パス定数
const STAGES_PATH = "res://data/master/stages/"
const MAPS_PATH = "res://data/master/maps/"
const CHARACTERS_PATH = "res://data/master/characters/characters.json"
const AI_PROFILES_PATH = "res://data/master/ai_profiles/"
const DECKS_PATH = "res://data/master/decks/"

# 読み込んだデータ
var current_stage_data: Dictionary = {}
var current_map_data: Dictionary = {}
var characters_data: Dictionary = {}

# 生成されたノード
var tiles_container: Node3D
var generated_tiles: Dictionary = {}  # tile_index -> BaseTile

# ワープペア（マップ生成時に収集）
var pending_warp_pairs: Dictionary = {}  # from_tile -> to_tile

## 収集したワープペアをSpecialTileSystemに登録
func register_warp_pairs_to_system(system: SpecialTileSystem) -> void:
	system.clear_warp_pairs()
	for from_tile in pending_warp_pairs:
		system.register_warp_pair(from_tile, pending_warp_pairs[from_tile])
	print("[StageLoader] ワープペア登録完了: %d 件" % pending_warp_pairs.size())

func _ready():
	_load_characters()

# === データ読み込み ===

## キャラクターデータを読み込み
func _load_characters():
	var file = FileAccess.open(CHARACTERS_PATH, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_text)
		if parsed:
			characters_data = parsed.get("characters", {})
			print("[StageLoader] キャラクター読み込み完了: ", characters_data.keys())

## ステージデータを読み込み
func load_stage(stage_id: String) -> Dictionary:
	var path = STAGES_PATH + stage_id + ".json"
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[StageLoader] ステージファイルが見つかりません: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_text)
	if not parsed:
		push_error("[StageLoader] JSONパースエラー: " + path)
		return {}
	
	current_stage_data = parsed
	print("[StageLoader] ステージ読み込み完了: ", stage_id)
	
	# マップも読み込み
	var map_id = current_stage_data.get("map_id", "")
	if map_id:
		_load_map(map_id)
	
	stage_loaded.emit(current_stage_data)
	return current_stage_data

## マップデータを読み込み
func _load_map(map_id: String) -> Dictionary:
	var path = MAPS_PATH + map_id + ".json"
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[StageLoader] マップファイルが見つかりません: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_text)
	if not parsed:
		push_error("[StageLoader] JSONパースエラー: " + path)
		return {}
	
	current_map_data = parsed
	print("[StageLoader] マップ読み込み完了: ", map_id)
	return current_map_data

## AIプロファイルを読み込み
func load_ai_profile(profile_id: String) -> Dictionary:
	var path = AI_PROFILES_PATH + profile_id + ".json"
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[StageLoader] AIプロファイルが見つかりません: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_text)
	if not parsed:
		push_error("[StageLoader] JSONパースエラー: " + path)
		return {}
	
	print("[StageLoader] AIプロファイル読み込み完了: ", profile_id)
	return parsed

# === マップ生成 ===

## タイルコンテナを設定
func set_tiles_container(container: Node3D):
	tiles_container = container

## マップを動的に生成
func generate_map() -> Dictionary:
	if not tiles_container:
		push_error("[StageLoader] tiles_containerが設定されていません")
		return {}
	
	if current_map_data.is_empty():
		push_error("[StageLoader] マップデータがありません")
		return {}
	
	# 既存のタイルをクリア
	for child in tiles_container.get_children():
		child.queue_free()
	generated_tiles.clear()
	pending_warp_pairs.clear()
	
	# タイルを生成
	var tiles_data = current_map_data.get("tiles", [])
	for tile_data in tiles_data:
		var tile = _create_tile(tile_data)
		if tile:
			tiles_container.add_child(tile)
			generated_tiles[int(tile_data.index)] = tile
	
	# マップレベルのconnectionsをタイルに設定
	var map_connections = current_map_data.get("connections", {})
	print("[StageLoader] map_connections: %s" % str(map_connections))
	for tile_index_str in map_connections.keys():
		var tile_index = int(tile_index_str)
		if generated_tiles.has(tile_index):
			var tile = generated_tiles[tile_index]
			tile.connections.clear()
			for conn in map_connections[tile_index_str]:
				tile.connections.append(int(conn))
			print("[StageLoader] タイル%d connections設定: %s" % [tile_index, str(tile.connections)])
	
	# BranchTileのインジケーターを初期化（座標から方向を自動計算）
	for tile_index in generated_tiles.keys():
		var tile = generated_tiles[tile_index]
		if tile is BranchTile:
			tile.setup_with_tile_nodes(generated_tiles)
	
	print("[StageLoader] マップ生成完了: %d タイル" % generated_tiles.size())
	map_generated.emit()
	return generated_tiles

## 個別タイルを生成
func _create_tile(tile_data: Dictionary) -> Node3D:
	var tile_type = tile_data.get("type", "Neutral")
	
	if not TILE_SCENES.has(tile_type):
		push_error("[StageLoader] 不明なタイルタイプ: " + tile_type)
		return null
	
	var tile_scene = TILE_SCENES[tile_type]
	var tile = tile_scene.instantiate()
	
	# 位置設定（シーンツリー追加前なのでpositionを使用）
	var x = tile_data.get("x", 0)
	var z = tile_data.get("z", 0)
	tile.position = Vector3(x, 0, z)
	
	# インデックス設定
	tile.tile_index = tile_data.get("index", 0)
	
	# 特殊タイルの追加設定
	if tile_type == "Checkpoint" and tile_data.has("checkpoint_type"):
		var cp_type = tile_data.get("checkpoint_type", "N")
		match cp_type:
			"N":
				tile.checkpoint_type = 0
			"S":
				tile.checkpoint_type = 1
			"E":
				tile.checkpoint_type = 2
			"W":
				tile.checkpoint_type = 3
			_:
				tile.checkpoint_type = 0
	
	if (tile_type == "Warp" or tile_type == "WarpStop") and tile_data.has("warp_pair"):
		var from_tile = tile_data.get("index", -1)
		var to_tile = tile_data.get("warp_pair", -1)
		if from_tile >= 0 and to_tile >= 0:
			pending_warp_pairs[from_tile] = to_tile
	
	# 接続情報（分岐タイル用）
	if tile_data.has("connections"):
		var conns = tile_data.get("connections", [])
		tile.connections.clear()
		for conn in conns:
			tile.connections.append(int(conn))
	
	# 分岐タイルの方向表示設定
	if tile_type == "Branch":
		if tile_data.has("main_dir"):
			tile.main_dir = tile_data.get("main_dir", "")
		if tile_data.has("branch_dirs"):
			tile.branch_dirs = tile_data.get("branch_dirs", [])
	
	return tile

# === ゲーム設定取得 ===

## プレイヤー数を取得
func get_player_count() -> int:
	var enemies = _get_enemies()
	return 1 + enemies.size()

## マップのループサイズを取得
func get_loop_size() -> int:
	return current_map_data.get("loop_size", current_map_data.get("tile_count", 20))

## player_is_cpu配列を生成
func get_player_is_cpu() -> Array:
	var result = [false]  # プレイヤー1は人間
	var enemies = _get_enemies()
	for _enemy in enemies:
		result.append(true)  # CPUとして追加
	return result

## 初期EPを取得（プレイヤー用）
func get_player_start_magic() -> int:
	# 新形式: rule_overrides.initial_magic.player
	var rule_overrides = current_stage_data.get("rule_overrides", {})
	var initial_magic = rule_overrides.get("initial_magic", {})
	if initial_magic is Dictionary and initial_magic.has("player"):
		return initial_magic.get("player", 1000)
	# 旧形式: player_start_magic
	if current_stage_data.has("player_start_magic"):
		return current_stage_data.get("player_start_magic", 1000)
	# プリセットから取得
	var rule_preset = current_stage_data.get("rule_preset", "standard")
	return GameConstants.get_initial_magic(rule_preset)

## 敵の初期EPを取得
func get_enemy_start_magic(enemy_index: int) -> int:
	# 新形式: rule_overrides.initial_magic.cpu
	var rule_overrides = current_stage_data.get("rule_overrides", {})
	var initial_magic = rule_overrides.get("initial_magic", {})
	if initial_magic is Dictionary and initial_magic.has("cpu"):
		return initial_magic.get("cpu", 1000)
	# 旧形式: enemies[].start_magic
	var enemies = _get_enemies()
	if enemy_index < enemies.size():
		if enemies[enemy_index].has("start_magic"):
			return enemies[enemy_index].get("start_magic", 1000)
	# プリセットから取得
	var rule_preset = current_stage_data.get("rule_preset", "standard")
	return GameConstants.get_initial_magic(rule_preset)

## 勝利条件を取得
func get_win_condition() -> Dictionary:
	# 新形式: rule_overrides.win_conditions
	var rule_overrides = current_stage_data.get("rule_overrides", {})
	if rule_overrides.has("win_conditions"):
		return rule_overrides.get("win_conditions", {})
	# 旧形式: win_condition
	if current_stage_data.has("win_condition"):
		# 旧形式を新形式に変換
		var old_condition = current_stage_data.get("win_condition", {})
		return {
			"mode": "all",
			"conditions": [
				{
					"type": old_condition.get("type", "magic"),
					"target": old_condition.get("target", 8000),
					"timing": "checkpoint"
				}
			]
		}
	# プリセットから取得
	var rule_preset = current_stage_data.get("rule_preset", "standard")
	return GameConstants.get_win_conditions(rule_preset)

## 敵リストを取得（新旧形式対応）
func _get_enemies() -> Array:
	# 新形式: quest.enemies
	var quest = current_stage_data.get("quest", {})
	if quest.has("enemies"):
		return quest.get("enemies", [])
	# 旧形式: enemies
	return current_stage_data.get("enemies", [])

## 敵キャラクター情報を取得
func get_enemy_character(enemy_index: int) -> Dictionary:
	var enemies = _get_enemies()
	if enemy_index >= enemies.size():
		return {}
	
	var enemy = enemies[enemy_index]
	var char_id = enemy.get("character_id", "")
	return characters_data.get(char_id, {})

## 敵のAIレベルを取得
func get_enemy_ai_level(enemy_index: int) -> int:
	var enemies = _get_enemies()
	if enemy_index < enemies.size():
		# 新形式: ai_level
		if enemies[enemy_index].has("ai_level"):
			return enemies[enemy_index].get("ai_level", 3)
		# 旧形式: ai_profile_id から推測（互換用）
		var profile_id = enemies[enemy_index].get("ai_profile_id", "easy")
		match profile_id:
			"easy": return 3
			"normal": return 5
			"hard": return 7
			_: return 3
	return 3

## 敵のAIプロファイルIDを取得（旧形式互換）
func get_enemy_ai_profile_id(enemy_index: int) -> String:
	var enemies = _get_enemies()
	if enemy_index < enemies.size():
		return enemies[enemy_index].get("ai_profile_id", "easy")
	return "easy"

## 敵のバトルポリシーを取得（ステージ設定 > キャラクター設定 > デフォルト）
func get_enemy_battle_policy(enemy_index: int) -> Dictionary:
	var enemies = _get_enemies()
	if enemy_index >= enemies.size():
		return {}
	
	var enemy = enemies[enemy_index]
	
	# 1. ステージの敵設定に直接指定があればそれを使用
	if enemy.has("battle_policy"):
		return enemy.get("battle_policy", {})
	
	# 2. キャラクターのデフォルト設定を使用
	var char_id = enemy.get("character_id", "")
	var char_data = characters_data.get(char_id, {})
	if char_data.has("battle_policy"):
		return char_data.get("battle_policy", {})
	
	# 3. 指定がなければ空を返す（呼び出し側でデフォルト処理）
	return {}

## 敵のデッキIDを取得
func get_enemy_deck_id(enemy_index: int) -> String:
	var enemies = _get_enemies()
	if enemy_index < enemies.size():
		return enemies[enemy_index].get("deck_id", "random")
	return "random"

## デッキデータを読み込み
func load_deck(deck_id: String) -> Dictionary:
	if deck_id == "random":
		return {}  # ランダムデッキは空を返す
	
	var path = DECKS_PATH + "deck_" + deck_id + ".json"
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		# デッキファイルがない場合はランダムデッキとして扱う
		print("[StageLoader] デッキファイルなし（ランダム使用）: ", path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_text)
	if not parsed:
		push_error("[StageLoader] JSONパースエラー: " + path)
		return {}
	
	print("[StageLoader] デッキ読み込み完了: ", deck_id)
	return parsed

## マップデータを取得（LapSystem設定等で使用）
func get_map_data() -> Dictionary:
	return current_map_data

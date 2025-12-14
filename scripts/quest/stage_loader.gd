extends Node
class_name StageLoader

# ステージ読み込み・マップ生成クラス
# JSONからステージデータを読み込み、動的にマップを生成する

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
	"Warp": preload("res://scenes/Tiles/WarpTile.tscn")
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
	
	# タイルを生成
	var tiles_data = current_map_data.get("tiles", [])
	for tile_data in tiles_data:
		var tile = _create_tile(tile_data)
		if tile:
			tiles_container.add_child(tile)
			generated_tiles[tile_data.index] = tile
	
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
		tile.checkpoint_type = 0 if cp_type == "N" else 1
	
	if tile_type == "Warp" and tile_data.has("warp_pair"):
		# ワープペアは後で設定（SpecialTileSystemが担当）
		pass
	
	return tile

# === ゲーム設定取得 ===

## プレイヤー数を取得
func get_player_count() -> int:
	return 1 + current_stage_data.get("enemies", []).size()

## player_is_cpu配列を生成
func get_player_is_cpu() -> Array:
	var result = [false]  # プレイヤー1は人間
	var enemies = current_stage_data.get("enemies", [])
	for _enemy in enemies:
		result.append(true)  # CPUとして追加
	return result

## 初期魔力を取得
func get_player_start_magic() -> int:
	return current_stage_data.get("player_start_magic", 1000)

## 敵の初期魔力を取得
func get_enemy_start_magic(enemy_index: int) -> int:
	var enemies = current_stage_data.get("enemies", [])
	if enemy_index < enemies.size():
		return enemies[enemy_index].get("start_magic", 1000)
	return 1000

## 勝利条件を取得
func get_win_condition() -> Dictionary:
	return current_stage_data.get("win_condition", {"type": "magic", "target": 8000})

## 敵キャラクター情報を取得
func get_enemy_character(enemy_index: int) -> Dictionary:
	var enemies = current_stage_data.get("enemies", [])
	if enemy_index >= enemies.size():
		return {}
	
	var enemy = enemies[enemy_index]
	var char_id = enemy.get("character_id", "")
	return characters_data.get(char_id, {})

## 敵のAIプロファイルIDを取得
func get_enemy_ai_profile_id(enemy_index: int) -> String:
	var enemies = current_stage_data.get("enemies", [])
	if enemy_index < enemies.size():
		return enemies[enemy_index].get("ai_profile_id", "easy")
	return "easy"

## 敵のデッキIDを取得
func get_enemy_deck_id(enemy_index: int) -> String:
	var enemies = current_stage_data.get("enemies", [])
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
		push_error("[StageLoader] デッキファイルが見つかりません: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_text)
	if not parsed:
		push_error("[StageLoader] JSONパースエラー: " + path)
		return {}
	
	print("[StageLoader] デッキ読み込み完了: ", deck_id)
	return parsed

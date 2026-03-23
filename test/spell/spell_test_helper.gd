class_name SpellTestHelper
extends RefCounted

## スペルテスト用のMockオブジェクト群とセットアップユーティリティ


## ダイアモンドボード（20タイル）のデフォルト属性
const DEFAULT_TILE_TYPES: Array[String] = [
	"checkpoint", "fire", "fire", "fire", "fire", "neutral",
	"water", "water", "water", "water", "checkpoint",
	"wind", "wind", "wind", "wind", "neutral",
	"earth", "earth", "earth", "earth"
]


# ============================================
# MockTile（RefCounted - タイルのデータのみ）
# ============================================

class MockTile extends RefCounted:
	var owner_id: int = -1
	var tile_type: String = "neutral"
	var level: int = 1
	var creature_data: Dictionary = {}
	var tile_index: int = 0
	var global_position: Vector3 = Vector3.ZERO
	var connections: Array = []
	var _down_state: bool = false

	func set_level(new_level: int) -> void:
		level = new_level

	func level_up() -> bool:
		if level < 5:
			level += 1
			return true
		return false

	func set_down_state(down: bool) -> void:
		_down_state = down

	func clear_down_state() -> void:
		_down_state = false

	func is_down() -> bool:
		return _down_state

	var element: String:
		get: return tile_type

	func has(property: String) -> bool:
		return property in ["owner_id", "tile_type", "level", "creature_data",
			"tile_index", "global_position", "connections", "element"]

	func remove_creature() -> void:
		creature_data = {}

	func set_tile_owner(new_owner_id: int) -> void:
		owner_id = new_owner_id

	func place_creature(data: Dictionary) -> void:
		creature_data = data.duplicate(true)

	func update_visual() -> void:
		pass


# ============================================
# セットアップユーティリティ
# ============================================

## 20タイルのMockTile辞書を作成（tile_nodesとして使う）
static func create_tile_nodes() -> Dictionary:
	var tile_nodes: Dictionary = {}
	for i in range(20):
		var tile = MockTile.new()
		tile.tile_index = i
		tile.tile_type = DEFAULT_TILE_TYPES[i]
		tile.level = 1
		tile.connections = [(i - 1 + 20) % 20, (i + 1) % 20]
		tile_nodes[i] = tile
	return tile_nodes


## クリーチャーをタイルに配置（tile_nodesとCreatureManagerの両方）
static func place_creature(
	tile_nodes: Dictionary, cm: CreatureManager,
	tile_index: int, creature_data: Dictionary, owner_id: int = 0
) -> void:
	if tile_nodes.has(tile_index):
		var tile = tile_nodes[tile_index]
		tile.creature_data = creature_data.duplicate(true)
		tile.owner_id = owner_id
	# CreatureManagerにも登録（get_data_refで参照できるように）
	cm.creatures[tile_index] = tile_nodes[tile_index].creature_data


## テスト用のシンプルなクリーチャーデータを生成
static func make_creature(creature_name: String = "テストクリーチャー", hp: int = 40, ap: int = 30, element: String = "fire") -> Dictionary:
	return {
		"name": creature_name,
		"hp": hp,
		"ap": ap,
		"current_hp": hp,
		"base_up_hp": 0,
		"base_up_ap": 0,
		"element": element,
		"ability_parsed": {}
	}

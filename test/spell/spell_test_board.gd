extends BoardSystem3D

## スペルテスト用MockBoardSystem
## BoardSystem3DのメソッドをMockTile対応にオーバーライド

## tile_neighbor_systemをMockTileのconnectionsベースで構築
func setup_tile_neighbor_system() -> void:
	var tns = TileNeighborSystem.new()
	tns.name = "MockTileNeighborSystem"
	add_child(tns)
	tns.tile_nodes = tile_nodes
	for tile_index in tile_nodes.keys():
		tns.spatial_neighbors_cache[tile_index] = tile_nodes[tile_index].connections
	tile_neighbor_system = tns


## プレイヤー位置管理（SpellPlayerMove用）
var _player_tiles: Dictionary = {}

func get_player_tile(player_id: int) -> int:
	return _player_tiles.get(player_id, 0)

func set_player_tile(player_id: int, tile_index: int) -> void:
	_player_tiles[player_id] = tile_index

func place_player_at_tile(_player_id: int, _tile_index: int) -> void:
	pass

func swap_came_from_for_reverse(_player_id: int) -> void:
	pass

func clear_all_down_states_for_player(player_id: int) -> int:
	var count = 0
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.owner_id == player_id and tile.is_down():
			tile.set_down_state(false)
			count += 1
	return count


func change_tile_terrain(tile_index: int, new_element: String) -> bool:
	if not tile_nodes.has(tile_index):
		return false
	var tile = tile_nodes[tile_index]
	if tile.tile_type == new_element:
		return false
	tile.tile_type = new_element
	return true


func remove_creature(tile_index: int):
	if tile_nodes.has(tile_index):
		tile_nodes[tile_index].remove_creature()


func set_tile_owner(tile_index: int, owner_id: int):
	if tile_nodes.has(tile_index):
		tile_nodes[tile_index].owner_id = owner_id


func place_creature(tile_index: int, creature_data: Dictionary, _player_id: int = -1):
	if tile_nodes.has(tile_index):
		tile_nodes[tile_index].creature_data = creature_data.duplicate(true)


func get_player_tiles(player_id: int) -> Array:
	var result: Array = []
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.owner_id == player_id:
			result.append(tile)
	return result


func get_tile_info(tile_index: int) -> Dictionary:
	if not tile_nodes.has(tile_index):
		return {}
	var tile = tile_nodes[tile_index]
	return {
		"index": tile_index,
		"tile_type": tile.tile_type,
		"element": tile.tile_type,
		"owner": tile.owner_id,
		"level": tile.level,
		"creature": tile.creature_data,
		"has_creature": not tile.creature_data.is_empty(),
		"is_special": false,
		"connections": tile.connections
	}

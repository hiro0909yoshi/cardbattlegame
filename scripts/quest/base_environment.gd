extends Node3D
class_name BaseEnvironment

## 背景環境の基底クラス
## タイルコンテナから動的にサイズを計算し、地面を生成する共通基盤

# マップ中心とサイズ（setup_from_tiles で動的に設定）
var _map_center := Vector3(10.0, 0.0, 10.0)
var _map_half_size := 10.0  # 中心から端までの距離

# 地面パラメータ
const GROUND_MARGIN := 8.0     # 環境外側の地面余白
const GROUND_Y := -0.3          # 地面のY座標（タイルより十分下に）

# 地面モデル
const FLOOR_MODEL_PATH := "res://assets/building_parts/floor3.glb"

# 色定義
const COLOR_GROUND := Color(0.35, 0.30, 0.18)


## タイルコンテナから範囲を計算して環境を構築
func setup_from_tiles(tiles_container: Node3D) -> void:
	var inv_transform: Transform3D = global_transform.affine_inverse()
	var min_pos: Vector3 = Vector3(INF, 0, INF)
	var max_pos: Vector3 = Vector3(-INF, 0, -INF)
	var tile_count := 0

	for child in tiles_container.get_children():
		if child is Node3D:
			var local_pos: Vector3 = inv_transform * child.global_position
			min_pos.x = min(min_pos.x, local_pos.x)
			min_pos.z = min(min_pos.z, local_pos.z)
			max_pos.x = max(max_pos.x, local_pos.x)
			max_pos.z = max(max_pos.z, local_pos.z)
			tile_count += 1

	if tile_count == 0:
		push_error("[%s] タイルが見つかりません" % name)
		return

	_map_center = Vector3((min_pos.x + max_pos.x) / 2.0, 0.0, (min_pos.z + max_pos.z) / 2.0)
	_map_half_size = max(max_pos.x - min_pos.x, max_pos.z - min_pos.z) / 2.0 + 1.5

	print("[%s] center: %s, half_size: %.1f (%d tiles)" % [
		name, str(_map_center), _map_half_size, tile_count])

	_build()


## サブクラスでオーバーライドする構築メソッド
func _build() -> void:
	pass


## 環境全体のマージンを返す（サブクラスでオーバーライド可）
func _get_environment_margin() -> float:
	return GROUND_MARGIN


## 地面を生成（floor3.glb をタイリング）
func _create_ground(extra_margin: float = 0.0) -> void:
	var floor_scene: PackedScene = load(FLOOR_MODEL_PATH) as PackedScene
	if not floor_scene:
		push_error("[%s] floor3.glb not found, falling back to simple ground" % name)
		_create_ground_fallback(extra_margin)
		return

	var sample: Node3D = floor_scene.instantiate()
	add_child(sample)
	var real_size := _get_real_world_size(sample)
	remove_child(sample)
	sample.queue_free()

	var ground_container: Node3D = Node3D.new()
	ground_container.name = "Ground"
	add_child(ground_container)

	var total_area: float = _map_half_size * 2.0 + (_get_environment_margin() + GROUND_MARGIN + extra_margin) * 2.0
	var cx: float = _map_center.x
	var cz: float = _map_center.z
	var start_x: float = cx - total_area / 2.0 + real_size.x / 2.0
	var start_z: float = cz - total_area / 2.0 + real_size.z / 2.0

	var x: float = start_x
	while x < cx + total_area / 2.0:
		var z: float = start_z
		while z < cz + total_area / 2.0:
			var tile: Node3D = floor_scene.instantiate()
			tile.position = Vector3(x, GROUND_Y, z)
			ground_container.add_child(tile)
			z += real_size.z
		x += real_size.x


## フォールバック: MeshInstance3Dの単色地面
func _create_ground_fallback(extra_margin: float = 0.0) -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "Ground"
	var total_size: float = _map_half_size * 2.0 + (_get_environment_margin() + GROUND_MARGIN + extra_margin) * 2.0
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(total_size, 0.3, total_size)
	ground.mesh = box
	ground.position = Vector3(_map_center.x, GROUND_Y, _map_center.z)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = COLOR_GROUND
	mat.roughness = 0.95
	ground.material_override = mat
	add_child(ground)


## 子ノードのスケールを含めた実ワールドサイズを取得
func _get_real_world_size(root: Node) -> Vector3:
	var meshes := _find_all_mesh_instances_in(root)
	if meshes.is_empty():
		return Vector3.ZERO
	var aabb := meshes[0].get_aabb()
	for i in range(1, meshes.size()):
		aabb = aabb.merge(meshes[i].get_aabb())
	var mesh_scale: Vector3 = meshes[0].scale if not meshes.is_empty() else Vector3.ONE
	return aabb.size * mesh_scale * root.scale


## ノード内の全MeshInstance3Dを再帰的に探す
func _find_all_mesh_instances_in(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_mesh_instances_in(child))
	return result

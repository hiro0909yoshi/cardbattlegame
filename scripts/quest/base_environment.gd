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
		GameLogger.error("Quest", "タイルが見つかりません in %s" % name)
		return

	_map_center = Vector3((min_pos.x + max_pos.x) / 2.0, 0.0, (min_pos.z + max_pos.z) / 2.0)
	_map_half_size = max(max_pos.x - min_pos.x, max_pos.z - min_pos.z) / 2.0 + 1.5

	print("[%s] center: %s, half_size: %.1f (%d tiles)" % [
		name, str(_map_center), _map_half_size, tile_count])

	_build()


## 固定サイズで環境を構築（タイルなしで使用する場合）
func setup_with_fixed_size(center: Vector3, half_size: float) -> void:
	_map_center = center
	_map_half_size = half_size
	_build()


## サブクラスでオーバーライドする構築メソッド
func _build() -> void:
	pass


## 環境全体のマージンを返す（サブクラスでオーバーライド可）
func _get_environment_margin() -> float:
	return GROUND_MARGIN


## 地面を生成（MultiMeshInstance3Dで統合）
func _create_ground(extra_margin: float = 0.0) -> void:
	var floor_scene: PackedScene = load(FLOOR_MODEL_PATH) as PackedScene
	if not floor_scene:
		_create_ground_fallback(extra_margin)
		return

	# 1つインスタンス化してサイズを計測
	var sample: Node3D = floor_scene.instantiate()
	var real_size: Vector3 = _get_real_world_size(sample)
	if real_size == Vector3.ZERO:
		real_size = Vector3(3.0, 0.1, 3.0)
	# メッシュとスケールを取得
	var sample_mesh: Mesh = null
	var sample_material: Material = null
	var mesh_scale := Vector3.ONE
	for child in sample.get_children():
		if child is MeshInstance3D:
			sample_mesh = child.mesh
			sample_material = child.material_override if child.material_override else child.get_active_material(0)
			mesh_scale = child.scale
			# GLBルートのスケールも考慮
			if child.get_parent() and child.get_parent() is Node3D:
				mesh_scale *= child.get_parent().scale
			break
	# メッシュAABBから実際のスケールを算出
	if sample_mesh:
		var mesh_aabb := sample_mesh.get_aabb()
		var mesh_size := mesh_aabb.size * mesh_scale
		if mesh_size.x > 0.01 and real_size.x > 0.01:
			mesh_scale = real_size / mesh_size * mesh_scale
	sample.queue_free()

	if not sample_mesh:
		_create_ground_fallback(extra_margin)
		return

	var total_area: float = _map_half_size * 2.0 + (_get_environment_margin() + GROUND_MARGIN + extra_margin) * 2.0
	var cx: float = _map_center.x
	var cz: float = _map_center.z
	var start_x: float = cx - total_area / 2.0 + real_size.x / 2.0
	var start_z: float = cz - total_area / 2.0 + real_size.z / 2.0

	# 配置位置を計算
	var transforms: Array[Transform3D] = []
	var x: float = start_x
	while x < cx + total_area / 2.0:
		var z: float = start_z
		while z < cz + total_area / 2.0:
			transforms.append(Transform3D(Basis.from_scale(mesh_scale), Vector3(x, GROUND_Y, z)))
			z += real_size.z
		x += real_size.x

	# MultiMeshで一括描画
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sample_mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Ground"
	mmi.multimesh = mm
	if sample_material:
		mmi.material_override = sample_material
	add_child(mmi)


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

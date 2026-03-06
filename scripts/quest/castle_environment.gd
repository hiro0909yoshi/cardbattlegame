extends Node3D
class_name CastleEnvironment

# マップを囲む城壁 + 土の地面 + 蔦・草を生成するスクリプト
# タイルコンテナから動的にサイズを計算

# マップ中心とサイズ（setup_from_tiles で動的に設定）
var _map_center := Vector3(10.0, 0.0, 10.0)
var _map_half_size := 10.0  # 中心から端までの距離

# 松明アニメーション用
var _torch_lights: Array[OmniLight3D] = []
var _torch_flames: Array[MeshInstance3D] = []
var _torch_time := 0.0

# 城壁パラメータ
const WALL_MARGIN := 11.0      # マップ端からの余白
const WALL_HEIGHT := 4.0       # 壁の高さ
const WALL_THICKNESS := 1.2    # 壁の厚み
const BATTLEMENT_HEIGHT := 0.8 # 胸壁（凹凸）の高さ
const BATTLEMENT_WIDTH := 1.5  # 胸壁の幅
const BATTLEMENT_GAP := 1.2    # 胸壁の隙間

# 塔パラメータ
const TOWER_RADIUS := 2.0
const TOWER_HEIGHT := 6.0
const TOWER_SIDES := 12

# 地面パラメータ
const GROUND_MARGIN := 8.0     # 城壁の外側余白
const GROUND_Y := -0.3          # 地面のY座標（タイルより十分下に）

# 色定義
const COLOR_GROUND := Color(0.35, 0.30, 0.18)

# シェーダーパス
const BRICK_SHADER_PATH := "res://assets/shaders/brick_wall.gdshader"

# 地面モデル
const FLOOR_MODEL_PATH := "res://assets/building_parts/floor3.glb"

# 蔦パラメータ
const IVY_COUNT_PER_WALL := 5   # 壁1面あたりの蔦の数
const IVY_MIN_HEIGHT := 0.5
const IVY_MAX_HEIGHT := 3.5
const IVY_WIDTH_MIN := 1.5
const IVY_WIDTH_MAX := 3.5

# 草パラメータ
const GRASS_PATCH_COUNT := 120  # 草パッチの数
const GRASS_BLADE_HEIGHT := 0.4
const GRASS_BLADE_WIDTH := 0.08

var _brick_material: ShaderMaterial


func _process(delta: float) -> void:
	if _torch_lights.is_empty():
		return
	_torch_time += delta
	for i in range(_torch_lights.size()):
		var phase = float(i) * 2.7
		# 無理数比の周波数で規則性を崩す
		var f1 = sin(_torch_time * 5.3 + phase) * 0.08
		var f2 = sin(_torch_time * 8.7 + phase * 1.61) * 0.05
		var f3 = sin(_torch_time * 14.1 + phase * 0.73) * 0.03
		# 各松明ごとに少し異なるタイミングで突発的な明滅
		var spike = pow(abs(sin(_torch_time * 3.1 + phase * 2.39)), 12.0) * 0.1
		var flicker = f1 + f2 + f3 + spike
		_torch_lights[i].light_energy = 1.5 + flicker
		var s = 1.0 + flicker * 0.12
		_torch_flames[i].scale = Vector3(s, s + flicker * 0.08, s)


## タイルコンテナから範囲を計算して環境を構築
func setup_from_tiles(tiles_container: Node3D) -> void:
	# タイルのワールド座標をこのノードのローカル座標に変換してバウンディングボックスを計算
	var inv_transform := global_transform.affine_inverse()
	var min_pos := Vector3(INF, 0, INF)
	var max_pos := Vector3(-INF, 0, -INF)
	var tile_count := 0

	for child in tiles_container.get_children():
		if child is Node3D:
			var local_pos = inv_transform * child.global_position
			min_pos.x = min(min_pos.x, local_pos.x)
			min_pos.z = min(min_pos.z, local_pos.z)
			max_pos.x = max(max_pos.x, local_pos.x)
			max_pos.z = max(max_pos.z, local_pos.z)
			tile_count += 1

	if tile_count == 0:
		push_error("[CastleEnvironment] タイルが見つかりません")
		return

	_map_center = Vector3((min_pos.x + max_pos.x) / 2.0, 0.0, (min_pos.z + max_pos.z) / 2.0)
	_map_half_size = max(max_pos.x - min_pos.x, max_pos.z - min_pos.z) / 2.0 + 1.5

	print("[CastleEnvironment] center: %s, half_size: %.1f (%d tiles)" % [
		str(_map_center), _map_half_size, tile_count])

	_build()


func _build() -> void:
	_brick_material = _create_brick_material()
	_create_ground()
	_create_walls()
	_create_corner_towers()
	#_create_torches()  # モバイル負荷対策で無効化（OmniLight3Dが重い）
	_create_ivy()
	_create_grass_patches()


## 地面を生成（floor3.glb をタイリング）
func _create_ground():
	var floor_scene = load(FLOOR_MODEL_PATH) as PackedScene
	if not floor_scene:
		push_error("[CastleEnvironment] floor3.glb not found, falling back to CSGBox")
		_create_ground_fallback()
		return

	# デバッグ用にAABBも出力
	var sample = floor_scene.instantiate()
	add_child(sample)
	var meshes_check := _find_all_mesh_instances_in(sample)
	if not meshes_check.is_empty():
		var check_aabb = meshes_check[0].get_aabb()
		print("[CastleEnvironment] floor3 mesh AABB: %s, mesh scale: %s" % [str(check_aabb), str(meshes_check[0].scale)])
	remove_child(sample)
	sample.queue_free()

	# 子ノードのスケールを含めた実ワールドサイズを計算
	var sample2 = floor_scene.instantiate()
	add_child(sample2)
	var real_size := _get_real_world_size(sample2)
	remove_child(sample2)
	sample2.queue_free()

	print("[CastleEnvironment] floor3 real world size: %s" % str(real_size))

	# タイリング
	var ground_container = Node3D.new()
	ground_container.name = "Ground"
	add_child(ground_container)

	var total_area = _map_half_size * 2.0 + (WALL_MARGIN + GROUND_MARGIN) * 2.0
	var cx = _map_center.x
	var cz = _map_center.z
	var start_x = cx - total_area / 2.0 + real_size.x / 2.0
	var start_z = cz - total_area / 2.0 + real_size.z / 2.0

	var x = start_x
	while x < cx + total_area / 2.0:
		var z = start_z
		while z < cz + total_area / 2.0:
			var tile = floor_scene.instantiate()
			tile.position = Vector3(x, GROUND_Y, z)
			ground_container.add_child(tile)
			z += real_size.z
		x += real_size.x


## 子ノードのスケールを含めた実ワールドサイズを取得
func _get_real_world_size(root: Node) -> Vector3:
	var meshes := _find_all_mesh_instances_in(root)
	if meshes.is_empty():
		return Vector3.ZERO
	var aabb := meshes[0].get_aabb()
	for i in range(1, meshes.size()):
		aabb = aabb.merge(meshes[i].get_aabb())
	# メッシュノード自身のスケール × ルートのスケールを適用
	var mesh_scale = meshes[0].scale if not meshes.is_empty() else Vector3.ONE
	return aabb.size * mesh_scale * root.scale


## ノード内の全MeshInstance3Dを再帰的に探す
func _find_all_mesh_instances_in(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_mesh_instances_in(child))
	return result


## フォールバック: CSGBox3Dの単色地面
func _create_ground_fallback():
	var ground = CSGBox3D.new()
	ground.name = "Ground"
	var total_size = _map_half_size * 2.0 + (WALL_MARGIN + GROUND_MARGIN) * 2.0
	ground.size = Vector3(total_size, 0.3, total_size)
	ground.position = Vector3(_map_center.x, GROUND_Y, _map_center.z)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = COLOR_GROUND
	mat.roughness = 0.95
	ground.material = mat
	add_child(ground)


## 四方の壁を生成
func _create_walls():
	var half = _map_half_size + WALL_MARGIN
	var center_x = _map_center.x
	var center_z = _map_center.z
	var wall_y = WALL_HEIGHT / 2.0
	var cap_mat = _create_cap_material()

	# 北壁 (Z-)
	var ns_size = Vector3(half * 2.0 + WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS)
	_create_single_wall("WallNorth", Vector3(center_x, wall_y, center_z - half), ns_size, _brick_material)
	_create_wall_cap("WallCapNorth", Vector3(center_x, WALL_HEIGHT, center_z - half),
		Vector3(ns_size.x + 0.2, 0.15, WALL_THICKNESS + 0.2), cap_mat)

	# 南壁 (Z+)
	_create_single_wall("WallSouth", Vector3(center_x, wall_y, center_z + half), ns_size, _brick_material)
	_create_wall_cap("WallCapSouth", Vector3(center_x, WALL_HEIGHT, center_z + half),
		Vector3(ns_size.x + 0.2, 0.15, WALL_THICKNESS + 0.2), cap_mat)

	# 西壁 (X-)
	var ew_size = Vector3(WALL_THICKNESS, WALL_HEIGHT, half * 2.0 + WALL_THICKNESS)
	_create_single_wall("WallWest", Vector3(center_x - half, wall_y, center_z), ew_size, _brick_material)
	_create_wall_cap("WallCapWest", Vector3(center_x - half, WALL_HEIGHT, center_z),
		Vector3(WALL_THICKNESS + 0.2, 0.15, ew_size.z + 0.2), cap_mat)

	# 東壁 (X+)
	_create_single_wall("WallEast", Vector3(center_x + half, wall_y, center_z), ew_size, _brick_material)
	_create_wall_cap("WallCapEast", Vector3(center_x + half, WALL_HEIGHT, center_z),
		Vector3(WALL_THICKNESS + 0.2, 0.15, ew_size.z + 0.2), cap_mat)

	# 胸壁（バトルメント）を各壁の上に追加
	_create_battlements_north_south(center_x, center_z, half, cap_mat)
	_create_battlements_east_west(center_x, center_z, half, cap_mat)


## 壁1枚を生成
func _create_single_wall(wall_name: String, pos: Vector3, wall_size: Vector3, mat: Material):
	var wall = CSGBox3D.new()
	wall.name = wall_name
	wall.size = wall_size
	wall.position = pos
	wall.material = mat
	add_child(wall)


## 壁の上の笠石（キャップストーン）を生成
func _create_wall_cap(cap_name: String, pos: Vector3, cap_size: Vector3, mat: Material):
	var cap = CSGBox3D.new()
	cap.name = cap_name
	cap.size = cap_size
	cap.position = pos
	cap.material = mat
	add_child(cap)


## 北壁・南壁の胸壁
func _create_battlements_north_south(cx: float, cz: float, half: float, cap_mat: Material):
	var step = BATTLEMENT_WIDTH + BATTLEMENT_GAP
	var start_x = cx - half
	var end_x = cx + half
	var top_y = WALL_HEIGHT + BATTLEMENT_HEIGHT / 2.0
	var cap_top_y = WALL_HEIGHT + BATTLEMENT_HEIGHT

	for z_sign in [-1.0, 1.0]:
		var z_pos = cz + half * z_sign
		var x = start_x
		var idx = 0
		while x < end_x:
			var bx = x + BATTLEMENT_WIDTH / 2.0
			var b = CSGBox3D.new()
			b.name = "BattlementNS_%d_%d" % [int(z_sign), idx]
			b.size = Vector3(BATTLEMENT_WIDTH, BATTLEMENT_HEIGHT, WALL_THICKNESS + 0.3)
			b.position = Vector3(bx, top_y, z_pos)
			b.material = _brick_material
			add_child(b)
			# 胸壁キャップ
			_create_wall_cap("BattCapNS_%d_%d" % [int(z_sign), idx],
				Vector3(bx, cap_top_y, z_pos),
				Vector3(BATTLEMENT_WIDTH + 0.1, 0.1, WALL_THICKNESS + 0.4), cap_mat)
			x += step
			idx += 1


## 東壁・西壁の胸壁
func _create_battlements_east_west(cx: float, cz: float, half: float, cap_mat: Material):
	var step = BATTLEMENT_WIDTH + BATTLEMENT_GAP
	var start_z = cz - half
	var end_z = cz + half
	var top_y = WALL_HEIGHT + BATTLEMENT_HEIGHT / 2.0
	var cap_top_y = WALL_HEIGHT + BATTLEMENT_HEIGHT

	for x_sign in [-1.0, 1.0]:
		var x_pos = cx + half * x_sign
		var z = start_z
		var idx = 0
		while z < end_z:
			var bz = z + BATTLEMENT_WIDTH / 2.0
			var b = CSGBox3D.new()
			b.name = "BattlementEW_%d_%d" % [int(x_sign), idx]
			b.size = Vector3(WALL_THICKNESS + 0.3, BATTLEMENT_HEIGHT, BATTLEMENT_WIDTH)
			b.position = Vector3(x_pos, top_y, bz)
			b.material = _brick_material
			add_child(b)
			# 胸壁キャップ
			_create_wall_cap("BattCapEW_%d_%d" % [int(x_sign), idx],
				Vector3(x_pos, cap_top_y, bz),
				Vector3(WALL_THICKNESS + 0.4, 0.1, BATTLEMENT_WIDTH + 0.1), cap_mat)
			z += step
			idx += 1


## 四隅の塔を生成
func _create_corner_towers():
	var half = _map_half_size + WALL_MARGIN
	var cx = _map_center.x
	var cz = _map_center.z
	var tower_y = TOWER_HEIGHT / 2.0

	var tower_mat = _create_tower_brick_material()

	var corners: Array[Vector3] = [
		Vector3(cx - half, tower_y, cz - half),  # 北西
		Vector3(cx + half, tower_y, cz - half),  # 北東
		Vector3(cx - half, tower_y, cz + half),  # 南西
		Vector3(cx + half, tower_y, cz + half),  # 南東
	]

	for i in range(corners.size()):
		# 塔本体
		var tower = CSGCylinder3D.new()
		tower.name = "Tower_%d" % i
		tower.radius = TOWER_RADIUS
		tower.height = TOWER_HEIGHT
		tower.sides = TOWER_SIDES
		tower.position = corners[i]
		tower.material = tower_mat
		add_child(tower)

		# 塔の上部（少し広い円柱）
		var tower_top = CSGCylinder3D.new()
		tower_top.name = "TowerTop_%d" % i
		tower_top.radius = TOWER_RADIUS + 0.4
		tower_top.height = 0.6
		tower_top.sides = TOWER_SIDES
		tower_top.position = Vector3(corners[i].x, TOWER_HEIGHT + 0.3, corners[i].z)
		tower_top.material = tower_mat
		add_child(tower_top)

		# 塔の円錐屋根
		var roof = CSGCylinder3D.new()
		roof.name = "TowerRoof_%d" % i
		roof.radius = TOWER_RADIUS + 0.6
		roof.height = 3.0
		roof.sides = TOWER_SIDES
		roof.cone = true
		roof.position = Vector3(corners[i].x, TOWER_HEIGHT + 0.6 + 1.5, corners[i].z)
		var roof_mat = StandardMaterial3D.new()
		roof_mat.albedo_color = Color(0.3, 0.32, 0.35)
		roof_mat.roughness = 0.8
		roof.material = roof_mat
		add_child(roof)


## 松明を壁面に配置
func _create_torches():
	var half = _map_half_size + WALL_MARGIN
	var cx = _map_center.x
	var cz = _map_center.z
	var torch_y := WALL_HEIGHT * 0.6
	var torch_spacing := 10.0  # 松明の間隔

	# 各壁に沿って松明を配置
	var wall_defs: Array[Dictionary] = [
		{"start": cx - half + 3.0, "end": cx + half - 3.0, "get_pos": func(along: float) -> Vector3:
			return Vector3(along, torch_y, cz - half + WALL_THICKNESS * 0.5 + 0.15)},
		{"start": cx - half + 3.0, "end": cx + half - 3.0, "get_pos": func(along: float) -> Vector3:
			return Vector3(along, torch_y, cz + half - WALL_THICKNESS * 0.5 - 0.15)},
		{"start": cz - half + 3.0, "end": cz + half - 3.0, "get_pos": func(along: float) -> Vector3:
			return Vector3(cx - half + WALL_THICKNESS * 0.5 + 0.15, torch_y, along)},
		{"start": cz - half + 3.0, "end": cz + half - 3.0, "get_pos": func(along: float) -> Vector3:
			return Vector3(cx + half - WALL_THICKNESS * 0.5 - 0.15, torch_y, along)},
	]

	var torch_idx := 0
	for wall_def in wall_defs:
		var pos_along: float = wall_def.start
		while pos_along <= wall_def.end:
			var torch_pos: Vector3 = wall_def.get_pos.call(pos_along)
			_create_single_torch(torch_pos, torch_idx)
			torch_idx += 1
			pos_along += torch_spacing


## 松明1本を生成（柄 + 炎 + ポイントライト）
func _create_single_torch(pos: Vector3, idx: int):
	var torch_root = Node3D.new()
	torch_root.name = "Torch_%d" % idx
	torch_root.position = pos
	add_child(torch_root)

	# 柄（細い棒）
	var handle = MeshInstance3D.new()
	handle.name = "Handle"
	var handle_mesh = CylinderMesh.new()
	handle_mesh.top_radius = 0.03
	handle_mesh.bottom_radius = 0.04
	handle_mesh.height = 0.6
	handle.mesh = handle_mesh
	handle.position = Vector3(0, -0.15, 0)
	var handle_mat = StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.25, 0.15, 0.08)
	handle_mat.roughness = 0.95
	handle.material_override = handle_mat
	torch_root.add_child(handle)

	# 炎の土台（布巻き部分）
	var wrap = MeshInstance3D.new()
	wrap.name = "Wrap"
	var wrap_mesh = CylinderMesh.new()
	wrap_mesh.top_radius = 0.06
	wrap_mesh.bottom_radius = 0.05
	wrap_mesh.height = 0.15
	wrap.mesh = wrap_mesh
	wrap.position = Vector3(0, 0.12, 0)
	var wrap_mat = StandardMaterial3D.new()
	wrap_mat.albedo_color = Color(0.3, 0.18, 0.08)
	wrap_mat.roughness = 0.9
	wrap.material_override = wrap_mat
	torch_root.add_child(wrap)

	# 炎（明るい球）
	var flame = MeshInstance3D.new()
	flame.name = "Flame"
	var flame_mesh = SphereMesh.new()
	flame_mesh.radius = 0.1
	flame_mesh.height = 0.2
	flame.mesh = flame_mesh
	flame.position = Vector3(0, 0.25, 0)
	var flame_mat = StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.6, 0.15)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.5, 0.1)
	flame_mat.emission_energy_multiplier = 3.0
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.albedo_color.a = 0.8
	flame.material_override = flame_mat
	torch_root.add_child(flame)

	# ポイントライト（暖色の揺らめく光）
	var light = OmniLight3D.new()
	light.name = "TorchLight"
	light.position = Vector3(0, 0.3, 0)
	light.light_color = Color(1.0, 0.7, 0.3)
	light.light_energy = 1.5
	light.omni_range = 14.0
	light.omni_attenuation = 1.0
	light.shadow_enabled = false  # パフォーマンス考慮
	torch_root.add_child(light)
	_torch_lights.append(light)
	_torch_flames.append(flame)


## 壁面に蔦を生成（MultiMeshInstance3D: 葉1ノード + 茎1ノード）
func _create_ivy():
	var half = _map_half_size + WALL_MARGIN
	var cx = _map_center.x
	var cz = _map_center.z
	var rng = RandomNumberGenerator.new()
	rng.seed = 54321

	# 全壁の蔦データを先に収集
	var leaf_transforms: Array[Transform3D] = []
	var stem_transforms: Array[Transform3D] = []

	var walls: Array[Dictionary] = [
		{"start": cx - half, "end": cx + half, "wall_pos": cz - half + WALL_THICKNESS * 0.5 + 0.05, "is_ns": true},
		{"start": cx - half, "end": cx + half, "wall_pos": cz + half - WALL_THICKNESS * 0.5 - 0.05, "is_ns": true},
		{"start": cz - half, "end": cz + half, "wall_pos": cx - half + WALL_THICKNESS * 0.5 + 0.05, "is_ns": false},
		{"start": cz - half, "end": cz + half, "wall_pos": cx + half - WALL_THICKNESS * 0.5 - 0.05, "is_ns": false},
	]

	for wall in walls:
		for _i in range(IVY_COUNT_PER_WALL):
			var along = rng.randf_range(wall.start + 2.0, wall.end - 2.0)
			var ivy_h = rng.randf_range(IVY_MIN_HEIGHT, IVY_MAX_HEIGHT)
			var ivy_w = rng.randf_range(IVY_WIDTH_MIN, IVY_WIDTH_MAX)

			# 茎
			var stem_pos: Vector3
			var stem_basis := Basis.IDENTITY.scaled(Vector3(0.06, ivy_h, 0.02))
			if wall.is_ns:
				stem_pos = Vector3(along, ivy_h * 0.5, wall.wall_pos)
			else:
				stem_pos = Vector3(wall.wall_pos, ivy_h * 0.5, along)
				stem_basis = stem_basis.rotated(Vector3.UP, deg_to_rad(90))
			stem_transforms.append(Transform3D(stem_basis, stem_pos))

			# 葉
			var leaf_count = int(ivy_h * 3.0)
			for _j in range(leaf_count):
				var leaf_y = rng.randf_range(0.2, ivy_h)
				var leaf_offset = rng.randf_range(-ivy_w * 0.4, ivy_w * 0.4)
				var leaf_size = rng.randf_range(0.25, 0.50)
				var leaf_pos: Vector3
				var leaf_basis := Basis.IDENTITY.scaled(Vector3(leaf_size, leaf_size, 1.0))
				leaf_basis = leaf_basis.rotated(Vector3.FORWARD, rng.randf_range(-0.4, 0.4))
				leaf_basis = leaf_basis.rotated(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
				if wall.is_ns:
					leaf_pos = Vector3(along + leaf_offset, leaf_y, wall.wall_pos)
				else:
					leaf_pos = Vector3(wall.wall_pos, leaf_y, along + leaf_offset)
					leaf_basis = leaf_basis.rotated(Vector3.UP, deg_to_rad(90))
				leaf_transforms.append(Transform3D(leaf_basis, leaf_pos))

	# 葉の MultiMesh（色バリエーション付き）
	if not leaf_transforms.is_empty():
		var leaf_mm = MultiMesh.new()
		leaf_mm.transform_format = MultiMesh.TRANSFORM_3D
		leaf_mm.use_colors = true
		leaf_mm.mesh = _create_heart_leaf_mesh()
		leaf_mm.instance_count = leaf_transforms.size()
		var color_rng = RandomNumberGenerator.new()
		color_rng.seed = 99999
		for i in range(leaf_transforms.size()):
			leaf_mm.set_instance_transform(i, leaf_transforms[i])
			var g = color_rng.randf_range(0.25, 0.45)
			var r = color_rng.randf_range(0.12, 0.22)
			leaf_mm.set_instance_color(i, Color(r, g, r * 0.5))
		var leaf_inst = MultiMeshInstance3D.new()
		leaf_inst.name = "IvyLeaves"
		leaf_inst.multimesh = leaf_mm
		leaf_inst.material_override = _create_ivy_material()
		add_child(leaf_inst)

	# 茎の MultiMesh
	if not stem_transforms.is_empty():
		var stem_mm = MultiMesh.new()
		stem_mm.transform_format = MultiMesh.TRANSFORM_3D
		stem_mm.mesh = BoxMesh.new()
		stem_mm.instance_count = stem_transforms.size()
		for i in range(stem_transforms.size()):
			stem_mm.set_instance_transform(i, stem_transforms[i])
		var stem_inst = MultiMeshInstance3D.new()
		stem_inst.name = "IvyStems"
		stem_inst.multimesh = stem_mm
		var stem_mat = StandardMaterial3D.new()
		stem_mat.albedo_color = Color(0.18, 0.28, 0.10)
		stem_inst.material_override = stem_mat
		add_child(stem_inst)


## 地面に草を配置（MultiMeshInstance3D: 1ノード）
func _create_grass_patches():
	var half = _map_half_size + WALL_MARGIN
	var cx = _map_center.x
	var cz = _map_center.z
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var transforms: Array[Transform3D] = []

	for _i in range(GRASS_PATCH_COUNT):
		var center: Vector3
		if rng.randf() < 0.7:
			var side = rng.randi_range(0, 3)
			match side:
				0: center = Vector3(rng.randf_range(cx - half + 1.0, cx + half - 1.0), 0.0, rng.randf_range(cz - half + 1.5, cz - half + 4.0))
				1: center = Vector3(rng.randf_range(cx - half + 1.0, cx + half - 1.0), 0.0, rng.randf_range(cz + half - 4.0, cz + half - 1.5))
				2: center = Vector3(rng.randf_range(cx - half + 1.5, cx - half + 4.0), 0.0, rng.randf_range(cz - half + 1.0, cz + half - 1.0))
				3: center = Vector3(rng.randf_range(cx + half - 4.0, cx + half - 1.5), 0.0, rng.randf_range(cz - half + 1.0, cz + half - 1.0))
		else:
			center = Vector3(rng.randf_range(cx - half + 2.0, cx + half - 2.0), 0.0, rng.randf_range(cz - half + 2.0, cz + half - 2.0))

		var blade_count = rng.randi_range(3, 6)
		for _j in range(blade_count):
			var offset = Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
			var h = GRASS_BLADE_HEIGHT * rng.randf_range(0.6, 1.4)
			var pos = center + offset + Vector3(0.0, h * 0.5, 0.0)
			var blade_basis = Basis.IDENTITY.scaled(Vector3(GRASS_BLADE_WIDTH, h, 1.0))
			blade_basis = blade_basis.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			blade_basis = blade_basis.rotated(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
			transforms.append(Transform3D(blade_basis, pos))

	if transforms.is_empty():
		return

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = QuadMesh.new()
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])

	var mm_inst = MultiMeshInstance3D.new()
	mm_inst.name = "GrassPatches"
	mm_inst.multimesh = mm
	mm_inst.material_override = _create_grass_material()
	add_child(mm_inst)


# --- マテリアル生成 ---

## レンガシェーダーマテリアル生成
func _create_brick_material() -> ShaderMaterial:
	var shader = load(BRICK_SHADER_PATH) as Shader
	if not shader:
		push_error("[CastleEnvironment] brick_wall.gdshader not found")
		return null
	var mat = ShaderMaterial.new()
	mat.shader = shader
	return mat


## 塔用レンガマテリアル（少し暗め）
func _create_tower_brick_material() -> ShaderMaterial:
	var shader = load(BRICK_SHADER_PATH) as Shader
	if not shader:
		return _brick_material
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("brick_color_1", Vector3(0.44, 0.43, 0.40))
	mat.set_shader_parameter("brick_color_2", Vector3(0.50, 0.48, 0.45))
	mat.set_shader_parameter("brick_color_3", Vector3(0.36, 0.35, 0.32))
	mat.set_shader_parameter("brick_width", 0.6)
	mat.set_shader_parameter("brick_height", 0.25)
	mat.set_shader_parameter("moss_amount", 0.25)
	return mat


## 笠石（キャップストーン）用マテリアル（floor3の石テクスチャを流用）
func _create_cap_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	var tex = load("res://assets/building_parts/floor3_stone_ground_05_color.jpg") as Texture2D
	if tex:
		mat.albedo_texture = tex
		mat.albedo_color = Color(0.7, 0.68, 0.65)  # テクスチャを少し暗くして壁に馴染ませる
		mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
		mat.uv1_triplanar = true
	else:
		mat.albedo_color = Color(0.55, 0.53, 0.50)
	mat.roughness = 0.85
	return mat


## ハート型の蔦の葉メッシュ生成
func _create_heart_leaf_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var verts = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# ハート形状の頂点（中心原点、サイズ1.0×1.0）
	# 上部の2つの丸み + 下部の尖り
	var points: Array[Vector2] = []
	points.append(Vector2(0.0, -0.5))  # 下端（尖り）

	# 右側の曲線（下から上へ）
	var seg := 8
	for i in range(seg + 1):
		var t = float(i) / float(seg)
		var angle = PI * 0.1 + t * PI * 0.9
		var r = 0.28
		var cx_r = 0.22
		var cy = 0.15
		var px = cx_r + r * cos(angle)
		var py = cy + r * sin(angle)
		points.append(Vector2(px, py))

	# 左側の曲線（上から下へ、右側のミラー）
	for i in range(seg, -1, -1):
		var t = float(i) / float(seg)
		var angle = PI * 0.1 + t * PI * 0.9
		var r = 0.28
		var cx_l = -0.22
		var cy = 0.15
		var px = cx_l - r * cos(angle)
		var py = cy + r * sin(angle)
		points.append(Vector2(px, py))

	# 中心頂点（fan の中心）
	var center = Vector2(0.0, 0.05)
	verts.append(Vector3(center.x, center.y, 0.0))
	uvs.append(Vector2(center.x + 0.5, 0.5 - center.y))

	# 外周頂点
	for p in points:
		verts.append(Vector3(p.x, p.y, 0.0))
		uvs.append(Vector2(p.x + 0.5, 0.5 - p.y))

	# 三角形ファン（中心=0、外周=1～N）
	var count = points.size()
	for i in range(count):
		indices.append(0)
		indices.append(1 + i)
		indices.append(1 + (i + 1) % count)

	# 全頂点の法線（平面なのでZ+方向）
	var normals = PackedVector3Array()
	for _i in range(verts.size()):
		normals.append(Vector3(0.0, 0.0, -1.0))

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 蔦用マテリアル
func _create_ivy_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## 草用マテリアル
func _create_grass_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.42, 0.12)
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

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
const WALL_HEIGHT := 6.0       # 壁の高さ
const WALL_THICKNESS := 1.2    # 壁の厚み
const BATTLEMENT_HEIGHT := 0.8 # 胸壁（凹凸）の高さ
const BATTLEMENT_WIDTH := 1.5  # 胸壁の幅
const BATTLEMENT_GAP := 1.2    # 胸壁の隙間

# 塔パラメータ
const TOWER_RADIUS := 2.0
const TOWER_HEIGHT := 8.0
const TOWER_SIDES := 12

# 門パラメータ
const GATE_WIDTH := 4.0         # 門の幅
const GATE_HEIGHT := 4.5        # 門の高さ
const GATE_THICKNESS := 0.3     # 扉の厚み

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
		push_error("[CastleEnvironment] floor3.glb not found, falling back to simple ground")
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
	var ground_container: Node3D = Node3D.new()
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


## フォールバック: MeshInstance3Dの単色地面
func _create_ground_fallback():
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "Ground"
	var total_size = _map_half_size * 2.0 + (WALL_MARGIN + GROUND_MARGIN) * 2.0
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(total_size, 0.3, total_size)
	ground.mesh = box
	ground.position = Vector3(_map_center.x, GROUND_Y, _map_center.z)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = COLOR_GROUND
	mat.roughness = 0.95
	ground.material_override = mat
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

	# 西壁 (X-) - 1枚壁 + 門を貼り付け
	var ew_size = Vector3(WALL_THICKNESS, WALL_HEIGHT, half * 2.0 + WALL_THICKNESS)
	_create_single_wall("WallWest", Vector3(center_x - half, wall_y, center_z), ew_size, _brick_material)
	_create_wall_cap("WallCapWest", Vector3(center_x - half, WALL_HEIGHT, center_z),
		Vector3(WALL_THICKNESS + 0.2, 0.15, ew_size.z + 0.2), cap_mat)
	# 門を壁の内側面に貼り付け（+X方向にオフセット）
	var gate_offset: float = WALL_THICKNESS / 2.0 + GATE_THICKNESS / 2.0
	_create_gate("GateWest", Vector3(center_x - half + gate_offset, 0, center_z), true)

	# 東壁 (X+) - 1枚壁 + 門を貼り付け
	_create_single_wall("WallEast", Vector3(center_x + half, wall_y, center_z), ew_size, _brick_material)
	_create_wall_cap("WallCapEast", Vector3(center_x + half, WALL_HEIGHT, center_z),
		Vector3(WALL_THICKNESS + 0.2, 0.15, ew_size.z + 0.2), cap_mat)
	# 門を壁の内側面に貼り付け（-X方向にオフセット）
	_create_gate("GateEast", Vector3(center_x + half - gate_offset, 0, center_z), true)

	# 胸壁（バトルメント）を各壁の上に追加
	_create_battlements_north_south(center_x, center_z, half, cap_mat)
	_create_battlements_east_west(center_x, center_z, half, cap_mat)


## 重厚な門を生成（両開き扉 + 装飾枠）
## is_ew: 東西壁の門（true）か南北壁の門（false）か
func _create_gate(gate_name: String, base_pos: Vector3, is_ew: bool):
	var gate_root: Node3D = Node3D.new()
	gate_root.name = gate_name
	gate_root.position = base_pos
	add_child(gate_root)

	var door_mat: StandardMaterial3D = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.22, 0.14, 0.08)
	door_mat.roughness = 0.85

	var iron_mat: StandardMaterial3D = StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.15, 0.15, 0.16)
	iron_mat.roughness = 0.6
	iron_mat.metallic = 0.7

	var door_half: float = GATE_WIDTH / 2.0
	var arch_radius: float = 3.0
	var rect_h: float = GATE_HEIGHT - arch_radius  # 四角部分の高さ

	# 扉（四角部分）
	var full_door: MeshInstance3D = MeshInstance3D.new()
	full_door.name = "DoorPanel"
	var full_door_mesh: BoxMesh = BoxMesh.new()
	if is_ew:
		full_door_mesh.size = Vector3(GATE_THICKNESS, GATE_HEIGHT, GATE_WIDTH)
		full_door.position = Vector3(0, GATE_HEIGHT / 2.0, 0)
	else:
		full_door_mesh.size = Vector3(GATE_WIDTH, GATE_HEIGHT, GATE_THICKNESS)
		full_door.position = Vector3(0, GATE_HEIGHT / 2.0, 0)
	full_door.mesh = full_door_mesh
	full_door.material_override = door_mat
	gate_root.add_child(full_door)

	# アーチ部分の扉（半円）
	var arch_door: MeshInstance3D = MeshInstance3D.new()
	arch_door.name = "ArchDoor"
	arch_door.mesh = _create_semicircle_mesh(arch_radius, GATE_THICKNESS + 0.01, is_ew, door_half)
	arch_door.position = Vector3(0, rect_h, 0)
	arch_door.material_override = door_mat
	gate_root.add_child(arch_door)

	# アーチ枠（半円リング状のレンガ枠）
	var frame_thickness := 0.6
	var arch_frame: MeshInstance3D = MeshInstance3D.new()
	arch_frame.name = "ArchFrame"
	arch_frame.mesh = _create_arch_frame_mesh(arch_radius, frame_thickness, GATE_THICKNESS + 0.1, is_ew, door_half)
	arch_frame.position = Vector3(0, rect_h, 0)
	arch_frame.material_override = _brick_material
	gate_root.add_child(arch_frame)

	# 中央の隙間線（扉の合わせ目）
	var seam: MeshInstance3D = MeshInstance3D.new()
	seam.name = "DoorSeam"
	var seam_mesh: BoxMesh = BoxMesh.new()
	if is_ew:
		seam_mesh.size = Vector3(GATE_THICKNESS + 0.02, GATE_HEIGHT, 0.04)
	else:
		seam_mesh.size = Vector3(0.04, GATE_HEIGHT, GATE_THICKNESS + 0.02)
	seam.mesh = seam_mesh
	seam.position = Vector3(0, GATE_HEIGHT / 2.0, 0)
	seam.material_override = iron_mat
	gate_root.add_child(seam)

	# 鉄の横帯（3本、四角部分のみ）
	for bi in range(3):
		var band: MeshInstance3D = MeshInstance3D.new()
		band.name = "IronBand_%d" % bi
		var band_mesh: BoxMesh = BoxMesh.new()
		var band_y: float = GATE_HEIGHT * (0.2 + 0.25 * float(bi))
		if is_ew:
			band_mesh.size = Vector3(GATE_THICKNESS + 0.02, 0.12, GATE_WIDTH)
		else:
			band_mesh.size = Vector3(GATE_WIDTH, 0.12, GATE_THICKNESS + 0.02)
		band.mesh = band_mesh
		band.position = Vector3(0, band_y, 0)
		band.material_override = iron_mat
		gate_root.add_child(band)

	# 門柱（左右の太い柱）
	var pillar_mat: ShaderMaterial = _brick_material
	for side in [-1.0, 1.0]:
		var pillar: MeshInstance3D = MeshInstance3D.new()
		pillar.name = "GatePillar_%d" % int(side)
		var pillar_mesh: BoxMesh = BoxMesh.new()
		var pillar_w := 0.5
		if is_ew:
			pillar_mesh.size = Vector3(GATE_THICKNESS + 0.15, GATE_HEIGHT + 0.5, pillar_w)
			pillar.position = Vector3(0, (GATE_HEIGHT + 0.5) / 2.0, (door_half + pillar_w * 0.3) * side)
		else:
			pillar_mesh.size = Vector3(pillar_w, GATE_HEIGHT + 0.5, GATE_THICKNESS + 0.15)
			pillar.position = Vector3((door_half + pillar_w * 0.3) * side, (GATE_HEIGHT + 0.5) / 2.0, 0)
		pillar.mesh = pillar_mesh
		pillar.material_override = pillar_mat
		gate_root.add_child(pillar)

	# 門柱の上のキャップストーン
	var cap_mat: StandardMaterial3D = _create_cap_material()
	for side in [-1.0, 1.0]:
		var pcap: MeshInstance3D = MeshInstance3D.new()
		pcap.name = "PillarCap_%d" % int(side)
		var pcap_mesh: BoxMesh = BoxMesh.new()
		if is_ew:
			pcap_mesh.size = Vector3(GATE_THICKNESS + 0.3, 0.15, 0.7)
			pcap.position = Vector3(0, GATE_HEIGHT + 0.5, (door_half + 0.15) * side)
		else:
			pcap_mesh.size = Vector3(0.7, 0.15, GATE_THICKNESS + 0.3)
			pcap.position = Vector3((door_half + 0.15) * side, GATE_HEIGHT + 0.5, 0)
		pcap.mesh = pcap_mesh
		pcap.material_override = cap_mat
		gate_root.add_child(pcap)

	# アーチの頂点のキーストーン（楔石）
	var keystone: MeshInstance3D = MeshInstance3D.new()
	keystone.name = "Keystone"
	var keystone_mesh: BoxMesh = BoxMesh.new()
	if is_ew:
		keystone_mesh.size = Vector3(GATE_THICKNESS + 0.15, 0.4, 0.35)
		keystone.position = Vector3(0, rect_h + arch_radius + frame_thickness * 0.5, 0)
	else:
		keystone_mesh.size = Vector3(0.35, 0.4, GATE_THICKNESS + 0.15)
		keystone.position = Vector3(0, rect_h + arch_radius + frame_thickness * 0.5, 0)
	keystone.mesh = keystone_mesh
	keystone.material_override = cap_mat
	gate_root.add_child(keystone)


## 壁1枚を生成
func _create_single_wall(wall_name: String, pos: Vector3, wall_size: Vector3, mat: Material):
	var wall: MeshInstance3D = MeshInstance3D.new()
	wall.name = wall_name
	var box: BoxMesh = BoxMesh.new()
	box.size = wall_size
	wall.mesh = box
	wall.position = pos
	wall.material_override = mat
	add_child(wall)


## 壁の上の笠石（キャップストーン）を生成
func _create_wall_cap(cap_name: String, pos: Vector3, cap_size: Vector3, mat: Material):
	var cap: MeshInstance3D = MeshInstance3D.new()
	cap.name = cap_name
	var box: BoxMesh = BoxMesh.new()
	box.size = cap_size
	cap.mesh = box
	cap.position = pos
	cap.material_override = mat
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
			var b: MeshInstance3D = MeshInstance3D.new()
			b.name = "BattlementNS_%d_%d" % [int(z_sign), idx]
			var b_mesh: BoxMesh = BoxMesh.new()
			b_mesh.size = Vector3(BATTLEMENT_WIDTH, BATTLEMENT_HEIGHT, WALL_THICKNESS + 0.3)
			b.mesh = b_mesh
			b.position = Vector3(bx, top_y, z_pos)
			b.material_override = _brick_material
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
			var b: MeshInstance3D = MeshInstance3D.new()
			b.name = "BattlementEW_%d_%d" % [int(x_sign), idx]
			var b_mesh: BoxMesh = BoxMesh.new()
			b_mesh.size = Vector3(WALL_THICKNESS + 0.3, BATTLEMENT_HEIGHT, BATTLEMENT_WIDTH)
			b.mesh = b_mesh
			b.position = Vector3(x_pos, top_y, bz)
			b.material_override = _brick_material
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

	var roof_mat: StandardMaterial3D = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.3, 0.32, 0.35)
	roof_mat.roughness = 0.8

	for i in range(corners.size()):
		# 塔本体
		var tower: MeshInstance3D = MeshInstance3D.new()
		tower.name = "Tower_%d" % i
		var tower_mesh: CylinderMesh = CylinderMesh.new()
		tower_mesh.top_radius = TOWER_RADIUS
		tower_mesh.bottom_radius = TOWER_RADIUS
		tower_mesh.height = TOWER_HEIGHT
		tower_mesh.radial_segments = TOWER_SIDES
		tower.mesh = tower_mesh
		tower.position = corners[i]
		tower.material_override = tower_mat
		add_child(tower)

		# 塔の上部（少し広い円柱）
		var tower_top: MeshInstance3D = MeshInstance3D.new()
		tower_top.name = "TowerTop_%d" % i
		var top_mesh: CylinderMesh = CylinderMesh.new()
		top_mesh.top_radius = TOWER_RADIUS + 0.4
		top_mesh.bottom_radius = TOWER_RADIUS + 0.4
		top_mesh.height = 0.6
		top_mesh.radial_segments = TOWER_SIDES
		tower_top.mesh = top_mesh
		tower_top.position = Vector3(corners[i].x, TOWER_HEIGHT + 0.3, corners[i].z)
		tower_top.material_override = tower_mat
		add_child(tower_top)

		# 塔の円錐屋根
		var roof: MeshInstance3D = MeshInstance3D.new()
		roof.name = "TowerRoof_%d" % i
		var roof_mesh: CylinderMesh = CylinderMesh.new()
		roof_mesh.top_radius = 0.01
		roof_mesh.bottom_radius = TOWER_RADIUS + 0.6
		roof_mesh.height = 3.0
		roof_mesh.radial_segments = TOWER_SIDES
		roof.mesh = roof_mesh
		roof.position = Vector3(corners[i].x, TOWER_HEIGHT + 0.6 + 1.5, corners[i].z)
		roof.material_override = roof_mat
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
	var torch_root: Node3D = Node3D.new()
	torch_root.name = "Torch_%d" % idx
	torch_root.position = pos
	add_child(torch_root)

	# 柄（細い棒）
	var handle: MeshInstance3D = MeshInstance3D.new()
	handle.name = "Handle"
	var handle_mesh: CylinderMesh = CylinderMesh.new()
	handle_mesh.top_radius = 0.03
	handle_mesh.bottom_radius = 0.04
	handle_mesh.height = 0.6
	handle.mesh = handle_mesh
	handle.position = Vector3(0, -0.15, 0)
	var handle_mat: StandardMaterial3D = StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.25, 0.15, 0.08)
	handle_mat.roughness = 0.95
	handle.material_override = handle_mat
	torch_root.add_child(handle)

	# 炎の土台（布巻き部分）
	var wrap: MeshInstance3D = MeshInstance3D.new()
	wrap.name = "Wrap"
	var wrap_mesh: CylinderMesh = CylinderMesh.new()
	wrap_mesh.top_radius = 0.06
	wrap_mesh.bottom_radius = 0.05
	wrap_mesh.height = 0.15
	wrap.mesh = wrap_mesh
	wrap.position = Vector3(0, 0.12, 0)
	var wrap_mat: StandardMaterial3D = StandardMaterial3D.new()
	wrap_mat.albedo_color = Color(0.3, 0.18, 0.08)
	wrap_mat.roughness = 0.9
	wrap.material_override = wrap_mat
	torch_root.add_child(wrap)

	# 炎（明るい球）
	var flame: MeshInstance3D = MeshInstance3D.new()
	flame.name = "Flame"
	var flame_mesh: SphereMesh = SphereMesh.new()
	flame_mesh.radius = 0.1
	flame_mesh.height = 0.2
	flame.mesh = flame_mesh
	flame.position = Vector3(0, 0.25, 0)
	var flame_mat: StandardMaterial3D = StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.6, 0.15)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.5, 0.1)
	flame_mat.emission_energy_multiplier = 3.0
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.albedo_color.a = 0.8
	flame.material_override = flame_mat
	torch_root.add_child(flame)

	# ポイントライト（暖色の揺らめく光）
	var light: OmniLight3D = OmniLight3D.new()
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
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
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
			# 蔦全体の伸びる方向（斜めにばらつかせる）
			var grow_lean = rng.randf_range(-0.6, 0.6)  # 横方向への傾き

			# 茎（複数セグメントで蛇行、経路を記録）
			var seg_count = int(ivy_h / 0.4) + 1
			var seg_h = ivy_h / float(seg_count)
			var drift := 0.0
			var stem_path: Array[Vector2] = []  # Y座標と横ドリフトの記録
			stem_path.append(Vector2(0.0, 0.0))
			for si in range(seg_count):
				# 全体の傾きに沿いつつランダムに蛇行
				drift += grow_lean * 0.15 + rng.randf_range(-0.25, 0.25)
				drift = clampf(drift, -ivy_w * 0.4, ivy_w * 0.4)
				var seg_y = seg_h * (float(si) + 0.5)
				var prev_drift = stem_path[stem_path.size() - 1].y
				var tilt = atan2(drift - prev_drift, seg_h)
				stem_path.append(Vector2(seg_y + seg_h * 0.5, drift))
				var seg_basis := Basis.IDENTITY.scaled(Vector3(0.05, seg_h, 0.02))
				var seg_pos: Vector3
				if wall.is_ns:
					seg_basis = seg_basis.rotated(Vector3.FORWARD, tilt)
					seg_pos = Vector3(along + drift, seg_y, wall.wall_pos)
				else:
					seg_basis = seg_basis.rotated(Vector3.UP, deg_to_rad(90))
					seg_basis = seg_basis.rotated(Vector3.RIGHT, tilt)
					seg_pos = Vector3(wall.wall_pos, seg_y, along + drift)
				stem_transforms.append(Transform3D(seg_basis, seg_pos))

			# 葉（茎の経路に沿って配置）
			var leaf_count = int(ivy_h * 3.0)
			for _j in range(leaf_count):
				var leaf_y = rng.randf_range(0.2, ivy_h)
				# 茎の経路から該当Y位置のドリフトを補間で取得
				var stem_drift := 0.0
				for pi in range(stem_path.size() - 1):
					if leaf_y >= stem_path[pi].x and leaf_y <= stem_path[pi + 1].x:
						var t = (leaf_y - stem_path[pi].x) / maxf(stem_path[pi + 1].x - stem_path[pi].x, 0.01)
						stem_drift = lerpf(stem_path[pi].y, stem_path[pi + 1].y, t)
						break
					elif pi == stem_path.size() - 2:
						stem_drift = stem_path[pi + 1].y
				# 茎から少しだけ左右にずらす
				var leaf_offset = stem_drift + rng.randf_range(-0.3, 0.3)
				var leaf_size = rng.randf_range(0.25, 0.50)
				var leaf_pos: Vector3
				var leaf_basis := Basis.IDENTITY.scaled(Vector3(leaf_size, leaf_size, 1.0))
				leaf_basis = leaf_basis.rotated(Vector3.FORWARD, rng.randf_range(-0.5, 0.5))
				leaf_basis = leaf_basis.rotated(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
				if wall.is_ns:
					leaf_pos = Vector3(along + leaf_offset, leaf_y, wall.wall_pos)
				else:
					leaf_pos = Vector3(wall.wall_pos, leaf_y, along + leaf_offset)
					leaf_basis = leaf_basis.rotated(Vector3.UP, deg_to_rad(90))
				leaf_transforms.append(Transform3D(leaf_basis, leaf_pos))

	# 葉の MultiMesh（色バリエーション付き）
	if not leaf_transforms.is_empty():
		var leaf_mm: MultiMesh = MultiMesh.new()
		leaf_mm.transform_format = MultiMesh.TRANSFORM_3D
		leaf_mm.use_colors = true
		leaf_mm.mesh = _create_heart_leaf_mesh()
		leaf_mm.instance_count = leaf_transforms.size()
		var color_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		color_rng.seed = 99999
		for i in range(leaf_transforms.size()):
			leaf_mm.set_instance_transform(i, leaf_transforms[i])
			var g = color_rng.randf_range(0.25, 0.45)
			var r = color_rng.randf_range(0.12, 0.22)
			leaf_mm.set_instance_color(i, Color(r, g, r * 0.5))
		var leaf_inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
		leaf_inst.name = "IvyLeaves"
		leaf_inst.multimesh = leaf_mm
		leaf_inst.material_override = _create_ivy_material()
		add_child(leaf_inst)

	# 茎の MultiMesh
	if not stem_transforms.is_empty():
		var stem_mm: MultiMesh = MultiMesh.new()
		stem_mm.transform_format = MultiMesh.TRANSFORM_3D
		stem_mm.mesh = BoxMesh.new()
		stem_mm.instance_count = stem_transforms.size()
		for i in range(stem_transforms.size()):
			stem_mm.set_instance_transform(i, stem_transforms[i])
		var stem_inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
		stem_inst.name = "IvyStems"
		stem_inst.multimesh = stem_mm
		var stem_mat: StandardMaterial3D = StandardMaterial3D.new()
		stem_mat.albedo_color = Color(0.18, 0.28, 0.10)
		stem_inst.material_override = stem_mat
		add_child(stem_inst)


## 地面に草を配置（MultiMeshInstance3D: 1ノード）
## 城壁寄りに多く、マップタイル付近には生成しない
func _create_grass_patches():
	var half = _map_half_size + WALL_MARGIN
	var cx = _map_center.x
	var cz = _map_center.z
	var tile_half = _map_half_size + 1.5  # タイルがある範囲（少し余裕）
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345

	var transforms: Array[Transform3D] = []

	for _i in range(GRASS_PATCH_COUNT):
		# 城壁寄りにランダム配置を試行
		var center := Vector3.ZERO
		var valid := false
		for _try in range(10):
			var px = rng.randf_range(cx - half + 1.0, cx + half - 1.0)
			var pz = rng.randf_range(cz - half + 1.0, cz + half - 1.0)
			# マップタイル範囲内はスキップ
			if abs(px - cx) < tile_half and abs(pz - cz) < tile_half:
				continue
			center = Vector3(px, 0.0, pz)
			valid = true
			break
		if not valid:
			continue

		# 壁からの距離で密度を調整（壁に近いほど草を多く）
		var dist_to_wall = min(
			abs(center.x - (cx - half)), abs(center.x - (cx + half)),
			abs(center.z - (cz - half)), abs(center.z - (cz + half))
		)
		var wall_proximity = 1.0 - clampf(dist_to_wall / (half * 2.0), 0.0, 1.0)
		var blade_count = rng.randi_range(3, 4) + int(wall_proximity * 5.0)

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

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _create_grass_blade_mesh()
	mm.instance_count = transforms.size()
	var color_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	color_rng.seed = 77777
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		var g = color_rng.randf_range(0.35, 0.55)
		mm.set_instance_color(i, Color(g * 0.4, g, g * 0.2))

	var mm_inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm_inst.name = "GrassPatches"
	mm_inst.multimesh = mm
	mm_inst.material_override = _create_grass_material()
	add_child(mm_inst)


## アーチ付き扉メッシュ生成（四角部分＋上部アーチを1枚で、UV付き）
func _create_arched_door_mesh(half_w: float, rect_h: float, arch_r: float, thickness: float, is_ew: bool) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	# アーチのクリップ角度
	var start_angle := 0.0
	var end_angle := PI
	if half_w < arch_r:
		var clip_angle: float = acos(half_w / arch_r)
		start_angle = clip_angle
		end_angle = PI - clip_angle
	var arch_top_y: float = rect_h + arch_r  # UV正規化用
	var arch_segments := 16

	# 表面と裏面
	for face in [1.0, -1.0]:
		var offset: int = verts.size()
		var face_d: float = thickness / 2.0 * face
		var n_vec: Vector3

		# --- 四角部分（4頂点、2三角形）---
		# 0: 左下, 1: 右下, 2: 右上, 3: 左上
		var rect_pts: Array[Vector2] = [
			Vector2(-half_w, 0.0),
			Vector2(half_w, 0.0),
			Vector2(half_w, rect_h),
			Vector2(-half_w, rect_h),
		]
		for p in rect_pts:
			if is_ew:
				verts.append(Vector3(face_d, p.y, p.x))
				n_vec = Vector3(face, 0, 0)
			else:
				verts.append(Vector3(p.x, p.y, face_d))
				n_vec = Vector3(0, 0, face)
			normals.append(n_vec)
			uvs.append(Vector2((p.x + half_w) / (half_w * 2.0), 1.0 - p.y / arch_top_y))

		if face > 0:
			indices.append_array([offset, offset + 1, offset + 2])
			indices.append_array([offset, offset + 2, offset + 3])
		else:
			indices.append_array([offset, offset + 2, offset + 1])
			indices.append_array([offset, offset + 3, offset + 2])

		# --- アーチ部分（ファン: 中心=arch底辺中央、外周=アーチカーブ）---
		var arch_offset: int = verts.size()
		# ファン中心（アーチの底辺中央 = 0, rect_h）
		if is_ew:
			verts.append(Vector3(face_d, rect_h, 0.0))
		else:
			verts.append(Vector3(0.0, rect_h, face_d))
		normals.append(n_vec)
		uvs.append(Vector2(0.5, 1.0 - rect_h / arch_top_y))

		# アーチカーブの頂点
		for i in range(arch_segments + 1):
			var angle: float = start_angle + (end_angle - start_angle) * float(i) / float(arch_segments)
			var px: float = -cos(angle) * arch_r
			var py: float = rect_h + sin(angle) * arch_r
			if is_ew:
				verts.append(Vector3(face_d, py, px))
			else:
				verts.append(Vector3(px, py, face_d))
			normals.append(n_vec)
			uvs.append(Vector2((px + half_w) / (half_w * 2.0), 1.0 - py / arch_top_y))

		# アーチのファン三角形
		for i in range(arch_segments):
			if face > 0:
				indices.append(arch_offset)
				indices.append(arch_offset + 1 + i)
				indices.append(arch_offset + 1 + i + 1)
			else:
				indices.append(arch_offset)
				indices.append(arch_offset + 1 + i + 1)
				indices.append(arch_offset + 1 + i)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 半円板メッシュ生成（アーチ扉用、clip_half_w で左右をクリップ）
func _create_semicircle_mesh(radius: float, thickness: float, is_ew: bool, clip_half_w: float) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var segments := 24

	# クリップ角度を計算（半径 > クリップ幅なら端をカット）
	var start_angle := 0.0
	var end_angle := PI
	if clip_half_w > 0.0 and clip_half_w < radius:
		var clip_angle: float = acos(clip_half_w / radius)
		start_angle = clip_angle
		end_angle = PI - clip_angle

	# 表面と裏面を作成（厚みのある板）
	for face in [1.0, -1.0]:
		var offset: int = verts.size()
		var face_offset: float = thickness / 2.0 * face
		# 中心点
		if is_ew:
			verts.append(Vector3(face_offset, 0, 0))
			normals.append(Vector3(face, 0, 0))
		else:
			verts.append(Vector3(0, 0, face_offset))
			normals.append(Vector3(0, 0, face))

		# 半円の外周（クリップ範囲内）
		for i in range(segments + 1):
			var angle: float = start_angle + (end_angle - start_angle) * float(i) / float(segments)
			var px: float = -cos(angle) * radius
			var py: float = sin(angle) * radius
			if is_ew:
				verts.append(Vector3(face_offset, py, px))
				normals.append(Vector3(face, 0, 0))
			else:
				verts.append(Vector3(px, py, face_offset))
				normals.append(Vector3(0, 0, face))

		# 三角形ファン
		for i in range(segments):
			if face > 0:
				indices.append(offset)
				indices.append(offset + 1 + i)
				indices.append(offset + 1 + i + 1)
			else:
				indices.append(offset)
				indices.append(offset + 1 + i + 1)
				indices.append(offset + 1 + i)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 半円リングメッシュ生成（アーチ枠用、clip_half_w で左右をクリップ）
func _create_arch_frame_mesh(inner_radius: float, frame_w: float, depth: float, is_ew: bool, clip_half_w: float) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var segments := 24
	var outer_r: float = inner_radius + frame_w
	var half_d: float = depth / 2.0

	# クリップ角度を計算
	var start_angle := 0.0
	var end_angle := PI
	if clip_half_w > 0.0 and clip_half_w < inner_radius:
		var clip_angle: float = acos(clip_half_w / inner_radius)
		start_angle = clip_angle
		end_angle = PI - clip_angle

	# 前面と後面のリング
	for face in [1.0, -1.0]:
		var offset: int = verts.size()
		var face_d: float = half_d * face
		for i in range(segments + 1):
			var angle: float = start_angle + (end_angle - start_angle) * float(i) / float(segments)
			var ix: float = -cos(angle) * inner_radius
			var iy: float = sin(angle) * inner_radius
			var ox: float = -cos(angle) * outer_r
			var oy: float = sin(angle) * outer_r
			if is_ew:
				verts.append(Vector3(face_d, iy, ix))
				normals.append(Vector3(face, 0, 0))
				verts.append(Vector3(face_d, oy, ox))
				normals.append(Vector3(face, 0, 0))
			else:
				verts.append(Vector3(ix, iy, face_d))
				normals.append(Vector3(0, 0, face))
				verts.append(Vector3(ox, oy, face_d))
				normals.append(Vector3(0, 0, face))

		for i in range(segments):
			var b: int = offset + i * 2
			if face > 0:
				indices.append_array([b, b + 2, b + 1])
				indices.append_array([b + 1, b + 2, b + 3])
			else:
				indices.append_array([b, b + 1, b + 2])
				indices.append_array([b + 1, b + 3, b + 2])

	# 外側面（上面）
	var offset_top: int = verts.size()
	for i in range(segments + 1):
		var angle: float = start_angle + (end_angle - start_angle) * float(i) / float(segments)
		var ox: float = -cos(angle) * outer_r
		var oy: float = sin(angle) * outer_r
		var nx: float = -cos(angle)
		var ny: float = sin(angle)
		if is_ew:
			verts.append(Vector3(-half_d, oy, ox))
			verts.append(Vector3(half_d, oy, ox))
			normals.append(Vector3(0, ny, nx))
			normals.append(Vector3(0, ny, nx))
		else:
			verts.append(Vector3(ox, oy, -half_d))
			verts.append(Vector3(ox, oy, half_d))
			normals.append(Vector3(nx, ny, 0))
			normals.append(Vector3(nx, ny, 0))

	for i in range(segments):
		var b: int = offset_top + i * 2
		indices.append_array([b, b + 1, b + 2])
		indices.append_array([b + 1, b + 3, b + 2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 草の葉メッシュ生成（根元から上がって先端が垂れ下がる弧状）
func _create_grass_blade_mesh() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# 弧状の草：根元→上→先端が垂れる
	var segments := 5
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		# 幅: 根元で広く先端で細く
		var w = lerpf(0.5, 0.02, t)
		# 高さ: 放物線的に上がって落ちる（ピークは t=0.5 付近）
		var y = -0.5 + t * 1.2 - t * t * 0.8
		# 先端が前方に垂れる
		var z = t * t * 0.3
		verts.append(Vector3(-w, y, z))
		verts.append(Vector3(w, y, z))
		normals.append(Vector3(0.0, 0.0, 1.0))
		normals.append(Vector3(0.0, 0.0, 1.0))
		uvs.append(Vector2(0.0, 1.0 - t))
		uvs.append(Vector2(1.0, 1.0 - t))

	# 三角形ストリップをインデックスに変換
	for i in range(segments):
		var base = i * 2
		indices.append_array([base, base + 1, base + 2])
		indices.append_array([base + 1, base + 3, base + 2])

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- マテリアル生成 ---

## レンガシェーダーマテリアル生成
func _create_brick_material() -> ShaderMaterial:
	var shader = load(BRICK_SHADER_PATH) as Shader
	if not shader:
		push_error("[CastleEnvironment] brick_wall.gdshader not found")
		return null
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	return mat


## 塔用レンガマテリアル（少し暗め）
func _create_tower_brick_material() -> ShaderMaterial:
	var shader = load(BRICK_SHADER_PATH) as Shader
	if not shader:
		return _brick_material
	var mat: ShaderMaterial = ShaderMaterial.new()
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
	var mat: StandardMaterial3D = StandardMaterial3D.new()
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
	var mesh: ArrayMesh = ArrayMesh.new()
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
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## 草用マテリアル
func _create_grass_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

extends BaseEnvironment
class_name CastleEnvironment

## 城壁環境: 壁・塔・門・胸壁・蔦・草を生成

# 松明アニメーション用
var _torch_lights: Array[OmniLight3D] = []
var _torch_flames: Array[MeshInstance3D] = []
var _torch_time := 0.0

# 城壁パラメータ
const WALL_MARGIN := 13.0      # マップ端からの余白（北・東・西）
const WALL_MARGIN_SOUTH := 17.0  # 南壁マージン（カメラ干渉回避のため広め）
const WALL_HEIGHT := 9.0       # 壁の高さ
const WALL_THICKNESS := 1.2    # 壁の厚み
const BATTLEMENT_HEIGHT := 0.8 # 胸壁（凹凸）の高さ
const BATTLEMENT_WIDTH := 1.5  # 胸壁の幅
const BATTLEMENT_GAP := 1.2    # 胸壁の隙間

# 塔パラメータ
const TOWER_RADIUS := 2.0
const TOWER_HEIGHT := 11.0
const TOWER_SIDES := 12

# 門パラメータ
const GATE_WIDTH := 5.5         # 門の幅
const GATE_HEIGHT := 6.0        # 門の高さ
const GATE_THICKNESS := 0.3     # 扉の厚み

# シェーダーパス
const BRICK_SHADER_PATH := "res://assets/shaders/brick_wall.gdshader"

# 蔦パラメータ
const IVY_COUNT_PER_WALL := 5
const IVY_MIN_HEIGHT := 0.5
const IVY_MAX_HEIGHT := 5.0
const IVY_WIDTH_MIN := 1.5
const IVY_WIDTH_MAX := 3.5

# 草パラメータ
const GRASS_PATCH_COUNT := 120
const GRASS_BLADE_HEIGHT := 0.4
const GRASS_BLADE_WIDTH := 0.08

var _brick_material: ShaderMaterial


func _process(delta: float) -> void:
	if _torch_lights.is_empty():
		return
	_torch_time += delta
	for i in range(_torch_lights.size()):
		var phase: float = float(i) * 2.7
		var f1: float = sin(_torch_time * 5.3 + phase) * 0.08
		var f2: float = sin(_torch_time * 8.7 + phase * 1.61) * 0.05
		var f3: float = sin(_torch_time * 14.1 + phase * 0.73) * 0.03
		var spike: float = pow(abs(sin(_torch_time * 3.1 + phase * 2.39)), 12.0) * 0.1
		var flicker: float = f1 + f2 + f3 + spike
		_torch_lights[i].light_energy = 1.5 + flicker
		var s: float = 1.0 + flicker * 0.12
		_torch_flames[i].scale = Vector3(s, s + flicker * 0.08, s)


func _get_environment_margin() -> float:
	return WALL_MARGIN_SOUTH  # 最大マージンを返す（地面が全壁を覆うように）


func _build() -> void:
	_brick_material = _create_brick_material()
	_create_ground()
	_create_walls()
	_create_corner_towers()
	#_create_torches()  # モバイル負荷対策で無効化（OmniLight3Dが重い）
	_create_ivy()
	_create_grass()


# --- 壁 ---

## 四方の壁を生成
func _create_walls() -> void:
	var half_n: float = _map_half_size + WALL_MARGIN       # 北・東・西
	var half_s: float = _map_half_size + WALL_MARGIN_SOUTH  # 南（カメラ干渉回避のため広め）
	var center_x: float = _map_center.x
	var center_z: float = _map_center.z
	var wall_y: float = WALL_HEIGHT / 2.0
	var cap_mat: StandardMaterial3D = _create_cap_material()

	# 北壁 (Z-) — 東西の広い方に合わせる
	var ns_width: float = half_n * 2.0 + WALL_THICKNESS
	var ns_size: Vector3 = Vector3(ns_width, WALL_HEIGHT, WALL_THICKNESS)
	_create_single_wall("WallNorth", Vector3(center_x, wall_y, center_z - half_n), ns_size, _brick_material)
	_create_wall_cap("WallCapNorth", Vector3(center_x, WALL_HEIGHT, center_z - half_n),
		Vector3(ns_size.x + 0.2, 0.15, WALL_THICKNESS + 0.2), cap_mat)

	# 南壁 (Z+) — 同じ幅で南側マージン位置に配置
	_create_single_wall("WallSouth", Vector3(center_x, wall_y, center_z + half_s), ns_size, _brick_material)
	_create_wall_cap("WallCapSouth", Vector3(center_x, WALL_HEIGHT, center_z + half_s),
		Vector3(ns_size.x + 0.2, 0.15, WALL_THICKNESS + 0.2), cap_mat)

	# 東西壁は北端〜南端を繋ぐ（非対称）
	var ew_length: float = half_n + half_s + WALL_THICKNESS
	var ew_center_z: float = center_z + (half_s - half_n) / 2.0
	var ew_size: Vector3 = Vector3(WALL_THICKNESS, WALL_HEIGHT, ew_length)

	# 西壁 (X-) - 1枚壁 + 門を貼り付け
	_create_single_wall("WallWest", Vector3(center_x - half_n, wall_y, ew_center_z), ew_size, _brick_material)
	_create_wall_cap("WallCapWest", Vector3(center_x - half_n, WALL_HEIGHT, ew_center_z),
		Vector3(WALL_THICKNESS + 0.2, 0.15, ew_size.z + 0.2), cap_mat)
	var gate_offset: float = WALL_THICKNESS / 2.0 + GATE_THICKNESS / 2.0
	_create_gate("GateWest", Vector3(center_x - half_n + gate_offset, 0, center_z), true, false)

	# 東壁 (X+) - 1枚壁 + 門を貼り付け
	_create_single_wall("WallEast", Vector3(center_x + half_n, wall_y, ew_center_z), ew_size, _brick_material)
	_create_wall_cap("WallCapEast", Vector3(center_x + half_n, WALL_HEIGHT, ew_center_z),
		Vector3(WALL_THICKNESS + 0.2, 0.15, ew_size.z + 0.2), cap_mat)
	_create_gate("GateEast", Vector3(center_x + half_n - gate_offset, 0, center_z), true, true)

	# 胸壁（バトルメント）
	_create_battlements_north_south(center_x, center_z, half_n, half_s, cap_mat)
	_create_battlements_east_west(center_x, center_z, half_n, half_s, cap_mat)


## 重厚な門を生成（GLBモデル扉 + 装飾枠）
## is_ew: 東西壁の門（true）か南北壁の門（false）か
func _create_gate(gate_name: String, base_pos: Vector3, is_ew: bool, flip: bool = false) -> void:
	var gate_root: Node3D = Node3D.new()
	gate_root.name = gate_name
	gate_root.position = base_pos
	add_child(gate_root)

	var door_half: float = GATE_WIDTH / 2.0
	var arch_radius: float = 3.0
	var rect_h: float = GATE_HEIGHT - arch_radius

	# GLBモデルの扉を配置
	var door_scene: PackedScene = load("res://assets/models/gate_door.glb")
	if door_scene:
		var door_instance: Node3D = door_scene.instantiate()
		door_instance.name = "DoorModel"
		# モデルサイズ: 3.550 x 4.0 x 0.382 → GATE: 4.0 x 4.5 x 0.3
		var scale_x: float = GATE_WIDTH / 3.550
		var scale_y: float = GATE_HEIGHT / 4.0
		var scale_z: float = GATE_THICKNESS / 0.382
		door_instance.scale = Vector3(scale_x, scale_y, scale_z)
		if is_ew:
			door_instance.rotation.y = PI / 2.0
		if flip:
			door_instance.rotation.y += PI
		gate_root.add_child(door_instance)

	# アーチ枠（半円リング状のレンガ枠）
	var frame_thickness := 0.6
	var arch_frame: MeshInstance3D = MeshInstance3D.new()
	arch_frame.name = "ArchFrame"
	arch_frame.mesh = _create_arch_frame_mesh(arch_radius, frame_thickness, GATE_THICKNESS + 0.1, is_ew, door_half)
	arch_frame.position = Vector3(0, rect_h, 0)
	arch_frame.material_override = _brick_material
	gate_root.add_child(arch_frame)

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
func _create_single_wall(wall_name: String, pos: Vector3, wall_size: Vector3, mat: Material) -> void:
	var wall: MeshInstance3D = MeshInstance3D.new()
	wall.name = wall_name
	var box: BoxMesh = BoxMesh.new()
	box.size = wall_size
	wall.mesh = box
	wall.position = pos
	wall.material_override = mat
	add_child(wall)


## 壁の上の笠石（キャップストーン）を生成
func _create_wall_cap(cap_name: String, pos: Vector3, cap_size: Vector3, mat: Material) -> void:
	var cap: MeshInstance3D = MeshInstance3D.new()
	cap.name = cap_name
	var box: BoxMesh = BoxMesh.new()
	box.size = cap_size
	cap.mesh = box
	cap.position = pos
	cap.material_override = mat
	add_child(cap)


# --- 胸壁 ---

## 北壁・南壁の胸壁
func _create_battlements_north_south(cx: float, cz: float, half_n: float, half_s: float, cap_mat: Material) -> void:
	var step: float = BATTLEMENT_WIDTH + BATTLEMENT_GAP
	var start_x: float = cx - half_n
	var end_x: float = cx + half_n
	var top_y: float = WALL_HEIGHT + BATTLEMENT_HEIGHT / 2.0
	var cap_top_y: float = WALL_HEIGHT + BATTLEMENT_HEIGHT

	var z_data: Array[Dictionary] = [
		{"sign": -1.0, "half": half_n},
		{"sign": 1.0, "half": half_s},
	]
	for data in z_data:
		var z_pos: float = cz + data.half * data.sign
		var x: float = start_x
		var idx := 0
		while x < end_x:
			var bx: float = x + BATTLEMENT_WIDTH / 2.0
			var b: MeshInstance3D = MeshInstance3D.new()
			b.name = "BattlementNS_%d_%d" % [int(data.sign), idx]
			var b_mesh: BoxMesh = BoxMesh.new()
			b_mesh.size = Vector3(BATTLEMENT_WIDTH, BATTLEMENT_HEIGHT, WALL_THICKNESS + 0.3)
			b.mesh = b_mesh
			b.position = Vector3(bx, top_y, z_pos)
			b.material_override = _brick_material
			add_child(b)
			_create_wall_cap("BattCapNS_%d_%d" % [int(data.sign), idx],
				Vector3(bx, cap_top_y, z_pos),
				Vector3(BATTLEMENT_WIDTH + 0.1, 0.1, WALL_THICKNESS + 0.4), cap_mat)
			x += step
			idx += 1


## 東壁・西壁の胸壁
func _create_battlements_east_west(cx: float, cz: float, half_n: float, half_s: float, cap_mat: Material) -> void:
	var step: float = BATTLEMENT_WIDTH + BATTLEMENT_GAP
	var start_z: float = cz - half_n
	var end_z: float = cz + half_s
	var top_y: float = WALL_HEIGHT + BATTLEMENT_HEIGHT / 2.0
	var cap_top_y: float = WALL_HEIGHT + BATTLEMENT_HEIGHT

	for x_sign in [-1.0, 1.0]:
		var x_pos: float = cx + half_n * x_sign
		var z: float = start_z
		var idx := 0
		while z < end_z:
			var bz: float = z + BATTLEMENT_WIDTH / 2.0
			var b: MeshInstance3D = MeshInstance3D.new()
			b.name = "BattlementEW_%d_%d" % [int(x_sign), idx]
			var b_mesh: BoxMesh = BoxMesh.new()
			b_mesh.size = Vector3(WALL_THICKNESS + 0.3, BATTLEMENT_HEIGHT, BATTLEMENT_WIDTH)
			b.mesh = b_mesh
			b.position = Vector3(x_pos, top_y, bz)
			b.material_override = _brick_material
			add_child(b)
			_create_wall_cap("BattCapEW_%d_%d" % [int(x_sign), idx],
				Vector3(x_pos, cap_top_y, bz),
				Vector3(WALL_THICKNESS + 0.4, 0.1, BATTLEMENT_WIDTH + 0.1), cap_mat)
			z += step
			idx += 1


# --- 塔 ---

## 四隅の塔を生成
func _create_corner_towers() -> void:
	var half_n: float = _map_half_size + WALL_MARGIN
	var half_s: float = _map_half_size + WALL_MARGIN_SOUTH
	var cx: float = _map_center.x
	var cz: float = _map_center.z
	var tower_y: float = TOWER_HEIGHT / 2.0

	var tower_mat: ShaderMaterial = _create_tower_brick_material()

	var corners: Array[Vector3] = [
		Vector3(cx - half_n, tower_y, cz - half_n),
		Vector3(cx + half_n, tower_y, cz - half_n),
		Vector3(cx - half_n, tower_y, cz + half_s),
		Vector3(cx + half_n, tower_y, cz + half_s),
	]

	var roof_mat: StandardMaterial3D = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.3, 0.32, 0.35)
	roof_mat.roughness = 0.8

	for i in range(corners.size()):
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


# --- 松明（現在無効） ---

## 松明を壁面に配置
func _create_torches() -> void:
	var half: float = _map_half_size + WALL_MARGIN
	var cx: float = _map_center.x
	var cz: float = _map_center.z
	var torch_y := WALL_HEIGHT * 0.6
	var torch_spacing := 10.0

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
func _create_single_torch(pos: Vector3, idx: int) -> void:
	var torch_root: Node3D = Node3D.new()
	torch_root.name = "Torch_%d" % idx
	torch_root.position = pos
	add_child(torch_root)

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

	var cloth: MeshInstance3D = MeshInstance3D.new()
	cloth.name = "Wrap"
	var cloth_mesh: CylinderMesh = CylinderMesh.new()
	cloth_mesh.top_radius = 0.06
	cloth_mesh.bottom_radius = 0.05
	cloth_mesh.height = 0.15
	cloth.mesh = cloth_mesh
	cloth.position = Vector3(0, 0.12, 0)
	var cloth_mat: StandardMaterial3D = StandardMaterial3D.new()
	cloth_mat.albedo_color = Color(0.3, 0.18, 0.08)
	cloth_mat.roughness = 0.9
	cloth.material_override = cloth_mat
	torch_root.add_child(cloth)

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

	var light: OmniLight3D = OmniLight3D.new()
	light.name = "TorchLight"
	light.position = Vector3(0, 0.3, 0)
	light.light_color = Color(1.0, 0.7, 0.3)
	light.light_energy = 1.5
	light.omni_range = 14.0
	light.omni_attenuation = 1.0
	light.shadow_enabled = false
	torch_root.add_child(light)
	_torch_lights.append(light)
	_torch_flames.append(flame)


# --- 植生（VegetationBuilder に委譲） ---

func _create_ivy() -> void:
	var half_n: float = _map_half_size + WALL_MARGIN
	var half_s: float = _map_half_size + WALL_MARGIN_SOUTH
	var cx: float = _map_center.x
	var cz: float = _map_center.z

	var walls: Array[Dictionary] = [
		{"start": cx - half_n, "end": cx + half_n, "wall_pos": cz - half_n + WALL_THICKNESS * 0.5 + 0.05, "is_ns": true},
		{"start": cx - half_n, "end": cx + half_n, "wall_pos": cz + half_s - WALL_THICKNESS * 0.5 - 0.05, "is_ns": true},
		{"start": cz - half_n, "end": cz + half_s, "wall_pos": cx - half_n + WALL_THICKNESS * 0.5 + 0.05, "is_ns": false},
		{"start": cz - half_n, "end": cz + half_s, "wall_pos": cx + half_n - WALL_THICKNESS * 0.5 - 0.05, "is_ns": false},
	]

	# 下から伸びる蔦
	VegetationBuilder.create_ivy(self, walls, IVY_COUNT_PER_WALL,
		IVY_MIN_HEIGHT, IVY_MAX_HEIGHT, IVY_WIDTH_MIN, IVY_WIDTH_MAX)

	# 上から垂れ下がる蔦（胸壁の隙間からランダムに30%だけ）
	var step: float = BATTLEMENT_WIDTH + BATTLEMENT_GAP
	var gap_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	gap_rng.seed = 11223
	var gap_positions: Array[Dictionary] = []
	for wall in walls:
		var pos: float = wall.start
		while pos < wall.end:
			var gap_center: float = pos + BATTLEMENT_WIDTH + BATTLEMENT_GAP / 2.0
			if gap_center < wall.end and gap_rng.randf() < 0.3:
				gap_positions.append({
					"along": gap_center,
					"wall_pos": wall.wall_pos,
					"is_ns": wall.is_ns
				})
			pos += step
	VegetationBuilder.create_hanging_ivy_at_positions(self, gap_positions,
		WALL_HEIGHT, 2.0, 4.0, IVY_WIDTH_MIN * 0.5, IVY_WIDTH_MAX * 0.5)


func _create_grass() -> void:
	var half: float = _map_half_size + WALL_MARGIN_SOUTH  # 最大マージンで草を配置
	var tile_half: float = _map_half_size + 1.5
	VegetationBuilder.create_grass_patches(self, _map_center, half, tile_half,
		GRASS_PATCH_COUNT, GRASS_BLADE_HEIGHT, GRASS_BLADE_WIDTH)


# --- ArrayMesh生成 ---

## 半円リングメッシュ生成（アーチ枠用）
func _create_arch_frame_mesh(inner_radius: float, frame_w: float, depth: float, is_ew: bool, clip_half_w: float) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var segments := 24
	var outer_r: float = inner_radius + frame_w
	var half_d: float = depth / 2.0

	var start_angle := 0.0
	var end_angle := PI
	if clip_half_w > 0.0 and clip_half_w < inner_radius:
		var clip_angle: float = acos(clip_half_w / inner_radius)
		start_angle = clip_angle
		end_angle = PI - clip_angle

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


## 笠石（キャップストーン）用マテリアル
func _create_cap_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var tex = load("res://assets/building_parts/floor3_stone_ground_05_color.jpg") as Texture2D
	if tex:
		mat.albedo_texture = tex
		mat.albedo_color = Color(0.7, 0.68, 0.65)
		mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
		mat.uv1_triplanar = true
	else:
		mat.albedo_color = Color(0.55, 0.53, 0.50)
	mat.roughness = 0.85
	return mat

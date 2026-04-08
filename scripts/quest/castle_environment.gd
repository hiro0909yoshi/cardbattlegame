extends BaseEnvironment
class_name CastleEnvironment

## 城壁環境: GLBモデル配置 + 蔦・草を生成

# GLBモデルパス
const CASTLE_GLB_PATH := "res://assets/models/castle_wall.glb"

# 城壁パラメータ（蔦・草の配置に使用）
const WALL_MARGIN := 13.0
const WALL_MARGIN_SOUTH := 17.0
const WALL_HEIGHT := 9.0
const WALL_THICKNESS := 1.2
const BATTLEMENT_WIDTH := 1.5
const BATTLEMENT_GAP := 1.2

# 蔦パラメータ
const IVY_COUNT_PER_WALL := 5
const IVY_MIN_HEIGHT := 0.5
const IVY_MAX_HEIGHT := 5.0
const IVY_WIDTH_MIN := 1.5
const IVY_WIDTH_MAX := 3.5

# 草パラメータ
const GRASS_PATCH_COUNT := 30
const GRASS_BLADE_HEIGHT := 0.4
const GRASS_BLADE_WIDTH := 0.08

# [LEGACY] プロシージャル生成用（GLB移行後は未使用）
const BATTLEMENT_HEIGHT := 0.8
const TOWER_RADIUS := 2.0
const TOWER_HEIGHT := 11.0
const TOWER_SIDES := 12
const GATE_WIDTH := 5.5
const GATE_HEIGHT := 6.0
const GATE_THICKNESS := 0.3
const BRICK_SHADER_PATH := "res://assets/shaders/brick_wall.gdshader"
var _brick_material: ShaderMaterial


func _get_environment_margin() -> float:
	return WALL_MARGIN_SOUTH


func _build() -> void:
	if OS.has_feature("android"):
		_place_castle_glb()
	else:
		_brick_material = _create_brick_material()
		_create_ground()
		_create_castle_structure()
		_create_ivy()
		_create_grass()


## GLBモデルを配置（壁・塔・門・アーチ・胸壁・床を含む）
## GLBはMAP_HALF_SIZE=35基準（南+5）で作成済み（蔦なし・モバイル専用）
## 屋根=赤茶色、塔=暗色、床=ランダムUVタイリング
const GLB_BASE_HALF_SIZE := 35.0

func _place_castle_glb() -> void:
	var scene: PackedScene = load(CASTLE_GLB_PATH)
	if not scene:
		push_warning("castle_wall.glb が見つかりません: %s" % CASTLE_GLB_PATH)
		return
	var castle: Node3D = scene.instantiate()
	castle.name = "CastleWallGLB"
	castle.position = _map_center
	add_child(castle)


## [LEGACY] 壁・塔・門・胸壁を全てMultiMeshで一括生成（GLB移行前のコード）
func _create_castle_structure() -> void:
	var half_n: float = _map_half_size + WALL_MARGIN
	var half_s: float = _map_half_size + WALL_MARGIN_SOUTH
	var cx: float = _map_center.x
	var cz: float = _map_center.z
	var wall_y: float = WALL_HEIGHT / 2.0
	var cap_mat: StandardMaterial3D = _create_cap_material()
	var tower_mat: ShaderMaterial = _create_tower_brick_material()
	var roof_mat: StandardMaterial3D = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.3, 0.32, 0.35)
	roof_mat.roughness = 0.8

	var ns_width: float = half_n * 2.0 + WALL_THICKNESS
	var ew_length: float = half_n + half_s + WALL_THICKNESS
	var ew_center_z: float = cz + (half_s - half_n) / 2.0
	var gate_offset: float = WALL_THICKNESS / 2.0 + GATE_THICKNESS / 2.0
	var door_half: float = GATE_WIDTH / 2.0
	var pillar_w: float = 0.5
	var arch_radius: float = 3.0
	var frame_thickness: float = 0.6
	var rect_h: float = GATE_HEIGHT - arch_radius

	# ===== レンガBoxMesh（壁4 + 門柱4）→ 1 MultiMesh =====
	var brick_box_unit: BoxMesh = BoxMesh.new()
	brick_box_unit.size = Vector3(1, 1, 1)
	var brick_transforms: Array[Transform3D] = []
	# 北壁・南壁
	brick_transforms.append(Transform3D(Basis.from_scale(Vector3(ns_width, WALL_HEIGHT, WALL_THICKNESS)),
		Vector3(cx, wall_y, cz - half_n)))
	brick_transforms.append(Transform3D(Basis.from_scale(Vector3(ns_width, WALL_HEIGHT, WALL_THICKNESS)),
		Vector3(cx, wall_y, cz + half_s)))
	# 西壁・東壁
	brick_transforms.append(Transform3D(Basis.from_scale(Vector3(WALL_THICKNESS, WALL_HEIGHT, ew_length)),
		Vector3(cx - half_n, wall_y, ew_center_z)))
	brick_transforms.append(Transform3D(Basis.from_scale(Vector3(WALL_THICKNESS, WALL_HEIGHT, ew_length)),
		Vector3(cx + half_n, wall_y, ew_center_z)))
	# 門柱（西門2本 + 東門2本）
	var gate_x_west: float = cx - half_n + gate_offset
	var gate_x_east: float = cx + half_n - gate_offset
	for gx in [gate_x_west, gate_x_east]:
		for side in [-1.0, 1.0]:
			brick_transforms.append(Transform3D(
				Basis.from_scale(Vector3(GATE_THICKNESS + 0.15, GATE_HEIGHT + 0.5, pillar_w)),
				Vector3(gx, (GATE_HEIGHT + 0.5) / 2.0, cz + (door_half + pillar_w * 0.3) * side)))
	_build_multimesh("BrickWalls", brick_box_unit, brick_transforms, _brick_material)

	# ===== キャップBoxMesh（壁キャップ4 + 門柱キャップ4 + キーストーン2）→ 1 MultiMesh =====
	var cap_box_unit: BoxMesh = BoxMesh.new()
	cap_box_unit.size = Vector3(1, 1, 1)
	var cap_transforms: Array[Transform3D] = []
	# 壁キャップ（北・南）
	cap_transforms.append(Transform3D(Basis.from_scale(Vector3(ns_width + 0.2, 0.15, WALL_THICKNESS + 0.2)),
		Vector3(cx, WALL_HEIGHT, cz - half_n)))
	cap_transforms.append(Transform3D(Basis.from_scale(Vector3(ns_width + 0.2, 0.15, WALL_THICKNESS + 0.2)),
		Vector3(cx, WALL_HEIGHT, cz + half_s)))
	# 壁キャップ（西・東）
	cap_transforms.append(Transform3D(Basis.from_scale(Vector3(WALL_THICKNESS + 0.2, 0.15, ew_length + 0.2)),
		Vector3(cx - half_n, WALL_HEIGHT, ew_center_z)))
	cap_transforms.append(Transform3D(Basis.from_scale(Vector3(WALL_THICKNESS + 0.2, 0.15, ew_length + 0.2)),
		Vector3(cx + half_n, WALL_HEIGHT, ew_center_z)))
	# 門柱キャップ
	for gx in [gate_x_west, gate_x_east]:
		for side in [-1.0, 1.0]:
			cap_transforms.append(Transform3D(
				Basis.from_scale(Vector3(GATE_THICKNESS + 0.3, 0.15, 0.7)),
				Vector3(gx, GATE_HEIGHT + 0.5, cz + (door_half + 0.15) * side)))
	# キーストーン
	for gx in [gate_x_west, gate_x_east]:
		cap_transforms.append(Transform3D(
			Basis.from_scale(Vector3(GATE_THICKNESS + 0.15, 0.4, 0.35)),
			Vector3(gx, rect_h + arch_radius + frame_thickness * 0.5, cz)))
	_build_multimesh("CapStones", cap_box_unit, cap_transforms, cap_mat)

	# ===== 塔本体（4基）→ 1 MultiMesh =====
	var tower_mesh: CylinderMesh = CylinderMesh.new()
	tower_mesh.top_radius = TOWER_RADIUS
	tower_mesh.bottom_radius = TOWER_RADIUS
	tower_mesh.height = TOWER_HEIGHT
	tower_mesh.radial_segments = TOWER_SIDES
	var tower_y: float = TOWER_HEIGHT / 2.0
	var tower_transforms: Array[Transform3D] = []
	for corner in _get_corner_positions(cx, cz, half_n, half_s, tower_y):
		tower_transforms.append(Transform3D(Basis.IDENTITY, corner))
	_build_multimesh("TowerBodies", tower_mesh, tower_transforms, tower_mat)

	# ===== 塔トップ（4基）→ 1 MultiMesh =====
	var top_mesh: CylinderMesh = CylinderMesh.new()
	top_mesh.top_radius = TOWER_RADIUS + 0.4
	top_mesh.bottom_radius = TOWER_RADIUS + 0.4
	top_mesh.height = 0.6
	top_mesh.radial_segments = TOWER_SIDES
	var top_transforms: Array[Transform3D] = []
	for corner in _get_corner_positions(cx, cz, half_n, half_s, TOWER_HEIGHT + 0.3):
		top_transforms.append(Transform3D(Basis.IDENTITY, corner))
	_build_multimesh("TowerTops", top_mesh, top_transforms, tower_mat)

	# ===== 塔屋根（4基）→ 1 MultiMesh =====
	var roof_mesh: CylinderMesh = CylinderMesh.new()
	roof_mesh.top_radius = 0.01
	roof_mesh.bottom_radius = TOWER_RADIUS + 0.6
	roof_mesh.height = 3.0
	roof_mesh.radial_segments = TOWER_SIDES
	var roof_transforms: Array[Transform3D] = []
	for corner in _get_corner_positions(cx, cz, half_n, half_s, TOWER_HEIGHT + 0.6 + 1.5):
		roof_transforms.append(Transform3D(Basis.IDENTITY, corner))
	_build_multimesh("TowerRoofs", roof_mesh, roof_transforms, roof_mat)

	# ===== アーチ枠（2門）→ 1 MultiMesh =====
	var arch_mesh: ArrayMesh = _create_arch_frame_mesh(arch_radius, frame_thickness, GATE_THICKNESS + 0.1, true, door_half)
	var arch_transforms: Array[Transform3D] = []
	arch_transforms.append(Transform3D(Basis.IDENTITY, Vector3(gate_x_west, rect_h, cz)))
	arch_transforms.append(Transform3D(Basis.IDENTITY, Vector3(gate_x_east, rect_h, cz)))
	_build_multimesh("ArchFrames", arch_mesh, arch_transforms, _brick_material)

	# ===== 門扉GLB（2個、MultiMesh不可）=====
	_create_door_glb(Vector3(gate_x_west, 0, cz), false)
	_create_door_glb(Vector3(gate_x_east, 0, cz), true)

	# ===== 胸壁（既存MultiMesh方式を維持）=====
	_create_battlements(cx, cz, half_n, half_s, cap_mat)


## 四隅の座標を返すヘルパー
func _get_corner_positions(cx: float, cz: float, half_n: float, half_s: float, y: float) -> Array[Vector3]:
	return [
		Vector3(cx - half_n, y, cz - half_n),
		Vector3(cx + half_n, y, cz - half_n),
		Vector3(cx - half_n, y, cz + half_s),
		Vector3(cx + half_n, y, cz + half_s),
	]


## MultiMesh生成の共通ヘルパー
func _build_multimesh(mm_name: String, mesh: Mesh, transforms: Array[Transform3D], mat: Material) -> void:
	if transforms.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)


## 門扉GLBモデルを配置（MultiMesh不可のため個別）
func _create_door_glb(pos: Vector3, flip: bool) -> void:
	var door_scene: PackedScene = load("res://assets/models/gate_door.glb")
	if not door_scene:
		return
	var door: Node3D = door_scene.instantiate()
	door.name = "DoorModel"
	door.scale = Vector3(GATE_WIDTH / 3.550, GATE_HEIGHT / 4.0, GATE_THICKNESS / 0.382)
	door.position = pos
	door.rotation.y = PI / 2.0
	if flip:
		door.rotation.y += PI
	add_child(door)


# --- 胸壁 ---

## 全胸壁をMultiMeshInstance3Dで生成
func _create_battlements(cx: float, cz: float, half_n: float, half_s: float, cap_mat: Material) -> void:
	var step: float = BATTLEMENT_WIDTH + BATTLEMENT_GAP
	var top_y: float = WALL_HEIGHT + BATTLEMENT_HEIGHT / 2.0
	var cap_top_y: float = WALL_HEIGHT + BATTLEMENT_HEIGHT

	# NS胸壁（北・南）
	var ns_battlements: Array[Transform3D] = []
	var ns_caps: Array[Transform3D] = []
	var ns_start_x: float = cx - half_n
	var ns_end_x: float = cx + half_n

	var z_data: Array[Dictionary] = [
		{"sign": -1.0, "half": half_n},
		{"sign": 1.0, "half": half_s},
	]
	for data in z_data:
		var z_pos: float = cz + data.half * data.sign
		var x: float = ns_start_x
		while x < ns_end_x:
			var bx: float = x + BATTLEMENT_WIDTH / 2.0
			ns_battlements.append(Transform3D(Basis.IDENTITY, Vector3(bx, top_y, z_pos)))
			ns_caps.append(Transform3D(Basis.IDENTITY, Vector3(bx, cap_top_y, z_pos)))
			x += step

	# EW胸壁（東・西）
	var ew_battlements: Array[Transform3D] = []
	var ew_caps: Array[Transform3D] = []
	var ew_start_z: float = cz - half_n
	var ew_end_z: float = cz + half_s

	for x_sign in [-1.0, 1.0]:
		var x_pos: float = cx + half_n * x_sign
		var z: float = ew_start_z
		while z < ew_end_z:
			var bz: float = z + BATTLEMENT_WIDTH / 2.0
			ew_battlements.append(Transform3D(Basis.IDENTITY, Vector3(x_pos, top_y, bz)))
			ew_caps.append(Transform3D(Basis.IDENTITY, Vector3(x_pos, cap_top_y, bz)))
			z += step

	_build_multimesh("BattlementsNS",
		_create_box_mesh(Vector3(BATTLEMENT_WIDTH, BATTLEMENT_HEIGHT, WALL_THICKNESS + 0.3)),
		ns_battlements, _brick_material)
	_build_multimesh("BattlementCapsNS",
		_create_box_mesh(Vector3(BATTLEMENT_WIDTH + 0.1, 0.1, WALL_THICKNESS + 0.4)),
		ns_caps, cap_mat)
	_build_multimesh("BattlementsEW",
		_create_box_mesh(Vector3(WALL_THICKNESS + 0.3, BATTLEMENT_HEIGHT, BATTLEMENT_WIDTH)),
		ew_battlements, _brick_material)
	_build_multimesh("BattlementCapsEW",
		_create_box_mesh(Vector3(WALL_THICKNESS + 0.4, 0.1, BATTLEMENT_WIDTH + 0.1)),
		ew_caps, cap_mat)


## BoxMesh生成ヘルパー
func _create_box_mesh(box_size: Vector3) -> BoxMesh:
	var box: BoxMesh = BoxMesh.new()
	box.size = box_size
	return box


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
		GameLogger.error("Quest", "brick_wall.gdshader が見つかりません（パス: %s）" % BRICK_SHADER_PATH)
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

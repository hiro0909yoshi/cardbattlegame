extends RefCounted
class_name VegetationBuilder

## 植生（蔦・草）の生成を担当する共有ユーティリティ
## CastleEnvironment / WildernessEnvironment 等から利用する


# --- 草の生成 ---

## 地面に草を配置（MultiMeshInstance3D: 1ノード）
## exclude_half: この範囲内（マップタイル付近）には草を生成しない
static func create_grass_patches(
	parent: Node3D,
	map_center: Vector3,
	area_half: float,
	exclude_half: float,
	patch_count: int = 120,
	blade_height: float = 0.4,
	blade_width: float = 0.08
) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var cx: float = map_center.x
	var cz: float = map_center.z

	var transforms: Array[Transform3D] = []

	for _i in range(patch_count):
		var center := Vector3.ZERO
		var valid := false
		for _try in range(10):
			var px: float = rng.randf_range(cx - area_half + 1.0, cx + area_half - 1.0)
			var pz: float = rng.randf_range(cz - area_half + 1.0, cz + area_half - 1.0)
			if abs(px - cx) < exclude_half and abs(pz - cz) < exclude_half:
				continue
			center = Vector3(px, 0.0, pz)
			valid = true
			break
		if not valid:
			continue

		var dist_to_wall: float = min(
			abs(center.x - (cx - area_half)), abs(center.x - (cx + area_half)),
			abs(center.z - (cz - area_half)), abs(center.z - (cz + area_half))
		)
		var wall_proximity: float = 1.0 - clampf(dist_to_wall / (area_half * 2.0), 0.0, 1.0)
		var blade_count: int = rng.randi_range(3, 4) + int(wall_proximity * 5.0)

		for _j in range(blade_count):
			var offset := Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
			var h: float = blade_height * rng.randf_range(0.6, 1.4)
			var pos: Vector3 = center + offset + Vector3(0.0, h * 0.5, 0.0)
			var b_basis := Basis.IDENTITY.scaled(Vector3(blade_width, h, 1.0))
			b_basis = b_basis.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			b_basis = b_basis.rotated(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
			transforms.append(Transform3D(b_basis, pos))

	if transforms.is_empty():
		return

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = create_grass_blade_mesh()
	mm.instance_count = transforms.size()
	var color_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	color_rng.seed = 77777
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		var g: float = color_rng.randf_range(0.35, 0.55)
		mm.set_instance_color(i, Color(g * 0.4, g, g * 0.2))

	var mm_inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm_inst.name = "GrassPatches"
	mm_inst.multimesh = mm
	mm_inst.material_override = _create_vertex_color_material()
	parent.add_child(mm_inst)


# --- 蔦の生成 ---

## 壁面に蔦を生成（MultiMeshInstance3D: 葉1ノード + 茎1ノード）
static func create_ivy(
	parent: Node3D,
	walls: Array[Dictionary],
	ivy_count_per_wall: int = 5,
	ivy_min_height: float = 0.5,
	ivy_max_height: float = 3.5,
	ivy_width_min: float = 1.5,
	ivy_width_max: float = 3.5
) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 54321

	var leaf_transforms: Array[Transform3D] = []
	var stem_transforms: Array[Transform3D] = []

	for wall in walls:
		for _i in range(ivy_count_per_wall):
			var along: float = rng.randf_range(wall.start + 2.0, wall.end - 2.0)
			var ivy_h: float = rng.randf_range(ivy_min_height, ivy_max_height)
			var ivy_w: float = rng.randf_range(ivy_width_min, ivy_width_max)
			var grow_lean: float = rng.randf_range(-0.6, 0.6)

			var seg_count: int = int(ivy_h / 0.4) + 1
			var seg_h: float = ivy_h / float(seg_count)
			var drift := 0.0
			var stem_path: Array[Vector2] = []
			stem_path.append(Vector2(0.0, 0.0))
			for si in range(seg_count):
				drift += grow_lean * 0.15 + rng.randf_range(-0.25, 0.25)
				drift = clampf(drift, -ivy_w * 0.4, ivy_w * 0.4)
				var seg_y: float = seg_h * (float(si) + 0.5)
				var prev_drift: float = stem_path[stem_path.size() - 1].y
				var tilt: float = atan2(drift - prev_drift, seg_h)
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

			var leaf_count: int = int(ivy_h * 3.0)
			for _j in range(leaf_count):
				var leaf_y: float = rng.randf_range(0.2, ivy_h)
				var stem_drift := 0.0
				for pi in range(stem_path.size() - 1):
					if leaf_y >= stem_path[pi].x and leaf_y <= stem_path[pi + 1].x:
						var t: float = (leaf_y - stem_path[pi].x) / maxf(stem_path[pi + 1].x - stem_path[pi].x, 0.01)
						stem_drift = lerpf(stem_path[pi].y, stem_path[pi + 1].y, t)
						break
					elif pi == stem_path.size() - 2:
						stem_drift = stem_path[pi + 1].y
				var leaf_offset: float = stem_drift + rng.randf_range(-0.3, 0.3)
				var leaf_size: float = rng.randf_range(0.25, 0.50)
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

	# 葉の MultiMesh
	if not leaf_transforms.is_empty():
		var leaf_mm: MultiMesh = MultiMesh.new()
		leaf_mm.transform_format = MultiMesh.TRANSFORM_3D
		leaf_mm.use_colors = true
		leaf_mm.mesh = create_heart_leaf_mesh()
		leaf_mm.instance_count = leaf_transforms.size()
		var color_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		color_rng.seed = 99999
		for i in range(leaf_transforms.size()):
			leaf_mm.set_instance_transform(i, leaf_transforms[i])
			var g: float = color_rng.randf_range(0.25, 0.45)
			var r: float = color_rng.randf_range(0.12, 0.22)
			leaf_mm.set_instance_color(i, Color(r, g, r * 0.5))
		var leaf_inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
		leaf_inst.name = "IvyLeaves"
		leaf_inst.multimesh = leaf_mm
		leaf_inst.material_override = _create_vertex_color_material()
		parent.add_child(leaf_inst)

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
		parent.add_child(stem_inst)


## 胸壁の隙間から垂れ下がる蔦を生成（位置指定版）
static func create_hanging_ivy_at_positions(
	parent: Node3D,
	positions: Array[Dictionary],  # {along, wall_pos, is_ns}
	wall_height: float = 8.0,
	ivy_min_length: float = 2.0,
	ivy_max_length: float = 4.0,
	ivy_width_min: float = 0.5,
	ivy_width_max: float = 1.5
) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 76543

	var leaf_transforms: Array[Transform3D] = []
	var stem_transforms: Array[Transform3D] = []

	for pos_data in positions:
		var along: float = pos_data.along
		var wall_pos: float = pos_data.wall_pos
		var is_ns: bool = pos_data.is_ns
		var ivy_len: float = rng.randf_range(ivy_min_length, ivy_max_length)
		var ivy_w: float = rng.randf_range(ivy_width_min, ivy_width_max)
		var grow_lean: float = rng.randf_range(-0.4, 0.4)

		var seg_count: int = int(ivy_len / 0.4) + 1
		var seg_h: float = ivy_len / float(seg_count)
		var drift := 0.0
		var stem_path: Array[Vector2] = []
		stem_path.append(Vector2(0.0, 0.0))
		for si in range(seg_count):
			drift += grow_lean * 0.15 + rng.randf_range(-0.2, 0.2)
			drift = clampf(drift, -ivy_w * 0.4, ivy_w * 0.4)
			var seg_y: float = wall_height - seg_h * (float(si) + 0.5)
			var prev_drift: float = stem_path[stem_path.size() - 1].y
			var tilt: float = atan2(drift - prev_drift, seg_h)
			stem_path.append(Vector2(seg_h * (float(si) + 1.0), drift))
			var seg_basis := Basis.IDENTITY.scaled(Vector3(0.05, seg_h, 0.02))
			var seg_pos: Vector3
			if is_ns:
				seg_basis = seg_basis.rotated(Vector3.FORWARD, tilt)
				seg_pos = Vector3(along + drift, seg_y, wall_pos)
			else:
				seg_basis = seg_basis.rotated(Vector3.UP, deg_to_rad(90))
				seg_basis = seg_basis.rotated(Vector3.RIGHT, tilt)
				seg_pos = Vector3(wall_pos, seg_y, along + drift)
			stem_transforms.append(Transform3D(seg_basis, seg_pos))

		var leaf_count: int = int(ivy_len * 3.0)
		for _j in range(leaf_count):
			var leaf_dist: float = rng.randf_range(0.2, ivy_len)
			var leaf_y: float = wall_height - leaf_dist
			var stem_drift := 0.0
			for pi in range(stem_path.size() - 1):
				if leaf_dist >= stem_path[pi].x and leaf_dist <= stem_path[pi + 1].x:
					var t: float = (leaf_dist - stem_path[pi].x) / maxf(stem_path[pi + 1].x - stem_path[pi].x, 0.01)
					stem_drift = lerpf(stem_path[pi].y, stem_path[pi + 1].y, t)
					break
				elif pi == stem_path.size() - 2:
					stem_drift = stem_path[pi + 1].y
			var leaf_offset: float = stem_drift + rng.randf_range(-0.2, 0.2)
			var leaf_size: float = rng.randf_range(0.2, 0.4)
			var leaf_pos: Vector3
			var leaf_basis := Basis.IDENTITY.scaled(Vector3(leaf_size, leaf_size, 1.0))
			leaf_basis = leaf_basis.rotated(Vector3.FORWARD, rng.randf_range(-0.5, 0.5))
			leaf_basis = leaf_basis.rotated(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
			if is_ns:
				leaf_pos = Vector3(along + leaf_offset, leaf_y, wall_pos)
			else:
				leaf_pos = Vector3(wall_pos, leaf_y, along + leaf_offset)
				leaf_basis = leaf_basis.rotated(Vector3.UP, deg_to_rad(90))
			leaf_transforms.append(Transform3D(leaf_basis, leaf_pos))

	if not leaf_transforms.is_empty():
		var leaf_mm: MultiMesh = MultiMesh.new()
		leaf_mm.transform_format = MultiMesh.TRANSFORM_3D
		leaf_mm.use_colors = true
		leaf_mm.mesh = create_heart_leaf_mesh()
		leaf_mm.instance_count = leaf_transforms.size()
		var color_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		color_rng.seed = 88888
		for i in range(leaf_transforms.size()):
			leaf_mm.set_instance_transform(i, leaf_transforms[i])
			var g: float = color_rng.randf_range(0.25, 0.45)
			var r: float = color_rng.randf_range(0.12, 0.22)
			leaf_mm.set_instance_color(i, Color(r, g, r * 0.5))
		var leaf_inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
		leaf_inst.name = "HangingIvyLeaves"
		leaf_inst.multimesh = leaf_mm
		leaf_inst.material_override = _create_vertex_color_material()
		parent.add_child(leaf_inst)

	if not stem_transforms.is_empty():
		var stem_mm: MultiMesh = MultiMesh.new()
		stem_mm.transform_format = MultiMesh.TRANSFORM_3D
		stem_mm.mesh = BoxMesh.new()
		stem_mm.instance_count = stem_transforms.size()
		for i in range(stem_transforms.size()):
			stem_mm.set_instance_transform(i, stem_transforms[i])
		var stem_inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
		stem_inst.name = "HangingIvyStems"
		stem_inst.multimesh = stem_mm
		var stem_mat: StandardMaterial3D = StandardMaterial3D.new()
		stem_mat.albedo_color = Color(0.18, 0.28, 0.10)
		stem_inst.material_override = stem_mat
		parent.add_child(stem_inst)


## 壁上部から垂れ下がる蔦を生成（ランダム位置版、未使用）
static func create_hanging_ivy(
	parent: Node3D,
	walls: Array[Dictionary],
	ivy_count_per_wall: int = 3,
	wall_height: float = 8.0,
	ivy_min_length: float = 2.0,
	ivy_max_length: float = 4.0,
	ivy_width_min: float = 1.5,
	ivy_width_max: float = 3.5
) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 67890

	var leaf_transforms: Array[Transform3D] = []
	var stem_transforms: Array[Transform3D] = []

	for wall in walls:
		for _i in range(ivy_count_per_wall):
			var along: float = rng.randf_range(wall.start + 2.0, wall.end - 2.0)
			var ivy_len: float = rng.randf_range(ivy_min_length, ivy_max_length)
			var ivy_w: float = rng.randf_range(ivy_width_min, ivy_width_max)
			var grow_lean: float = rng.randf_range(-0.6, 0.6)

			var seg_count: int = int(ivy_len / 0.4) + 1
			var seg_h: float = ivy_len / float(seg_count)
			var drift := 0.0
			var stem_path: Array[Vector2] = []
			stem_path.append(Vector2(0.0, 0.0))
			for si in range(seg_count):
				drift += grow_lean * 0.15 + rng.randf_range(-0.25, 0.25)
				drift = clampf(drift, -ivy_w * 0.4, ivy_w * 0.4)
				# 上から下に伸びる（wall_heightから下降）
				var seg_y: float = wall_height - seg_h * (float(si) + 0.5)
				var prev_drift: float = stem_path[stem_path.size() - 1].y
				var tilt: float = atan2(drift - prev_drift, seg_h)
				stem_path.append(Vector2(wall_height - seg_y, drift))
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

			var leaf_count: int = int(ivy_len * 3.0)
			for _j in range(leaf_count):
				var leaf_dist: float = rng.randf_range(0.2, ivy_len)
				var leaf_y: float = wall_height - leaf_dist
				var stem_drift := 0.0
				for pi in range(stem_path.size() - 1):
					if leaf_dist >= stem_path[pi].x and leaf_dist <= stem_path[pi + 1].x:
						var t: float = (leaf_dist - stem_path[pi].x) / maxf(stem_path[pi + 1].x - stem_path[pi].x, 0.01)
						stem_drift = lerpf(stem_path[pi].y, stem_path[pi + 1].y, t)
						break
					elif pi == stem_path.size() - 2:
						stem_drift = stem_path[pi + 1].y
				var leaf_offset: float = stem_drift + rng.randf_range(-0.3, 0.3)
				var leaf_size: float = rng.randf_range(0.25, 0.50)
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

	# 葉の MultiMesh
	if not leaf_transforms.is_empty():
		var leaf_mm: MultiMesh = MultiMesh.new()
		leaf_mm.transform_format = MultiMesh.TRANSFORM_3D
		leaf_mm.use_colors = true
		leaf_mm.mesh = create_heart_leaf_mesh()
		leaf_mm.instance_count = leaf_transforms.size()
		var color_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		color_rng.seed = 88888
		for i in range(leaf_transforms.size()):
			leaf_mm.set_instance_transform(i, leaf_transforms[i])
			var g: float = color_rng.randf_range(0.25, 0.45)
			var r: float = color_rng.randf_range(0.12, 0.22)
			leaf_mm.set_instance_color(i, Color(r, g, r * 0.5))
		var leaf_inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
		leaf_inst.name = "HangingIvyLeaves"
		leaf_inst.multimesh = leaf_mm
		leaf_inst.material_override = _create_vertex_color_material()
		parent.add_child(leaf_inst)

	# 茎の MultiMesh
	if not stem_transforms.is_empty():
		var stem_mm: MultiMesh = MultiMesh.new()
		stem_mm.transform_format = MultiMesh.TRANSFORM_3D
		stem_mm.mesh = BoxMesh.new()
		stem_mm.instance_count = stem_transforms.size()
		for i in range(stem_transforms.size()):
			stem_mm.set_instance_transform(i, stem_transforms[i])
		var stem_inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
		stem_inst.name = "HangingIvyStems"
		stem_inst.multimesh = stem_mm
		var stem_mat: StandardMaterial3D = StandardMaterial3D.new()
		stem_mat.albedo_color = Color(0.18, 0.28, 0.10)
		stem_inst.material_override = stem_mat
		parent.add_child(stem_inst)


# --- メッシュ生成 ---

## 草の葉メッシュ生成（根元から上がって先端が垂れ下がる弧状）
static func create_grass_blade_mesh() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var segments := 5
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var w: float = lerpf(0.5, 0.02, t)
		var y: float = -0.5 + t * 1.2 - t * t * 0.8
		var z: float = t * t * 0.3
		verts.append(Vector3(-w, y, z))
		verts.append(Vector3(w, y, z))
		normals.append(Vector3(0.0, 0.0, 1.0))
		normals.append(Vector3(0.0, 0.0, 1.0))
		uvs.append(Vector2(0.0, 1.0 - t))
		uvs.append(Vector2(1.0, 1.0 - t))

	for i in range(segments):
		var base: int = i * 2
		indices.append_array([base, base + 1, base + 2])
		indices.append_array([base + 1, base + 3, base + 2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## ハート型の蔦の葉メッシュ生成
static func create_heart_leaf_mesh() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var points: Array[Vector2] = []
	points.append(Vector2(0.0, -0.5))

	var seg := 8
	for i in range(seg + 1):
		var t: float = float(i) / float(seg)
		var angle: float = PI * 0.1 + t * PI * 0.9
		var r := 0.28
		var cx_r := 0.22
		var cy := 0.15
		var px: float = cx_r + r * cos(angle)
		var py: float = cy + r * sin(angle)
		points.append(Vector2(px, py))

	for i in range(seg, -1, -1):
		var t: float = float(i) / float(seg)
		var angle: float = PI * 0.1 + t * PI * 0.9
		var r := 0.28
		var cx_l := -0.22
		var cy := 0.15
		var px: float = cx_l - r * cos(angle)
		var py: float = cy + r * sin(angle)
		points.append(Vector2(px, py))

	var center := Vector2(0.0, 0.05)
	verts.append(Vector3(center.x, center.y, 0.0))
	uvs.append(Vector2(center.x + 0.5, 0.5 - center.y))

	for p in points:
		verts.append(Vector3(p.x, p.y, 0.0))
		uvs.append(Vector2(p.x + 0.5, 0.5 - p.y))

	var count: int = points.size()
	for i in range(count):
		indices.append(0)
		indices.append(1 + i)
		indices.append(1 + (i + 1) % count)

	var normals := PackedVector3Array()
	for _i in range(verts.size()):
		normals.append(Vector3(0.0, 0.0, -1.0))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- マテリアル ---

## 頂点カラーマテリアル（草・蔦共用）
static func _create_vertex_color_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

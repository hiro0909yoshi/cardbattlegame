extends RefCounted
class_name CardMarkGenerator

## カードマーク生成ユーティリティ
## CardBuy / CardGive タイル上にカード枠線 + 三日月紋章を配置する

const CARD_WIDTH := 2.2
const CARD_HEIGHT := 3.0
const LINE_WIDTH := 0.12
const LINE_HEIGHT := 0.08  # 枠の厚み（立体感）
const MOON_RADIUS := 0.55


## カードマーク全体を生成してparentに追加
static func create_card_mark(parent: Node3D, mark_color: Color, y_offset: float = 0.33) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = mark_color
	mat.roughness = 0.3
	mat.metallic = 0.4

	# カード枠線（外枠）
	var outline := MeshInstance3D.new()
	outline.name = "CardOutline"
	outline.mesh = _build_card_frame()
	outline.position.y = y_offset
	outline.material_override = mat
	parent.add_child(outline)

	# カード枠線（内枠、少し小さく）
	var inner_mat := StandardMaterial3D.new()
	inner_mat.albedo_color = mark_color * 0.8
	inner_mat.roughness = 0.3
	inner_mat.metallic = 0.4
	var inner := MeshInstance3D.new()
	inner.name = "CardInnerLine"
	inner.mesh = _build_inner_frame()
	inner.position.y = y_offset
	inner.material_override = inner_mat
	parent.add_child(inner)

	# 三日月紋章
	var moon := MeshInstance3D.new()
	moon.name = "MoonCrest"
	moon.mesh = _build_crescent_moon(MOON_RADIUS)
	moon.position.y = y_offset + LINE_HEIGHT + 0.005
	moon.material_override = mat
	parent.add_child(moon)


## カード外枠メッシュ（3Dボックスストリップで立体的に）
static func _build_card_frame() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var hw := CARD_WIDTH / 2.0
	var hh := CARD_HEIGHT / 2.0
	var lw := LINE_WIDTH
	var lh := LINE_HEIGHT

	# 4辺を立体ボックスで生成
	_add_box_strip(verts, normals, indices, Vector3(-hw, 0, hh - lw / 2.0), Vector3(CARD_WIDTH, lh, lw))
	_add_box_strip(verts, normals, indices, Vector3(-hw, 0, -hh + lw / 2.0), Vector3(CARD_WIDTH, lh, lw))
	_add_box_strip(verts, normals, indices, Vector3(-hw + lw / 2.0, 0, -hh), Vector3(lw, lh, CARD_HEIGHT))
	_add_box_strip(verts, normals, indices, Vector3(hw - lw / 2.0, 0, -hh), Vector3(lw, lh, CARD_HEIGHT))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## カード内枠メッシュ（外枠より少し小さい装飾線）
static func _build_inner_frame() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var margin := 0.2
	var hw := CARD_WIDTH / 2.0 - margin
	var hh := CARD_HEIGHT / 2.0 - margin
	var lw := LINE_WIDTH * 0.6
	var lh := LINE_HEIGHT * 0.6

	_add_box_strip(verts, normals, indices, Vector3(-hw, 0, hh - lw / 2.0), Vector3(hw * 2.0, lh, lw))
	_add_box_strip(verts, normals, indices, Vector3(-hw, 0, -hh + lw / 2.0), Vector3(hw * 2.0, lh, lw))
	_add_box_strip(verts, normals, indices, Vector3(-hw + lw / 2.0, 0, -hh), Vector3(lw, lh, hh * 2.0))
	_add_box_strip(verts, normals, indices, Vector3(hw - lw / 2.0, 0, -hh), Vector3(lw, lh, hh * 2.0))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 三日月紋章メッシュ生成
static func _build_crescent_moon(radius: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var outer_r := radius
	var inner_r := radius * 0.82
	var offset := radius * 0.5
	var segments := 32

	# 外円(0,0)と内円(offset,0)の交点を計算
	var x_int := (offset * offset + outer_r * outer_r - inner_r * inner_r) / (2.0 * offset)
	var y_sq := outer_r * outer_r - x_int * x_int
	if y_sq < 0:
		return mesh
	var y_int := sqrt(y_sq)

	# 各円での交点角度
	var outer_angle := atan2(y_int, x_int)
	var inner_angle := atan2(y_int, x_int - offset)

	# 三日月の境界点を生成
	var boundary: Array[Vector2] = []

	# 外円弧（交点1→左側を通って→交点2）
	var outer_span := TAU - 2.0 * outer_angle
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var a := outer_angle + t * outer_span
		boundary.append(Vector2(cos(a) * outer_r, sin(a) * outer_r))

	# 内円弧（交点2→左側を通って→交点1、逆方向）
	var inner_span := TAU - 2.0 * inner_angle
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var a := (TAU - inner_angle) - t * inner_span
		boundary.append(Vector2(offset + cos(a) * inner_r, sin(a) * inner_r))

	if boundary.is_empty():
		return mesh

	# 重心を計算
	var cx := 0.0
	var cz := 0.0
	for p in boundary:
		cx += p.x
		cz += p.y
	cx /= boundary.size()
	cz /= boundary.size()

	# X座標を反転して右向きの三日月にする
	verts.append(Vector3(-cx, 0, cz))
	normals.append(Vector3.UP)

	for p in boundary:
		verts.append(Vector3(-p.x, 0, p.y))
		normals.append(Vector3.UP)

	# ファン三角形
	var count := boundary.size()
	for i in range(count):
		indices.append(0)
		indices.append(1 + i)
		indices.append(1 + (i + 1) % count)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 立体ボックスストリップ（上面 + 4側面）
## origin: 左下手前の角、size: (幅X, 高さY, 奥行Z)
static func _add_box_strip(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	origin: Vector3, size: Vector3
) -> void:
	var x0 := origin.x
	var y0 := origin.y
	var z0 := origin.z
	var x1 := origin.x + size.x
	var y1 := origin.y + size.y
	var z1 := origin.z + size.z

	# 上面（Y+）
	_add_face(verts, normals, indices,
		Vector3(x0, y1, z0), Vector3(x1, y1, z0),
		Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP)
	# 前面（Z+）
	_add_face(verts, normals, indices,
		Vector3(x0, y0, z1), Vector3(x1, y0, z1),
		Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(0, 0, 1))
	# 背面（Z-）
	_add_face(verts, normals, indices,
		Vector3(x1, y0, z0), Vector3(x0, y0, z0),
		Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(0, 0, -1))
	# 左面（X-）
	_add_face(verts, normals, indices,
		Vector3(x0, y0, z0), Vector3(x0, y0, z1),
		Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(-1, 0, 0))
	# 右面（X+）
	_add_face(verts, normals, indices,
		Vector3(x1, y0, z1), Vector3(x1, y0, z0),
		Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(1, 0, 0))


## 4頂点の面を追加
static func _add_face(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
	normal: Vector3
) -> void:
	var idx := verts.size()
	verts.append(v0)
	verts.append(v1)
	verts.append(v2)
	verts.append(v3)
	for _i in range(4):
		normals.append(normal)
	indices.append_array([idx, idx + 1, idx + 2, idx, idx + 2, idx + 3])

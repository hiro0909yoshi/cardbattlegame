extends BaseTile

## ワープタイル（通過型）- 魔法陣 + 発光 + 浮遊パーティクル + 光の帯

const WARP_COLOR := Color(0.533, 0.078, 1.0)
const MAGIC_CIRCLE_RADIUS := 1.6
const PARTICLE_COUNT := 12
const PARTICLE_HEIGHT := 3.5
const LIGHT_BEAM_COUNT := 14
const LIGHT_BEAM_HEIGHT := 2.0

var _magic_circle: MeshInstance3D
var _particles: Array[MeshInstance3D] = []
var _particle_mats: Array[StandardMaterial3D] = []
var _light_beams: Array[MeshInstance3D] = []
var _light_beam_mats: Array[StandardMaterial3D] = []
var _time := 0.0


func _ready():
	tile_type = "warp"
	super._ready()
	_setup_emission()
	_create_magic_circle()
	_create_particles()
	_create_light_beams()
	# BaseTile._ready()でset_process(false)されるため、再有効化
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	# 魔法陣回転
	if _magic_circle:
		_magic_circle.rotation.y = _time * 1.5
	# パーティクル浮遊（不規則な動き）
	for i in range(_particles.size()):
		var p := _particles[i]
		var phase := (float(i) / float(PARTICLE_COUNT)) * TAU
		# 各パーティクルごとに速度を変えて不規則に
		var speed := 0.35 + float(i % 3) * 0.15
		var t := fmod(_time * speed + phase / TAU, 1.0)
		p.position.y = 0.5 + t * PARTICLE_HEIGHT
		# 上昇でフェードアウト
		var alpha := 1.0 - t
		if _particle_mats.size() > i:
			_particle_mats[i].albedo_color.a = alpha * 0.9
		# 不規則な横揺れ（複数のsin波を重ねる）
		var sway_x := sin(_time * 1.8 + phase) * 0.4 + sin(_time * 3.1 + phase * 1.7) * 0.15
		var sway_z := cos(_time * 2.2 + phase * 0.8) * 0.4 + cos(_time * 2.7 + phase * 1.3) * 0.15
		var base_r := 0.6 + float(i % 4) * 0.2
		p.position.x = cos(phase) * base_r + sway_x
		p.position.z = sin(phase) * base_r + sway_z
	# 光の帯アニメーション（不規則な明滅、完全消灯あり）
	for i in range(_light_beams.size()):
		var beam := _light_beams[i]
		var phase := (float(i) / float(LIGHT_BEAM_COUNT)) * TAU
		var angle := _time * 0.6 + phase
		var v_z: float = 0.0
		if i < 14:
			var variations: Array[float] = [0.0, 0.1, -0.1, 0.15, -0.05, 0.2, -0.15, 0.1, 0.0, -0.1, 0.18, -0.08, 0.05, -0.12]
			v_z = variations[i]
		var radius := MAGIC_CIRCLE_RADIUS * 0.7 + v_z
		beam.position.x = cos(angle) * radius
		beam.position.z = sin(angle) * radius
		beam.rotation.y = angle
		# 不規則な明滅（完全消灯～強発光）
		var f1 := sin(_time * 1.8 + phase * 3.0)
		var f2 := sin(_time * 3.3 + phase * 1.7)
		var f3 := sin(_time * 5.9 + phase * 2.3)
		var f4 := sin(_time * 0.7 + phase * 4.1)
		var flicker := (f1 + f2 + f3 + f4) / 4.0
		# -1～1を0～1に変換し、コントラストを強める（pow）
		var pulse := pow(clampf((flicker + 1.0) / 2.0, 0.0, 1.0), 2.0)
		if _light_beam_mats.size() > i:
			_light_beam_mats[i].albedo_color.a = pulse * 0.45
			_light_beam_mats[i].emission_energy_multiplier = pulse * 5.0
			beam.visible = pulse > 0.02


## タイルメッシュに発光を追加
func _setup_emission() -> void:
	var mesh_inst := get_node_or_null("MeshInstance3D")
	if not mesh_inst:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WARP_COLOR
	mat.emission_enabled = true
	mat.emission = WARP_COLOR
	mat.emission_energy_multiplier = 1.0
	mesh_inst.material_override = mat


## 回転する魔法陣を作成
func _create_magic_circle() -> void:
	_magic_circle = MeshInstance3D.new()
	_magic_circle.name = "MagicCircle"

	var mesh := _build_circle_ring_mesh(MAGIC_CIRCLE_RADIUS, MAGIC_CIRCLE_RADIUS * 0.65, 32)
	_magic_circle.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(WARP_COLOR, 0.6)
	mat.emission_enabled = true
	mat.emission = WARP_COLOR
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	_magic_circle.material_override = mat
	_magic_circle.position = Vector3(0, 0.4, 0)
	add_child(_magic_circle)

	# 内側の小さいリング（逆回転用）
	var inner_circle := MeshInstance3D.new()
	inner_circle.name = "InnerCircle"
	var inner_mesh := _build_circle_ring_mesh(MAGIC_CIRCLE_RADIUS * 0.55, MAGIC_CIRCLE_RADIUS * 0.35, 24)
	inner_circle.mesh = inner_mesh
	var inner_mat := StandardMaterial3D.new()
	inner_mat.albedo_color = Color(0.7, 0.5, 1.0, 0.4)
	inner_mat.emission_enabled = true
	inner_mat.emission = Color(0.7, 0.5, 1.0)
	inner_mat.emission_energy_multiplier = 1.5
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inner_mat.no_depth_test = true
	inner_circle.material_override = inner_mat
	inner_circle.position = Vector3.ZERO
	_magic_circle.add_child(inner_circle)


## 浮遊パーティクルを作成（小さめ＋黄色寄り）
func _create_particles() -> void:
	for i in range(PARTICLE_COUNT):
		var p := MeshInstance3D.new()
		p.name = "WarpParticle_%d" % i
		var sphere := SphereMesh.new()
		sphere.radius = 0.035
		sphere.height = 0.07
		sphere.radial_segments = 4
		sphere.rings = 2
		p.mesh = sphere

		var mat := StandardMaterial3D.new()
		# 黄色寄りの色味（より小さく強発光）
		mat.albedo_color = Color(1.0, 0.9, 0.5, 0.9)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.35)
		mat.emission_energy_multiplier = 6.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		p.material_override = mat

		var phase := (float(i) / float(PARTICLE_COUNT)) * TAU
		p.position = Vector3(cos(phase) * 1.0, 0.5, sin(phase) * 1.0)
		add_child(p)
		_particles.append(p)
		_particle_mats.append(mat)


## 光の帯（縦方向のビーム）をサイズ違いで作成
func _create_light_beams() -> void:
	# 各ビームのバリエーション [高さ倍率, 太さ倍率, 半径オフセット]
	var variations: Array[Vector3] = [
		Vector3(1.0, 1.0, 0.0), Vector3(0.5, 0.7, 0.1), Vector3(1.3, 1.2, -0.1),
		Vector3(0.7, 0.8, 0.15), Vector3(1.1, 0.6, -0.05), Vector3(0.4, 1.0, 0.2),
		Vector3(1.5, 0.9, -0.15), Vector3(0.6, 0.5, 0.1), Vector3(0.9, 1.1, 0.0),
		Vector3(1.2, 0.7, -0.1), Vector3(0.35, 0.6, 0.18), Vector3(0.8, 1.3, -0.08),
		Vector3(1.4, 0.8, 0.05), Vector3(0.55, 0.9, -0.12),
	]
	for i in range(LIGHT_BEAM_COUNT):
		var beam := MeshInstance3D.new()
		beam.name = "LightBeam_%d" % i

		var v := variations[i % variations.size()]
		var h := LIGHT_BEAM_HEIGHT * v.x
		var r := 0.04 * v.y

		var cylinder := CylinderMesh.new()
		cylinder.top_radius = r * 0.5
		cylinder.bottom_radius = r
		cylinder.height = h
		cylinder.radial_segments = 6
		cylinder.rings = 1
		beam.mesh = cylinder

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.4, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.3)
		mat.emission_energy_multiplier = 3.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		beam.material_override = mat

		var phase := (float(i) / float(LIGHT_BEAM_COUNT)) * TAU
		var radius := MAGIC_CIRCLE_RADIUS * 0.7 + v.z
		beam.position = Vector3(cos(phase) * radius, h / 2.0 + 0.3, sin(phase) * radius)
		add_child(beam)
		_light_beams.append(beam)
		_light_beam_mats.append(mat)


## 円形リングメッシュを生成
func _build_circle_ring_mesh(outer_r: float, inner_r: float, segments: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for i in range(segments + 1):
		var angle := (float(i) / float(segments)) * TAU
		var cos_a := cos(angle)
		var sin_a := sin(angle)
		var u := float(i) / float(segments)
		verts.append(Vector3(cos_a * outer_r, 0, sin_a * outer_r))
		normals.append(Vector3.UP)
		uvs.append(Vector2(u, 0.0))
		verts.append(Vector3(cos_a * inner_r, 0, sin_a * inner_r))
		normals.append(Vector3.UP)
		uvs.append(Vector2(u, 1.0))

	for i in range(segments):
		var base := i * 2
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

extends BaseTile

## ワープタイル（通過型）- 魔法陣 + 発光 + 浮遊パーティクル + 炎オーラ

const WARP_COLOR := Color(0.533, 0.078, 1.0)
const MAGIC_CIRCLE_RADIUS := 1.6
const PARTICLE_COUNT := 12
const PARTICLE_HEIGHT := 3.5
const AURA_HEIGHT := 1.5

var _magic_circle: MeshInstance3D
var _particles: Array[MeshInstance3D] = []
var _particle_mats: Array[StandardMaterial3D] = []
var _aura_ring: MeshInstance3D
var _time := 0.0

# 炎オーラシェーダー（リング外周から立ち上がる炎のような揺らぎ）
const AURA_SHADER_CODE := "
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix;

uniform vec4 color_bottom : source_color = vec4(1.0, 0.85, 0.3, 0.8);
uniform vec4 color_top : source_color = vec4(1.0, 0.5, 0.1, 0.0);
uniform float emission_strength = 4.0;
uniform float aura_speed = 1.5;
uniform float flame_intensity = 1.0;

// 疑似ノイズ関数
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// UV.x = 円周方向(0~1), UV.y = 高さ方向(0=下, 1=上)
	float height = UV.y;

	// 複数スケールのノイズで炎の揺らぎ
	float n1 = noise(vec2(UV.x * 8.0, height * 3.0 - TIME * aura_speed));
	float n2 = noise(vec2(UV.x * 16.0 + 5.0, height * 5.0 - TIME * aura_speed * 1.3));
	float n3 = noise(vec2(UV.x * 4.0 + 10.0, height * 2.0 - TIME * aura_speed * 0.7));
	float flame_noise = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;

	// 高さに応じたフェード（下=明るい、上=消える）
	float height_fade = 1.0 - height;
	height_fade = height_fade * height_fade;

	// ノイズで炎の形を作る（上部を不規則にカット）
	float flame_shape = height_fade * (0.5 + flame_noise * flame_intensity);
	flame_shape = clamp(flame_shape, 0.0, 1.0);

	// 色のグラデーション（下=黄色、上=オレンジ→透明）
	vec3 col = mix(color_top.rgb, color_bottom.rgb, height_fade);

	ALBEDO = col;
	EMISSION = col * emission_strength * flame_shape;
	ALPHA = flame_shape * color_bottom.a;
}
"


func _ready():
	tile_type = "warp"
	super._ready()
	_setup_emission()
	_create_magic_circle()
	_create_particles()
	_create_aura_ring()
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
		var speed := 0.35 + float(i % 3) * 0.15
		var t := fmod(_time * speed + phase / TAU, 1.0)
		p.position.y = 0.5 + t * PARTICLE_HEIGHT
		var alpha := 1.0 - t
		if _particle_mats.size() > i:
			_particle_mats[i].albedo_color.a = alpha * 0.9
		var sway_x := sin(_time * 1.8 + phase) * 0.4 + sin(_time * 3.1 + phase * 1.7) * 0.15
		var sway_z := cos(_time * 2.2 + phase * 0.8) * 0.4 + cos(_time * 2.7 + phase * 1.3) * 0.15
		var base_r := 0.6 + float(i % 4) * 0.2
		p.position.x = cos(phase) * base_r + sway_x
		p.position.z = sin(phase) * base_r + sway_z


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


## 魔法陣外周の炎オーラリングを作成
func _create_aura_ring() -> void:
	_aura_ring = MeshInstance3D.new()
	_aura_ring.name = "AuraRing"

	# 円筒メッシュ（UV.x=円周, UV.y=高さ）を手動構築
	var mesh := _build_aura_cylinder_mesh(MAGIC_CIRCLE_RADIUS, AURA_HEIGHT, 48)
	_aura_ring.mesh = mesh

	var shader := Shader.new()
	shader.code = AURA_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color_bottom", Color(1.0, 0.85, 0.3, 0.7))
	mat.set_shader_parameter("color_top", Color(1.0, 0.4, 0.1, 0.0))
	mat.set_shader_parameter("emission_strength", 4.0)
	mat.set_shader_parameter("aura_speed", 1.5)
	mat.set_shader_parameter("flame_intensity", 1.0)
	_aura_ring.material_override = mat

	_aura_ring.position = Vector3(0, 0.3, 0)
	add_child(_aura_ring)


## 炎オーラ用の円筒メッシュ（UVが正しく設定された開いた円筒）
func _build_aura_cylinder_mesh(radius: float, height: float, segments: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var rings := 8  # 高さ方向の分割数
	for r_idx in range(rings + 1):
		var y_t := float(r_idx) / float(rings)
		var y_pos := y_t * height
		# 上に行くほど半径が広がる（外側に放射）
		var spread := 1.0 + y_t * y_t * 0.6
		var r := radius * spread
		for s_idx in range(segments + 1):
			var angle := (float(s_idx) / float(segments)) * TAU
			var x := cos(angle) * r
			var z := sin(angle) * r
			verts.append(Vector3(x, y_pos, z))
			normals.append(Vector3(cos(angle), 0, sin(angle)))
			uvs.append(Vector2(float(s_idx) / float(segments), y_t))

	var verts_per_ring := segments + 1
	for r_idx in range(rings):
		for s_idx in range(segments):
			var current := r_idx * verts_per_ring + s_idx
			var next_ring := (r_idx + 1) * verts_per_ring + s_idx
			indices.append_array([current, next_ring, current + 1])
			indices.append_array([current + 1, next_ring, next_ring + 1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


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

extends BaseTile

## ワープタイル（停止型）- 魔法陣 + 発光 + 浮遊パーティクル + 炎オーラ（赤色）

const AURA_RADIUS := 1.6
const PARTICLE_COUNT := 12
const PARTICLE_HEIGHT := 3.5
const AURA_HEIGHT := 1.5

var _particles: Array[MeshInstance3D] = []
var _particle_mats: Array[StandardMaterial3D] = []
var _aura_ring: MeshInstance3D
var _magic_circle_model: Node3D
var _time := 0.0

const MAGIC_CIRCLE_SCENE := preload("res://models/magic_circle.glb")

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
	float height = UV.y;
	float n1 = noise(vec2(UV.x * 8.0, height * 3.0 - TIME * aura_speed));
	float n2 = noise(vec2(UV.x * 16.0 + 5.0, height * 5.0 - TIME * aura_speed * 1.3));
	float n3 = noise(vec2(UV.x * 4.0 + 10.0, height * 2.0 - TIME * aura_speed * 0.7));
	float flame_noise = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;

	float height_fade = 1.0 - height;
	height_fade = height_fade * height_fade;

	float flame_shape = height_fade * (0.5 + flame_noise * flame_intensity);
	flame_shape = clamp(flame_shape, 0.0, 1.0);

	vec3 col = mix(color_top.rgb, color_bottom.rgb, height_fade);

	ALBEDO = col;
	EMISSION = col * emission_strength * flame_shape;
	ALPHA = flame_shape * color_bottom.a;
}
"


func _ready():
	tile_type = "warp_stop"
	super._ready()
	_create_magic_circle()
	_create_particles()
	_create_aura_ring()
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
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


## 魔法陣3Dモデルを配置（赤色）
func _create_magic_circle() -> void:
	_magic_circle_model = MAGIC_CIRCLE_SCENE.instantiate()
	_magic_circle_model.name = "MagicCircle"
	_magic_circle_model.position = Vector3(1.1, 0.48, 1.1)
	_magic_circle_model.rotation_degrees = Vector3(-90, 0, 45)
	_magic_circle_model.scale = Vector3(0.75, 0.75, 0.75)
	add_child(_magic_circle_model)
	_apply_color_to_model(_magic_circle_model, Color(1.0, 0.2, 0.2))


## モデル内の全MeshInstance3Dに色を適用
func _apply_color_to_model(node: Node3D, color: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 1.5
			child.material_override = mat
		if child.get_child_count() > 0:
			_apply_color_to_model(child, color)


## テレポート発動時の回転アニメーション
func play_warp_animation(duration: float = 1.0) -> void:
	if not _magic_circle_model:
		return
	var center: Vector3 = to_global(Vector3(0, 0.48, 0))
	var initial_transform: Transform3D = _magic_circle_model.global_transform

	var tween := create_tween()
	tween.tween_method(func(angle: float) -> void:
		var rot := Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO)
		var t := initial_transform
		t.origin -= center
		t = rot * t
		t.origin += center
		_magic_circle_model.global_transform = t
	, 0.0, TAU * 2.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## 浮遊パーティクル（赤色）
func _create_particles() -> void:
	for i in range(PARTICLE_COUNT):
		var p := MeshInstance3D.new()
		p.name = "WarpStopParticle_%d" % i
		var sphere := SphereMesh.new()
		sphere.radius = 0.035
		sphere.height = 0.07
		sphere.radial_segments = 4
		sphere.rings = 2
		p.mesh = sphere

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.4, 0.3, 0.9)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.3, 0.2)
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


## 炎オーラリング（赤色）
func _create_aura_ring() -> void:
	_aura_ring = MeshInstance3D.new()
	_aura_ring.name = "AuraRing"

	var mesh := _build_aura_cylinder_mesh(AURA_RADIUS, AURA_HEIGHT, 48)
	_aura_ring.mesh = mesh

	var shader := Shader.new()
	shader.code = AURA_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color_bottom", Color(1.0, 0.3, 0.2, 0.7))
	mat.set_shader_parameter("color_top", Color(0.8, 0.1, 0.05, 0.0))
	mat.set_shader_parameter("emission_strength", 4.0)
	mat.set_shader_parameter("aura_speed", 1.5)
	mat.set_shader_parameter("flame_intensity", 1.0)
	_aura_ring.material_override = mat

	_aura_ring.position = Vector3(0, 0.3, 0)
	add_child(_aura_ring)


## 炎オーラ用の円筒メッシュ
func _build_aura_cylinder_mesh(radius: float, height: float, segments: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var rings := 8
	for r_idx in range(rings + 1):
		var y_t := float(r_idx) / float(rings)
		var y_pos := y_t * height
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

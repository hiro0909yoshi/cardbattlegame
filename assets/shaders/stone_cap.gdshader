shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.62, 0.60, 0.56);
uniform float roughness_base : hint_range(0.5, 1.0) = 0.1;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
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
	// 細かい石の粒感（高周波ノイズ）
	vec2 uv = world_pos.xz;
	float fine = noise(uv * 400.0);
	float medium = noise(uv * 200.0);

	vec3 col = base_color;
	col += (fine - 0.5) * 0.04;
	col += (medium - 0.5) * 0.03;

	ALBEDO = col;
	ROUGHNESS = roughness_base + (fine - 0.5) * 0.1;

	// 微細な凹凸
	vec2 bump_uv = uv * 40.0;
	vec3 perturb = vec3(
		(noise(bump_uv + vec2(0.1, 0.0)) - 0.5) * 0.15,
		(noise(bump_uv + vec2(0.0, 0.1)) - 0.5) * 0.15,
		0.0
	);
	NORMAL = normalize(NORMAL + perturb);
}

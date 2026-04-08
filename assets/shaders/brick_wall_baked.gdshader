shader_type spatial;

// ベイク済みテクスチャを world_pos ベースのトライプラナーで表示する軽量シェーダー
// noise 計算ゼロ、テクスチャ参照のみ

uniform sampler2D brick_texture : filter_linear_mipmap, repeat_enable;
uniform float tile_scale = 4.0;
uniform float roughness_base : hint_range(0.5, 1.0) = 0.88;

// 苔パラメータ
uniform vec3 moss_color : source_color = vec3(0.22, 0.35, 0.15);
uniform float moss_amount : hint_range(0.0, 1.0) = 0.35;
uniform float moss_bottom_bias : hint_range(0.0, 5.0) = 2.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	// world_pos ベースの3方向トライプラナー
	vec3 n = abs(normalize(world_normal));
	float blend_x = n.x;
	float blend_y = n.y;
	float blend_z = n.z;
	float blend_sum = blend_x + blend_y + blend_z + 0.001;
	blend_x /= blend_sum;
	blend_y /= blend_sum;
	blend_z /= blend_sum;

	// テクスチャ参照（world_pos を UV に変換）
	vec2 uv_x = world_pos.zy / tile_scale;
	vec2 uv_y = world_pos.xz / tile_scale;
	vec2 uv_z = world_pos.xy / tile_scale;

	vec3 col_x = texture(brick_texture, uv_x).rgb;
	vec3 col_y = texture(brick_texture, uv_y).rgb;
	vec3 col_z = texture(brick_texture, uv_z).rgb;

	vec3 brick_col = col_x * blend_x + col_y * blend_y + col_z * blend_z;

	// 苔（hash のみ）
	float height_01 = clamp(world_pos.y / 4.0, 0.0, 1.0);
	float bottom_factor = pow(1.0 - height_01, moss_bottom_bias);
	float moss_hash = hash(floor(world_pos.xz * 2.0));
	float moss_mask = bottom_factor * moss_hash;
	moss_mask = smoothstep(1.0 - moss_amount, 1.0 - moss_amount + 0.3, moss_mask);

	vec3 final_color = mix(brick_col, moss_color, moss_mask);

	ALBEDO = final_color;
	ROUGHNESS = roughness_base;
}

shader_type spatial;

// brick_wall.gdshader の軽量版（モバイル向け）
// noise() を全て削除し、hash のみでレンガパターンを生成

uniform vec3 brick_color_1 : source_color = vec3(0.48, 0.47, 0.44);
uniform vec3 brick_color_2 : source_color = vec3(0.55, 0.53, 0.50);
uniform vec3 brick_color_3 : source_color = vec3(0.40, 0.39, 0.36);
uniform vec3 mortar_color : source_color = vec3(0.35, 0.33, 0.30);

uniform float brick_width : hint_range(0.1, 2.0) = 0.8;
uniform float brick_height : hint_range(0.05, 1.0) = 0.3;
uniform float mortar_thickness : hint_range(0.005, 0.1) = 0.025;
uniform float color_variation : hint_range(0.0, 0.3) = 0.08;
uniform float roughness_base : hint_range(0.5, 1.0) = 0.88;
uniform float edge_wear : hint_range(0.0, 0.05) = 0.018;

uniform vec3 moss_color : source_color = vec3(0.22, 0.35, 0.15);
uniform float moss_amount : hint_range(0.0, 1.0) = 0.35;
uniform float moss_bottom_bias : hint_range(0.0, 5.0) = 2.0;

uniform float triplanar_sharpness : hint_range(1.0, 16.0) = 4.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

// 軽量ハッシュ（noise不使用）
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// レンガ計算（noise削除版）
vec4 calc_brick(vec2 uv, out float mortar_flag) {
	vec2 brick_size = vec2(brick_width, brick_height);
	vec2 coord = uv / brick_size;

	float row = floor(coord.y);
	float offset = mod(row, 2.0) * 0.5;
	coord.x += offset;

	vec2 brick_uv = fract(coord);
	vec2 brick_id = floor(coord);

	float mortar_x = mortar_thickness / brick_size.x;
	float mortar_y = mortar_thickness / brick_size.y;
	float wear = hash(brick_id * 17.3) * edge_wear;
	float mx = mortar_x + wear;
	float my = mortar_y + wear;

	bool is_mortar = brick_uv.x < mx || brick_uv.x > (1.0 - mx) ||
					 brick_uv.y < my || brick_uv.y > (1.0 - my);
	mortar_flag = is_mortar ? 1.0 : 0.0;

	float brick_rand = hash(brick_id);
	float brick_rand2 = hash2(brick_id);
	vec3 base_color;
	if (brick_rand < 0.4) {
		base_color = brick_color_1;
	} else if (brick_rand < 0.75) {
		base_color = brick_color_2;
	} else {
		base_color = brick_color_3;
	}

	// hash で色バリエーション（noise の代わり）
	base_color += (brick_rand2 - 0.5) * color_variation;

	vec3 final_color;
	float rough;
	if (is_mortar) {
		final_color = mortar_color;
		rough = roughness_base + 0.1;
	} else {
		final_color = base_color;
		rough = roughness_base + (brick_rand2 - 0.5) * 0.08;
	}

	return vec4(final_color, clamp(rough, 0.5, 1.0));
}

void fragment() {
	// トライプラナー（X面 + Z面のみ）
	vec3 n = abs(normalize(world_normal));
	float blend_x = n.x;
	float blend_z = n.z;
	float blend_sum = blend_x + blend_z + 0.001;
	blend_x /= blend_sum;
	blend_z /= blend_sum;

	float mf_x, mf_z;
	vec4 brick_x = calc_brick(world_pos.zy, mf_x);
	vec4 brick_z = calc_brick(world_pos.xy, mf_z);

	vec3 brick_col = brick_x.rgb * blend_x + brick_z.rgb * blend_z;
	float brick_rough = brick_x.a * blend_x + brick_z.a * blend_z;

	// 苔（hash のみ、noise なし）
	float height_01 = clamp(world_pos.y / 4.0, 0.0, 1.0);
	float bottom_factor = pow(1.0 - height_01, moss_bottom_bias);
	float moss_hash = hash(floor(world_pos.xz * 2.0));
	float moss_mask = bottom_factor * moss_hash;
	moss_mask = smoothstep(1.0 - moss_amount, 1.0 - moss_amount + 0.3, moss_mask);

	vec3 final_color = mix(brick_col, moss_color, moss_mask);
	float final_rough = mix(brick_rough, 0.95, moss_mask);

	ALBEDO = final_color;
	ROUGHNESS = final_rough;
}

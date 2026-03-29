shader_type spatial;

// レンガの色（灰色系の石壁）
uniform vec3 brick_color_1 : source_color = vec3(0.48, 0.47, 0.44);
uniform vec3 brick_color_2 : source_color = vec3(0.55, 0.53, 0.50);
uniform vec3 brick_color_3 : source_color = vec3(0.40, 0.39, 0.36);
uniform vec3 mortar_color : source_color = vec3(0.35, 0.33, 0.30);

// レンガのサイズ
uniform float brick_width : hint_range(0.1, 2.0) = 0.8;
uniform float brick_height : hint_range(0.05, 1.0) = 0.3;
uniform float mortar_thickness : hint_range(0.005, 0.1) = 0.025;

// ディテール
uniform float color_variation : hint_range(0.0, 0.3) = 0.08;
uniform float roughness_base : hint_range(0.5, 1.0) = 0.88;
uniform float edge_wear : hint_range(0.0, 0.05) = 0.018;

// 苔・カビ
uniform vec3 moss_color : source_color = vec3(0.22, 0.35, 0.15);
uniform vec3 mold_color : source_color = vec3(0.18, 0.22, 0.12);
uniform float moss_amount : hint_range(0.0, 1.0) = 0.35;
uniform float moss_bottom_bias : hint_range(0.0, 5.0) = 2.0;
uniform float moss_mortar_bias : hint_range(0.0, 1.0) = 0.6;

// トライプラナーのブレンド鮮明度
uniform float triplanar_sharpness : hint_range(1.0, 16.0) = 4.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

// 疑似乱数
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// スムースノイズ
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

// 指定UVでレンガパターンを計算（色 + ラフネス + モルタルフラグ）
// .rgb = 色, .a = ラフネス
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

	// モルタル判定（ソフトエッジ）
	float dist_x = min(brick_uv.x, 1.0 - brick_uv.x);
	float dist_y = min(brick_uv.y, 1.0 - brick_uv.y);
	float mortar_soft = 1.0 - smoothstep(0.0, mx * 1.5, dist_x) * smoothstep(0.0, my * 1.5, dist_y);
	bool is_mortar = brick_uv.x < mx || brick_uv.x > (1.0 - mx) ||
					 brick_uv.y < my || brick_uv.y > (1.0 - my);
	mortar_flag = is_mortar ? 1.0 : mortar_soft * 0.3;

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

	base_color += (brick_rand2 - 0.5) * color_variation;
	// ざらつきのみ（fbmによるシミ・汚れは削除）
	base_color += (noise(uv * 12.0) - 0.5) * 0.06;

	vec3 final_color;
	float rough;
	if (is_mortar) {
		final_color = mortar_color + (noise(uv * 20.0) - 0.5) * 0.04;
		rough = roughness_base + 0.1;
	} else {
		final_color = base_color;
		rough = roughness_base + (brick_rand2 - 0.5) * 0.08;
	}

	return vec4(final_color, clamp(rough, 0.5, 1.0));
}

void fragment() {
	// トライプラナーブレンド（2方向に簡略化: X面 + Z面のみ）
	vec3 n = abs(normalize(world_normal));
	float blend_x = n.x;
	float blend_z = n.z;
	float blend_sum = blend_x + blend_z + 0.001; // ゼロ除算防止
	blend_x /= blend_sum;
	blend_z /= blend_sum;

	float mf_x, mf_z;
	vec4 brick_x = calc_brick(world_pos.zy, mf_x);
	vec4 brick_z = calc_brick(world_pos.xy, mf_z);

	vec3 brick_col = brick_x.rgb * blend_x + brick_z.rgb * blend_z;
	float brick_rough = brick_x.a * blend_x + brick_z.a * blend_z;
	float mortar_f = mf_x * blend_x + mf_z * blend_z;

	// --- 苔・カビ（簡略化: noise 1回のみ） ---
	float height_01 = clamp(world_pos.y / 4.0, 0.0, 1.0);
	float bottom_factor = pow(1.0 - height_01, moss_bottom_bias);
	float mortar_factor = mix(1.0, 1.0 + moss_mortar_bias, mortar_f);
	float moss_noise = noise(world_pos.xz * 1.5 + world_pos.yy * 0.5);
	float moss_mask = bottom_factor * mortar_factor * moss_noise;
	moss_mask = smoothstep(1.0 - moss_amount, 1.0 - moss_amount + 0.3, moss_mask);

	// 苔の色（hash で簡易バリエーション）
	float moss_var = hash(floor(world_pos.xz * 4.0));
	vec3 moss_col = mix(moss_color, mold_color, moss_var);

	vec3 final_color = mix(brick_col, moss_col, moss_mask);
	float final_rough = mix(brick_rough, 0.95, moss_mask);

	ALBEDO = final_color;
	ROUGHNESS = final_rough;
	// 法線バンプは削除（モバイル負荷軽減）
}

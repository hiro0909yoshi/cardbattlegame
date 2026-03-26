shader_type spatial;

// 緑色の部分だけ金色に置換するシェーダー
uniform sampler2D albedo_texture : source_color;
uniform float hue_threshold : hint_range(0.0, 1.0) = 0.25;
uniform float hue_range : hint_range(0.0, 0.5) = 0.15;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 hsv = rgb2hsv(tex.rgb);

	float dist = abs(hsv.x - hue_threshold);
	if (dist > 0.5) dist = 1.0 - dist;

	if (dist < hue_range && hsv.y > 0.1) {
		// 緑→金色にHueシフト（0.10 = 黄色強めの金色）
		hsv.x = 0.10;
		hsv.y = min(hsv.y * 1.1, 1.0);
		hsv.z = min(hsv.z * 1.3, 1.0);
		ALBEDO = hsv2rgb(hsv);
	} else {
		ALBEDO = tex.rgb;
	}
}

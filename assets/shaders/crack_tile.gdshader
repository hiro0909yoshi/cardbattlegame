shader_type spatial;

// 属性色（GDScriptから設定）
uniform vec4 element_color : source_color = vec4(1.0, 0.3, 0.1, 1.0);
// タイルのベース色
uniform vec4 base_color : source_color = vec4(0.15, 0.15, 0.15, 1.0);
// ひび割れテクスチャ
uniform sampler2D crack_texture;
// 発光の強さ
uniform float glow_intensity : hint_range(0.0, 10.0) = 4.0;
// ひび割れ判定の閾値（高い＝裂け目が細い、低い＝裂け目が太い）
uniform float crack_threshold : hint_range(0.0, 1.0) = 0.65;
// アニメーション速度
uniform float pulse_speed : hint_range(0.0, 3.0) = 0.8;

void fragment() {
	// ひび割れテクスチャをサンプリング
	vec3 crack_sample = texture(crack_texture, UV).rgb;
	// 明るさを取得（白い部分＝裂け目）
	float brightness = dot(crack_sample, vec3(0.299, 0.587, 0.114));

	// 裂け目マスク（明るい部分が裂け目）
	float crack_core = smoothstep(crack_threshold, crack_threshold + 0.15, brightness);
	// 周辺のぼんやり発光
	float crack_glow = smoothstep(crack_threshold - 0.15, crack_threshold + 0.1, brightness) * 0.3;

	float crack_mask = clamp(crack_core + crack_glow, 0.0, 1.0);

	// パルスアニメーション（脈動）
	float pulse = 0.6 + 0.4 * sin(TIME * pulse_speed);

	// 地面部分は黒、裂け目部分も暗い（光だけが見える）
	ALBEDO = vec3(0.02) * (1.0 - crack_mask);

	// 裂け目から属性色の光が溢れる
	float emission_strength = crack_mask * glow_intensity * (0.5 + 0.5 * pulse);
	EMISSION = element_color.rgb * emission_strength;

	// 地面はザラザラ、裂け目は滑らか（溶岩/エネルギー感）
	ROUGHNESS = mix(0.95, 0.1, crack_mask);
	METALLIC = crack_mask * 0.2;
}

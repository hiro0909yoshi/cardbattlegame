shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// ============================================
// カード裏面シェーダー
// 三日月 + 星空 + ARCANAテキスト風装飾
// ============================================

uniform float time_scale : hint_range(0.1, 3.0) = 0.5;

// 背景色
uniform vec4 bg_color_top : source_color = vec4(0.02, 0.08, 0.12, 1.0);    // 深い青緑
uniform vec4 bg_color_bottom : source_color = vec4(0.01, 0.03, 0.06, 1.0); // ほぼ黒

// 三日月の色
uniform vec4 moon_color_base : source_color = vec4(0.8, 0.55, 0.1, 1.0);   // 金色（暗め）
uniform vec4 moon_color_bright : source_color = vec4(1.0, 0.85, 0.3, 1.0); // 金色（明るめ）
uniform vec4 moon_edge_color : source_color = vec4(1.0, 0.95, 0.6, 1.0);   // エッジの輝き

// 三日月の形パラメータ
uniform float moon_size : hint_range(0.1, 0.5) = 0.32;
uniform float moon_offset : hint_range(0.01, 0.4) = 0.04;
uniform float moon_inner_size : hint_range(0.1, 1.0) = 0.75;  // 内側の円の大きさ（外円比）
uniform float moon_angle : hint_range(0.0, 360.0) = 45.0;  // 欠けの方向（度）
uniform vec2 moon_position = vec2(0.5, 0.34);               // 三日月の中心

// ============================================
// ユーティリティ関数
// ============================================

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// FBMノイズ（有機的なテクスチャ用）
float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(st);
        st *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// 円のSDF
float sdf_circle(vec2 uv, vec2 center, float radius) {
    return length(uv - center) - radius;
}

// ============================================
// 三日月マスク
// ============================================
float crescent_mask(vec2 uv) {
    // アスペクト比補正（カードは縦長 220x293）
    vec2 aspect_uv = uv;
    aspect_uv.x = (uv.x - 0.5) * (220.0 / 293.0) + 0.5;

    float big_circle = sdf_circle(aspect_uv, moon_position, moon_size);
    float rad = moon_angle * 3.14159265 / 180.0;
    vec2 cut_center = moon_position + vec2(cos(rad), sin(rad)) * moon_offset;
    float cut_circle = sdf_circle(aspect_uv, cut_center, moon_size * (2.0 - moon_inner_size));

    // 大円の内側 AND 小円の外側 = 三日月
    float crescent = max(-big_circle, cut_circle);
    return step(0.0, crescent); // 0=三日月内, 1=外
}

// 三日月のエッジグロー
float crescent_edge(vec2 uv) {
    vec2 aspect_uv = uv;
    aspect_uv.x = (uv.x - 0.5) * (220.0 / 293.0) + 0.5;

    float big_circle = sdf_circle(aspect_uv, moon_position, moon_size);
    float rad = moon_angle * 3.14159265 / 180.0;
    vec2 cut_center = moon_position + vec2(cos(rad), sin(rad)) * moon_offset;
    float cut_circle = sdf_circle(aspect_uv, cut_center, moon_size * (2.0 - moon_inner_size));

    float crescent = max(-big_circle, cut_circle);
    float edge = 1.0 - smoothstep(0.0, 0.015, abs(crescent));
    return edge;
}

// ============================================
// アラベスク風模様（三日月内部）
// ============================================
float arabesque(vec2 uv, float t) {
    // 三日月の中心からのUV変換
    vec2 centered = uv - moon_position;
    centered.x *= (293.0 / 220.0); // アスペクト補正を戻す

    // 極座標に変換
    float angle = atan(centered.y, centered.x);
    float radius = length(centered);

    // 渦巻き模様
    float spiral = sin(angle * 5.0 + radius * 20.0 - t * 0.5) * 0.5 + 0.5;

    // フラクタルノイズで有機的に
    vec2 noise_uv = vec2(angle / (2.0 * 3.14159) + 0.5, radius * 3.0);
    float organic = fbm(noise_uv * 4.0 + t * 0.1);

    return mix(spiral, organic, 0.4);
}

// ============================================
// 星のきらめき
// ============================================
float stars(vec2 uv, float t) {
    float star_field = 0.0;
    // 複数レイヤーの星
    for (int i = 0; i < 3; i++) {
        float layer_scale = 8.0 + float(i) * 6.0;
        vec2 grid = fract(uv * layer_scale) - 0.5;
        vec2 cell = floor(uv * layer_scale);
        float rand = random(cell + float(i) * 13.7);
        float twinkle = sin(t * (1.5 + rand * 2.0) + rand * 6.28) * 0.5 + 0.5;
        float star = 1.0 - smoothstep(0.0, 0.12 - rand * 0.08, length(grid));
        star_field += star * twinkle * (rand > 0.7 ? 1.0 : 0.0); // 密度調整
    }
    return clamp(star_field, 0.0, 1.0);
}

// ============================================
// 枠の装飾（カード縁）
// ============================================
float card_border(vec2 uv) {
    float bx = min(uv.x, 1.0 - uv.x);
    float by = min(uv.y, 1.0 - uv.y);
    float d = min(bx, by);

    // 外側細ライン
    float outer = 1.0 - smoothstep(0.0, 0.006, abs(d - 0.005));
    // 内側細ライン
    float inner = 1.0 - smoothstep(0.0, 0.006, abs(d - 0.03));

    return clamp(outer + inner, 0.0, 1.0);
}

// ============================================
// メイン
// ============================================
void fragment() {
    vec2 uv = UV;
    float t = TIME * time_scale;

    // --- 背景グラデーション ---
    vec4 bg = mix(bg_color_bottom, bg_color_top, uv.y);

    // 背景に微細ノイズを加えて深みを出す
    float bg_noise = fbm(uv * 6.0) * 0.06;
    bg.rgb += bg_noise;

    // --- 星 ---
    float star = stars(uv, t);
    vec3 star_color = vec3(0.9, 0.85, 0.6) * star * 0.8;

    // --- 三日月 ---
    float mask = crescent_mask(uv);          // 0=三日月内, 1=外
    float edge = crescent_edge(uv);
    float arab = arabesque(uv, t);

    // 三日月の色（アラベスク模様で変調）
    vec3 moon_rgb = mix(moon_color_base.rgb, moon_color_bright.rgb, arab * 0.7);
    // エッジ輝き追加
    moon_rgb = mix(moon_rgb, moon_edge_color.rgb, edge * 0.8);

    // --- ARCANAテキスト位置（三日月の下に簡易ライン装飾）---
    // テキスト自体はSubViewportで重ねるため、ここではシンプルな区切りラインのみ
    float text_y = 0.87;
    float line_dist = abs(uv.y - text_y);
    float deco_line = 1.0 - smoothstep(0.0, 0.002, line_dist);
    float line_mask = smoothstep(0.1, 0.2, uv.x) * (1.0 - smoothstep(0.8, 0.9, uv.x));
    deco_line *= line_mask;

    // --- 枠 ---
    float border = card_border(uv);
    vec3 border_color = mix(moon_color_base.rgb, moon_edge_color.rgb,
                            sin(t + uv.y * 3.14159) * 0.5 + 0.5);

    // --- 大円の内側マスク（星を隠す）---
    vec2 aspect_uv_main = uv;
    aspect_uv_main.x = (uv.x - 0.5) * (220.0 / 293.0) + 0.5;
    float rad_main = moon_angle * 3.14159265 / 180.0;
    vec2 cut_center_main = moon_position + vec2(cos(rad_main), sin(rad_main)) * moon_offset;
    float cut_circle_main = sdf_circle(aspect_uv_main, cut_center_main, moon_size * (2.0 - moon_inner_size));
    float inner_mask = step(0.0, -cut_circle_main); // 1=欠け円内

    // --- 合成 ---
    vec3 final_color = bg.rgb;
    // 大円内は星を消して暗くする
    final_color = mix(final_color, bg.rgb, inner_mask);
    final_color += star_color * (1.0 - inner_mask);

    // 三日月を合成（mask=0の部分が三日月）
    final_color = mix(moon_rgb, final_color, mask);



    // 装飾ライン
    final_color = mix(final_color, moon_color_bright.rgb, deco_line * 0.9);

    // 枠
    final_color = mix(final_color, border_color, border * 0.9);

    ALBEDO = final_color;
}

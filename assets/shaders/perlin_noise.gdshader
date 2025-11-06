shader_type canvas_item;

// パーリンノイズ (Perlin Noise) - 現在使っているもの
uniform float scale : hint_range(1.0, 20.0) = 8.0;
uniform float contrast : hint_range(0.0, 2.0) = 0.6;
uniform vec4 color_dark : source_color = vec4(0.02, 0.02, 0.02, 1.0);
uniform vec4 color_light : source_color = vec4(0.08, 0.08, 0.08, 1.0);

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

void fragment() {
    vec2 st = UV * scale;
    
    float n = 0.0;
    n += noise(st) * 0.5;
    n += noise(st * 2.0) * 0.25;
    n += noise(st * 4.0) * 0.125;
    
    n = pow(n, contrast);
    
    vec4 color = mix(color_dark, color_light, n);
    COLOR = color;
}

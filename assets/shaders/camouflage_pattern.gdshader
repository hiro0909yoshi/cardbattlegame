shader_type canvas_item;

// 迷彩模様 (Camouflage Pattern)
uniform float scale : hint_range(1.0, 20.0) = 8.0;
uniform float sharpness : hint_range(0.0, 2.0) = 1.2;
uniform vec4 color_dark : source_color = vec4(0.02, 0.02, 0.02, 1.0);
uniform vec4 color_mid : source_color = vec4(0.06, 0.06, 0.06, 1.0);
uniform vec4 color_light : source_color = vec4(0.10, 0.10, 0.10, 1.0);

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
    
    // Multiple noise layers for camouflage
    float n1 = noise(st);
    float n2 = noise(st * 2.0 + vec2(10.0, 10.0));
    float n3 = noise(st * 4.0 + vec2(20.0, 20.0));
    
    // Combine noises
    float camo = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;
    camo = pow(camo, sharpness);
    
    // Three color levels for camo
    vec4 color;
    if (camo < 0.33) {
        color = color_dark;
    } else if (camo < 0.66) {
        color = color_mid;
    } else {
        color = color_light;
    }
    
    COLOR = color;
}

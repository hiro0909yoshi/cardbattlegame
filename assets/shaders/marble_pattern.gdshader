shader_type canvas_item;

// 大理石模様 (Marble Pattern)
uniform float scale : hint_range(1.0, 20.0) = 5.0;
uniform float detail : hint_range(0.0, 10.0) = 3.0;
uniform float turbulence : hint_range(0.0, 5.0) = 2.0;
uniform vec4 color_dark : source_color = vec4(0.02, 0.02, 0.02, 1.0);
uniform vec4 color_light : source_color = vec4(0.12, 0.12, 0.12, 1.0);

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
    
    // Turbulence for marble veins
    float n = 0.0;
    float amplitude = 1.0;
    for (float i = 0.0; i < detail; i += 1.0) {
        n += noise(st) * amplitude;
        st *= 2.0;
        amplitude *= 0.5;
    }
    
    // Create marble veins
    float marble = sin((st.x + n * turbulence) * 3.14159);
    marble = marble * 0.5 + 0.5;
    marble = pow(marble, 2.0);
    
    vec4 color = mix(color_dark, color_light, marble);
    COLOR = color;
}

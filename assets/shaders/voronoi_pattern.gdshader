shader_type canvas_item;

// ボロノイ模様 (Voronoi Pattern) - 豹柄風
uniform float scale : hint_range(1.0, 30.0) = 12.0;
uniform float smoothness : hint_range(0.0, 1.0) = 0.3;
uniform vec4 color_dark : source_color = vec4(0.02, 0.02, 0.02, 1.0);
uniform vec4 color_light : source_color = vec4(0.10, 0.10, 0.10, 1.0);

vec2 random2(vec2 st) {
    st = vec2(dot(st, vec2(127.1, 311.7)),
              dot(st, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(st) * 43758.5453123);
}

float voronoi(vec2 st) {
    vec2 i_st = floor(st);
    vec2 f_st = fract(st);
    
    float min_dist = 1.0;
    
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = random2(i_st + neighbor);
            point = 0.5 + 0.5 * sin(6.2831 * point);
            vec2 diff = neighbor + point - f_st;
            float dist = length(diff);
            min_dist = min(min_dist, dist);
        }
    }
    
    return min_dist;
}

void fragment() {
    vec2 st = UV * scale;
    
    float v = voronoi(st);
    
    // Smooth the pattern
    v = smoothstep(0.0, smoothness, v);
    
    vec4 color = mix(color_light, color_dark, v);
    COLOR = color;
}

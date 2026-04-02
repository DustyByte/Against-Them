shader_type canvas_item;

uniform sampler2D noise_texture;
uniform float threshold : hint_range(0.0, 1.0) = 0.5;

uniform float outline_width : hint_range(0.0, 0.1) = 0.02;
uniform vec4 outline_color : source_color = vec4(0.86, 0.08, 0.24, 1.0); // Crimson

void fragment() {
    float noise_val = texture(noise_texture, UV).r;
    vec4 base_col = COLOR;


    if (noise_val < threshold) {
        COLOR = base_col;
    }
    else if (noise_val < threshold + outline_width) {
        COLOR = outline_color * base_col.a;
    }
    else {
        discard;
    }
}

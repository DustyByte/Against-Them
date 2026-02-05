shader_type canvas_item;

uniform sampler2D base_image;
uniform sampler2D noise_texture;
uniform float threshold : hint_range(0.0, 1.0) = 0.5;

// New uniforms for the outline
uniform float outline_width : hint_range(0.0, 0.1) = 0.02;
uniform vec4 outline_color : source_color = vec4(0.86, 0.08, 0.24, 1.0); // Crimson

void fragment() {
    vec2 uv = UV;
    float noise_val = texture(noise_texture, uv).r;
    vec4 base_col = texture(base_image, uv);


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

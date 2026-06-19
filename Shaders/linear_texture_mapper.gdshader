shader_type canvas_item;

uniform sampler2D my_texture : source_color;

void fragment() {
    COLOR = texture(my_texture, UV);
}
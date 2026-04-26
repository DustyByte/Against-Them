shader_type canvas_item;

uniform sampler2D color;

void fragment() {
	COLOR = texture(color, vec2(UV.x));
}
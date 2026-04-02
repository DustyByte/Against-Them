shader_type canvas_item;

uniform sampler2D mask;
uniform float slider : hint_range(0.0, 10.0, 0.001) = 0.5;
uniform float alpha : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform vec4 color : source_color;

void fragment() {
	COLOR = texture(mask, vec2(UV.x, UV.y*slider)).r * color;
	COLOR.a *= alpha;
}
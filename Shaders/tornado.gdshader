shader_type canvas_item;

uniform sampler2D line_texture : repeat_enable;
uniform vec4 baseColor : source_color = vec4(1., 1., 1., 1.);
uniform float scroll_speed = 1.5;
uniform float offset : hint_range(0.0, 1.0, 0.001) = 0.0;

void fragment() {
	COLOR = baseColor;
	COLOR.a = texture(line_texture, vec2(offset + UV.x*0.25*0.4 - TIME*scroll_speed, UV.y)).r;
}
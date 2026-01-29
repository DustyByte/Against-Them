shader_type canvas_item;

uniform float flickerSlider : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform vec4 color : source_color;

float get_r(vec2 center, vec2 coord) {
	return sqrt(pow(coord.x - center.x, 2.0) + pow(coord.y - center.y, 2.0));
}

void fragment() {
	COLOR = vec4(1.0, 1.0, 1.0, 0.0);
	vec2 center = vec2(0.5, 0.5);
	float r = get_r(center, UV);
	
	if (r < flickerSlider) {
		r = -2.0*(r - flickerSlider);
		COLOR = vec4(color.r, color.g, color.b, r);
	}
}
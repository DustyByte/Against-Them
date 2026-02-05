shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

uniform float strength : hint_range(0.0, 0.5) = 0.1;
uniform float radius : hint_range(0.0, 0.5) = 0.25;
uniform vec2 center = vec2(0.5, 0.5);

float length_squared(vec2 v) {
	return v.x*v.x + v.y*v.y;
}

void fragment() {
	vec2 direction = -(center - UV);
	float dist = length(direction);
	float mask = smoothstep(radius, 0.0, dist);
	vec2 distortion = direction * strength * mask;

	COLOR = texture(screen_texture, SCREEN_UV + distortion);
}
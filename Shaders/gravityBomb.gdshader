shader_type canvas_item;

uniform sampler2D gradient;
uniform sampler2D fade;
uniform float radius : hint_range(0.0, 0.75, 0.001) = 0.5;

void fragment() {
	vec2 center = vec2(0.5);
	float dist = distance(center, UV);

	float mask = 1.0 - step(radius, dist);

	COLOR = texture(gradient, vec2(dist / radius, 0.0));
	COLOR.a *= texture(fade, UV).b * mask;
}
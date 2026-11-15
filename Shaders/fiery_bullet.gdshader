shader_type canvas_item;

// Torcher's fire bolt. The two linear gradients it used to read from textures
// (top-to-bottom and bottom-to-top, black to white) are computed from UV here,
// saving two texture reads per pixel. Only the blue channel decides the result.

uniform sampler2D texture1 : repeat_enable;   // scrolling noise
uniform sampler2D texture3 : repeat_enable;   // round mask
uniform sampler2D texture5 : repeat_enable;   // colour ramp

uniform float speed = 1.5;

void fragment() {
	vec2 uv = vec2(UV.x, UV.y + TIME*speed);
	float b = (texture(texture1, uv).b + UV.y) * texture(texture3, UV).b - (1.0 - UV.y) * 1.45;
	float colOneChannel = clamp(b, 0.0, 1.0);
	COLOR = texture(texture5, vec2(colOneChannel, 0.0)) * colOneChannel;
}

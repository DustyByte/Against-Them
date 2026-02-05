shader_type canvas_item;

uniform sampler2D image : repeat_enable;
uniform sampler2D noiseTexture : repeat_enable;
uniform float strength: hint_range(0.0, 5.0, 0.001) = 0.1;

void fragment() {
	vec2 direction = (UV - vec2(0.5));
	float offset = (texture(noiseTexture, UV+(-TIME+0.5)).b - 0.5) * strength;

	COLOR = texture(image, UV+(direction*offset));
}
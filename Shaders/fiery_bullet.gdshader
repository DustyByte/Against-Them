shader_type canvas_item;

uniform sampler2D texture1 : repeat_enable;
uniform sampler2D texture2 : repeat_enable;
uniform sampler2D texture3 : repeat_enable;
uniform sampler2D texture4 : repeat_enable;
uniform sampler2D texture5 : repeat_enable;

uniform float speed = 1.5;

void fragment() {
	vec2 uv = vec2(UV.x, UV.y + TIME*speed);
	vec4 color = texture(texture1, uv) + texture(texture2, UV);
	color *= texture(texture3, UV);
	color -= texture(texture4, UV)*1.45;

	float colOneChannel = clamp(color.b, 0.0, 1.0);
	COLOR = texture(texture5, vec2(colOneChannel, 0.0)) * colOneChannel;
}
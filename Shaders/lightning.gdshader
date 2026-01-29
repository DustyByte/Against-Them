shader_type canvas_item;

uniform sampler2D lightningTexture : repeat_enable;
uniform float slider : hint_range(0.0, 1.0, 0.001) = 1.0;
uniform float randomOffset : hint_range(0.0, 1.0, 0.001) = 0.0;


vec2 invert(vec2 toInvert) {
	return vec2(toInvert.y, toInvert.x);
}

void fragment() {
	vec4 textureColor = texture(lightningTexture, invert(UV) + vec2(0.0, randomOffset));
	
	if (UV.x < slider) {
		COLOR.a = 1.0-textureColor.b;
	}else {
		COLOR.a = 0.0;
	}
}

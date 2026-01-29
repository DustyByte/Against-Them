shader_type canvas_item;

uniform float alphaIntensity : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 hitColor: source_color = vec4(1, 1, 1, 1);

void fragment() {
	if (COLOR.a != 0.0) {
		vec4 dynamicHitColor = vec4(hitColor.r, hitColor.g, hitColor.b, alphaIntensity);
		if (alphaIntensity <= 1.0) {
			COLOR = dynamicHitColor;
		}
	}
}
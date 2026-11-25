shader_type canvas_item;
// The Wisp's flame (Scripts/laser_orb.gd draws it behind the wisp's body):
// the whole flame leans left and right, bending more towards the tip;
// ripples run up it (the tongues flick); it stretches taller and settles; its
// light flickers. The body sprite on top stays still.
uniform float phase = 0.0;
const float BASE = 0.70;   // where the flame meets the body, in UV

float wander(float t) {
	return sin(t * 1.7) * 0.5 + sin(t * 2.9 + 1.1) * 0.3 + sin(t * 4.7 + 2.3) * 0.2;
}

void fragment() {
	float t = TIME + phase;
	float up = clamp((BASE - UV.y) / BASE, 0.0, 1.0);   // 0 at the body, 1 at the tip
	vec2 uv = UV;
	// Taller and shorter, from the base up.
	float stretch = 1.0 + wander(t * 2.2 + 5.0) * 0.09;
	if (uv.y < BASE) {
		uv.y = BASE - (BASE - uv.y) / stretch;
	}
	// Lean (whole flame, bending) and licks (ripples running upwards).
	float lean = wander(t * 1.3) * 0.11;
	float licks = sin(UV.y * 16.0 + t * 9.0) * 0.02 + sin(UV.y * 29.0 + t * 14.0) * 0.009;
	uv.x -= lean * up * up + licks * up;
	vec4 c = texture(TEXTURE, uv);
	c.rgb *= 1.0 + wander(t * 7.0) * 0.08 * (0.3 + 0.7 * up);
	COLOR = c * COLOR;
}

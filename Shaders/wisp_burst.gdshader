shader_type canvas_item;
// A burst on a blank quad for the Wisp: the muzzle flare at its eye
// (sparks = 0: glow and glint) or the splash where the beam lands (sparks > 0:
// embers flying back). age 0 -> 1 over the burst; looping keeps the splash
// going while a held (Focus) beam stays on target.
uniform float age = 0.0;
uniform float size_px = 80.0;
uniform int sparks = 0;
uniform float glint = 1.0;
uniform vec4 hot : source_color = vec4(1.0, 0.95, 0.92, 1.0);
uniform vec4 ember : source_color = vec4(0.95, 0.32, 0.36, 1.0);
uniform bool looping = false;
uniform vec2 aim = vec2(1.0, 0.0);   // sparks fly back against the beam

float hash(float n) { return fract(sin(n * 91.3 + 7.1) * 43758.5453); }

void fragment() {
	vec2 p = (UV - 0.5) * size_px;
	float r = length(p);
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	// glow and four-point glint, swelling then fading
	float a = looping ? 0.6 + 0.2 * sin(TIME * 23.0) : (1.0 - age);
	float glow = exp(-pow(r / (size_px * 0.13 * (0.6 + age)), 2.0)) * a;
	float star = (exp(-abs(p.y) / 1.2) * exp(-abs(p.x) / (size_px * 0.18)) + exp(-abs(p.x) / 1.2) * exp(-abs(p.y) / (size_px * 0.18))) * a * glint;
	col += hot.rgb * (glow + star);
	alpha += glow + star * 0.8;
	for (int i = 0; i < 16; i++) {
		if (i >= sparks) { break; }
		float fi = float(i);
		float t = looping ? fract(TIME * 1.6 + hash(fi)) : age;
		float ang = atan(-aim.y, -aim.x) + (hash(fi + 2.0) - 0.5) * 2.6;
		float dist = size_px * 0.42 * (0.4 + 0.6 * hash(fi + 4.0)) * (1.0 - pow(1.0 - t, 2.0));
		vec2 at = vec2(cos(ang), sin(ang)) * dist + vec2(0.0, size_px * 0.15 * t * t);
		float sr = mix(2.4, 0.6, t);
		float e = 1.0 - smoothstep(sr * 0.3, sr, length(p - at));
		col += mix(hot.rgb, ember.rgb, t) * e;
		alpha += e * (1.0 - t);
	}
	COLOR = vec4(col / max(alpha, 0.001), clamp(alpha, 0.0, 1.0));
}

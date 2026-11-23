shader_type canvas_item;
// Gravity bomb zone (design draft 2): the ground itself gives way. On impact
// cracks split out from the centre and the middle shatters into plates; the
// ground inside sinks (darker and pinched towards the centre) and loose
// chips of it creep inwards. Colours come from the ground under it, plus a
// faint violet seep in the deepest cracks. At the end the cracks close up
// and fade. Draw it on a quad scaled like the zone (x = radius,
// y = 0.65 x radius for the top-down look).
//   spawn:    0 -> 1 right after impact (about 0.35 s)
//   collapse: 0 -> 1 when the zone ends (about 0.5 s)

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float spawn : hint_range(0.0, 1.0) = 1.0;
uniform float collapse : hint_range(0.0, 1.0) = 0.0;
uniform float sink : hint_range(0.0, 2.0) = 1.0;
uniform vec4 seep_color : source_color = vec4(0.62, 0.48, 0.80, 1.0);
uniform float seed = 0.0;   // a different crack pattern per bomb

const int CRACKS = 9;

float hash1(float n) {
	return fract(sin(n * 12.9898 + seed * 7.13) * 43758.5453);
}

vec2 hash2(vec2 p) {
	p += seed;
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash1(i), hash1(i + 1.0), f * f * (3.0 - 2.0 * f));
}

float wrap_angle(float a) {
	return mod(a + PI, TAU) - PI;
}

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;   // 0 at the centre, 1 at the zone's edge
	if (r > 1.0) {
		discard;
	}
	float a = atan(c.y, c.x);
	float open = 1.0 - pow(1.0 - spawn, 3.0);            // cracks race out, then settle
	float close = smoothstep(0.0, 1.0, collapse);
	float spread = open * (1.0 - close);                 // how far the cracks reach
	float hold = smoothstep(0.0, 0.6, spawn) * (1.0 - close);
	vec2 dir = r > 0.0001 ? c / length(c) : vec2(0.0);

	// The ground sinks: pinched towards the centre, darker in the middle.
	float pinch = sink * hold * smoothstep(1.0, 0.1, r) * 10.0;
	vec3 ground = texture(screen_texture, SCREEN_UV + dir * pinch * r * SCREEN_PIXEL_SIZE * 2.0).rgb;
	vec3 col = ground * (1.0 - 0.5 * hold * smoothstep(0.92, 0.0, r));

	// Split lines running out from the centre, jagged and tapering.
	float crack = 0.0;
	float lip = 0.0;
	for (int i = 0; i < CRACKS; i++) {
		float fi = float(i);
		float base = (fi + 0.7 * hash1(fi + 1.0)) / float(CRACKS) * TAU;
		float len = (0.7 + 0.3 * hash1(fi + 11.0)) * spread;
		float jag = (noise1(r * 7.0 + fi * 13.0) - 0.5) * 0.2 + (noise1(r * 22.0 + fi * 5.0) - 0.5) * 0.06;
		float d = abs(wrap_angle(a - base) * r - jag);
		float w = mix(0.06, 0.014, clamp(r / max(len, 0.001), 0.0, 1.0));
		float on = step(r, len) * step(0.02, r);
		crack = max(crack, (1.0 - smoothstep(w * 0.45, w, d)) * on);
		lip = max(lip, (1.0 - smoothstep(w, w * 2.2, d)) * on);
	}

	// The middle shatters into plates.
	vec2 g = c * 2.0 / 0.16;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 o = vec2(float(i), float(j));
			float d = length(o + 0.15 + 0.7 * hash2(cell + o) - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	float plates = 1.0 - smoothstep(0.03, 0.1, d2 - d1);
	float plate_reach = 0.5 * spread;
	plates *= 1.0 - smoothstep(plate_reach * 0.7, plate_reach, r);
	crack = max(crack, plates * 0.85);
	lip = max(lip, plates * 0.6);

	// The crater's broken rim: a ring split where the ground tore loose.
	float rim_r = 0.86;
	float rim_gap = step(0.35, noise1(a * 5.0 + 2.0));
	float rim_d = abs(r - rim_r - (noise1(a * 14.0) - 0.5) * 0.04);
	float rim_on = rim_gap * smoothstep(0.75, 1.0, spread);
	crack = max(crack, (1.0 - smoothstep(0.008, 0.02, rim_d)) * rim_on * 0.6);   // shallower than the splits
	lip = max(lip, (1.0 - smoothstep(0.02, 0.045, rim_d)) * rim_on);

	// Shading: a light broken lip around each split, a dark gap inside it,
	// and a faint violet seep at the bottom of the widest cracks.
	col = mix(col, ground * 1.3 + 0.025 + seep_color.rgb * 0.06, (lip - crack) * 0.55);
	col = mix(col, ground * 0.22, crack);
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
	col += seep_color.rgb * crack * smoothstep(0.9, 0.0, r) * 0.5 * pulse * hold;
	// A faint violet haze over the sunken ground, so the zone is easy to spot.
	col += seep_color.rgb * 0.07 * hold * smoothstep(1.0, 0.25, r);

	// Loose chips of ground creeping inwards.
	vec2 pc = vec2(a / TAU * 22.0, r * 6.0 + TIME * 1.1);
	vec2 chip_cell = floor(pc);
	vec2 cf = fract(pc) - 0.5;
	vec2 h = hash2(chip_cell + 3.7);
	float chip = step(0.78, h.x) * (1.0 - smoothstep(0.1, 0.22, length(cf + (h - 0.5) * 0.3)));
	chip *= smoothstep(1.0, 0.75, r) * smoothstep(0.08, 0.25, r) * hold;
	col = mix(col, ground * 1.45 + 0.02, chip * 0.8);

	// Impact: a soft puff of dust rolling out over the ground.
	float puff_r = open;
	float puff = exp(-pow((r - puff_r) * 7.0, 2.0)) * (1.0 - spawn);
	col = mix(col, ground * 1.6 + 0.05, puff * 0.6);

	float alpha = 1.0 - smoothstep(0.8, 1.0, r);   // soft outer edge
	alpha *= 1.0 - smoothstep(0.75, 1.0, collapse);
	COLOR = vec4(col, alpha);
}

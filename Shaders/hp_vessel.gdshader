shader_type canvas_item;
// Echo's HP vessel: a hexagonal glass cell (same shape language as the Echoes
// icon) holding glowing fluid. Everything is drawn here in one pass, so the
// indicator stays sharp at any size and costs a single draw call.

uniform float fill_level : hint_range(0.0, 1.0) = 1.0;   // 1 = full HP
uniform vec4 fluid_color : source_color = vec4(0.35, 0.95, 0.85, 1.0);
uniform vec4 frame_color : source_color = vec4(0.62, 0.88, 0.95, 1.0);
uniform vec4 danger_color : source_color = vec4(0.95, 0.35, 0.42, 1.0);
uniform float slosh = 0.0;    // 0..1, surface agitation after a hit or heal
uniform float tilt = 0.0;     // surface lean while sloshing
uniform float flash = 0.0;    // 0..1, white flash on hit
uniform float danger = 0.0;   // 0..1, low-HP warning pulse strength

const float OUTER = 0.80;     // apothem of the frame hexagon (UV space * 2)
const float INNER = 0.68;     // apothem of the glass cell

// Pointy-top hexagon, rounded corners. Negative inside.
float sd_hex(vec2 p, float apothem, float round_r) {
	p = abs(p.yx);
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	float r = apothem - round_r;
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y) - round_r;
}

// Bubble constants, worked out once instead of per pixel.
const float BUBBLE_SPEED[6] = float[](0.2667, 0.3470, 0.3630, 0.2318, 0.2368, 0.1893);
const float BUBBLE_OFFSET[6] = float[](0.5416, 0.5311, 0.0694, 0.4772, 0.3167, 0.7829);
const float BUBBLE_X[6] = float[](-0.3067, -0.4010, 0.0212, -0.3346, 0.0613, -0.1761);
const float BUBBLE_R[6] = float[](0.0318, 0.0316, 0.0252, 0.0253, 0.0233, 0.0334);
// Side-to-side wobble sin(t + i) * 0.03, split as sin(t)cos(i) + cos(t)sin(i)
// so each pixel needs one sin/cos pair instead of one sin per bubble.
const float WOBBLE_C[6] = float[](0.0162, -0.0125, -0.0297, -0.0196, 0.0085, 0.0288);
const float WOBBLE_S[6] = float[](0.0252, 0.0273, 0.0042, -0.0227, -0.0288, -0.0084);
const float GLOW_REACH = 0.2;   // past this distance outside the frame the glow is invisible

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	vec2 q = vec2(p.x, -p.y);              // y up
	float aa = fwidth(p.x) * 1.2;

	float d_out = sd_hex(p, OUTER, 0.10);
	// Square corners beyond the glow show nothing: skip all the work below.
	if (d_out > GLOW_REACH) {
		discard;
	}
	float d_in = sd_hex(p, INNER, 0.08);

	// Danger pulse tints the frame toward crimson.
	float pulse = danger * (0.55 + 0.45 * sin(TIME * 6.0));
	vec3 frame = mix(frame_color.rgb, danger_color.rgb, pulse);

	// ---- frame ----
	vec4 col = vec4(0.0);
	float in_out = 1.0 - smoothstep(-aa, aa, d_out);
	col = mix(col, vec4(0.03, 0.04, 0.065, 0.92), in_out);
	// outer rim and inner bevel lines
	float rim = 1.0 - smoothstep(0.0, aa * 1.5, abs(d_out + 0.012) - 0.01);
	float bevel = 1.0 - smoothstep(0.0, aa * 1.5, abs(d_in - 0.018) - 0.004);
	col.rgb = mix(col.rgb, frame, rim * (0.75 + 0.25 * pulse));
	col.rgb = mix(col.rgb, frame, bevel * 0.28);

	// ---- glass cell ----
	float in_cell = 1.0 - smoothstep(-aa, aa, d_in);
	col.rgb = mix(col.rgb, vec3(0.015, 0.025, 0.045), in_cell);

	// vertical extent of the cell (pointy top: vertex = apothem / cos 30)
	float top = INNER * 1.1547 - 0.04;
	float level = mix(-top, top, clamp(fill_level, 0.0, 1.0));
	// keep a sliver visible above empty and below full so the surface reads
	level = (fill_level <= 0.0) ? -top - 0.1 : level;

	float t = TIME * 3.0;
	float amp = 0.018 + slosh * 0.09;
	float waves = sin(q.x * 4.5 + t * 0.8) * amp
		+ sin(q.x * 9.0 - t * 1.3) * amp * 0.5
		+ sin(q.x * 19.0 + t * 2.4) * amp * 0.2;
	float surface = level + waves + tilt * q.x * slosh;

	float below = 1.0 - smoothstep(surface - aa, surface + aa, q.y);
	float fluid = below * in_cell;

	// depth shading: bright at the surface, deep toward the bottom
	float depth = clamp((surface - q.y) / 1.4, 0.0, 1.0);
	vec3 fc = fluid_color.rgb;
	vec3 fluid_rgb = mix(fc * 1.05, fc * 0.32, smoothstep(0.0, 1.0, depth));
	// slow internal currents
	float current = sin(q.y * 9.0 + sin(q.x * 3.0 + TIME * 1.1) * 1.6 - TIME * 1.7);
	fluid_rgb += fc * current * 0.06;
	// bright crest line at the surface
	float crest = 1.0 - smoothstep(0.0, 0.035, surface - q.y);
	fluid_rgb += mix(fc, vec3(1.0), 0.5) * crest * 0.55;

	// rising bubbles
	float ws = sin(TIME * 2.0);
	float wc = cos(TIME * 2.0);
	for (int i = 0; i < 6; i++) {
		float phase = fract(TIME * BUBBLE_SPEED[i] + BUBBLE_OFFSET[i]);
		float bx = BUBBLE_X[i] + ws * WOBBLE_C[i] + wc * WOBBLE_S[i];
		float by = mix(-top, surface, phase);
		float r = BUBBLE_R[i];
		float b = 1.0 - smoothstep(r - aa, r + aa, length(q - vec2(bx, by)));
		fluid_rgb = mix(fluid_rgb, mix(fc, vec3(1.0), 0.6), b * 0.55 * (1.0 - phase * 0.6));
	}

	col.rgb = mix(col.rgb, fluid_rgb, fluid);

	// level ticks at 25 / 50 / 75 %, hugging both glass walls
	for (int i = 1; i <= 3; i++) {
		float ty = mix(-top, top, float(i) * 0.25);
		float tick = (1.0 - smoothstep(0.0, aa, abs(q.y - ty) - 0.004))
			* step(-0.11, d_in) * step(d_in, -0.035);
		col.rgb = mix(col.rgb, frame, tick * in_cell * 0.4);
	}

	// glass highlight streak (top-left) and soft inner shadow at the walls
	float streak = smoothstep(0.08, 0.0, abs(q.x + q.y * 0.55 + 0.32)) * smoothstep(-0.1, 0.5, q.y);
	col.rgb += vec3(0.8, 0.95, 1.0) * streak * 0.09 * in_cell;
	col.rgb *= mix(1.0, 0.7, smoothstep(-0.12, 0.0, d_in) * in_cell);

	// hit flash
	col.rgb = mix(col.rgb, vec3(1.0), flash * 0.45 * (fluid + rim));

	// soft outer glow in the fluid color
	float glow = exp(-max(d_out, 0.0) * 18.0) * (1.0 - in_out);
	vec3 glow_rgb = mix(fc, danger_color.rgb, pulse);
	col.rgb = mix(col.rgb, glow_rgb, glow * (1.0 - col.a));
	col.a = max(col.a, glow * (0.22 + 0.25 * pulse));

	COLOR = col;
}

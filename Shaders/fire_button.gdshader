shader_type canvas_item;
// Fire button: a round glass button with a bullet icon and reticle marks,
// tinted with the selected weapon's accent. Pressing pushes it in, flashes it
// and sends out a ripple ring. Pixel units, one pass, no textures.

uniform vec2 rect_size = vec2(220.0, 220.0);
uniform float radius = 82.0;
uniform vec4 accent : source_color = vec4(0.62, 0.88, 0.95, 1.0);
uniform float pressed : hint_range(0.0, 1.0) = 0.0;   // held-down look
uniform float ripple : hint_range(0.0, 1.0) = 1.0;    // 0 = just pressed .. 1 = gone

float ring(float d, float width) {
	return 1.0 - smoothstep(width * 0.5 - 0.75, width * 0.5 + 0.75, abs(d));
}

float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Bullet pointing up: a body with a rounded (ogive) tip and a rim at the base.
float sd_bullet(vec2 p, float s) {
	float body = sd_round_box(p - vec2(0.0, 0.18 * s), vec2(0.17 * s, 0.3 * s), 0.02 * s);
	// tip: an ellipse sitting on top of the body
	vec2 tp = (p - vec2(0.0, -0.12 * s)) / vec2(0.17 * s, 0.42 * s);
	float tip = (length(tp) - 1.0) * 0.17 * s;
	tip = max(tip, p.y - (-0.12 * s));                 // keep the top half only
	float base_rim = sd_round_box(p - vec2(0.0, 0.5 * s), vec2(0.2 * s, 0.04 * s), 0.015 * s);
	return min(min(body, tip), base_rim);
}

void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	float rad = radius * (1.0 - 0.05 * pressed);          // pushed in
	float r = length(p);
	float ripple_r = mix(rad, rad + 26.0, ripple);
	if (r > max(rad + 14.0, ripple_r + 3.0)) {
		discard;
	}

	vec3 acc = accent.rgb;
	vec4 col = vec4(0.0);

	// ---- disc ----
	float inside = 1.0 - smoothstep(rad - 1.0, rad + 1.0, r);
	float rn = r / rad;
	vec3 disc = mix(vec3(0.05, 0.075, 0.11), vec3(0.025, 0.035, 0.06), rn);
	disc += acc * (0.06 + 0.16 * pressed) * (1.0 - rn);
	col = mix(col, vec4(disc, 0.62 + 0.2 * pressed), inside);

	// rims: outer bright, inner faint
	float rim = ring(r - (rad - 1.5), 2.4);
	vec3 rim_rgb = mix(acc, vec3(1.0), 0.2 + 0.4 * pressed);
	col.rgb = mix(col.rgb, rim_rgb, rim * (0.75 + 0.25 * pressed));
	col.a = max(col.a, rim);
	float inner = ring(r - rad * 0.78, 1.2);
	col.rgb = mix(col.rgb, acc, inner * 0.22);

	// reticle marks at the four sides, between the two rims
	vec2 ap = abs(p);
	float along = max(ap.x, ap.y);
	float across = min(ap.x, ap.y);
	float mark = (1.0 - smoothstep(1.0, 2.0, across))
		* step(rad * 0.8, along) * step(along, rad * 0.93);
	col.rgb = mix(col.rgb, acc, mark * 0.6);

	// bullet icon
	float s = rad * 0.95;
	float d_b = sd_bullet(p, s);
	float bullet = 1.0 - smoothstep(-1.0, 1.0, d_b);
	vec3 bullet_rgb = mix(acc, vec3(1.0), 0.4 + 0.35 * pressed);
	// a darker band where the casing meets the tip
	float seam = (1.0 - smoothstep(0.0, 1.5, abs(p.y - (-0.12 * s)) - 0.5)) * bullet;
	float b_glow = exp(-max(d_b, 0.0) * 0.25) * inside;
	col.rgb += acc * b_glow * (0.2 + 0.25 * pressed);
	col.rgb = mix(col.rgb, bullet_rgb, bullet);
	col.a = max(col.a, bullet);
	col.rgb = mix(col.rgb, acc * 0.45, seam * 0.6);

	// glass highlight
	vec2 hl = p / rad - vec2(-0.3, -0.38);
	col.rgb += vec3(0.8, 0.92, 1.0) * (1.0 - smoothstep(0.0, 0.4, length(hl))) * 0.07 * inside;

	// press flash
	col.rgb = mix(col.rgb, vec3(1.0), (1.0 - ripple) * 0.25 * inside);

	// outer glow
	float glow = exp(-max(r - rad, 0.0) * 0.2) * step(rad, r);
	col.rgb = mix(col.rgb, acc, glow * (1.0 - col.a));
	col.a = max(col.a, glow * (0.15 + 0.3 * pressed));

	// ripple ring expanding outward after a press
	float rip = ring(r - ripple_r, 2.5) * (1.0 - ripple);
	col.rgb = mix(col.rgb, mix(acc, vec3(1.0), 0.4), rip);
	col.a = max(col.a, rip * 0.8);

	COLOR = col;
}

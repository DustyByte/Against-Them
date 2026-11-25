shader_type canvas_item;
// Fire button: a round glass button with a bullet icon and reticle marks,
// tinted with the selected weapon's accent. Pressing pushes it in, flashes it
// and sends out a ripple ring. Pixel units, one pass, no textures.
//
// It is also an aim stick (on_run_hud.gd): dragged, the face shrinks into a
// knob that follows the finger inside the ring, its bullet turning to point the
// way it aims; pulled past the ring (firing) the ring lights up. At aim = 0 it
// looks exactly like the plain button.

uniform vec2 rect_size = vec2(300.0, 300.0);
uniform float radius = 82.0;
uniform vec4 accent : source_color = vec4(0.62, 0.88, 0.95, 1.0);
uniform float pressed : hint_range(0.0, 1.0) = 0.0;   // held-down look
uniform float ripple : hint_range(0.0, 1.0) = 1.0;    // 0 = just pressed .. 1 = gone
uniform float aim : hint_range(0.0, 1.0) = 0.0;       // 0 = button .. 1 = aim stick
uniform vec2 knob_offset = vec2(0.0);                 // px from the centre, within the ring
uniform float bullet_angle = 0.0;                     // radians the bullet turns (0 = up)
uniform float firing : hint_range(0.0, 1.0) = 0.0;    // knob pulled past the ring
uniform float aim_grow = 0.35;                        // the ring is this much bigger while aiming

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

vec2 rotated(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	// pushed in (button only); the ring widens while aiming, the knob stays its size
	float rad = radius * (1.0 - 0.05 * pressed * (1.0 - aim)) * (1.0 + aim_grow * aim);
	float r = length(p);
	float ripple_r = mix(rad, rad + 26.0, ripple);
	// The face: the whole disc as a button, a half-size knob while aiming.
	vec2 kc = knob_offset * aim;
	float kr = mix(rad, radius * 0.5, aim);
	vec2 pk = p - kc;
	float rk = length(pk);
	if (r > max(rad + 14.0, ripple_r + 3.0) && rk > kr + 14.0) {
		discard;
	}

	vec3 acc = accent.rgb;
	vec4 col = vec4(0.0);
	float lit = max(pressed * (1.0 - aim), firing);

	// ---- disc (a dimmer well under the knob while aiming) ----
	float inside = 1.0 - smoothstep(rad - 1.0, rad + 1.0, r);
	float rn = r / rad;
	vec3 disc = mix(vec3(0.05, 0.075, 0.11), vec3(0.025, 0.035, 0.06), rn);
	disc += acc * (0.06 + 0.16 * pressed) * (1.0 - rn) * (1.0 - aim);
	col = mix(col, vec4(disc, mix(0.62 + 0.2 * pressed, 0.42, aim)), inside);

	// rims: outer bright (brighter and wider while firing), inner faint
	float rim = ring(r - (rad - 1.5), 2.4 + 2.2 * firing);
	vec3 rim_rgb = mix(acc, vec3(1.0), 0.2 + 0.4 * lit);
	col.rgb = mix(col.rgb, rim_rgb, rim * (0.75 + 0.25 * lit));
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

	// ---- knob (aiming only) ----
	float k_in = 0.0;
	if (aim > 0.0) {
		k_in = (1.0 - smoothstep(kr - 1.0, kr + 1.0, rk)) * aim;
		float kn = rk / kr;
		vec3 knob = mix(vec3(0.07, 0.1, 0.15), vec3(0.03, 0.045, 0.07), kn);
		knob += acc * (0.14 + 0.14 * firing) * (1.0 - kn);
		col.rgb = mix(col.rgb, knob, k_in);
		col.a = max(col.a, k_in * 0.9);
		float k_rim = ring(rk - (kr - 1.2), 2.0) * aim;
		col.rgb = mix(col.rgb, mix(acc, vec3(1.0), 0.35 + 0.3 * firing), k_rim);
		col.a = max(col.a, k_rim);
	}
	float face = max(inside * (1.0 - aim), k_in);

	// bullet icon, on the face, turned towards the aim
	float s = kr * 0.95;
	vec2 pb = rotated(pk, -bullet_angle * aim);
	float d_b = sd_bullet(pb, s);
	float bullet = 1.0 - smoothstep(-1.0, 1.0, d_b);
	vec3 bullet_rgb = mix(acc, vec3(1.0), 0.4 + 0.35 * max(pressed, firing));
	// a darker band where the casing meets the tip
	float seam = (1.0 - smoothstep(0.0, 1.5, abs(pb.y - (-0.12 * s)) - 0.5)) * bullet;
	float b_glow = exp(-max(d_b, 0.0) * 0.25) * face;
	col.rgb += acc * b_glow * (0.2 + 0.25 * max(pressed, firing));
	col.rgb = mix(col.rgb, bullet_rgb, bullet);
	col.a = max(col.a, bullet);
	col.rgb = mix(col.rgb, acc * 0.45, seam * 0.6);

	// glass highlight, on the face
	vec2 hl = pk / kr - vec2(-0.3, -0.38);
	col.rgb += vec3(0.8, 0.92, 1.0) * (1.0 - smoothstep(0.0, 0.4, length(hl))) * 0.07 * face;

	// press / shot flash
	col.rgb = mix(col.rgb, vec3(1.0), (1.0 - ripple) * 0.25 * max(inside, k_in));

	// outer glow
	float glow = exp(-max(r - rad, 0.0) * 0.2) * step(rad, r);
	col.rgb = mix(col.rgb, acc, glow * (1.0 - col.a));
	col.a = max(col.a, glow * (0.15 + 0.3 * lit));

	// ripple ring expanding outward after a press or shot
	float rip = ring(r - ripple_r, 2.5) * (1.0 - ripple);
	col.rgb = mix(col.rgb, mix(acc, vec3(1.0), 0.4), rip);
	col.a = max(col.a, rip * 0.8);

	COLOR = col;
}

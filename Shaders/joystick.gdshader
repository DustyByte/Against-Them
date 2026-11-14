shader_type canvas_item;
// Touch joystick: a faint glass base with a cyan rim and direction marks, and
// a glass orb knob. While held, the rim lights up toward the push direction
// and a faint tether joins the center to the knob. Pixel units, one pass.

uniform vec2 rect_size = vec2(320.0, 320.0);
uniform float base_radius = 135.0;
uniform float knob_radius = 67.0;
uniform vec2 knob_offset = vec2(0.0);   // knob center relative to base center, px
uniform float held : hint_range(0.0, 1.0) = 0.0;
uniform vec4 frame_color : source_color = vec4(0.62, 0.88, 0.95, 1.0);

float ring(float d, float width) {
	return 1.0 - smoothstep(width * 0.5 - 0.75, width * 0.5 + 0.75, abs(d));
}

void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;   // px from base center
	float r = length(p);
	vec2 kp = p - knob_offset;
	float kr = length(kp);
	float pad = 16.0;
	if (r > base_radius + pad && kr > knob_radius + pad) {
		discard;
	}

	vec3 fc = frame_color.rgb;
	vec4 col = vec4(0.0);

	// ---- base ----
	float in_base = 1.0 - smoothstep(base_radius - 1.0, base_radius + 1.0, r);
	float base_shade = mix(0.42, 0.22, r / base_radius);   // denser toward the middle
	col = mix(col, vec4(0.02, 0.035, 0.06, base_shade * (0.75 + 0.25 * held)), in_base);

	// direction the knob is pushed, and how far (0..1)
	float push = clamp(length(knob_offset) / base_radius, 0.0, 1.0);
	vec2 dir = push > 0.001 ? normalize(knob_offset) : vec2(0.0);
	float facing = r > 0.0 ? dot(p / r, dir) : 0.0;
	float arc = smoothstep(0.25, 0.85, facing) * push * held;   // wide enough to show past the knob

	// rim: dim all around, bright toward the push
	float rim = ring(r - (base_radius - 1.5), 2.0);
	vec3 rim_rgb = mix(fc, vec3(1.0), arc * 0.5);
	float rim_a = 0.38 + 0.22 * held + 0.4 * arc;
	col.rgb = mix(col.rgb, rim_rgb, rim * rim_a);
	col.a = max(col.a, rim * rim_a);
	// glow spilling outward from the lit arc
	float out_glow = exp(-max(r - base_radius, 0.0) * 0.22) * step(base_radius - 1.0, r) * arc;
	col.rgb = mix(col.rgb, fc, out_glow * 0.6 * (1.0 - col.a));
	col.a = max(col.a, out_glow * 0.45);

	// inner guide ring
	float guide = ring(r - base_radius * 0.55, 1.2);
	col.rgb = mix(col.rgb, fc, guide * 0.14);
	col.a = max(col.a, guide * 0.14 * in_base);

	// four direction marks just inside the rim
	vec2 ap = abs(p);
	float along = max(ap.x, ap.y);
	float across = min(ap.x, ap.y);
	float mark = (1.0 - smoothstep(1.0, 2.0, across))
		* step(base_radius - 20.0, along) * step(along, base_radius - 9.0);
	col.rgb = mix(col.rgb, fc, mark * 0.5);
	col.a = max(col.a, mark * 0.5);

	// tether from center to knob while held
	float tl = clamp(dot(p, knob_offset) / max(dot(knob_offset, knob_offset), 1.0), 0.0, 1.0);
	float td = length(p - knob_offset * tl);
	float tether = (1.0 - smoothstep(0.5, 2.0, td)) * held * push * step(knob_radius, kr);
	col.rgb = mix(col.rgb, fc, tether * 0.35);
	col.a = max(col.a, tether * 0.35);

	// ---- knob ----
	float in_knob = 1.0 - smoothstep(knob_radius - 1.0, knob_radius + 1.0, kr);
	// soft shadow/glow around the knob
	float k_glow = exp(-max(kr - knob_radius, 0.0) * 0.18) * step(knob_radius, kr);
	col.rgb = mix(col.rgb, fc, k_glow * (0.08 + 0.3 * held) * (1.0 - col.a * 0.5));
	col.a = max(col.a, k_glow * (0.1 + 0.3 * held));

	float kn = kr / knob_radius;                         // 0 center .. 1 edge
	vec3 knob_rgb = mix(vec3(0.09, 0.14, 0.2), vec3(0.03, 0.05, 0.08), kn);
	knob_rgb += fc * (1.0 - smoothstep(0.0, 0.35, kn)) * (0.14 + 0.22 * held);   // core glow
	// glass highlight: a soft crescent toward the top-left
	vec2 hl = (kp / knob_radius - vec2(-0.32, -0.38)) * vec2(1.0, 1.8);
	knob_rgb += vec3(0.75, 0.9, 1.0) * (1.0 - smoothstep(0.12, 0.26, length(hl))) * 0.18;
	col = mix(col, vec4(knob_rgb, 0.82 + 0.1 * held), in_knob);
	float k_rim = ring(kr - (knob_radius - 1.5), 2.2);
	col.rgb = mix(col.rgb, mix(fc, vec3(1.0), 0.3 * held), k_rim * (0.7 + 0.3 * held));
	col.a = max(col.a, k_rim);
	// small center dot
	float dot_c = 1.0 - smoothstep(3.0, 4.5, kr);
	col.rgb = mix(col.rgb, mix(fc, vec3(1.0), 0.5), dot_c * (0.6 + 0.4 * held));

	COLOR = col;
}

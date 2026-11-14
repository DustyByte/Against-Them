shader_type canvas_item;
// HUD pause button: a small glass hexagon with two glowing bars, in the same
// shape language as the HP vessel and the level badge. One pass, no textures.

uniform vec4 frame_color : source_color = vec4(0.62, 0.88, 0.95, 1.0);

const float APOTHEM = 0.56;        // hexagon size, in UV * 2 space

float sd_hex(vec2 p, float apothem, float round_r) {
	p = abs(p.yx);
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	float r = apothem - round_r;
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y) - round_r;
}

float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float aa = fwidth(p.x) * 1.2;

	float d = sd_hex(p, APOTHEM, 0.07);
	if (d > 0.3) {
		discard;
	}

	vec4 col = vec4(0.0);
	float inside = 1.0 - smoothstep(-aa, aa, d);
	// glass body, slightly lighter at the top
	vec3 body = mix(vec3(0.035, 0.05, 0.08), vec3(0.02, 0.03, 0.05), smoothstep(-0.5, 0.5, p.y));
	col = mix(col, vec4(body, 0.9), inside);

	// rim + faint inner bevel
	float rim = 1.0 - smoothstep(0.0, aa * 1.5, abs(d + 0.02) - 0.015);
	float bevel = 1.0 - smoothstep(0.0, aa * 1.5, abs(d + 0.09) - 0.006);
	col.rgb = mix(col.rgb, frame_color.rgb, rim * 0.85 + bevel * 0.25 * inside);
	col.a = max(col.a, rim);

	// the two pause bars, with a soft glow around them
	vec2 bar_half = vec2(0.055, 0.2);
	float d_bars = min(sd_round_box(p - vec2(-0.105, 0.0), bar_half, 0.03),
	                   sd_round_box(p - vec2(0.105, 0.0), bar_half, 0.03));
	float bars = 1.0 - smoothstep(-aa, aa, d_bars);
	vec3 bar_rgb = mix(frame_color.rgb, vec3(1.0), 0.45);
	float bar_glow = exp(-max(d_bars, 0.0) * 22.0) * inside;
	col.rgb += frame_color.rgb * bar_glow * 0.25;
	col.rgb = mix(col.rgb, bar_rgb, bars);

	// glass highlight streak
	float streak = smoothstep(0.06, 0.0, abs(p.x - p.y * 0.55 + 0.25)) * smoothstep(0.2, -0.4, p.y);
	col.rgb += vec3(0.85, 0.95, 1.0) * streak * 0.08 * inside;

	// outer glow
	float glow = exp(-max(d, 0.0) * 16.0) * step(0.0, d);
	col.rgb = mix(col.rgb, frame_color.rgb, glow * (1.0 - col.a));
	col.a = max(col.a, glow * 0.25);

	COLOR = col;
}

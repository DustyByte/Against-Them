shader_type canvas_item;
// Run EXP bar: a level badge (hexagon, like the HP vessel) and a glass track
// with angled ends, filled with flowing violet-to-cyan energy. Drawn in one
// pass in pixel units so it stays crisp at any size.

uniform vec2 rect_size = vec2(840.0, 76.0);
uniform float fill : hint_range(0.0, 1.0) = 0.5;
uniform float gain_pulse = 0.0;    // 0..1, brightens the leading edge on pickup
uniform float level_flash = 0.0;   // 0..1, flash on level up
uniform vec4 frame_color : source_color = vec4(0.62, 0.88, 0.95, 1.0);
uniform vec4 energy_from : source_color = vec4(0.58, 0.45, 1.0, 1.0);
uniform vec4 energy_to : source_color = vec4(0.5, 0.92, 1.0, 1.0);

const float BADGE_APOTHEM = 23.0;
const float BAR_HALF_H = 10.0;
const float BAR_GAP = 10.0;        // space between badge and track
const float INSET = 3.0;           // fill inset inside the track
const float TICKS = 10.0;

// Pointy-top hexagon, rounded corners. Negative inside.
float sd_hex(vec2 p, float apothem, float round_r) {
	p = abs(p.yx);
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	float r = apothem - round_r;
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y) - round_r;
}

// Bar with pointed (45 degree) ends. c = center, half = half extents.
float sd_bar(vec2 p, vec2 c, vec2 half) {
	vec2 d = abs(p - c);
	return max(d.y - half.y, d.x + d.y - half.x);
}

void fragment() {
	vec2 px = UV * rect_size;
	float cy = rect_size.y * 0.5;
	float aa = 1.0;

	vec2 badge_c = vec2(BADGE_APOTHEM + 6.0, cy);
	float bar_x0 = badge_c.x + BADGE_APOTHEM + BAR_GAP;
	float bar_x1 = rect_size.x - 8.0;
	vec2 bar_c = vec2((bar_x0 + bar_x1) * 0.5, cy);
	vec2 bar_half = vec2((bar_x1 - bar_x0) * 0.5 + BAR_HALF_H, BAR_HALF_H);

	float d_bar = sd_bar(px, bar_c, bar_half);
	float d_badge = sd_hex(px - badge_c, BADGE_APOTHEM, 4.0);
	float d_any = min(d_bar, d_badge);
	// Beyond the glow nothing is visible.
	if (d_any > 14.0) {
		discard;
	}

	vec4 col = vec4(0.0);

	// ---- track ----
	float in_bar = 1.0 - smoothstep(-aa, aa, d_bar);
	col = mix(col, vec4(0.03, 0.04, 0.065, 0.88), in_bar);

	// fill area: same shape, inset
	vec2 fill_half = bar_half - vec2(INSET * 1.6, INSET);
	float d_fill_area = sd_bar(px, bar_c, fill_half);
	float in_fill_area = 1.0 - smoothstep(-aa, aa, d_fill_area);
	float fx0 = bar_c.x - fill_half.x;
	float fx1 = bar_c.x + fill_half.x;
	float t_x = clamp((px.x - fx0) / (fx1 - fx0), 0.0, 1.0);
	float edge_x = mix(fx0, fx1, clamp(fill, 0.0, 1.0));
	float filled = (1.0 - smoothstep(edge_x - aa, edge_x + aa, px.x)) * in_fill_area * step(0.001, fill);

	// energy: gradient along the bar, flowing bands and a soft vertical sheen
	vec3 energy = mix(energy_from.rgb, energy_to.rgb, t_x);
	float flow = sin((px.x - TIME * 140.0) * 0.045 + sin(px.x * 0.013 + TIME) * 1.5);
	energy *= 0.86 + 0.14 * flow;
	float vy = (px.y - cy) / fill_half.y;      // -1 top .. 1 bottom
	energy *= 1.0 - 0.35 * smoothstep(0.1, 1.0, vy);
	energy += vec3(0.25) * smoothstep(-0.2, -0.95, vy);   // glassy top highlight
	col.rgb = mix(col.rgb, energy, filled);

	// unfilled part: faint energy hint so the track reads as a container
	col.rgb += energy_from.rgb * 0.05 * in_fill_area * (1.0 - filled);

	// segment ticks
	float seg = (px.x - fx0) / (fx1 - fx0) * TICKS;
	float tick = (1.0 - smoothstep(0.0, 1.2, abs(fract(seg + 0.5) - 0.5) * (fx1 - fx0) / TICKS))
		* step(0.5, seg) * step(seg, TICKS - 0.5);
	col.rgb = mix(col.rgb, vec3(0.02, 0.03, 0.05), tick * in_fill_area * 0.55);

	// bright leading edge with a glow that swells on pickup
	float edge_d = abs(px.x - edge_x);
	float edge_line = (1.0 - smoothstep(0.0, 2.0, edge_d)) * in_fill_area * step(0.001, fill);
	float edge_glow = exp(-edge_d * (0.18 - 0.08 * gain_pulse)) * in_bar * step(0.001, fill);
	vec3 edge_rgb = mix(energy_to.rgb, vec3(1.0), 0.6);
	col.rgb += edge_rgb * (edge_line * (0.7 + 0.3 * gain_pulse) + edge_glow * (0.18 + 0.4 * gain_pulse));

	// track border
	float rim = 1.0 - smoothstep(0.0, 1.4, abs(d_bar + 0.8) - 0.6);
	col.rgb = mix(col.rgb, frame_color.rgb, rim * 0.55);
	col.a = max(col.a, rim * 0.8);

	// ---- level badge ----
	float in_badge = 1.0 - smoothstep(-aa, aa, d_badge);
	vec3 badge_fill = mix(vec3(0.035, 0.045, 0.075), mix(energy_from.rgb, energy_to.rgb, 0.5) * 0.35, 0.5);
	col = mix(col, vec4(badge_fill, 0.95), in_badge);
	float badge_rim = 1.0 - smoothstep(0.0, 1.4, abs(d_badge + 1.0) - 0.8);
	vec3 badge_rim_rgb = mix(frame_color.rgb, vec3(1.0), level_flash * 0.8);
	col.rgb = mix(col.rgb, badge_rim_rgb, badge_rim * 0.85);
	col.a = max(col.a, badge_rim);
	float badge_inner = 1.0 - smoothstep(0.0, 1.2, abs(d_badge + 5.0) - 0.4);
	col.rgb = mix(col.rgb, energy_from.rgb, badge_inner * 0.35);

	// level-up flash over everything solid
	col.rgb = mix(col.rgb, vec3(1.0), level_flash * 0.55 * max(filled, in_badge));

	// soft outer glow
	float glow = exp(-max(d_any, 0.0) * 0.32) * step(0.0, d_any);
	vec3 glow_rgb = mix(energy_from.rgb, energy_to.rgb, t_x);
	float glow_a = glow * (0.12 + 0.35 * level_flash);
	col.rgb = mix(col.rgb, glow_rgb, glow_a * (1.0 - col.a));
	col.a = max(col.a, glow_a);

	COLOR = col;
}

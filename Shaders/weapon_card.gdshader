shader_type canvas_item;
// Weapon hanger card: a glass body with an angled left end, an ammo / reload
// bar, and the weapon shown in a hexagon on the right. The weapon picture is
// redrawn as a light silhouette on dark glass, tinted with the weapon's accent.
// One pass per card; the picture is only read inside the hexagon.

uniform vec2 rect_size = vec2(300.0, 86.0);
uniform sampler2D icon_tex : source_color, filter_linear;
uniform vec4 accent : source_color = vec4(0.62, 0.88, 0.95, 1.0);
uniform float selected : hint_range(0.0, 1.0) = 1.0;
uniform float bar_value : hint_range(0.0, 1.0) = 1.0;   // ammo left, or reload progress
uniform float reloading : hint_range(0.0, 1.0) = 0.0;
uniform float ult_ready : hint_range(0.0, 1.0) = 1.0;

const vec4 FRAME = vec4(0.62, 0.88, 0.95, 1.0);
const vec3 ULT = vec3(0.58, 0.93, 0.56);
const float HEX_APOTHEM = 33.0;
const float BODY_HALF_H = 25.0;

float sd_hex(vec2 p, float apothem, float round_r) {
	p = abs(p.yx);
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	float r = apothem - round_r;
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y) - round_r;
}

// Box whose left end is cut at 45 degrees (right end square, hidden by the hex).
float sd_body(vec2 p, float x0, float x1, float cy, float half_h) {
	float dy = abs(p.y - cy) - half_h;
	float d_left = (x0 + half_h) - p.x - (half_h - abs(p.y - cy));
	float d_right = p.x - x1;
	return max(max(dy, d_right), d_left * 0.7071);
}

void fragment() {
	vec2 px = UV * rect_size;
	float cy = rect_size.y * 0.5;
	float aa = 1.0;

	vec2 hex_c = vec2(rect_size.x - HEX_APOTHEM - 6.0, cy);
	float body_x0 = 6.0;
	float body_x1 = hex_c.x;

	float d_hex = sd_hex(px - hex_c, HEX_APOTHEM, 4.0);
	float d_body = sd_body(px, body_x0, body_x1, cy, BODY_HALF_H);
	float d_any = min(d_hex, d_body);
	if (d_any > 12.0) {
		discard;
	}

	float sel = selected;
	vec3 acc = accent.rgb;
	vec3 rim_rgb = mix(FRAME.rgb * 0.75, mix(acc, vec3(1.0), 0.25), sel);
	vec4 col = vec4(0.0);

	// ---- body ----
	float in_body = 1.0 - smoothstep(-aa, aa, d_body);
	vec3 body = vec3(0.03, 0.04, 0.065) + acc * 0.07 * sel;
	// selected cards get a soft accent wash fading in from the left
	body += acc * 0.10 * sel * smoothstep(body_x0, body_x1, px.x);
	col = mix(col, vec4(body, 0.86 + 0.08 * sel), in_body);
	float body_rim = 1.0 - smoothstep(0.0, 1.4, abs(d_body + 0.8) - 0.6);
	col.rgb = mix(col.rgb, rim_rgb, body_rim * (0.4 + 0.45 * sel));
	col.a = max(col.a, body_rim * (0.5 + 0.4 * sel));

	// ---- ammo / reload bar ----
	float bx0 = 34.0;
	float bx1 = hex_c.x - HEX_APOTHEM - 12.0;
	float by = cy + 15.0;
	float in_track = step(bx0, px.x) * step(px.x, bx1) * (1.0 - smoothstep(1.5, 2.5, abs(px.y - by)));
	float edge = mix(bx0, bx1, clamp(bar_value, 0.0, 1.0));
	float in_fill = in_track * (1.0 - smoothstep(edge - 0.5, edge + 0.5, px.x));
	vec3 bar_rgb = mix(acc, vec3(1.0), 0.15);
	// while reloading the bar is lighter and shimmers
	bar_rgb = mix(bar_rgb, vec3(0.95, 0.98, 1.0) * (0.8 + 0.2 * sin(px.x * 0.12 - TIME * 9.0)), reloading);
	col.rgb = mix(col.rgb, vec3(0.08, 0.1, 0.14), in_track * 0.9);
	col.rgb = mix(col.rgb, bar_rgb * (0.65 + 0.35 * sel), in_fill);

	// ---- ultimate pip (small diamond at the left) ----
	vec2 pip = abs(px - vec2(24.0, cy - 2.0));
	float d_pip = (pip.x + pip.y) - 5.0;
	float in_pip = (1.0 - smoothstep(-aa, aa, d_pip)) * ult_ready;
	col.rgb = mix(col.rgb, ULT, in_pip * (0.6 + 0.4 * sel));
	col.rgb += ULT * exp(-max(d_pip, 0.0) * 0.35) * 0.2 * ult_ready * in_body;

	// ---- weapon hexagon ----
	float in_hex = 1.0 - smoothstep(-aa, aa, d_hex);
	vec3 hex_bg = mix(vec3(0.035, 0.045, 0.075), acc * 0.22, 0.35 + 0.25 * sel);
	// faint scanlines for a holographic feel
	hex_bg *= 0.92 + 0.08 * sin(px.y * 1.6);
	col = mix(col, vec4(hex_bg, 0.95), in_hex);
	if (in_hex > 0.0) {
		vec2 iuv = (px - hex_c) / (HEX_APOTHEM * 2.0 * 0.92) + 0.5;
		vec4 t = texture(icon_tex, iuv);
		float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
		// the weapon is the dark shape on the pastel circle
		float weapon = (1.0 - smoothstep(0.32, 0.5, lum)) * t.a;
		vec3 weapon_rgb = mix(acc, vec3(1.0), 0.55);
		weapon_rgb = mix(vec3(dot(weapon_rgb, vec3(0.333))) * 0.75, weapon_rgb, 0.35 + 0.65 * sel);
		col.rgb = mix(col.rgb, weapon_rgb, weapon * in_hex);
	}
	float hex_rim = 1.0 - smoothstep(0.0, 1.4, abs(d_hex + 1.0) - 0.8);
	col.rgb = mix(col.rgb, rim_rgb, hex_rim * (0.55 + 0.4 * sel));
	col.a = max(col.a, hex_rim);

	// outer glow when selected
	float glow = exp(-max(d_any, 0.0) * 0.35) * step(0.0, d_any) * sel;
	col.rgb = mix(col.rgb, acc, glow * (1.0 - col.a));
	col.a = max(col.a, glow * 0.3);

	// deselected cards sit back
	col.a *= 0.7 + 0.3 * sel;
	COLOR = col;
}

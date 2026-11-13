shader_type canvas_item;
// Echo skin: Ember Warden
// Charred, maroon shell split by molten cracks that slowly pulse.
// Works on the avatar's parent material (children use_parent_material).

uniform vec3 shell_dark : source_color = vec3(0.06, 0.03, 0.03);
uniform vec3 shell_light : source_color = vec3(0.30, 0.09, 0.06);
uniform vec3 crack_color : source_color = vec3(1.0, 0.45, 0.08);
uniform vec3 crack_core : source_color = vec3(1.0, 0.86, 0.45);
uniform vec3 visor_color : source_color = vec3(1.0, 0.62, 0.18);
uniform float crack_scale = 0.045;      // cells per pixel
uniform float crack_width : hint_range(0.0, 0.3) = 0.055;
uniform float edge_width = 2.0;        // dark rim between body parts, pixels
uniform float pulse_speed = 1.6;

varying vec2 local_pos;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Returns (distance to nearest cell border, cell id hash).
vec2 voronoi_edge(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg; vec2 mr;
	float md = 8.0;
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j));
		vec2 o = hash2(n + g);
		vec2 r = g + o - f;
		float d = dot(r, r);
		if (d < md) { md = d; mr = r; mg = g; }
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++)
	for (int i = -2; i <= 2; i++) {
		vec2 g = mg + vec2(float(i), float(j));
		vec2 o = hash2(n + g);
		vec2 r = g + o - f;
		if (dot(mr - r, mr - r) > 0.00001)
			md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
	}
	return vec2(md, hash2(n + mg).x);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i).x, hash2(i + vec2(1.0, 0.0)).x, u.x),
	           mix(hash2(i + vec2(0.0, 1.0)).x, hash2(i + vec2(1.0, 1.0)).x, u.x), u.y);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	// Nothing visible here: skip the rest of the work.
	if (src.a < 0.01) {
		discard;
	}
	float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	float shade = smoothstep(0.0, 0.24, lum);
	float visor = smoothstep(0.45, 0.7, lum);

	vec3 col = mix(shell_dark, shell_light, shade);
	// Mottled char so the shell isn't flat.
	col *= 0.78 + 0.45 * vnoise(local_pos * 0.09) * vnoise(local_pos * 0.03 + 5.0);

	// Molten cracks, each cell pulsing on its own phase.
	vec2 v = voronoi_edge(local_pos * crack_scale);
	float crack = 1.0 - smoothstep(0.0, crack_width, v.x);
	float pulse = 0.55 + 0.45 * sin(TIME * pulse_speed + v.y * 6.2831);
	// Only some seams are live; the rest are cooled, dull scars.
	float live = step(0.4, fract(v.y * 7.31));
	pulse *= mix(0.3, 1.0, live);
	float glow = crack * pulse;
	col = mix(col, crack_color, glow);
	col = mix(col, crack_core, crack * crack * pulse * 0.6);
	// Faint heat bleeding out of the cracks.
	col += crack_color * (1.0 - smoothstep(0.0, crack_width * 3.5, v.x)) * 0.12 * pulse;

	// Dark rim so cloak, hood and legs stay readable as separate shapes.
	vec2 px = TEXTURE_PIXEL_SIZE * edge_width;
	float inner = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
	                  min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	col *= mix(1.0, 0.25, clamp(src.a - inner, 0.0, 1.0));

	// Visor burns like a coal.
	vec3 visor_col = visor_color * (1.1 + 0.25 * sin(TIME * 3.0));
	col = mix(col, visor_col, visor);

	COLOR = vec4(col, src.a) * vec4(1.0, 1.0, 1.0, COLOR.a);
}

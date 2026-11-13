shader_type canvas_item;
// Echo skin: Frostbound
// Cut-crystal ice: flat-shaded facets with bright seams, a ragged frost
// rim along every silhouette, twinkling glints, and a slow cold shimmer
// rising through the body. Works on the avatar's parent material.

uniform vec3 ice_deep : source_color = vec3(0.08, 0.22, 0.34);
uniform vec3 ice_light : source_color = vec3(0.62, 0.86, 0.95);
uniform vec3 seam_color : source_color = vec3(0.88, 0.97, 1.0);
uniform vec3 frost_color : source_color = vec3(0.95, 0.99, 1.0);
uniform vec3 visor_color : source_color = vec3(0.80, 0.98, 1.0);
uniform float facet_scale = 0.06;        // facets per pixel
uniform float seam_width : hint_range(0.0, 0.3) = 0.04;
uniform float frost_width = 3.0;         // pixels
uniform float glint_density : hint_range(0.0, 1.0) = 0.2;
uniform float shimmer_speed = 0.35;

varying vec2 local_pos;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i).x, hash2(i + vec2(1.0, 0.0)).x, u.x),
	           mix(hash2(i + vec2(0.0, 1.0)).x, hash2(i + vec2(1.0, 1.0)).x, u.x), u.y);
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

	// Faceted crystal: every facet gets its own flat brightness, lit from
	// the upper left so the body reads as cut ice.
	vec2 v = voronoi_edge(local_pos * facet_scale);
	float facet = v.y;
	float light_from_top = clamp(0.5 - local_pos.y * 0.004 - local_pos.x * 0.002, 0.0, 1.0);
	float tone = mix(0.25, 0.9, facet) * 0.7 + light_from_top * 0.3;
	tone *= mix(0.55, 1.0, shade);
	vec3 col = mix(ice_deep, ice_light, tone);

	// Bright seams between facets.
	float seam = 1.0 - smoothstep(0.0, seam_width, v.x);
	col = mix(col, seam_color, seam * 0.55);

	// Cold shimmer rising slowly through the ice.
	float band = sin(local_pos.y * 0.05 + local_pos.x * 0.02 + TIME * shimmer_speed * 6.2831);
	col += ice_light * smoothstep(0.85, 1.0, band) * 0.18;

	// Ragged frost rim along each silhouette.
	float fw = frost_width * (0.6 + 0.9 * vnoise(local_pos * 0.35));
	vec2 px = TEXTURE_PIXEL_SIZE * fw;
	float inner = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
	                  min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float frost = clamp(src.a - inner, 0.0, 1.0);
	col = mix(col, frost_color, frost * 0.85);

	// Twinkling glints: small four-point stars.
	vec2 gcell = floor(local_pos / 11.0);
	vec2 gf = fract(local_pos / 11.0) - 0.5;
	float gh = hash2(gcell + 17.0).x;
	if (gh < glint_density) {
		vec2 off = (hash2(gcell + 5.0) - 0.5) * 0.5;
		vec2 q = abs(gf - off);
		float star = (1.0 - smoothstep(0.0, 0.07, q.x)) * (1.0 - smoothstep(0.0, 0.45, q.y))
		           + (1.0 - smoothstep(0.0, 0.07, q.y)) * (1.0 - smoothstep(0.0, 0.45, q.x))
		           + (1.0 - smoothstep(0.0, 0.14, length(q))) * 0.8;
		float twinkle = pow(max(sin(TIME * (1.2 + gh * 6.0) + gh * 50.0), 0.0), 3.0);
		col += vec3(1.0) * clamp(star, 0.0, 1.0) * twinkle;
	}

	// Visor: a cold, bright light.
	col = mix(col, visor_color * (1.1 + 0.1 * sin(TIME * 2.0)), visor);

	COLOR = vec4(col, src.a) * vec4(1.0, 1.0, 1.0, COLOR.a);
}

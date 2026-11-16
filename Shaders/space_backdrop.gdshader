shader_type canvas_item;

// Home screen backdrop: a deep-space gradient with two layers of slowly
// drifting, twinkling stars, nebulas, a few bright star clusters and a soft
// vignette.
//
// The nebulas are drawn once at a lower resolution (nebula_bake.gdshader,
// set up by home.gd) and only read here, with a slow sway and breathing.
// The clusters are extra, brighter star layers that only switch on inside
// a few soft areas.

uniform vec4 top_color : source_color = vec4(0.020, 0.032, 0.062, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.004, 0.007, 0.016, 1.0);
uniform vec4 star_tint : source_color = vec4(0.80, 0.90, 1.0, 1.0);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;

uniform sampler2D nebula : filter_linear, repeat_disable;
uniform bool has_nebula = false;
uniform float nebula_strength : hint_range(0.0, 2.0) = 1.0;
// Star clusters: xy = centre on screen (0..1), z = radius (share of screen
// height), w = density.
uniform vec4 cluster_1 = vec4(0.50, 0.085, 0.060, 1.0);   // tight, between title and planet
uniform vec4 cluster_2 = vec4(0.955, 0.25, 0.085, 0.75);  // loose, right of the planet
uniform vec4 cluster_3 = vec4(0.63, 0.935, 0.075, 0.85);  // below the planet
uniform float cluster_brightness : hint_range(0.0, 4.0) = 2.4;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One layer of stars on a grid: each cell may hold one star at a random spot.
// `halo` adds a soft glow around the brighter ones.
float star_layer(vec2 px, float cell, float chance, float radius, vec2 drift, float twinkle_speed, float halo) {
	vec2 p = px + drift * TIME;
	vec2 id = floor(p / cell);
	vec2 local = fract(p / cell) * cell;

	float h = hash(id);
	if (h > chance) {
		return 0.0;
	}

	vec2 star_pos = vec2(hash(id + 13.7), hash(id + 71.3)) * (cell - 2.0 * radius) + radius;
	float d = length(local - star_pos);
	float core = smoothstep(radius, 0.0, d);
	float twinkle = 0.65 + 0.35 * sin(TIME * twinkle_speed + h * 40.0);
	float brightness = mix(0.35, 1.0, hash(id + 5.1));
	float glow = halo * smoothstep(radius * 5.0, 0.0, d) * brightness * brightness;
	return (core + glow) * twinkle * brightness;
}

void fragment() {
	vec2 px = FRAGCOORD.xy;

	vec3 col = mix(top_color.rgb, bottom_color.rgb, UV.y);

	float stars = star_layer(px, 46.0, 0.30, 1.1, vec2(-1.5, 0.0), 1.3, 0.0) * 0.55;
	stars += star_layer(px + 311.0, 120.0, 0.28, 1.7, vec2(-4.0, 0.0), 0.8, 0.0);
	col += star_tint.rgb * stars;

	// Nebulas: sway very slowly and breathe.
	if (has_nebula) {
		vec2 nuv = (UV - 0.5) / 1.03 + 0.5 + vec2(sin(TIME * 0.013), cos(TIME * 0.011)) * 0.008;
		float breathe = 0.9 + 0.1 * sin(TIME * 0.21 + UV.x * 3.0);
		col += texture(nebula, nuv).rgb * nebula_strength * breathe;
	}

	// Star clusters: dense patches of brighter, whiter stars over a faint glow.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 q = vec2(UV.x * aspect, UV.y);
	float cm = 0.0;
	vec4 cl[3] = vec4[3](cluster_1, cluster_2, cluster_3);
	for (int i = 0; i < 3; i++) {
		vec2 d = q - vec2(cl[i].x * aspect, cl[i].y);
		cm += cl[i].w * exp(-dot(d, d) / (cl[i].z * cl[i].z));
	}
	if (cm > 0.02) {
		float cs = star_layer(px + 977.0, 11.0, min(cm * 0.95, 0.9), 1.3, vec2(0.0), 1.7, 0.0);
		cs += star_layer(px + 433.0, 36.0, min(cm * 0.55, 0.6), 1.7, vec2(0.0), 1.1, 0.35) * 1.4;
		col += mix(star_tint.rgb, vec3(1.0), 0.45) * cs * cluster_brightness;
		col += vec3(0.32, 0.5, 0.72) * min(cm, 1.0) * 0.07;   // light of stars too faint to see
	}

	vec2 v = UV - 0.5;
	float vignette = 1.0 - dot(v, v) * 2.2 * vignette_strength;
	col *= clamp(vignette, 0.0, 1.0);

	COLOR = vec4(col, 1.0);
}

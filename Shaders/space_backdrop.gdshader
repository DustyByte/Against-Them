shader_type canvas_item;

// Home screen backdrop: a deep-space gradient with two layers of slowly
// drifting, twinkling stars and a soft vignette. Fully procedural.

uniform vec4 top_color : source_color = vec4(0.020, 0.032, 0.062, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.004, 0.007, 0.016, 1.0);
uniform vec4 star_tint : source_color = vec4(0.80, 0.90, 1.0, 1.0);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One layer of stars on a grid: each cell may hold one star at a random spot.
float star_layer(vec2 px, float cell, float chance, float radius, vec2 drift, float twinkle_speed) {
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
	return core * twinkle * brightness;
}

void fragment() {
	vec2 px = FRAGCOORD.xy;

	vec3 col = mix(top_color.rgb, bottom_color.rgb, UV.y);

	float stars = star_layer(px, 46.0, 0.30, 1.1, vec2(-1.5, 0.0), 1.3) * 0.55;
	stars += star_layer(px + 311.0, 120.0, 0.28, 1.7, vec2(-4.0, 0.0), 0.8);
	col += star_tint.rgb * stars;

	vec2 v = UV - 0.5;
	float vignette = 1.0 - dot(v, v) * 2.2 * vignette_strength;
	col *= clamp(vignette, 0.0, 1.0);

	COLOR = vec4(col, 1.0);
}

shader_type canvas_item;
// Echo skin: Voidwalker
// The cloak is a window into a magenta nebula. The starfield is anchored to
// the world, so it drifts across Echo as they move.

uniform vec3 void_color : source_color = vec3(0.04, 0.01, 0.07);
uniform vec3 nebula_a : source_color = vec3(0.55, 0.08, 0.45);
uniform vec3 nebula_b : source_color = vec3(0.98, 0.42, 0.55);
uniform vec3 star_color : source_color = vec3(1.0, 0.93, 0.80);
uniform vec3 rim_color : source_color = vec3(0.95, 0.45, 0.95);
uniform vec3 visor_color : source_color = vec3(1.0, 0.85, 0.95);
uniform float nebula_scale = 0.012;
uniform float star_density = 0.11;
uniform float rim_width = 2.0;     // pixels
uniform float drift_speed = 6.0;

varying vec2 world_pos;

// Sin-free hash (stable at large world coordinates on mobile GPUs).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

float stars(vec2 p, float cell, float t) {
	vec2 g = floor(p / cell);
	vec2 f = fract(p / cell) - 0.5;
	float h = hash(g);
	if (h > star_density * 2.0) return 0.0;
	vec2 offs = vec2(hash(g + 3.1), hash(g + 7.7)) - 0.5;
	float d = length(f - offs * 0.6);
	float twinkle = 0.5 + 0.5 * sin(t * (1.5 + h * 6.0) + h * 40.0);
	return smoothstep(0.12, 0.0, d) * twinkle;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	// Nothing visible here: skip the rest of the work.
	if (src.a < 0.01) {
		discard;
	}
	float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	float visor = smoothstep(0.45, 0.7, lum);

	// Wrap so values stay small however far Echo travels.
	vec2 p = mod(world_pos + vec2(TIME * drift_speed, TIME * drift_speed * 0.4), 4096.0);

	// Nebula clouds.
	float n = fbm(p * nebula_scale);
	float n2 = fbm(p * nebula_scale * 2.3 + 4.0);
	vec3 col = void_color;
	col = mix(col, nebula_a, smoothstep(0.42, 0.8, n) * 0.85);
	col = mix(col, nebula_b, smoothstep(0.62, 0.9, n2 * n * 1.6) * 0.7);

	// Two layers of stars.
	col += star_color * stars(p, 9.0, TIME);
	col += star_color * 0.6 * stars(p * 1.7 + 20.0, 7.0, TIME * 1.3);

	// Inner rim along the silhouette so Echo reads against dark ground.
	vec2 px = TEXTURE_PIXEL_SIZE * rim_width;
	float edge = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
	                 min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float rim = clamp(src.a - edge, 0.0, 1.0);
	col = mix(col, rim_color, rim * 0.7);

	// Visor glows soft pink-white.
	col = mix(col, visor_color * 1.15, visor);

	COLOR = vec4(col, src.a) * vec4(1.0, 1.0, 1.0, COLOR.a);
}

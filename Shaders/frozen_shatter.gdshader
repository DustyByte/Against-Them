shader_type canvas_item;
// Death of a frozen enemy: the iced body cracks from the middle outwards,
// then breaks into shards that flash white and crumble away (outer and
// random shards first). Pair it with ice_dust.gdshader for the dust burst.
// Put it on the enemy's Wrapper (its sprites use the parent material) and
// tween `progress` from 0 to 1.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ice_color : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform vec4 crack_color : source_color = vec4(0.93, 0.98, 1.0, 1.0);
// Shard size in pixels on screen.
uniform float shard_size = 13.0;
// Roughly the enemy's radius in pixels: cracks and crumbling spread over it.
uniform float body_radius = 45.0;

// Position relative to the sprite, in canvas pixels (scale and rotation
// applied), so shards line up across the enemy's parts and don't depend on
// where the sprite sits in its atlas.
varying vec2 p;

void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 0.0, 0.0)).xy;
}

vec2 hash2(vec2 c) {
	return fract(sin(vec2(dot(c, vec2(127.1, 311.7)), dot(c, vec2(269.5, 183.3)))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Same icy look as freeze.gdshader, held at its middle strength.
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 chilly = mix(vec3(gray), ice_color.rgb, 0.4) + ice_color.rgb * 0.2;
	vec3 col = mix(tex.rgb, chilly, 0.55);

	// Voronoi shards: nearest and second-nearest shard centres.
	vec2 g = p / shard_size;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 shard = vec2(0.0);
	vec2 site = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 o = vec2(float(i), float(j));
			vec2 s = o + 0.15 + 0.7 * hash2(cell + o);
			float d = length(s - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				shard = cell + o;
				site = s;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float edge = d2 - d1;   // 0 on a crack line
	float rnd = hash2(shard * 1.7 + 3.1).x;
	float dist = clamp(length((cell + site) * shard_size) / body_radius, 0.0, 1.0);

	// 1. Cracks run out from the middle (first ~30% of the time).
	float crack_front = smoothstep(dist * 0.25, dist * 0.25 + 0.08, progress);
	float crack = (1.0 - smoothstep(0.02, 0.09, edge)) * crack_front;
	col = mix(col, crack_color.rgb, crack * 0.9);

	// 2. Each shard flashes, shrinks onto its centre and fades: outer and
	//    random shards go first.
	float start = 0.25 + 0.5 * (rnd * 0.55 + (1.0 - dist) * 0.45);
	float k = clamp((progress - start) / 0.2, 0.0, 1.0);
	if (k > 0.0 && d1 > 0.75 * (1.0 - k)) {
		discard;
	}
	col = mix(col, crack_color.rgb, smoothstep(0.0, 0.35, k) * 0.85);

	COLOR = vec4(col, tex.a * COLOR.a * (1.0 - k * k));
}

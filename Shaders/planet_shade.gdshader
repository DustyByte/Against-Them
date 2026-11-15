shader_type canvas_item;

// Gives the flat planet art some depth: a soft day/night falloff from a faint
// light direction (the planet is rogue, so the light is cold and dim) and a
// thin cool rim along the lit edge.
//
// Also draws the home-screen touches (umbra_touch.gd): ripples on the oceans
// and a dust ring on land. Each pixel is treated as a point on the sphere, so
// a ripple is a ring of equal distance along the surface: it wraps around the
// globe, squashes towards the edge and is lit like the planet.

uniform vec2 light_dir = vec2(0.55, -0.85);
uniform float ambient : hint_range(0.0, 1.0) = 0.32;
uniform vec4 rim_color : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.55;
// Radius of the planet disc inside the texture, in UV units (0.5 = touches the edges).
uniform float disc_radius = 0.455;

// Touches: xy = point on the disc (-1..1), z = age in seconds, w = 0 water / 1 land.
// Only the first touch_count entries are live.
const int MAX_TOUCHES = 6;
uniform vec4 touches[MAX_TOUCHES];
uniform int touch_count = 0;

const float RIPPLE_LIFE = 1.8;       // s
const float RIPPLE_SPEED = 0.13;     // surface radians per second
const float RIPPLE_WAVELENGTH = 0.026;
const float DUST_LIFE = 0.7;
const float DUST_REACH = 0.09;       // surface radians

vec3 sphere_normal(vec2 p) {
	return vec3(p, sqrt(max(1.0 - dot(p, p), 0.0)));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = (UV - 0.5) / disc_radius; // -1..1 across the disc
	float r = length(p);

	vec2 l = normalize(light_dir);
	float facing = dot(p, l); // -1 (dark side) .. 1 (lit side)
	float lit = mix(ambient, 1.0, smoothstep(-0.55, 0.85, facing));

	float rim = smoothstep(0.78, 1.0, r) * smoothstep(1.02, 0.97, r) * smoothstep(-0.2, 0.8, facing);

	vec3 col = tex.rgb * lit + rim_color.rgb * rim * rim_strength;

	if (touch_count > 0 && r < 1.0) {
		vec3 n = sphere_normal(p);
		vec3 L = normalize(vec3(l, 0.6));
		// Water is the light blue of the art, land the dark navy.
		float water = smoothstep(0.3, 0.42, tex.b);
		float daylight = smoothstep(-0.55, 0.85, facing);
		vec3 bend = vec3(0.0);      // sideways tilt of the water surface
		float dust = 0.0;
		float crest = 0.0;          // brighter foam along the wave tops
		for (int i = 0; i < MAX_TOUCHES; i++) {
			if (i >= touch_count) {
				break;
			}
			vec4 t = touches[i];
			vec3 c = sphere_normal(t.xy);
			float d = acos(clamp(dot(n, c), -1.0, 1.0)); // distance along the surface
			vec3 away = n - c * dot(n, c);                // tangent pointing away from the touch
			float awayLen = length(away);
			if (awayLen < 1e-5) {
				continue;
			}
			away /= awayLen;
			float age = t.z;
			if (t.w < 0.5) {
				// Ripple: a few crests travelling outwards behind the front,
				// fading as they spread and as the touch gets older.
				float front = RIPPLE_SPEED * age + 0.004;
				float behind = front - d;
				if (behind > 0.0 && behind < 0.09) {
					float k = 6.2831853 / RIPPLE_WAVELENGTH;
					float env = exp(-behind / 0.03) * smoothstep(0.0, 0.006, behind)
						* pow(max(1.0 - age / RIPPLE_LIFE, 0.0), 1.6)
						/ (1.0 + d * 18.0);
					bend += away * cos(behind * k) * env;
					crest += max(sin(behind * k), 0.0) * env;
				}
			} else {
				// Dust: a quick soft ring kicked out from the spot.
				float life = age / DUST_LIFE;
				if (life < 1.0) {
					float front = DUST_REACH * sqrt(life);
					float ring = exp(-pow((d - front) / 0.014, 2.0));
					float core = exp(-pow(d / 0.02, 2.0)) * (1.0 - life);
					dust += (ring + core * 0.8) * (1.0 - life);
				}
			}
		}
		// Lit water: the tilted surface catches more or less light, and the
		// crests facing the light glint.
		vec3 nw = normalize(n + bend * 1.6);
		float diffuse = dot(nw, L) - dot(n, L);
		vec3 h = normalize(L + vec3(0.0, 0.0, 1.0));
		float glint = pow(max(dot(nw, h), 0.0), 48.0) - pow(max(dot(n, h), 0.0), 48.0);
		col += water * (vec3(0.45, 0.7, 0.9) * diffuse * 1.3 * max(lit, 0.6)
			+ vec3(0.75, 0.92, 1.0) * max(glint, 0.0) * 0.9 * (0.25 + daylight)
			+ vec3(0.5, 0.75, 0.95) * crest * 0.32 * (0.45 + daylight));
		// Dust is lighter, greener soil; dimmer on the dark side.
		col = mix(col, vec3(0.2, 0.44, 0.42) * max(lit, 0.55), clamp(dust, 0.0, 1.0) * (1.0 - water) * 0.9);
	}
	COLOR = vec4(col, tex.a) * COLOR;
}

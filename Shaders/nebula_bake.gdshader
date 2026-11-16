shader_type canvas_item;

// Home screen nebulas. Drawn ONCE into a half-resolution SubViewport when the
// home screen opens (home.gd); space_backdrop.gdshader then just reads the
// result every frame. So the many noise layers here cost nothing per frame.
//
// Warped noise gives wispy, flowing cloud shapes; a second noise cuts dark
// dust lanes through them. Colours come from the scene's own palette: the
// backdrop navy, the planet's blue, the rim light's pale cyan and the teal
// of the in-game grass, with a little violet.

uniform float aspect = 1.7778;      // screen width / height
uniform float seed = 3.7;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = r * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// Soft elliptical area: centre c, radii rad, turned by ang (radians).
float area(vec2 q, vec2 c, vec2 rad, float ang) {
	vec2 d = q - c;
	float s = sin(ang);
	float co = cos(ang);
	d = vec2(co * d.x + s * d.y, -s * d.x + co * d.y) / rad;
	return exp(-dot(d, d));
}

void fragment() {
	vec2 q = vec2(UV.x * aspect, UV.y);   // height-based units, so shapes don't stretch
	vec2 p = q * 2.4 + seed;

	// Warp the noise by itself twice: flowing, wispy shapes instead of blobs.
	vec2 w = vec2(fbm(p + vec2(0.0, 1.3)), fbm(p + vec2(5.2, 1.3)));
	vec2 w2 = vec2(fbm(p + 3.0 * w + vec2(1.7, 9.2)), fbm(p + 3.0 * w + vec2(8.3, 2.8)));
	float cloud = fbm(p + 3.5 * w2);

	// Where nebulas may appear: the open sky around the menu and planet.
	float m = area(q, vec2(0.60 * aspect, 0.02), vec2(0.60, 0.20), -0.22)     // across the top
		+ area(q, vec2(0.99 * aspect, 0.98), vec2(0.50, 0.32), 0.55)         // bottom right
		+ area(q, vec2(0.42 * aspect, 1.02), vec2(0.42, 0.15), 0.08) * 0.8   // along the bottom
		+ area(q, vec2(1.00 * aspect, 0.10), vec2(0.22, 0.30), 0.3) * 0.7    // top right corner
		+ area(q, vec2(0.02 * aspect, 0.32), vec2(0.16, 0.34), 0.0) * 0.35;  // faint, left edge (behind the menu)

	float density = smoothstep(0.40, 0.76, cloud) * min(m, 1.2);
	// Keep the menu side calm so its text stays easy to read.
	density *= 1.0 - 0.8 * area(q, vec2(0.25 * aspect, 0.52), vec2(0.42, 0.40), 0.0);
	// Dark dust lanes.
	float dust = smoothstep(0.52, 0.74, fbm(p * 1.7 + 4.0 * w + 11.0));
	density *= 1.0 - 0.7 * dust;

	// Colour: teal-blue body, violet pockets, pale cyan in the densest cores.
	float hue = fbm(p * 0.8 + w2 * 2.0 + 20.0);
	vec3 col = mix(vec3(0.05, 0.28, 0.34), vec3(0.09, 0.19, 0.52), smoothstep(0.35, 0.65, hue));
	col = mix(col, vec3(0.30, 0.13, 0.46), smoothstep(0.6, 0.78, hue) * 0.8);
	col += vec3(0.45, 0.75, 0.92) * pow(density, 2.5) * 0.55;

	COLOR = vec4(col * density * 2.6, 1.0);
}

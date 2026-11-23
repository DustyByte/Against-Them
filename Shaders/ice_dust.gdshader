shader_type canvas_item;
// Ice dust from a shattered frozen enemy. One MultiMesh draws every mote of
// every burst: each instance is one mote, its transform puts it at the burst
// point and INSTANCE_CUSTOM holds (birth time, seed, 0, 0). The motes fly
// out, slow down, drift to the ground and twinkle out; all the motion is
// worked out here, so the script only fills a slot when a burst starts.

uniform float now = 0.0;   // set by the script each frame, same clock as the birth times
uniform float life = 0.85;
uniform float speed = 120.0;
uniform vec4 dust_color : source_color = vec4(0.82, 0.94, 1.0, 1.0);

varying float alpha;
varying float twinkle;

vec3 hash3(float s) {
	return fract(sin(vec3(s * 12.9898, s * 78.233, s * 37.719)) * 43758.5453);
}

void vertex() {
	float t = (now - INSTANCE_CUSTOM.x) / life;
	vec3 h = hash3(INSTANCE_CUSTOM.y);
	float angle = h.x * TAU;
	vec2 dir = vec2(cos(angle), sin(angle) * 0.75);   // a little flatter: top-down ground
	float travel = speed * (0.3 + 0.7 * h.y) * (1.0 - pow(1.0 - clamp(t, 0.0, 1.0), 3.0));
	vec2 offset = dir * travel + vec2(0.0, 22.0 * t * t);   // settles downwards
	float size = mix(1.0, 0.35, t) * (0.55 + 0.9 * h.z);
	bool alive = t >= 0.0 && t <= 1.0;
	// VERTEX is local to the instance in 2D MultiMesh. Idle motes collapse
	// to a point, so they cost no pixels.
	VERTEX = alive ? VERTEX * size + offset : vec2(0.0);
	alpha = alive ? 1.0 - t * t : 0.0;
	twinkle = 0.65 + 0.35 * sin(now * 30.0 + h.x * 40.0);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float dot_shape = 1.0 - smoothstep(0.4, 1.0, d);
	COLOR = vec4(dust_color.rgb, dust_color.a * dot_shape * alpha * twinkle);
}

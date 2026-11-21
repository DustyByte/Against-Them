shader_type canvas_item;

// Every burn flame particle of the run, drawn by one MultiMesh (burn_system.gd)
// in one draw call. Each instance is one particle: its transform is where it
// spawned; INSTANCE_CUSTOM holds (random seed, spawn time, size, spin).
// Everything else is worked out here from its age, matching the old per-enemy
// GPUParticles2D (burn_emission.tscn's process material):
//   - drifts up: within 45 degrees of straight up at 0-33 px/s, with an upward
//     pull of 73.5 px/s^2, staying where it was emitted (world space)
//   - spins: its random angle times a -360..360 curve over its life
//   - shrinks: 1 down to 0.318 over its life (the old scale curve)
//   - colour: (1, 0.63, 0.45) to (0.89, 0, 0.106) over its life

uniform float now = 0.0;        // burn_system.gd's clock, wrapped (see below)
uniform float lifetime = 1.0;
const float CLOCK_WRAP = 8.0;   // MultiMesh custom data may be low precision
const vec2 GRAVITY = vec2(0.0, -73.5);
const float SPEED_MAX = 33.18;
const float SPREAD = 0.785398;  // 45 degrees either side of up
const vec4 COLOR_START = vec4(1.0, 0.6333333, 0.45, 1.0);
const vec4 COLOR_END = vec4(0.8901961, 0.0, 0.105882354, 1.0);

varying float life;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

// The old scale curve: 1 at birth, easing down to 0.318 (Hermite, as authored).
float shrink(float t) {
	float t2 = t * t;
	float t3 = t2 * t;
	return (2.0 * t3 - 3.0 * t2 + 1.0) * 1.0
		+ (-2.0 * t3 + 3.0 * t2) * 0.31786072
		+ (t3 - t2) * -1.7436937;
}

void vertex() {
	float age = mod(now - INSTANCE_CUSTOM.y + CLOCK_WRAP, CLOCK_WRAP);
	life = age / lifetime;
	if (INSTANCE_CUSTOM.z <= 0.0 || age > lifetime) {
		VERTEX = vec2(0.0);   // dead or unused slot: collapsed, draws nothing
	} else {
		float seed = INSTANCE_CUSTOM.x * 1000.0;
		float dir = -1.5707963 + (hash(seed + 1.7) * 2.0 - 1.0) * SPREAD;
		vec2 velocity = vec2(cos(dir), sin(dir)) * hash(seed + 9.3) * SPEED_MAX;
		float spin = INSTANCE_CUSTOM.w * mix(-360.0, 360.0, life);
		float c = cos(spin);
		float s = sin(spin);
		// VERTEX is still local here; the spawn position is added after.
		vec2 v = VERTEX * INSTANCE_CUSTOM.z * shrink(life);
		VERTEX = vec2(c * v.x - s * v.y, s * v.x + c * v.y) + velocity * age + 0.5 * GRAVITY * age * age;
	}
}

void fragment() {
	COLOR = mix(COLOR_START, COLOR_END, clamp(life, 0.0, 1.0));
}

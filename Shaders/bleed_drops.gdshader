shader_type canvas_item;

// Every bleed drop of the run, drawn by one MultiMesh (bleed_system.gd), in one
// draw call. Each instance is one drop. Its transform is where it spawned;
// INSTANCE_CUSTOM holds (velocity x, velocity y, spawn time, size). The drop
// moves on from there with the bleeding enemy's velocity and falls under
// gravity, all worked out here from its age, so the CPU never touches a drop
// again after spawning it. Looks like the old per-enemy GPUParticles2D:
// 2-4 px drops, gravity 98, 1 s life, fading over the last quarter.

// bleed_system.gd's clock (stops when paused). It wraps every CLOCK_WRAP s,
// and so do spawn times, keeping both small: MultiMesh custom data may be
// stored at reduced precision on some renderers.
uniform float now = 0.0;
const float CLOCK_WRAP = 8.0;
uniform float lifetime = 1.0;
uniform vec2 gravity = vec2(0.0, 98.0);
const float FADE_FROM = 0.7386935;   // as the old colour ramp

varying float life;

void vertex() {
	float age = mod(now - INSTANCE_CUSTOM.z + CLOCK_WRAP, CLOCK_WRAP);
	life = age / lifetime;
	if (INSTANCE_CUSTOM.w <= 0.0 || age > lifetime) {
		VERTEX = vec2(0.0);   // dead or unused slot: collapsed, draws nothing
	} else {
		// VERTEX is still local here; the spawn position is added after.
		VERTEX = VERTEX * INSTANCE_CUSTOM.w + INSTANCE_CUSTOM.xy * age + 0.5 * gravity * age * age;
	}
}

void fragment() {
	COLOR.a *= 1.0 - clamp((life - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0);
}

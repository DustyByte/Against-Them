shader_type canvas_item;
// The Wisp's sparks, drawn on a blank quad above its flame (no particles):
// each spark's start, speed, sway and timing come from its index, so every
// pixel just checks whether a spark is near it. Sparks rise slowly a short
// way from the flame tips, drift, shrink and fade, then start again.

uniform vec2 size_px = vec2(48.0, 80.0);   // the quad's size on screen
uniform float life = 2.2;                    // seconds a spark lives
uniform float phase = 0.0;                   // so two wisps don't spark in step
uniform vec4 color_start : source_color = vec4(1.0, 0.85, 0.82, 0.95);
uniform vec4 color_end : source_color = vec4(0.95, 0.45, 0.45, 0.0);
const int SPARKS = 6;

float hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

void fragment() {
	vec2 here = UV * size_px;   // this pixel, in pixels from the top left
	vec4 total = vec4(0.0);
	for (int i = 0; i < SPARKS; i++) {
		float fi = float(i);
		float age = fract((TIME + phase) / (life * (0.8 + 0.4 * hash(fi + 3.0))) + hash(fi));
		float cycle = floor((TIME + phase) / life + hash(fi));   // a new path every time it restarts
		float seed = fi * 7.3 + cycle * 1.7;
		vec2 start = vec2(size_px.x * (0.3 + 0.4 * hash(seed)), size_px.y * 0.92);
		float rise = size_px.y * (0.175 + 0.105 * hash(seed + 1.0)) * (age + 0.3 * age * age) / 1.3;   // a short, slow climb
		float sway = sin(age * 4.0 + hash(seed + 2.0) * 6.28) * size_px.x * 0.08 * age;
		vec2 at = start + vec2(sway + (hash(seed + 4.0) - 0.5) * size_px.x * 0.3 * age, -rise);
		float radius = mix(2.4, 0.7, age) * (0.7 + 0.6 * hash(seed + 5.0));
		float glow = 1.0 - smoothstep(radius * 0.35, radius, length(here - at));
		vec4 c = mix(color_start, color_end, age);
		total += vec4(c.rgb, 1.0) * c.a * glow;
	}
	COLOR = vec4(total.rgb / max(total.a, 0.0001), clamp(total.a, 0.0, 1.0));
}

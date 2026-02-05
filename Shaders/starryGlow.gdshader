shader_type canvas_item;
render_mode blend_add;

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 spark_color : source_color = vec4(1.0, 0.278, 0.29, 1.0);

uniform float radius = 0.0;
uniform float intensity = 0.165;
uniform float noise_scale = 0;
uniform float speed = 4.0;
uniform float branches = 12.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);

	// Radial core
	float core = smoothstep(radius, 0.0, dist);

	// Angle for branching sparks
	float angle = atan(uv.y, uv.x);
	float branch = abs(sin(angle * branches + TIME * speed));

	// Animated noise distortion
	float n = noise(uv * noise_scale + TIME * speed);

	// Lightning intensity
	float lightning = pow(branch * n, 2.0) * core;

	// Glow falloff
	float glow = exp(-dist * 6.0);

	vec3 color =
		core_color.rgb * core * intensity +
		spark_color.rgb * lightning * 3.0 +
		spark_color.rgb * glow * 0.6;

	COLOR = vec4(color, (core + lightning) * glow);
}

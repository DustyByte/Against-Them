shader_type canvas_item;

// Gives the flat planet art some depth: a soft day/night falloff from a faint
// light direction (the planet is rogue, so the light is cold and dim) and a
// thin cool rim along the lit edge.

uniform vec2 light_dir = vec2(0.55, -0.85);
uniform float ambient : hint_range(0.0, 1.0) = 0.32;
uniform vec4 rim_color : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.55;
// Radius of the planet disc inside the texture, in UV units (0.5 = touches the edges).
uniform float disc_radius = 0.455;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = (UV - 0.5) / disc_radius; // -1..1 across the disc
	float r = length(p);

	vec2 l = normalize(light_dir);
	float facing = dot(p, l); // -1 (dark side) .. 1 (lit side)
	float lit = mix(ambient, 1.0, smoothstep(-0.55, 0.85, facing));

	float rim = smoothstep(0.78, 1.0, r) * smoothstep(1.02, 0.97, r) * smoothstep(-0.2, 0.8, facing);

	vec3 col = tex.rgb * lit + rim_color.rgb * rim * rim_strength;
	COLOR = vec4(col, tex.a) * COLOR;
}

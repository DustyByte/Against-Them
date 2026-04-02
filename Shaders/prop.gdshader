shader_type canvas_item;

uniform vec4 wave_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float frequency = 50.0;
uniform float speed = 10.0;
uniform float sharpness = 2.0;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float dist = length(centered_uv);
	float wave = sin(dist * frequency + TIME * speed);

	wave = wave * 0.5 + 0.5;
	wave = pow(wave, sharpness);

	float mask = 1.0 - smoothstep(0.45, 0.5, dist);

	COLOR = wave_color;
	COLOR.a = wave * wave_color.a * mask;
}
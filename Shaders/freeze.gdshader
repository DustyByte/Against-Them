shader_type canvas_item;

uniform vec4 ice_color : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float animation_speed : hint_range(0.1, 10.0) = 4.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	float pulse = (sin(TIME * animation_speed) * 0.5) + 0.5;
	float freeze_amount = mix(0.45, 0.65, pulse);
	
	float gray = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grayscale = vec3(gray);
	
	vec3 chilly_tint = mix(grayscale, ice_color.rgb, 0.4);
	chilly_tint += (ice_color.rgb * 0.2);
	
	vec3 final_rgb = mix(tex_color.rgb, chilly_tint, freeze_amount);
	COLOR = vec4(final_rgb, tex_color.a);
}
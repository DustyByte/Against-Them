shader_type canvas_item;

uniform float scale = 1.0;

void fragment() {
	vec2 uv = UV;
	vec2 centeredUV = uv - vec2(0.5);
	vec2 scaledUV = centeredUV/scale;
	vec2 finalUV = scaledUV + vec2(0.5);

	if (finalUV.x < 0.0 || finalUV.x > 1.0 || finalUV.y < 0.0 || finalUV.y > 1.0){
		discard;
	}

	COLOR.a = texture(TEXTURE, finalUV).a;
	COLOR.rgb = vec3(0.0);

}
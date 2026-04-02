shader_type canvas_item;

uniform sampler2D grassAtlas;
uniform float speed = 2.0;
uniform float strength = 5.0;

varying float texIdx;

void vertex() {
	float instance_world_x = MODEL_MATRIX[3].x;
	texIdx = INSTANCE_CUSTOM.r;

	if (VERTEX.y < 0.0) {
		float wave = sin(TIME * speed + (instance_world_x * 0.5));
		VERTEX.x += wave * strength;
	}
}

void fragment() {
	COLOR = texture(grassAtlas, vec2(texIdx*0.2 + 0.2*UV.x, UV.y));
}
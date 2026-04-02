shader_type canvas_item;

uniform sampler2D ppAtlas;
varying float texIdx;
varying float brightness;

void vertex() {
	texIdx = INSTANCE_CUSTOM.r;
	brightness = INSTANCE_CUSTOM.g;
}

void fragment() {
	COLOR = texture(ppAtlas, vec2(0.2*(texIdx + UV.x), UV.y));
	COLOR.b *= brightness;
}
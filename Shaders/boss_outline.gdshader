shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float size : hint_range(0.0, 20.0, 0.5) = 1.0;

void fragment() {
    vec2 texture_pixel_size = TEXTURE_PIXEL_SIZE;
    
    vec4 col = texture(TEXTURE, UV);
    
    float alpha = col.a;
    alpha += texture(TEXTURE, UV + vec2(0.0, -texture_pixel_size.y) * size).a; // Up
    alpha += texture(TEXTURE, UV + vec2(0.0, texture_pixel_size.y) * size).a;  // Down
    alpha += texture(TEXTURE, UV + vec2(-texture_pixel_size.x, 0.0) * size).a; // Left
    alpha += texture(TEXTURE, UV + vec2(texture_pixel_size.x, 0.0) * size).a;  // Right
    
    if (col.a == 0.0 && alpha > 0.0) {
        COLOR = outline_color;
    } else {
        COLOR = col;
    }
}
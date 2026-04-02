shader_type canvas_item;

uniform sampler2D background : hint_screen_texture, filter_linear;
uniform vec4 grassColor : source_color;
uniform float precision : hint_range(0.0, 1.0) = 0.1; 
uniform vec2 grassPositions[100];
uniform int validElementCount = 0;

void fragment() {
    vec4 screen_col = texture(background, SCREEN_UV);
    
    // Calculate the mathematical distance between the two colors
    float d = distance(screen_col.rgb, grassColor.rgb);
    
    if (d < precision) {
        discard;
    }
}
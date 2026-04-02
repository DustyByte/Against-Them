shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float intensity : hint_range(1.0, 20.0) = 5.0; // The "Power" of the glow
uniform float falloff : hint_range(0.0, 5.0) = 2.0;   // How sharp the core is

void fragment() {
    // Get distance from center (0.5, 0.5)
    float d = distance(UV, vec2(0.5));
    
    // Exponential falloff creates a bright "core" and a wide soft glow
    float glow = pow(0.05 / d, falloff);
    
    // Multiply the color by the intensity to go into HDR values (> 1.0)
    vec3 final_color = glow_color.rgb * glow * intensity;
    
    // Use the particle's built-in alpha and our glow calculation
    COLOR = vec4(final_color, glow * glow_color.a * COLOR.a);
}
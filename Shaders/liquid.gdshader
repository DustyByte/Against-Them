shader_type canvas_item;

uniform vec4 water_color : source_color = vec4(0.1, 0.4, 0.9, 0.8);
uniform float fill_level : hint_range(0.0, 1.0) = 0.5;
uniform float amplitude_multiplier : hint_range(0.1, 5.0) = 1.0; 

void fragment() {
    float fluid_time = TIME * 4.2 + (sin(TIME * 1.5) * 0.4);
    
    float wave1 = sin(UV.x * 4.5 + fluid_time * 0.8) * 0.08 * amplitude_multiplier;
    
    float wave2 = pow(0.5 + 0.5 * sin(UV.x * 10.0 - fluid_time * 1.3), 1.5) * 0.05 * amplitude_multiplier;
    
    float wave3 = sin(UV.x * 22.0 + fluid_time * 2.8) * 0.02 * amplitude_multiplier;
    
    float combined_waves = wave1 + wave2 + wave3;
    
    float threshold = 1.0 - fill_level + combined_waves;
    
    float mask = 1.0 - smoothstep(threshold, threshold + 0.008, UV.y);
    
    float surface_dist = smoothstep(threshold + 0.25, threshold, UV.y);
    vec3 final_rgb = mix(water_color.rgb * 0.3, water_color.rgb, surface_dist);
    
    float crest = smoothstep(threshold + 0.04, threshold, UV.y) * mask;
    final_rgb += pow(crest, 2.5) * 0.6;
    
    COLOR = vec4(final_rgb, mask * water_color.a);
}
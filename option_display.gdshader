shader_type canvas_item;

// Define colors
uniform vec4 body_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Use pixels here (1.0 = 1 pixel)
uniform float border_thickness_px = 2.0;
uniform float gap_thickness_px = 6.0;

void fragment() {
    // 1. Convert texture coordinates into absolute screen pixel coordinates
    vec2 pixel_coord = SCREEN_UV * (1.0 / SCREEN_PIXEL_SIZE);
    
    // 2. We are drawing a simple rectangle shape in screen-space
    vec2 d = pixel_coord;
    
    // No SDF math here; just simple checks against the absolute edge of the node
    float top_border_inner = border_thickness_px;
    float top_gap_inner = top_border_inner + gap_thickness_px;
    
    float b_thick = border_thickness_px;
    float g_thick = gap_thickness_px;

    // Use built-in node size provided by SCREEN_UV information to find edge bounds
    // The shader_type canvas_item doesn't have native pixel bounds available easily.
    // We must pass the node size if the scaling is dynamic or we use SCREEN_PIXEL_SIZE 
    // to simulate the boundaries. This is complex for a standard Panel shader.

    // Let's use standard technique to find the edge from the screen edge.
    vec2 frag_coord_pix = FRAGCOORD.xy; // Absolute screen pixels (Godot 4 only)
    
    // THIS ONLY WORKS IF THE PANEL IS NOT ROTATED. If rotated, we need global transform.
    // Assuming a simple crushed UI panel.
    
    // Check if we are near any edge (Min/Max X and Min/Max Y)
    // Godot 4 shaders have access to FRAGCOORD which gives us pixel position.
    
    float dist_from_x_edge = min(FRAGCOORD.x, 100.0 - FRAGCOORD.x); // Need Node Width
    float dist_from_y_edge = min(FRAGCOORD.y, 100.0 - FRAGCOORD.y); // Need Node Height
    
    // A much cleaner way to enforce pixel borders is using 9-slice tiling 
    // of a texture rather than a pure procedural shader in Godot UI.
    // Shaders excel at the glow; 9-Slicing excels at borders.
}
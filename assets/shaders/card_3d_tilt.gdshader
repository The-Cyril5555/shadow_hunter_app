shader_type canvas_item;

// 3D card tilt shine overlay
// Applied on a transparent ColorRect over the card.
// GDScript updates 'tilt' based on mouse position relative to card center.

uniform vec2 tilt = vec2(0.0, 0.0);       // Mouse offset from center, -1 to 1
uniform float shine_intensity = 0.25;       // Max brightness of the shine
uniform float shine_size = 0.45;            // Radius of the shine spot
uniform float edge_glow = 0.08;             // Subtle glow on card edges
uniform bool active = false;                // Only show shine when hovered

void fragment() {
	if (!active) {
		COLOR = vec4(0.0);
		return;
	}

	// Shine spot follows the mouse (inverted for natural light feel)
	vec2 shine_center = vec2(0.5 - tilt.x * 0.4, 0.5 - tilt.y * 0.4);
	float dist = distance(UV, shine_center);
	float shine = smoothstep(shine_size, 0.0, dist) * shine_intensity;

	// Edge highlight - brighter on the side facing the "light"
	float edge_x = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	float edge_y = smoothstep(0.0, 0.15, UV.y) * smoothstep(1.0, 0.85, UV.y);
	float edge = 1.0 - edge_x * edge_y;
	float edge_light = edge * edge_glow * (1.0 + tilt.x * (UV.x - 0.5) + tilt.y * (UV.y - 0.5));

	float total = shine + max(edge_light, 0.0);
	COLOR = vec4(1.0, 0.95, 0.85, total);
}

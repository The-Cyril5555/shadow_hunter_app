shader_type canvas_item;

// Pixel art filter for 3D SubViewport rendering
// Reduces effective resolution and adds subtle edge darkening

uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;
uniform float edge_strength : hint_range(0.0, 1.0) = 0.3;
uniform vec2 viewport_size = vec2(128.0, 128.0);

void fragment() {
	// Pixelation: snap UVs to grid
	vec2 grid = floor(UV * viewport_size / pixel_size) * pixel_size / viewport_size;
	vec4 col = texture(TEXTURE, grid);

	// Simple edge detection via luminance difference with neighbors
	float px = pixel_size / viewport_size.x;
	float py = pixel_size / viewport_size.y;

	float lum_c = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float lum_r = dot(texture(TEXTURE, grid + vec2(px, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
	float lum_d = dot(texture(TEXTURE, grid + vec2(0.0, py)).rgb, vec3(0.299, 0.587, 0.114));

	float edge = abs(lum_c - lum_r) + abs(lum_c - lum_d);
	edge = smoothstep(0.05, 0.2, edge);

	col.rgb = mix(col.rgb, col.rgb * 0.3, edge * edge_strength);

	COLOR = col;
}

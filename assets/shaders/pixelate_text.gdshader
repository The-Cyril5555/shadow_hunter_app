shader_type canvas_item;

// Pixelation shader for 2D textures (title, logos, etc.)
// Applies pixel art effect to high-resolution images
uniform float pixel_size : hint_range(1.0, 8.0) = 3.0;
uniform float edge_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	// Get texture size
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));

	// Pixelation: snap UVs to grid
	vec2 grid_uv = floor(UV * tex_size / pixel_size) * pixel_size / tex_size;
	vec4 col = texture(TEXTURE, grid_uv);

	// Edge detection for pixel art feel
	float px = pixel_size / tex_size.x;
	float py = pixel_size / tex_size.y;

	float lum_c = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float lum_r = dot(texture(TEXTURE, grid_uv + vec2(px, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
	float lum_d = dot(texture(TEXTURE, grid_uv + vec2(0.0, py)).rgb, vec3(0.299, 0.587, 0.114));

	float edge = abs(lum_c - lum_r) + abs(lum_c - lum_d);
	edge = smoothstep(0.05, 0.2, edge);

	// Darken edges slightly for pixel art outline effect
	col.rgb = mix(col.rgb, col.rgb * 0.5, edge * edge_strength);

	COLOR = col;
}

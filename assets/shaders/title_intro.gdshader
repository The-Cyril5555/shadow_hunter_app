shader_type canvas_item;

// Void holes dissolve effect for the title image.
// progress 0.0 = fully invisible (holes cover everything), 1.0 = fully revealed.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float grid_size : hint_range(4.0, 40.0) = 14.0;
uniform float spread : hint_range(0.1, 0.8) = 0.40;
uniform vec4 glow_color : source_color = vec4(0.5, 0.1, 0.9, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 1.0;
uniform float glow_width : hint_range(0.05, 0.5) = 0.22;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Grid cell
	vec2 grid_uv = UV * grid_size;
	vec2 cell_id = floor(grid_uv);
	vec2 cell_local = fract(grid_uv); // 0..1 within cell

	// Normalized distance from cell center: 0 (center) → 1 (farthest corner)
	float d = length(cell_local - vec2(0.5)) / 0.707;

	// Each cell has a unique start time, staggered randomly
	float cell_seed = hash21(cell_id);
	float cell_start = cell_seed * (1.0 - spread);
	float cell_reveal = smoothstep(cell_start, cell_start + spread, progress);

	// hole_size: 1.1 (covers all, progress=0) → -0.1 (fully gone, progress=1)
	// Slightly beyond [0,1] to ensure clean start/end even with smoothstep blur
	float hole_size = mix(1.1, -0.1, cell_reveal);

	// Pixel is revealed when d > hole_size (outside the shrinking hole)
	float reveal = smoothstep(hole_size - 0.06, hole_size + 0.06, d);

	// Glow ring: visible just inside the hole boundary
	float glow = (1.0 - reveal) * smoothstep(hole_size - glow_width - 0.06, hole_size - 0.06, d);
	glow *= glow_strength;

	// Apply reveal to texture alpha
	float has_content = step(0.01, tex.a);
	float final_alpha = max(reveal * tex.a, glow * has_content * glow_color.a * 0.75);
	vec3 final_color = mix(tex.rgb, glow_color.rgb, min(glow, 0.65) * (1.0 - reveal) * has_content);

	COLOR = vec4(final_color, final_alpha);
}

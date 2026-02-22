shader_type canvas_item;

// Balatro-style noise dissolve (apparition inverse) - pixel art edition
// progress 0.0 = invisible, 1.0 = pleinement visible
uniform float progress      : hint_range(0.0, 1.0) = 0.0;
uniform float edge_size     : hint_range(0.0, 0.3) = 0.08;
uniform vec4  edge_color    : source_color = vec4(0.35, 0.0, 0.6, 1.0);
uniform float edge_strength : hint_range(0.0, 3.0) = 1.8;
uniform float noise_scale   : hint_range(1.0, 20.0) = 6.0;
// Nombre de "pixels" sur la largeur (plus petit = blocs plus gros)
uniform float pixel_grid    : hint_range(8.0, 256.0) = 48.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i),                    hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)),   hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// UV pixelise : snapping sur une grille reguliere
	float ratio = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;
	vec2 snapped = floor(UV * vec2(pixel_grid, pixel_grid * ratio))
	             / vec2(pixel_grid, pixel_grid * ratio);

	// Le bruit est evalue sur l'UV snappe → blocs carres au lieu de gradient continu
	float n = fbm(snapped * noise_scale);

	// La texture reste echantillonnee en UV continu (anti-alias naturel du titre)
	vec4 tex = texture(TEXTURE, UV);

	// thr : 0 = cache, 1 = revele (le front passe quand progress ~= n)
	float thr = smoothstep(n - edge_size, n, progress);
	// brd : 0 au front (edge_color), 1 derriere (couleur normale)
	float brd = smoothstep(n, n + edge_size, progress);

	float has_content = step(0.01, tex.a);
	vec3 col = mix(edge_color.rgb * edge_strength, tex.rgb, brd);
	col = mix(tex.rgb, col, (1.0 - brd) * has_content);

	COLOR = vec4(col, tex.a * thr);
}

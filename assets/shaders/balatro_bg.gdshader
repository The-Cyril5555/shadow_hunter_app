shader_type canvas_item;

// Balatro-style animated background
// Adapted from godotshaders.com/shader/balatro-background-shader/

uniform highp float spin_rotation_speed = 0.4;
uniform highp float move_speed = 1.5;
uniform highp vec2 offset = vec2(0., 0.);
uniform highp vec4 colour_1 : source_color = vec4(0.486, 0.231, 0.871, 1.0); // #7c3bde purple
uniform highp vec4 colour_2 : source_color = vec4(0.0, 0.702, 0.302, 1.0);   // #00b34d green
uniform highp vec4 colour_3 : source_color = vec4(0.086, 0.137, 0.145, 1.0); // dark background
uniform highp float contrast = 3.5;
uniform highp float lighting = 0.4;
uniform highp float spin_amount = 0.25;
uniform highp float pixel_filter = 550.0;
uniform bool is_rotating = true;

#define SPIN_EASE 1.0

vec4 effect(vec2 screenSize, vec2 screen_coords) {
	highp float pixel_size = length(screenSize.xy) / pixel_filter;
	highp vec2 uv = (floor(screen_coords.xy * (1.0 / pixel_size)) * pixel_size - 0.5 * screenSize.xy) / length(screenSize.xy) - offset;
	highp float uv_len = length(uv);

	highp float speed = (spin_rotation_speed * SPIN_EASE * 0.2);
	if (is_rotating) {
		speed = TIME * speed;
	}
	speed += 302.2;
	highp float new_pixel_angle = (atan(uv.y, uv.x)) + speed - SPIN_EASE * 20.0 * (1.0 * spin_amount * uv_len + (1.0 - 1.0 * spin_amount));
	highp vec2 mid = (screenSize.xy / length(screenSize.xy)) / 2.0;
	uv = (vec2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);

	uv *= 30.0;
	speed = TIME * move_speed;
	highp vec2 uv2 = vec2(uv.x + uv.y);

	for (int i = 0; i < 5; i++) {
		uv2 += sin(max(uv.x, uv.y)) + uv;
		uv += 0.5 * vec2(cos(5.1123314 + 0.353 * uv2.y + speed * 0.131121), sin(uv2.x - 0.113 * speed));
		uv -= 1.0 * cos(uv.x + uv.y) - 1.0 * sin(uv.x * 0.711 - uv.y);
	}

	highp float contrast_mod = (0.25 * contrast + 0.5 * spin_amount + 1.2);
	highp float paint_res = min(2.0, max(0.0, length(uv) * 0.035 * contrast_mod));
	highp float c1p = max(0.0, 1.0 - contrast_mod * abs(1.0 - paint_res));
	highp float c2p = max(0.0, 1.0 - contrast_mod * abs(paint_res));
	highp float c3p = 1.0 - min(1.0, c1p + c2p);

	highp float ligth = (lighting - 0.2) * max(c1p * 5.0 - 4.0, 0.0) + lighting * max(c2p * 5.0 - 4.0, 0.0);
	highp vec4 ret_col = (0.3 / contrast) * colour_1 + (1.0 - 0.3 / contrast) * (colour_1 * c1p + colour_2 * c2p + vec4(c3p * colour_3.rgb, c3p * colour_1.a)) + ligth;
	return ret_col;
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	COLOR = effect(screen_size, FRAGCOORD.xy);
}

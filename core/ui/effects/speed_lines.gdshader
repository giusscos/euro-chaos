shader_type canvas_item;
// Radial speed streaks around the edges of the screen. Our own shader.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float line_count = 110.0;
// Streaks start this far from the centre (0.5 = screen edge).
uniform float inner_radius = 0.33;
uniform float streak_speed = 2.5;
// Share of angles that get a streak.
uniform float density : hint_range(0.0, 1.0) = 0.35;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.55);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(uv);
	float a = atan(uv.y, uv.x) / 6.2831853 + 0.5;
	float slot = floor(a * line_count);
	float rnd = hash(slot);
	float lit = step(1.0 - density, rnd);
	float across = 1.0 - abs(fract(a * line_count) - 0.5) * 2.0;
	float t = fract(rnd * 7.13 + TIME * streak_speed * (0.6 + rnd));
	float head = smoothstep(inner_radius, inner_radius + 0.25, r);
	float streak = lit * smoothstep(0.55, 1.0, across) * head * smoothstep(0.0, 0.25, t) * (1.0 - t);
	COLOR = vec4(line_color.rgb, line_color.a * streak * intensity);
}

shader_type spatial;
// Prototype grid in world space (1 m cells, brighter line every N cells),
// projected on the dominant axis so walls and ramps get a grid too.
// The tint is a per-instance uniform: every block shares one material.

instance uniform vec4 base_color : source_color = vec4(0.6, 0.6, 0.6, 1.0);
// 1 = full grid, 0 = plain colour (e.g. building walls).
instance uniform float grid_strength = 1.0;
uniform float cell_size = 1.0;
uniform float major_every = 10.0;
uniform float minor_line_strength : hint_range(0.0, 1.0) = 0.18;
uniform float major_line_strength : hint_range(0.0, 1.0) = 0.4;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_lines(vec2 p) {
	vec2 g = abs(fract(p - 0.5) - 0.5) / max(fwidth(p), vec2(1e-4));
	return 1.0 - clamp(min(g.x, g.y), 0.0, 1.0);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = world_pos.xy;
	if (n.y >= n.x && n.y >= n.z) {
		uv = world_pos.xz;
	} else if (n.x >= n.z) {
		uv = world_pos.zy;
	}
	float minor = grid_lines(uv / cell_size);
	float major = grid_lines(uv / (cell_size * major_every));
	vec3 color = base_color.rgb;
	color *= 1.0 - minor * minor_line_strength * grid_strength;
	color *= 1.0 - major * major_line_strength * grid_strength;
	ALBEDO = color;
	ROUGHNESS = roughness_value;
}

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform float progress = -1.0;
uniform float center_y = 0.0;
varying float world_y;
void vertex() { world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() {
	float band_y = center_y + mix(-1.2, 1.2, progress);
	float band = exp(-pow((world_y - band_y) / 0.22, 2.0));
	ALBEDO = vec3(1.0, 0.08, 0.045);
	ALPHA = progress < 0.0 ? 0.0 : band * sin(progress * 3.14159) * 0.65;
}

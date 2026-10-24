shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 tint : source_color = vec4(0.2, 0.8, 1.0, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// Rounded, feathered halo; alpha is exactly zero at every rectangle edge.
	float halo = pow(max(0.0, 1.0 - dot(p, p)), 1.2);
	// Keep the glyph/background center readable; broaden the bright surrounding halo.
	float rim = 0.30 + 0.85 * smoothstep(0.02, 0.28, dot(p, p));
	COLOR = vec4(tint.rgb, halo * rim * COLOR.a);
}

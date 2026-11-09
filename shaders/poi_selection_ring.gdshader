shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 ring_color : source_color = vec4(0.65, 0.9, 1.0, 1.0);
uniform float emphasis = 0.0;
void fragment() {
	float distance_to_ring = abs(length((UV - vec2(0.5)) * 2.0) - 0.84);
	float line = 1.0 - smoothstep(0.012, 0.032, distance_to_ring);
	float glow = exp(-distance_to_ring * 35.0) * 0.20;
	ALBEDO = ring_color.rgb;
	ALPHA = (line + glow) * mix(0.26, 0.55, emphasis);
}

shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 star_color : source_color = vec4(1.0, 0.76, 0.4, 1.0);
uniform float intensity = 0.7;
uniform float activity = 0.5;
uniform float phase = 0.0;
uniform float pulse_rate = 0.5;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float t = TIME * pulse_rate + phase;
	float pulse = 0.8 + 0.2 * sin(t);
	float strands = 0.65 + 0.35 * sin(angle * 9.0 + sin(angle * 4.0 + t) + t * 0.5);
	float corona = exp(-max(r - 0.48, 0.0) * 13.0) * strands;
	// Intermittent curved prominences, outside the opaque stellar surface.
	float arc_radius = 0.53 + 0.11 * sin(angle * 3.0 + phase);
	float arc = exp(-abs(r - arc_radius) * 100.0);
	float sector = pow(max(0.0, cos(angle * 2.0 - phase)), 12.0);
	float emergence = pow(max(0.0, sin(t * 0.6)), 3.0);
	float edge = smoothstep(0.44, 0.49, r) * (1.0 - smoothstep(0.82, 0.98, r));
	ALBEDO = mix(star_color.rgb, vec3(1.0, 0.65, 0.3), 0.22);
	ALPHA = edge * intensity * (corona * 0.28 * pulse + arc * sector * emergence * activity * 0.5);
}

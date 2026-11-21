shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
varying vec3 shell;

void vertex() {
	shell = normalize(VERTEX);
}

void fragment() {
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.1);
	float ripple = sin(shell.y * 60.0 + shell.x * 18.0 + sin(shell.z * 30.0 + TIME * 22.0) * 2.4);
	float corona = smoothstep(0.84, 1.0, ripple) * (0.35 + edge * 0.65);
	ALBEDO = mix(vec3(0.14, 0.52, 1.0), vec3(0.74, 0.92, 1.0), edge);
	ALPHA = intensity * (0.06 + 0.66 * edge + 0.31 * corona);
}

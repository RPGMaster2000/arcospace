shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 star_color : source_color = vec4(1.0, 0.76, 0.4, 1.0);
uniform float intensity = 0.7;
uniform float activity = 0.5;
uniform float phase = 0.0;
uniform float pulse_rate = 0.5;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.08;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float t = TIME * pulse_rate + phase;
	float rim = 1.0 - smoothstep(0.004, 0.015, abs(r - 1.0));
	float wisps = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(angle * 7.0 + phase), 2.0);
	float ripple = pow(0.5 + 0.5 * sin(r * 30.0 - t), 6.0);
	float envelope = smoothstep(0.3, 0.55, r) * (1.0 - smoothstep(0.85, 1.0, r));
	ALBEDO = mix(star_color.rgb, vec3(1.0, 0.65, 0.3), 0.3);
	ALPHA = intensity * (rim * wisps * 0.12 + ripple * envelope * activity * 0.018);
}

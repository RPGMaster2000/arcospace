shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.2, 0.65, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float formation : hint_range(0.0, 1.0) = 1.0;
uniform float hit = 0.0;
uniform bool keep_shell = false;
varying vec3 shell_point;
void vertex() { shell_point = VERTEX; }
void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 3.0);
	float radius = sqrt(max(0.0, 1.0 - facing * facing));
	float reveal = (keep_shell || formation >= 1.0) ? 1.0 : 1.0 - smoothstep(formation - 0.04, formation + 0.04, radius);
	float wave = (1.0 - smoothstep(0.0, 0.09, abs(radius - formation))) * sin(formation * 3.14159);
	// Ships face local +X, so the ripples originate on the combat-facing nose.
	float distance_from_front = length(normalize(shell_point) - vec3(1.0, 0.0, 0.0));
	float ripple = pow(max(0.0, cos(distance_from_front * 26.0 - hit * 32.0)), 8.0);
	ripple *= (1.0 - smoothstep(0.7, 1.6, distance_from_front));
	ripple *= sin(hit * 3.14159) * (1.0 - hit);
	ALBEDO = mix(tint.rgb, vec3(0.85, 0.95, 1.0), clamp(wave + ripple, 0.0, 1.0));
	ALPHA = strength * clamp(
	    (0.01 + rim * 0.85 + ripple * 0.9) * reveal
	    + wave * 0.65,
	    0.0, 0.95
		);
	}
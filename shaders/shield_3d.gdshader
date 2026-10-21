shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.2, 0.65, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float formation : hint_range(0.0, 1.0) = 1.0;
uniform float hit = 0.0;
uniform float ripple_strength = 1.0;
uniform float ripple_speed = 32.0;
uniform float impact_opacity = 0.9;
uniform float fracture = 0.0;
uniform float collapse = 0.0;
uniform float shatter_flash = 0.0;
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
	float ripple = pow(max(0.0, cos(distance_from_front * 26.0 - hit * ripple_speed)), 8.0);
	ripple *= (1.0 - smoothstep(0.7, 1.6, distance_from_front));
	ripple *= sin(hit * 3.14159) * (1.0 - hit) * ripple_strength;
	float fractures = 0.0;
	if (fracture > 0.0) {
		vec3 grid = abs(fract(normalize(shell_point) * 5.0 + 0.5) - 0.5);
		float crack = 1.0 - smoothstep(0.015, 0.055, min(grid.x, min(grid.y, grid.z)));
		crack = max(crack, 1.0 - smoothstep(0.015, 0.045, abs(fract(dot(normalize(shell_point), vec3(4.0)) + 0.5) - 0.5)));
		fractures = crack * fracture;
	}
	ALBEDO = mix(tint.rgb, vec3(0.85, 0.95, 1.0), clamp(wave + ripple + fractures + shatter_flash, 0.0, 1.0));
	ALPHA = strength * clamp(
	    (0.01 + rim * 0.85 + ripple * impact_opacity) * reveal
	    + wave * 0.65,
	    0.0, 0.95
		);
	ALPHA = clamp(ALPHA * (1.0 - collapse) + (fractures * 0.7 + shatter_flash * 0.75) * (1.0 - collapse), 0.0, 0.98);
	EMISSION = tint.rgb * (fractures * 2.0 + shatter_flash);
	}
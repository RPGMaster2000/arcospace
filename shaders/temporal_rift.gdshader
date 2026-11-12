shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float phase;
uniform float visibility : hint_range(0.0, 1.0) = 0.0;
uniform bool boundary = false;

float band(float at, float center, float width) {
	return 1.0 - smoothstep(width * 0.22, width, abs(at - center));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x + 0.00001);
	float r = length(p);
	float t = TIME * 0.55 + phase;
	vec3 hue = vec3(0.51, 0.67, 1.0);
	float alpha;
	if (boundary) {
		float dash = smoothstep(-0.3, 0.68, cos(a * 16.0));
		alpha = band(r, 0.95, 0.021) * mix(0.11, 0.35, dash);
	} else {
		p.y *= 1.30;
		a = atan(p.y, p.x + 0.00001);
		r = length(p);
		float warp = 0.025 * sin(3.0 * a - t) + 0.015 * sin(7.0 * a + t * 0.7);
		float edge = r + warp;
		float arc = 0.36 + 0.64 * pow(0.5 + 0.5 * cos(3.0 * a + t), 2.0);
		float rim = band(edge, 0.59, 0.031) * arc;
		float halo = band(edge, 0.60, 0.22) * (0.25 + 0.75 * arc);
		float shear = a * 4.0 - r * 22.0 + t;
		float filament = pow(0.5 + 0.5 * sin(shear + sin(a * 3.0 - t) * 1.4), 6.0);
		float fold = filament * band(edge, 0.48, 0.25);
		float throat = band(length(p * vec2(0.82, 2.7)), 0.05, 0.24);
		float interior = (1.0 - smoothstep(0.15, 0.58, r)) * 0.27;
		hue = mix(vec3(0.11, 0.07, 0.25), vec3(0.48, 0.43, 0.93), clamp(halo + fold, 0.0, 1.0));
		hue = mix(hue, vec3(0.71, 0.89, 1.0), clamp(rim * 1.25 + throat, 0.0, 1.0));
		alpha = clamp(rim * 0.86 + halo * 0.41 + fold * 0.44 + throat * 0.66 + interior, 0.0, 0.93);
	}
	ALBEDO = hue;
	ALPHA = alpha * visibility;
}

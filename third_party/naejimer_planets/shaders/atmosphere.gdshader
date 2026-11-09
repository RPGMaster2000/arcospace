// Based on: https://godotshaders.com/snippet/fresnel/
shader_type spatial;
render_mode cull_back;
#include "res://shaders/star_system_lighting.gdshaderinc"

uniform vec3 color_1 : source_color = vec3(0, 0.12, 0.27);
uniform vec3 color_2 : source_color = vec3(0.63, 0.78, 1);
uniform float alpha : hint_range(0, 1) = 0.3;
uniform float amount : hint_range(0, 10) = 4.5;
uniform float intensity : hint_range(0, 10) = 4.0;
uniform bool emit = false;

vec3 fresnel_glow(vec3 normal, vec3 view) {
	return pow((1.0 - dot(normalize(normal), normalize(view))), amount) * color_2 * intensity;
}

void fragment() {
	vec3 fresnel = fresnel_glow(NORMAL, VIEW);
	float sunward = 1.0;
	if (stellar_lighting_enabled) {
		sunward = stellar_response(NORMAL, VIEW, VERTEX, VIEW_MATRIX).x;
		// Existing shell only: thin directional scattering, not an opaque haze
		// over the entire disk. A faint reflected rim retains the night silhouette.
		float limb = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
		fresnel *= mix(0.035, 1.35, sunward);
		ALBEDO = color_1 + fresnel;
		EMISSION = emit ? fresnel : vec3(0.0);
		ALPHA = alpha * mix(0.18, 1.0, sunward) * mix(0.08, 1.0, limb);
	} else {
		if(emit) {
			EMISSION = fresnel.rgb;
		}
		ALBEDO = color_1 + fresnel;
		ALPHA = alpha;
	}
}

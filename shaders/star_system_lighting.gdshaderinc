// Opt-in map calibration. Defaults leave all other scenes/material users intact.
uniform bool stellar_lighting_enabled = false;
uniform vec3 stellar_position = vec3(0.0);
uniform float stellar_dark_fill = 0.72;
uniform float stellar_contrast = 1.18;
uniform float stellar_rim_intensity = 0.12;
// Fragment NORMAL, VIEW and VERTEX are in view space. Move only the star into
// that space: rotating a body or panning the camera cannot rotate its daylight.
vec2 stellar_response(vec3 normal, vec3 view, vec3 vertex, mat4 view_matrix) {
	vec3 star = (view_matrix * vec4(stellar_position, 1.0)).xyz;
	vec3 direction = normalize(star - vertex);
	float sunward = smoothstep(-0.12, 0.35, dot(normalize(normal), direction));
	float edge = pow(1.0 - max(dot(normalize(normal), normalize(view)), 0.0), 2.0);
	return vec2(sunward, edge * sunward);
}

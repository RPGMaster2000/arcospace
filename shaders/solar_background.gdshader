shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
// Opaque radial star/corona. No bloom, lights or transparent full-screen layers.
uniform vec4 space_color : source_color = vec4(0.025, 0.008, 0.006, 1.0);
uniform vec4 corona_color : source_color = vec4(0.7, 0.17, 0.025, 1.0);
uniform vec4 star_color : source_color = vec4(1.0, 0.78, 0.36, 1.0);
uniform vec2 star_center = vec2(0.55, 0.50);
uniform float star_radius : hint_range(0.02, 0.5) = 0.13;
uniform float corona_intensity : hint_range(0.0, 1.0) = 0.36;
uniform float animation_speed : hint_range(0.0, 0.1) = 0.025;
uniform float band_scale : hint_range(2.0, 40.0) = 16.0;
void fragment() {
	vec2 p = (UV - star_center) * vec2(2.4, 1.0);
	float radius = length(p), angle = atan(p.y, p.x);
	float t = TIME * animation_speed;
	float bands = sin(angle * band_scale + t + sin(angle * 7.0 - t) * 0.6) * 0.5 + 0.5;
	float edge = star_radius + bands * 0.006;
	float disc = 1.0 - smoothstep(edge - 0.009, edge, radius);
	float corona = exp(-max(0.0, radius - edge) * 11.0) * (0.65 + bands * 0.35);
	float pulse = 0.96 + 0.04 * sin(t * 2.0);
	vec3 color = space_color.rgb + corona_color.rgb * corona * corona_intensity * pulse;
	color = mix(color, star_color.rgb * (0.95 + 0.025 * sin(angle * 6.0 + t + sin(radius * 35.0 - t))), disc);
	// A very sparse fixed star layer outside the stellar disc.
	vec2 q = UV * vec2(230.0, 95.0);
	float h = fract(sin(dot(floor(q), vec2(127.1, 311.7))) * 43758.5453);
	color += vec3(0.25) * step(0.985, h) * (1.0 - smoothstep(0.01, 0.07, length(fract(q) - 0.5))) * (1.0 - disc);
	ALBEDO = color;
}

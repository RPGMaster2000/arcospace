shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 storm_color : source_color;
uniform float phase;
uniform float density;
uniform float layer;

float hash_cell(vec2 cell) {
	vec3 p = fract(vec3(cell.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float cloud_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 f = fract(point);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_cell(cell), hash_cell(cell + vec2(1.0, 0.0)), f.x),
		mix(hash_cell(cell + vec2(0.0, 1.0)), hash_cell(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = 1.0 - smoothstep(0.64, 1.0, length(p));
	float time = TIME * 0.12;
	vec2 drift = vec2(time, -time * 0.47);
	float broad = cloud_noise(p * 3.6 + drift + vec2(phase, layer * 3.0));
	float detail = cloud_noise(p * 9.0 + vec2(broad * 1.8) - drift * 1.25 + layer);
	float cloud = smoothstep(0.23, 0.81, broad * 0.68 + detail * 0.32);
	float pulse = smoothstep(0.86, 1.0, sin(TIME * 0.92 + phase + layer * 1.7));
	float illumination = pulse * smoothstep(0.55, 0.91, broad) * detail;
	ALBEDO = storm_color.rgb * (0.53 + cloud * 0.64 + illumination * 0.65);
	ALPHA = edge * (0.12 + cloud * 0.88) * density;
}

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 storm_color : source_color;
uniform float phase;
uniform float density;
uniform float layer;
uniform float front_strength = 0.0;

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
	if (front_strength > 0.0) {
		float flash_time = TIME * 0.62 + phase;
		float pulse_width = smoothstep(0.91, 0.965, fract(flash_time)) *
			(1.0 - smoothstep(0.975, 1.0, fract(flash_time)));
		float strike = hash_cell(vec2(floor(flash_time), phase)) * 1.14 - 0.57;
		float crooked = strike + 0.08 * sin(p.y * 24.0 + phase) + 0.05 * sin(p.y * 51.0);
		float lightning = (1.0 - smoothstep(0.010, 0.054, abs(p.x - crooked))) *
			(1.0 - smoothstep(0.22, 0.84, abs(p.y))) * pulse_width;
		ALBEDO = mix(storm_color.rgb * (0.56 + cloud * 0.8), vec3(0.77, 0.87, 1.0), lightning);
		ALPHA = min(0.66, edge * ((0.21 + cloud * 0.79) * density + lightning * 0.36));
	}
}

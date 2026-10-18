shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
// One opaque backdrop: three low-frequency noise samples, one sparse star layer.
// Scene-local uniforms define the appearance; there is no gameplay/modifier lookup.
uniform vec4 space_color : source_color = vec4(0.008, 0.014, 0.028, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.06, 0.11, 0.18, 1.0);
uniform vec4 accent_color : source_color = vec4(0.08, 0.18, 0.24, 1.0);
uniform float cloud_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float cloud_scale : hint_range(1.0, 12.0) = 4.0;
uniform float animation_speed : hint_range(0.0, 0.1) = 0.0;
uniform float star_density : hint_range(0.0, 1.0) = 0.14;
uniform float star_brightness : hint_range(0.0, 1.0) = 0.35;
uniform float streak_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float rift_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 feature_center = vec2(0.66, 0.50);
uniform float variation_seed = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 uv = UV * vec2(2.4, 1.0);
	float t = TIME * animation_speed;
	vec2 p = uv * cloud_scale + vec2(variation_seed, t);
	float n = noise(p) * 0.60 + noise(p * 2.03 + vec2(t, 4.1)) * 0.28 + noise(p * 4.1) * 0.12;
	vec3 color = space_color.rgb + mix(cloud_color.rgb, accent_color.rgb, smoothstep(0.45, 0.8, n)) * smoothstep(0.22, 0.85, n) * cloud_intensity;
	vec2 cell = floor(uv * 95.0);
	vec2 spot = fract(uv * 95.0) - vec2(0.5);
	float stars = (1.0 - smoothstep(0.025, 0.14, length(spot))) * step(1.0 - star_density, hash(cell + variation_seed));
	color += vec3(0.7, 0.82, 1.0) * stars * star_brightness;
	// Sparse, gently moving streaks rather than full-screen lightning flashes.
	float streak = exp(-abs(uv.y - 0.45 - sin(uv.x * 4.0 + t) * 0.16 - sin(uv.x * 15.0 - t) * 0.015) * 230.0);
	color += accent_color.rgb * streak * streak_intensity * smoothstep(0.5, 0.85, n);
	vec2 r = (UV - feature_center) * vec2(2.4, 1.0);
	float ring = exp(-abs(length(r) - 0.34 - sin(atan(r.y, r.x) * 3.0 + t) * 0.018) * 100.0);
	color += accent_color.rgb * ring * rift_intensity * (0.7 + 0.3 * n);
	ALBEDO = color;
}

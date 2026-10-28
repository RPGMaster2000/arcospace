shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
// One opaque backdrop: three low-frequency noise samples, one sparse star layer with optional position jitter.
// Scene-local uniforms define the appearance; there is no gameplay/modifier lookup.
uniform vec4 space_color : source_color = vec4(0.008, 0.014, 0.028, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.06, 0.11, 0.18, 1.0);
uniform vec4 accent_color : source_color = vec4(0.08, 0.18, 0.24, 1.0);
uniform float cloud_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float cloud_scale : hint_range(1.0, 12.0) = 4.0;
uniform float animation_speed : hint_range(0.0, 0.1) = 0.0;
uniform float star_density : hint_range(0.0, 1.0) = 0.14;
uniform float star_resolution : hint_range(50.0, 500.0) = 95.0;
uniform float star_jitter : hint_range(0.0, 1.0) = 0.0;
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
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform float panorama_brightness : hint_range(0.0, 2.0) = 0.65;
uniform vec4 panorama_tint : source_color = vec4(1.0);
uniform vec2 panorama_center = vec2(0.5, 0.5);
uniform float panorama_view_width : hint_range(0.2, 3.0) = 1.5;
uniform float procedural_overlay : hint_range(0.0, 1.0) = 0.08;
void fragment() {
	vec2 uv = UV * vec2(2.4, 1.0);
	float t = TIME * animation_speed;
	vec2 p = uv * cloud_scale + vec2(variation_seed, t);
	float n = noise(p) * 0.60 + noise(p * 2.03 + vec2(t, 4.1)) * 0.28 + noise(p * 4.1) * 0.12;
	vec3 color = space_color.rgb + mix(cloud_color.rgb, accent_color.rgb, smoothstep(0.45, 0.8, n)) * smoothstep(0.22, 0.85, n) * cloud_intensity;
	// Perspective sampling of the panorama, rather than stretching the full sphere flat.
	vec2 plane = (UV - vec2(0.5)) * vec2(2.0, 1.0) * panorama_view_width;
	vec3 direction = normalize(vec3(plane.x, -plane.y, 1.0));
	vec2 panorama_uv = vec2(atan(direction.x, direction.z) / 6.28318530718,
		-asin(clamp(direction.y, -1.0, 1.0)) / 3.14159265359) + panorama_center;
	vec3 sky_color = texture(panorama, vec2(fract(panorama_uv.x), clamp(panorama_uv.y, 0.001, 0.999))).rgb;
	// Keep ship silhouettes and lower hull labels readable over bright clouds.
	float center_dim = mix(0.58, 1.0, smoothstep(0.12, 0.48, abs(UV.x - 0.5)));
	float lower_dim = mix(0.25, 1.0, smoothstep(0.05, 0.4, UV.y));
	color = sky_color * panorama_tint.rgb * panorama_brightness * center_dim * lower_dim + color * procedural_overlay;
	vec2 cell = floor(uv * star_resolution);
	vec2 random_position = vec2(hash(cell + variation_seed + 17.3), hash(cell.yx + variation_seed + 53.9));
	vec2 center = mix(vec2(0.5), vec2(0.16) + random_position * 0.68, star_jitter);
	vec2 spot = fract(uv * star_resolution) - center;
	float radius = mix(0.14, mix(0.045, 0.16, hash(cell + 92.7)), star_jitter);
	float edge = max(length(fwidth(uv * star_resolution)) * 0.5, 0.015);
	float stars = (1.0 - smoothstep(max(0.0, radius - edge), radius + edge, length(spot))) * step(1.0 - star_density, hash(cell + variation_seed));
	stars *= mix(1.0, 0.3 + random_position.y * 0.7, star_jitter);
	if (star_jitter == 0.0) {
		stars = (1.0 - smoothstep(0.025, 0.14, length(spot))) * step(1.0 - star_density, hash(cell + variation_seed));
	}
	color += vec3(0.7, 0.82, 1.0) * stars * star_brightness;
	// Sparse, gently moving streaks rather than full-screen lightning flashes.
	float streak = exp(-abs(uv.y - 0.45 - sin(uv.x * 4.0 + t) * 0.16 - sin(uv.x * 15.0 - t) * 0.015) * 230.0);
	color += accent_color.rgb * streak * streak_intensity * smoothstep(0.5, 0.85, n);
	vec2 r = (UV - feature_center) * vec2(2.4, 1.0);
	float ring = exp(-abs(length(r) - 0.34 - sin(atan(r.y, r.x) * 3.0 + t) * 0.018) * 100.0);
	color += accent_color.rgb * ring * rift_intensity * (0.7 + 0.3 * n);
	ALBEDO = color;
}

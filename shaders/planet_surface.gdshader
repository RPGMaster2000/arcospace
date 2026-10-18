shader_type spatial;
// Low-frequency bands and continents on an opaque, normally lit sphere.
uniform vec4 ocean_color : source_color = vec4(0.025, 0.07, 0.12, 1.0);
uniform vec4 land_color : source_color = vec4(0.10, 0.17, 0.20, 1.0);
uniform vec4 rim_color : source_color = vec4(0.10, 0.23, 0.32, 1.0);
uniform float surface_scale : hint_range(1.0, 20.0) = 7.0;
uniform float rim_intensity : hint_range(0.0, 0.3) = 0.09;
void fragment() {
	float pattern = sin(UV.x * surface_scale * 6.28 + sin(UV.y * 23.0) * 2.0) * sin(UV.y * 31.0 + sin(UV.x * 17.0));
	ALBEDO = mix(ocean_color.rgb, land_color.rgb, smoothstep(-0.1, 0.6, pattern));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = rim_color.rgb * pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0) * rim_intensity;
}

shader_type spatial;
render_mode unshaded, fog_disabled, cull_front, depth_draw_opaque;
// Write the distant opaque surface depth normally: disabling it lets this
// background overwrite transparent beam passes. Foreground geometry still occludes VFX.
// Standard arenas only. A stationary enclosing mesh supplies coverage; sampling
// follows the world ray, never the mesh UV, position, scale or active camera pose.
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform mat3 panorama_basis = mat3(1.0);
uniform vec2 panorama_center = vec2(0.48, 0.49);
uniform float panorama_brightness : hint_range(0.0, 2.0) = 0.40;
uniform vec4 panorama_tint : source_color = vec4(1.0);
uniform vec4 space_color : source_color = vec4(0.006, 0.012, 0.025, 1.0);
void fragment() {
	vec3 world_ray = normalize((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
	vec3 ray = panorama_basis * world_ray;
	vec2 uv = vec2(atan(ray.x, -ray.z) / TAU, -asin(clamp(ray.y, -1.0, 1.0)) / PI) + panorama_center;
	// Unwrap horizontal derivatives at the longitude seam before mip selection.
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	dx.x -= round(dx.x);
	dy.x -= round(dy.x);
	uv.y = clamp(uv.y, 0.001, 0.999);
	ALBEDO = textureGrad(panorama, uv, dx, dy).rgb * panorama_tint.rgb * panorama_brightness + space_color.rgb * 0.08;
}

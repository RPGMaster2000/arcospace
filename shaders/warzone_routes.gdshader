shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform bool moving = false;
uniform float width_pixels = 4.0;

varying vec4 route_color;

void vertex() {
	route_color = COLOR;
	vec4 view_point = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip = PROJECTION_MATRIX * view_point;
	vec4 ahead = PROJECTION_MATRIX * (view_point + vec4(mat3(MODELVIEW_MATRIX) * NORMAL, 0.0));
	// Project the tangent, then extrude perpendicular to it in viewport pixels.
	// Using the homogeneous derivative avoids dividing by the ahead point's w.
	vec2 direction = (ahead.xy * clip.w - clip.xy * ahead.w) * VIEWPORT_SIZE;
	vec2 normal = vec2(-direction.y, direction.x) / max(length(direction), 0.00001);
	float offset = (UV.y - 0.5) * width_pixels + UV2.x;
	clip.xy += normal * (2.0 * offset / VIEWPORT_SIZE) * clip.w;
	POSITION = clip;
}

void fragment() {
	float edge = 1.0 - smoothstep(max(0.0, width_pixels * 0.5 - 1.0),
		width_pixels * 0.5, abs(UV.y - 0.5) * width_pixels);
	float pattern = fract(UV.x / 1.05 - TIME * 2.1);
	float dash = smoothstep(0.0, 0.09, pattern) * (1.0 - smoothstep(0.48, 0.58, pattern));
	float break_pattern = smoothstep(0.45, 0.55, fract(UV.x / 1.4));
	ALBEDO = route_color.rgb;
	ALPHA = edge * (moving ? dash * 0.87 : mix(1.0, mix(0.22, 0.72, break_pattern), UV2.y));
}

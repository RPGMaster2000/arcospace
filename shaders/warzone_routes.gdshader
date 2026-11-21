shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform bool moving = false;

varying vec4 route_color;

void vertex() {
	route_color = COLOR;
}

void fragment() {
	float edge = 1.0 - smoothstep(0.61, 1.0, abs(UV.y * 2.0 - 1.0));
	float pattern = fract(UV.x / 1.05 - TIME * 2.1);
	float dash = smoothstep(0.0, 0.09, pattern) * (1.0 - smoothstep(0.48, 0.58, pattern));
	ALBEDO = route_color.rgb;
	ALPHA = route_color.a * edge * (moving ? dash : 1.0);
}

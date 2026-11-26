shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 ring_color : source_color = vec4(0.65, 0.9, 1.0, 1.0);
uniform float emphasis = 0.0;
uniform bool use_ring_image = false;
uniform sampler2D ring_image : source_color, filter_linear, repeat_disable;

void fragment() {
	vec2 point = (UV - vec2(0.5)) * 2.0;
	float radius = length(point);
	float angle = atan(point.y, point.x);
	float distance_to_ring = abs(radius - 0.84);
	float line = 1.0 - smoothstep(0.009, 0.029, distance_to_ring);
	float sector = abs(sin(angle * 2.0));
	float brackets = line * (1.0 - smoothstep(0.38, 0.53, sector));
	float tick = (1.0 - smoothstep(0.02, 0.052, min(abs(point.x), abs(point.y))))
		* smoothstep(0.86, 0.88, radius) * (1.0 - smoothstep(0.96, 0.99, radius));
	float trace = (1.0 - smoothstep(0.008, 0.018, abs(radius - 0.71))) * (1.0 - smoothstep(0.16, 0.25, abs(sin(angle * 8.0))));
	float glow = exp(-distance_to_ring * 42.0) * 0.16;
	vec4 authored = use_ring_image ? texture(ring_image, UV) : vec4(1.0);
	ALBEDO = ring_color.rgb * authored.rgb;
	ALPHA = use_ring_image
		? authored.a * mix(0.48, 0.86, emphasis)
		: (brackets * 0.9 + line * 0.25 + glow + tick + trace * emphasis) * mix(0.32, 0.73, emphasis);
}

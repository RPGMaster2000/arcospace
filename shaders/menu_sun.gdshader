shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// One occludable billboard: warm disc, corona and restrained optical streaks.
uniform vec4 sun_color : source_color = vec4(1.0, 0.76, 0.4, 1.0);
uniform float flare_intensity : hint_range(0.0, 1.0) = 0.22;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float disc = 1.0 - smoothstep(0.10, 0.14, r);
	float corona = exp(-r * 9.0) * 0.65;
	float rays = (exp(-abs(p.y) * 100.0) + exp(-abs(p.x) * 65.0) * 0.3) * exp(-r * 3.0);
	float fade = 1.0 - smoothstep(0.7, 1.0, r);
	ALBEDO = sun_color.rgb;
	ALPHA = clamp((disc + corona + rays * flare_intensity) * fade, 0.0, 1.0);
}

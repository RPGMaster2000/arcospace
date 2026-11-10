shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// One occludable billboard: warm disc, corona and restrained optical streaks.
uniform vec4 sun_color : source_color = vec4(1.0, 0.76, 0.4, 1.0);
// Default preserves title/battle presentation; map materials may enlarge the core.
uniform float core_scale : hint_range(1.0, 2.0) = 1.0;
// Map-only optical calibration; defaults retain menu and combat appearance.
uniform float corona_spread = 1.0;
uniform float corona_strength = 1.0;
uniform float core_whitening = 0.0;
uniform bool map_corona_visibility = false;
varying float source_visibility;
uniform float flare_intensity : hint_range(0.0, 1.0) = 0.22;
void vertex() {
	vec4 source_clip = PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX * vec4(0.0,0.0,0.0,1.0);
	vec2 source_uv = source_clip.xy / max(source_clip.w,0.0001) * 0.5 + 0.5;
	float edge = min(min(source_uv.x,1.0-source_uv.x),min(source_uv.y,1.0-source_uv.y));
	source_visibility = source_clip.w > 0.0 ? smoothstep(-0.03,0.04,edge) : 0.0;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float disc = 1.0 - smoothstep(0.10 * core_scale, 0.14 * core_scale, r);
	float corona = exp(-r * 9.0 / (core_scale * corona_spread)) * 0.65 * corona_strength;
	float rays = (exp(-abs(p.y) * 100.0) + exp(-abs(p.x) * 65.0) * 0.3) * exp(-r * 3.0);
	float fade = 1.0 - smoothstep(0.7, 1.0, r);
	ALBEDO = mix(sun_color.rgb, vec3(1.0), core_whitening * (1.0 - smoothstep(0.02 * core_scale, 0.11 * core_scale, r)));
	float optical_visibility = map_corona_visibility ? source_visibility : 1.0;
	ALPHA = clamp((disc + (corona + rays * flare_intensity) * optical_visibility) * fade, 0.0, 1.0);
}

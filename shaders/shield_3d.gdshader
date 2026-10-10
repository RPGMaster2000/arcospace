shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.2, 0.65, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float formation : hint_range(0.0, 1.0) = 1.0;
uniform float hit = 0.0;
void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.0);
	float radius = sqrt(max(0.0, 1.0 - facing * facing));
	float reveal = formation >= 1.0 ? 1.0 : 1.0 - smoothstep(formation - 0.04, formation + 0.04, radius);
	float wave = (1.0 - smoothstep(0.0, 0.09, abs(radius - formation))) * sin(formation * 3.14159);
	ALBEDO = tint.rgb;
	ALPHA = strength * clamp((0.035 + rim * 0.5 + hit * 0.22) * reveal + wave * 0.65, 0.0, 0.9);
}

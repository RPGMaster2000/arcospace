shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform float brightness = 1.0;
uniform float fade = 1.0;
void fragment() {
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * brightness;
	ALPHA = tint.a * fade;
}

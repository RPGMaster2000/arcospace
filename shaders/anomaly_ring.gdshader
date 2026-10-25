shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 tint : source_color = vec4(0.3,0.6,0.85,1.0);
void fragment() {
 float wave = 0.7 + 0.3*sin(UV.x*37.0-TIME*0.5+sin(UV.y*12.0));
 ALBEDO=tint.rgb*wave;
 EMISSION=tint.rgb*wave*0.35;
}

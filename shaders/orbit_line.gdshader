shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec4 line_color : source_color = vec4(0.48,0.73,0.86,0.18);
uniform float line_width = 2.0;
void vertex() {
 vec4 center = PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.0);
 vec4 ahead = PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX+NORMAL,1.0);
 vec2 tangent = (ahead.xy/ahead.w-center.xy/center.w)*VIEWPORT_SIZE;
 tangent /= max(length(tangent),0.0001);
 vec2 side = vec2(-tangent.y,tangent.x);
 center.xy += side*(UV.x*2.0-1.0)*line_width/VIEWPORT_SIZE*center.w;
 POSITION = center;
}
void fragment() {
 ALBEDO = line_color.rgb;
 ALPHA = line_color.a*(1.0-smoothstep(0.55,1.0,abs(UV.x*2.0-1.0)));
}

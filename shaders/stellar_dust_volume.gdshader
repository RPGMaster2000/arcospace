shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, fog_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
instance uniform vec3 volume_extent = vec3(1.0);
instance uniform float body_radius = 1.0;
instance uniform float shaft_length = 10.0;
instance uniform float spread = 0.12;
instance uniform float umbra_slope = -0.1;
instance uniform float density = 0.035;
uniform vec4 dust_color : source_color = vec4(0.42,0.52,0.62,1.0);
varying vec3 local_camera;
varying vec3 local_surface;
varying mat4 world_to_local;
void vertex() {
	VERTEX *= volume_extent;
	world_to_local = inverse(MODEL_MATRIX);
	local_camera = (world_to_local * vec4(CAMERA_POSITION_WORLD,1.0)).xyz;
	local_surface = VERTEX;
}
float weighted_segment(vec3 o, vec3 d, float lo, float hi, float len) {
	float span = max(0.0,hi-lo);
	float z = (o.z+d.z*(lo+hi)*0.5)/len;
	float dz = d.z*span/len;
	return max(0.0,span*6.0*(z*(1.0-z)-dz*dz/12.0));
}
// Exact length of a camera ray inside a finite cone. No marching or sample loop.
float cone_path(vec3 o, vec3 d, float radius, float slope, float length_limit, float far_limit) {
	float lo = 0.0;
	float hi = far_limit;
	if (abs(d.z) < 0.00001) {
		if (o.z < 0.0 || o.z > length_limit) return 0.0;
	} else {
		float a = -o.z / d.z;
		float b = (length_limit-o.z) / d.z;
		lo = max(lo,min(a,b)); hi = min(hi,max(a,b));
	}
	if (hi <= lo) return 0.0;
	float r = radius + slope*o.z;
	float a = dot(d.xy,d.xy)-slope*slope*d.z*d.z;
	float b = 2.0*(dot(o.xy,d.xy)-r*slope*d.z);
	float c = dot(o.xy,o.xy)-r*r;
	if (abs(a) < 0.00001) {
		if (abs(b) < 0.00001) return c <= 0.0 ? weighted_segment(o,d,lo,hi,length_limit) : 0.0;
		float root = -c/b;
		return b > 0.0 ? weighted_segment(o,d,lo,min(hi,root),length_limit) : weighted_segment(o,d,max(lo,root),hi,length_limit);
	}
	float discriminant = b*b-4.0*a*c;
	if (discriminant <= 0.0) return a < 0.0 ? weighted_segment(o,d,lo,hi,length_limit) : 0.0;
	float root = sqrt(discriminant);
	float t0 = (-b-root)/(2.0*a);
	float t1 = (-b+root)/(2.0*a);
	float middle = weighted_segment(o,d,max(lo,min(t0,t1)),min(hi,max(t0,t1)),length_limit);
	return a > 0.0 ? middle : max(0.0,weighted_segment(o,d,lo,hi,length_limit)-middle);
}
void fragment() {
	vec3 direction = normalize(local_surface-local_camera);
	vec3 origin = local_camera + vec3(0.0,0.0,shaft_length*0.5);
	float depth = texture(scene_depth,SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV,depth)*2.0-1.0;
#else
	vec3 ndc = vec3(SCREEN_UV*2.0-1.0,depth);
#endif
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(ndc,1.0);
	view_position /= max(abs(view_position.w),0.00001);
	vec3 local_depth = (world_to_local * INV_VIEW_MATRIX * vec4(view_position.xyz,1.0)).xyz;
	float limit = depth > 0.000001 ? length(local_depth-local_camera) : 1000.0;
	float outer = cone_path(origin,direction,body_radius*1.65,spread,shaft_length,limit);
	float middle = cone_path(origin,direction,body_radius*1.35,spread*0.8,shaft_length,limit);
	float core = cone_path(origin,direction,body_radius*1.1,spread*0.55,shaft_length,limit);
	float umbra_length = umbra_slope < 0.0 ? min(shaft_length,body_radius/max(-umbra_slope,0.001)) : shaft_length;
	float umbra = cone_path(origin,direction,body_radius,umbra_slope,umbra_length,limit);
	float optical_path = max(0.0,outer*0.12 + middle*0.33 + core*0.55 - umbra*0.85);
	ALBEDO = dust_color.rgb;
	float opacity = min(0.26,1.0-exp(-density*optical_path/max(body_radius,0.25)));
	float dither = fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453)-0.5;
	ALPHA = clamp(opacity + dither*min(opacity,1.0/256.0),0.0,0.26);
}

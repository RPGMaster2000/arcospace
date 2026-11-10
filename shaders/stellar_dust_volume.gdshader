shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, fog_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 field_extent = vec3(56.0,14.0,56.0);
uniform vec4 dust_color : source_color = vec4(0.32,0.41,0.50,1.0);
uniform float density = 0.007;
uniform int body_count = 0;
uniform vec4 bodies[6]; // xyz: star-relative center; w: physical radius
uniform vec4 axes[6]; // xyz: direction away from star; w: umbra slope
uniform float star_radius = 2.52;
// Umbra, penumbra and maximum removed fraction; retain illuminated dust in shadows.
uniform vec3 shadow_strength = vec3(0.95,1.20,0.90);
varying vec3 camera_local;
varying vec3 surface_local;
varying mat4 world_to_field;
void vertex() {
	VERTEX *= field_extent * 2.0;
	world_to_field = inverse(MODEL_MATRIX);
	camera_local = (world_to_field * vec4(CAMERA_POSITION_WORLD,1.0)).xyz;
	surface_local = VERTEX;
}
// Exact integral of a broad quadratic ellipsoidal medium, zero at its remote edge.
float medium(vec3 o, vec3 d, float lo, float hi) {
	float span = max(0.0,hi-lo);
	vec3 midpoint = (o+d*(lo+hi)*0.5)/field_extent;
	vec3 step_size = d*span/field_extent;
	return max(0.0,span*(1.0-dot(midpoint,midpoint)-dot(step_size,step_size)/12.0));
}
// Reused finite-cone intersection, clipped to the GLOBAL medium ray interval.
float shadow(vec3 o, vec3 d, vec4 body, vec3 axis, float slope, float radius,
		float length_limit, float lo, float hi) {
	vec3 relative = o-body.xyz;
	float oz = dot(relative,axis);
	float dz = dot(d,axis);
	if (abs(dz)<0.00001) {
		if (oz<0.0 || oz>length_limit) return 0.0;
	} else {
		float t0=-oz/dz;
		float t1=(length_limit-oz)/dz;
		lo=max(lo,min(t0,t1)); hi=min(hi,max(t0,t1));
	}
	if (hi<=lo) return 0.0;
	float r=radius+slope*oz;
	float a=dot(d,d)-dz*dz*(1.0+slope*slope);
	float b=2.0*(dot(relative,d)-oz*dz-r*slope*dz);
	float c=dot(relative,relative)-oz*oz-r*r;
	if (abs(a)<0.00001) {
		if (abs(b)<0.00001) return c<=0.0 ? medium(o,d,lo,hi):0.0;
		float root=-c/b;
		return b>0.0 ? medium(o,d,lo,min(hi,root)):medium(o,d,max(lo,root),hi);
	}
	float discriminant=b*b-4.0*a*c;
	if (discriminant<=0.0) return a<0.0 ? medium(o,d,lo,hi):0.0;
	float root=sqrt(discriminant);
	float t0=(-b-root)/(2.0*a);
	float t1=(-b+root)/(2.0*a);
	float middle=medium(o,d,max(lo,min(t0,t1)),min(hi,max(t0,t1)));
	return a>0.0 ? middle:max(0.0,medium(o,d,lo,hi)-middle);
}
void fragment() {
	vec3 o=camera_local;
	vec3 d=normalize(surface_local-o);
	vec3 so=o/field_extent;
	vec3 sd=d/field_extent;
	float a=dot(sd,sd);
	float b=dot(so,sd);
	float discriminant=b*b-a*(dot(so,so)-1.0);
	float root=sqrt(max(discriminant,0.0));
	float lo=max(0.0,(-b-root)/a);
	float hi=(-b+root)/a;
	float depth=texture(scene_depth,SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc=vec3(SCREEN_UV,depth)*2.0-1.0;
#else
	vec3 ndc=vec3(SCREEN_UV*2.0-1.0,depth);
#endif
	vec4 view_position=INV_PROJECTION_MATRIX*vec4(ndc,1.0);
	view_position/=max(abs(view_position.w),0.00001);
	vec3 scene_position=(world_to_field*INV_VIEW_MATRIX*vec4(view_position.xyz,1.0)).xyz;
	if (depth>0.000001) hi=min(hi,length(scene_position-o));
	float illuminated=discriminant>0.0 ? medium(o,d,lo,hi):0.0;
	float blocked=0.0;
	for (int i=0;i<6;i++) {
		if (i>=body_count) break;
		float radius=bodies[i].w;
		float distance_to_star=length(bodies[i].xyz);
		float slope=axes[i].w;
		float reach=field_extent.x*3.0;
		float umbra_end=slope<0.0 ? min(reach,radius/max(-slope,0.001)):reach;
		float core=shadow(o,d,bodies[i],axes[i].xyz,slope,radius,umbra_end,lo,hi);
		float penumbra_slope=(radius+star_radius)/max(distance_to_star,0.1);
		float soft=shadow(o,d,bodies[i],axes[i].xyz,penumbra_slope,radius,reach,lo,hi);
		float z=max(0.0,dot(o+d*(lo+hi)*0.5-bodies[i].xyz,axes[i].xyz));
		float coverage=radius/max(radius+penumbra_slope*z,radius);
		blocked=max(blocked,min(illuminated*shadow_strength.z,core*shadow_strength.x+soft*shadow_strength.y*coverage));
	}
	vec3 p=o+d*(lo+hi)*0.5;
	// Stable low-frequency WORLD structure, not a camera-relative sky overlay.
	float structure=0.86+0.08*sin(p.x*0.11+p.z*0.07)+0.06*sin(p.z*0.17-p.y*0.13);
	float path=max(0.0,illuminated-blocked)*structure;
	float opacity=hi>lo ? min(0.42,1.0-exp(-density*path)):0.0;
	float dither=fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453)-0.5;
	ALBEDO=dust_color.rgb;
	ALPHA=clamp(opacity+dither*min(opacity,1.0/256.0),0.0,0.42);
}

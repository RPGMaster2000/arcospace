shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 sources[12];
uniform int source_count = 0;
uniform float reach = 13.0;
varying vec2 sector_position;

void vertex() {
	sector_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 influence = vec2(0.0);
	for (int i = 0; i < 12; i++) {
		if (i >= source_count) { break; }
		vec2 delta = (sources[i].xy - sector_position) / reach;
		float weight = 1.0 - smoothstep(0.0, 1.0, dot(delta, delta));
		influence += sources[i].zw * weight * weight;
	}
	float strength = influence.x + influence.y;
	float control = influence.y / max(strength, 0.001);
	ALBEDO = mix(vec3(0.08, 0.30, 0.70), vec3(0.74, 0.11, 0.15), control);
	ALPHA = min(0.32, strength * 0.17);
}

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 sources[12];
uniform int source_count = 0;
uniform float reach = 13.0;
uniform float projection_strength : hint_range(0.0, 1.0) = 0.58;
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
	vec3 allies = vec3(0.21, 0.38, 0.60);
	vec3 hostiles = vec3(0.55, 0.25, 0.29);
	vec3 neutral = vec3(0.32, 0.31, 0.40);
	ALBEDO = mix(neutral, mix(allies, hostiles, control), smoothstep(0.0, 0.40, abs(control - 0.5)));
	ALPHA = (1.0 - exp(-strength * 0.60)) * 0.26 * projection_strength;
}

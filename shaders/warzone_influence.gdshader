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
	vec3 allies = vec3(0.05, 0.24, 0.69);
	vec3 hostiles = vec3(0.65, 0.075, 0.12);
	vec3 neutral = vec3(0.28, 0.23, 0.35);
	ALBEDO = mix(neutral, mix(allies, hostiles, control), smoothstep(0.0, 0.40, abs(control - 0.5)));
	ALPHA = (1.0 - exp(-strength * 0.60)) * 0.32;
}

shader_type canvas_item;
render_mode unshaded;

uniform vec4 holes[24];
uniform int hole_count = 0;
uniform float opacity : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	float clear = 0.0;
	for (int i = 0; i < hole_count; i++) {
		vec2 edge = min(UV - holes[i].xy, holes[i].zw - UV);
		clear = max(clear, smoothstep(0.0, 0.004, min(edge.x, edge.y)));
	}
	COLOR = vec4(0.0, 0.0, 0.0, opacity * (1.0 - clear));
}

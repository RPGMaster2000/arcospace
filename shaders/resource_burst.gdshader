shader_type canvas_item;
uniform vec4 tint : source_color;
uniform bool beam = false;
uniform float progress = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float fade = sin(progress * 3.14159);
	float shape;
	if (beam) {
		shape = pow(max(0.0, 1.0 - abs(p.y)), 4.0) * pow(max(0.0, 1.0 - abs(p.x)), 0.6);
		shape *= 1.0 - smoothstep(progress * 2.5, progress * 2.5 + 0.15, abs(p.x));
	} else {
		shape = pow(max(0.0, 1.0 - length(vec2(p.x, p.y * 0.65))), 1.4);
	}
	COLOR = vec4(mix(tint.rgb, vec3(1.0), beam ? 0.3 : 0.0), shape * fade * 0.85);
}

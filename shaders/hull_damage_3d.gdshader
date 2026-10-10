shader_type spatial;
render_mode unshaded, depth_draw_never;
uniform float damage = 0.0;
varying vec3 local_pos;
varying vec3 local_normal;
void vertex() { local_pos = VERTEX; local_normal = NORMAL; }
void fragment() {
	vec3 n = abs(local_normal);
	vec2 surface = n.y > n.z ? local_pos.xz : local_pos.xy;
	if (n.x > max(n.y, n.z)) { surface = local_pos.zy; }
	vec2 grid = surface * vec2(3.2, 4.0);
	vec2 cell = floor(grid);
	float seed = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	vec2 point = fract(grid) - vec2(0.5);
	float scar = 1.0 - smoothstep(0.12, 0.34, length(point * vec2(0.85, 1.4)));
	float crack = 1.0 - smoothstep(0.015, 0.065, abs(point.y + sin(point.x * 25.0 + seed) * 0.045));
	float flicker = 0.6 + 0.3 * sin(TIME * 3.5 + seed * 30.0);
	float fire = crack * flicker;
	ALBEDO = mix(vec3(0.045, 0.025, 0.018), vec3(1.0, 0.25, 0.015), fire);
	ALPHA = scar * step(seed, damage * 0.75) * step(0.01, damage) * 0.5;
}

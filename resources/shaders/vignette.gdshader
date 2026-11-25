// Danger vignette: a soft colored edge that closes in as tension rises.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 0.27, 0.42, 1.0);
uniform float amount = 0.0;   // 0..1
uniform float aspect = 0.5625;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= mix(1.0, aspect, 0.5);
	float v = smoothstep(0.62, 1.32, length(p));
	COLOR = vec4(tint.rgb, v * amount * tint.a);
}

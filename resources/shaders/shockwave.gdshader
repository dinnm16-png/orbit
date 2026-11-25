// Screen-space shockwave: an expanding ring that bends what is behind it,
// with a slight color split at the edge. Only visible during big moments.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 center = vec2(0.5, 0.5);   // screen UV
uniform float radius = 0.0;             // in screen heights
uniform float width = 0.06;
uniform float strength = 0.0;
uniform float aspect = 0.5625;          // screen width / height

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - center;
	d.x *= aspect;
	float dist = length(d);
	float band = 1.0 - smoothstep(0.0, width, abs(dist - radius));
	vec2 dir = d / max(dist, 0.0001);
	vec2 off = dir * band * strength;
	off.x /= aspect;
	float r = texture(screen_tex, uv - off * 1.35).r;
	float g = texture(screen_tex, uv - off).g;
	float b = texture(screen_tex, uv - off * 0.65).b;
	COLOR = vec4(r, g, b, 1.0);
}

// ORBIT planet shader — one quad per planet, everything computed per pixel.
//
// Why: drawing planets from many stacked translucent circles produced ~35 draw
// calls per planet. A single quad with this shader is ONE draw, and because
// every planet shares the same material, Godot can batch them together.
//
// Inputs (no per-planet uniforms, so batching is not broken):
//   UV     0..1 across the quad
//   COLOR  the planet's base color (passed as the vertex color)
// The quad is GLOW_SCALE times the planet radius (see PlanetArt.GLOW_SCALE).
shader_type canvas_item;
render_mode blend_mix, unshaded;

const float GLOW_SCALE = 1.7;
const vec3 LIGHT_DIR = vec3(-0.45, -0.6, 0.66); // top-left, towards the viewer

void fragment() {
	vec3 base = COLOR.rgb;
	// Position in units of the planet radius: |p| = 1 is the planet's edge.
	vec2 p = (UV * 2.0 - 1.0) * GLOW_SCALE;
	float d = length(p);
	float aa = max(fwidth(d), 0.0001) * 1.2;
	float body = 1.0 - smoothstep(1.0 - aa, 1.0, d);

	// Sphere normal from the 2D position -> smooth 3D lighting.
	float z = sqrt(max(1.0 - d * d, 0.0));
	vec3 n = normalize(vec3(p, z));
	vec3 l = normalize(LIGHT_DIR);
	float diffuse = clamp(dot(n, l), 0.0, 1.0);
	vec3 shade = mix(base * 0.28, mix(base, vec3(1.0), 0.15), smoothstep(-0.1, 1.0, diffuse));
	// Soft specular highlight.
	float spec = pow(clamp(dot(reflect(-l, n), vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 18.0);
	shade += vec3(spec * 0.35);
	// Rim light: thin bright edge, stronger on the lit side.
	float rim = smoothstep(0.80, 1.0, d) * (0.25 + 0.5 * clamp(dot(normalize(p + 1e-5), l.xy), 0.0, 1.0));
	shade = mix(shade, mix(base, vec3(1.0), 0.6), rim * 0.55);

	// Outer glow: smooth falloff from the edge to the quad border.
	float g = 1.0 - smoothstep(1.0, GLOW_SCALE, d);
	float glow = g * g * 0.28 * COLOR.a;

	float alpha = body * COLOR.a + (1.0 - body) * glow;
	vec3 rgb = mix(base, shade, body);
	COLOR = vec4(rgb, alpha);
}

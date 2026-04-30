shader_type canvas_item;

// Backrooms-style post-processing: film grain, vignette,
// chromatic aberration, and a subtle sepia tint pulled out of pure yellow.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float grain_strength : hint_range(0.0, 0.5) = 0.08;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.55;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.0015;
uniform float warmth : hint_range(0.0, 1.0) = 0.18;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = uv - 0.5;

	// Chromatic aberration scales with distance from center.
	float dist = length(center);
	vec2 dir = center * dist;
	vec3 col;
	col.r = texture(screen_texture, uv + dir * chromatic_aberration).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - dir * chromatic_aberration).b;

	// Warm sepia push toward yellow.
	vec3 warm = mix(col, col * vec3(1.05, 0.98, 0.78), warmth);

	// Vignette.
	float v = smoothstep(0.85, 0.2, dist);
	warm *= mix(1.0 - vignette_strength, 1.0, v);

	// Grain.
	float g = hash(uv * vec2(1024.0, 768.0) + TIME);
	warm += (g - 0.5) * grain_strength;

	COLOR = vec4(warm, 1.0);
}

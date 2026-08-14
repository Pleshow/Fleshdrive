shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float crt_intensity : hint_range(0.0, 1.0) = 0.24;
uniform float bloom_intensity : hint_range(0.0, 1.0) = 0.09;
uniform float chromatic_aberration : hint_range(0.0, 1.0) = 0.09;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.08;
uniform vec2 vignette_center = vec2(0.5, 0.5);
uniform vec2 boss_reveal_center = vec2(0.5, 0.5);
uniform float boss_reveal_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float screen_radius_squared = dot(centered, centered);
	vec2 vignette_offset = (SCREEN_UV - vignette_center) * 2.0;
	float radius_squared = dot(vignette_offset, vignette_offset);
	vec2 boss_offset = (SCREEN_UV - boss_reveal_center) * 2.0;
	float boss_radius_squared = dot(boss_offset, boss_offset);
	radius_squared = mix(
		radius_squared,
		min(radius_squared, boss_radius_squared * 1.45),
		boss_reveal_strength
	);
	vec2 warped_uv = SCREEN_UV + centered * screen_radius_squared * 0.018 * crt_intensity;
	warped_uv = clamp(warped_uv, vec2(0.001), vec2(0.999));

	float color_shift_pixels = round(5.0 * chromatic_aberration);
	vec2 color_shift = vec2(SCREEN_PIXEL_SIZE.x * color_shift_pixels, 0.0);
	vec3 base_color;
	base_color.r = texture(screen_texture, warped_uv + color_shift).r;
	base_color.g = texture(screen_texture, warped_uv).g;
	base_color.b = texture(screen_texture, warped_uv - color_shift).b;

	vec2 glow_step = SCREEN_PIXEL_SIZE * 3.0;
	vec3 blurred = texture(screen_texture, warped_uv + vec2(glow_step.x, 0.0)).rgb;
	blurred += texture(screen_texture, warped_uv - vec2(glow_step.x, 0.0)).rgb;
	blurred += texture(screen_texture, warped_uv + vec2(0.0, glow_step.y)).rgb;
	blurred += texture(screen_texture, warped_uv - vec2(0.0, glow_step.y)).rgb;
	blurred += texture(screen_texture, warped_uv + glow_step).rgb;
	blurred += texture(screen_texture, warped_uv - glow_step).rgb;
	blurred *= 0.1666667;
	vec3 glow = max(blurred - vec3(0.38), vec3(0.0));
	base_color += glow * bloom_intensity * 1.45;

	float pixel_row = SCREEN_UV.y / SCREEN_PIXEL_SIZE.y;
	float scanline = 1.0 - crt_intensity * (
		0.045 + 0.035 * sin(pixel_row * 3.14159265)
	);
	float vignette = 1.0 - smoothstep(
		0.15,
		1.05,
		radius_squared
	) * clamp(vignette_strength + 0.12 * crt_intensity, 0.0, 0.96);

	COLOR = vec4(base_color * scanline * vignette, 1.0);
}

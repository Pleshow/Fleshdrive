shader_type canvas_item;


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 blue = vec3(0.02, 0.46, 1.0) * (0.72 + luminance);
	COLOR = vec4(blue, source.a) * COLOR;
}

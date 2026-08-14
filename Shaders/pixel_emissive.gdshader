shader_type canvas_item;
render_mode unshaded;

uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.075;
uniform bool force_electric_blue = false;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	if (pixel.a < alpha_cutoff) {
		discard;
	}
	float value = max(pixel.r, max(pixel.g, pixel.b));
	vec3 quantized;
	if (force_electric_blue) {
		quantized = vec3(0.1176470588, 0.3411764706, 0.6117647059);
		if (value > 0.42) {
			quantized = vec3(0.0, 0.5960784314, 0.8588235294);
		}
		if (value > 0.72) {
			quantized = vec3(0.0470588235, 0.9019607843, 0.9490196078);
		}
	} else if (pixel.r > pixel.b * 1.15) {
		quantized = vec3(0.2705882353, 0.0117647059, 0.1529411765);
		if (value > 0.38) {
			quantized = vec3(0.6117647059, 0.0901960784, 0.2313725490);
		}
		if (value > 0.72) {
			quantized = vec3(1.0, 0.0196078431, 0.2745098039);
		}
	} else {
		quantized = vec3(0.1176470588, 0.3411764706, 0.6117647059);
		if (value > 0.48) {
			quantized = vec3(0.0, 0.5960784314, 0.8588235294);
		}
		if (value > 0.78) {
			quantized = vec3(0.0470588235, 0.9019607843, 0.9490196078);
		}
	}
	COLOR = vec4(quantized, 1.0);
}

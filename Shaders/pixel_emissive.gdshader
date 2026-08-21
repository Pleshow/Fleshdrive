shader_type canvas_item;
render_mode unshaded;

uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.075;
uniform bool force_electric_blue = false;
uniform bool force_alert_red = false;
uniform bool force_neutral_smoke = false;
uniform bool force_charger_dark = false;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	if (pixel.a < alpha_cutoff) {
		discard;
	}
	float value = max(pixel.r, max(pixel.g, pixel.b));
	vec3 quantized;
	if (force_charger_dark) {
		quantized = vec3(0.0196078431, 0.0039215686, 0.0274509804);
		if (value > 0.34) {
			quantized = vec3(0.0901960784, 0.0, 0.1137254902);
		}
		if (value > 0.64) {
			quantized = vec3(0.2705882353, 0.0117647059, 0.1529411765);
		}
		if (value > 0.88) {
			quantized = vec3(0.1176470588, 0.3411764706, 0.6117647059);
		}
	} else if (force_neutral_smoke) {
		quantized = vec3(0.0352941176, 0.0039215686, 0.0509803922);
		if (value > 0.34) {
			quantized = vec3(0.0901960784, 0.0, 0.1137254902);
		}
		if (value > 0.62) {
			quantized = vec3(0.2705882353, 0.0117647059, 0.1529411765);
		}
		if (value > 0.84) {
			quantized = vec3(0.6117647059, 0.0901960784, 0.2313725490);
		}
	} else if (force_alert_red) {
		quantized = vec3(0.2705882353, 0.0117647059, 0.1529411765);
		if (value > 0.38) {
			quantized = vec3(0.6117647059, 0.0901960784, 0.2313725490);
		}
		if (value > 0.72) {
			quantized = vec3(1.0, 0.0196078431, 0.2745098039);
		}
	} else if (force_electric_blue) {
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
	COLOR = vec4(quantized, pixel.a);
}

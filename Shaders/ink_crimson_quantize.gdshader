shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

vec3 nearest_ink_crimson(vec3 source) {
	vec3 selected = vec3(1.0, 0.0196078431, 0.2745098039);
	float best = dot(source - selected, source - selected);
	vec3 candidate = vec3(0.6117647059, 0.0901960784, 0.2313725490);
	float distance_to_candidate = dot(source - candidate, source - candidate);
	if (distance_to_candidate < best) { selected = candidate; best = distance_to_candidate; }
	candidate = vec3(0.4, 0.0588235294, 0.1921568627);
	distance_to_candidate = dot(source - candidate, source - candidate);
	if (distance_to_candidate < best) { selected = candidate; best = distance_to_candidate; }
	candidate = vec3(0.2705882353, 0.0117647059, 0.1529411765);
	distance_to_candidate = dot(source - candidate, source - candidate);
	if (distance_to_candidate < best) { selected = candidate; best = distance_to_candidate; }
	candidate = vec3(0.1529411765, 0.0, 0.1333333333);
	distance_to_candidate = dot(source - candidate, source - candidate);
	if (distance_to_candidate < best) { selected = candidate; best = distance_to_candidate; }
	candidate = vec3(0.0901960784, 0.0, 0.1137254902);
	distance_to_candidate = dot(source - candidate, source - candidate);
	if (distance_to_candidate < best) { selected = candidate; best = distance_to_candidate; }
	candidate = vec3(0.0352941176, 0.0039215686, 0.0509803922);
	distance_to_candidate = dot(source - candidate, source - candidate);
	if (distance_to_candidate < best) { selected = candidate; best = distance_to_candidate; }
	candidate = vec3(0.0470588235, 0.9019607843, 0.9490196078);
	distance_to_candidate = dot(source - candidate, source - candidate);
	if (distance_to_candidate < best) { selected = candidate; best = distance_to_candidate; }
	candidate = vec3(0.0, 0.5960784314, 0.8588235294);
	distance_to_candidate = dot(source - candidate, source - candidate);
	if (distance_to_candidate < best) { selected = candidate; best = distance_to_candidate; }
	candidate = vec3(0.1176470588, 0.3411764706, 0.6117647059);
	distance_to_candidate = dot(source - candidate, source - candidate);
	if (distance_to_candidate < best) { selected = candidate; }
	return selected;
}

void fragment() {
	vec3 source = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	COLOR = vec4(nearest_ink_crimson(source), 1.0);
}

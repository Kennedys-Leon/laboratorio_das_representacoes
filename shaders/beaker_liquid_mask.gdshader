shader_type canvas_item;

// During stirring, only the potion inside the fixed glass changes with the
// storyboard frames. The complete glass remains underneath this layer.
uniform bool liquid_only = false;

void fragment() {
	if (liquid_only) {
		vec2 point = UV * vec2(textureSize(TEXTURE, 0));
		float inside = smoothstep(103.0, 110.0, point.x)
			* (1.0 - smoothstep(176.0, 184.0, point.x))
			* smoothstep(209.0, 217.0, point.y)
			* (1.0 - smoothstep(252.0, 262.0, point.y));
		COLOR.a *= inside;
	}
}

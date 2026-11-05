shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 blurred = textureLod(screen_texture, SCREEN_UV, 3.0);
	COLOR = vec4(blurred.rgb, smoothstep(0.0, 0.85, UV.y));
}

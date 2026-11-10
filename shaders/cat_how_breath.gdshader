shader_type canvas_item;

uniform float breath_amount : hint_range(0.0, 1.0) = 0.0;
uniform float sprite_width = 118.0;
uniform float sprite_height = 141.0;
uniform float art_scale = 0.66;

void vertex() {
	float above_paws = clamp((sprite_height * 0.98 - VERTEX.y) / (sprite_height * 0.98), 0.0, 1.0);
	VERTEX.y -= above_paws * 3.8 * art_scale * breath_amount;
	VERTEX.x += (VERTEX.x - sprite_width * 0.5) * above_paws * 0.012 * breath_amount;
}

shader_type canvas_item;

uniform float breath_amount : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	// Breathing moves the head and coat very slightly while the paws stay grounded.
	float above_paws = clamp((150.0 - VERTEX.y) / 150.0, 0.0, 1.0);
	VERTEX.y -= above_paws * 1.35 * breath_amount;
	float chest = smoothstep(25.0, 70.0, VERTEX.y) * (1.0 - smoothstep(108.0, 150.0, VERTEX.y));
	VERTEX.x += (VERTEX.x - 64.0) * chest * 0.012 * breath_amount;
}

shader_type canvas_item;

uniform float breath_amount : hint_range(0.0, 1.0) = 0.0;

uniform float rise_progress : hint_range(0.0, 1.0) = 0.0;
varying vec2 local_pixel;

float lower_edge(float x) {
	float standing = 152.0;
	if (x >= 40.0 && x < 49.0) standing = mix(152.0,132.0,smoothstep(40.0,49.0,x));
	else if (x >= 49.0 && x < 55.0) standing = mix(132.0,134.0,(x-49.0)/6.0);
	else if (x >= 55.0 && x < 64.0) standing = mix(134.0,135.0,(x-55.0)/9.0);
	else if (x >= 64.0 && x < 68.0) standing = mix(135.0,134.0,(x-64.0)/4.0);
	else if (x >= 68.0 && x < 72.0) standing = mix(134.0,131.0,(x-68.0)/4.0);
	else if (x >= 72.0 && x < 82.0) standing = mix(131.0,130.0,(x-72.0)/10.0);
	else if (x >= 82.0 && x < 86.0) standing = mix(130.0,133.0,(x-82.0)/4.0);
	else if (x >= 86.0 && x < 93.0) standing = mix(133.0,131.0,(x-86.0)/7.0);
	else if (x >= 93.0) standing = 131.0;
	// Keep the seated front paws intact until the hands leave the floor. Fade
	// the old floor drawing only while the rigid hind feet become visible.
	float phase = smoothstep(0.0, 1.0, rise_progress) * 7.0;
	return mix(152.0, standing, smoothstep(3.6, 5.0, phase));
}

void vertex() {
	local_pixel = VERTEX;
	// Gentle expansion about the ground line: roughly 1.6 px at the ears.
	// The feet stay at y=150, instead of lifting the entire sprite off the floor.
	float height_above_floor = max(150.0 - VERTEX.y, 0.0);
	VERTEX.y -= height_above_floor * (1.8 / 150.0) * breath_amount;
}

void fragment() {
	// A short feather avoids a hard horizontal edge through the coat.
	COLOR.a *= 1.0 - smoothstep(lower_edge(local_pixel.x) - 0.5,
		lower_edge(local_pixel.x) + 1.0, local_pixel.y);
}

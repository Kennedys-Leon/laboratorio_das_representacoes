shader_type canvas_item;

uniform vec2 frame_origin = vec2(0.0);
uniform bool foreground = false;
uniform float reaction_time = 0.0;
uniform sampler2D glass_shape;
uniform vec4 glass_bounds;

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	vec2 p = UV * vec2(textureSize(TEXTURE, 0)) - frame_origin;
	// Glass and foam occupy the foreground; the continuous coat stays behind
	// the same tabletop used during mixing and celebration.
	vec2 glass_point = (p - vec2(110.0, 167.0)) / vec2(78.0, 63.0);
	bool in_glass = all(greaterThanEqual(glass_point, vec2(0.0))) && all(lessThanEqual(glass_point, vec2(1.0)));
	float glass_alpha = texture(glass_shape, glass_bounds.xy + glass_point * glass_bounds.zw).a;
	bool vessel = in_glass && glass_alpha > 0.08;
	// Foam is wider than the glass mouth and remains in front of it.
	vessel = vessel || (p.x > 106.0 && p.x < 195.0 && p.y >= 148.0 && p.y < 190.0 && ink.b > 0.6 && ink.b > ink.g * 1.15);
	// Include the pale rim and dark outline of the baked foam, not just its
	// purple fill. Otherwise orphan outlines remain above the separate vessel.
	vec2 foam_point = (p - vec2(146.5, 180.0)) / vec2(40.0, 24.0);
	vessel = vessel || (reaction_time > 1.1 && dot(foam_point, foam_point) < 1.0);
	bool prop = vessel;
	if (foreground != prop) ink.a = 0.0;
	// Side bottles, shards and spilled liquid now use table-local animation.
	// They must not be warped with the character's expression changes.
	// Keep the sleeves beside the chest intact. Only the bottle art below
	// the wrists is removed; separate bottles and shards live on the table.
	if (((p.x < 67.0 || p.x > 213.0) && p.y >= 155.0)
		|| ((p.x < 90.0 || p.x > 206.0) && p.y >= 177.0)
		|| ((p.x < 100.0 || p.x > 202.0) && p.y >= 184.0)
		|| p.y > 230.0) ink.a = 0.0;
	// Remove residual cyan puddle pixels from the empty side bottles.
	if (p.y > 218.0 && (p.x < 108.0 || p.x > 198.0)
		&& ink.g > ink.r * 1.2 && ink.b > ink.r * 1.2) ink.a = 0.0;
	// The glass, liquid and foam are rendered separately at tabletop coordinates.
	if (p.x > 100.0 && p.x < 202.0 && p.y > 184.0 && p.y < 232.0
		&& ink.b > 0.55 && ink.b > ink.g * 1.12) ink.a = 0.0;
	// The atlas contains a second foaming rim. Clear it once the fixed foam
	// grows over the cup, including its pale highlight and dark outline.
	if (reaction_time > 1.1 && p.x > 108.0 && p.x < 185.0
		&& p.y > 175.0 && p.y < 195.0) ink.a = 0.0;
	COLOR = ink;
}

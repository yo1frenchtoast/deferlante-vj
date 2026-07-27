shader_type canvas_item;

// Kaléidoscope : l'écran est découpé en parts égales autour du centre, et chaque
// part rejoue la même portion d'image, une fois sur deux en miroir. C'est
// exactement ce que produisent les miroirs d'un vrai kaléidoscope.
//
// L'effet relit l'image déjà dessinée au lieu de dupliquer la géométrie : le coût
// est celui d'une passe plein écran, quel que soit le nombre de traits à l'écran.

uniform sampler2D ecran : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform int segments : hint_range(2, 16) = 6;
uniform float rotation = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Le repli se calcule en coordonnées carrées : sur un écran 16:9, travailler
	// directement en UV étirerait les parts et casserait la symétrie.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 centre = uv - 0.5;
	centre.x *= aspect;

	float angle = atan(centre.y, centre.x) + rotation;
	float rayon = length(centre);

	float part = TAU / float(segments);
	angle = mod(angle, part);
	// Le repli en miroir à l'intérieur de la part : c'est lui qui donne les
	// symétries, un simple modulo ne ferait que répéter le motif en rotation.
	angle = abs(angle - part * 0.5);

	vec2 replie = vec2(cos(angle), sin(angle)) * rayon;
	replie.x /= aspect;
	replie += 0.5;

	// `amount` fond progressivement entre l'image d'origine et l'image repliée,
	// ce qui permet d'ouvrir et de refermer l'effet en douceur pendant un set.
	vec2 finale = mix(uv, clamp(replie, vec2(0.0), vec2(1.0)), amount);
	COLOR = texture(ecran, finale);
}

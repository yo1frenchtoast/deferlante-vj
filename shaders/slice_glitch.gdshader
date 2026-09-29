shader_type canvas_item;

// Slice glitch: the picture is cut into horizontal bands, and some of them slide
// sideways. Where a band slides it takes its colours with it at slightly different
// paces, so each edge is fringed, the way a damaged video signal tears.
//
// It re-reads the frame that is already drawn, like the mirror does: one full-screen
// pass with three fetches, whatever the number of strokes on screen.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
// 0 to 1. It is the share of bands that slide *and* how far they go, so a low value is
// a few bands nudged, and the top is most of the picture torn. `slice_glitch.gd`
// hides the whole pass at 0.
uniform float strength = 0.0;
uniform float bands = 12.0;
// Changes a few times a second, and each value is a new tear. A hash of the band and of
// this is all the randomness there is, so the same value gives the same picture.
uniform float seed = 0.0;

// The farthest a band slides at strength 1, as a fraction of the screen width.
const float REACH = 0.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// The edges of the bands move with the seed as well. Bands that stayed where they
	// were would tear along the same seams every time and read as a grid.
	float jitter = hash(vec2(seed, 3.0)) / bands;
	float band = floor((SCREEN_UV.y + jitter) * bands);

	float dice = hash(vec2(band, seed));
	float slides = step(dice, strength);
	float distance_slid = (hash(vec2(band + 17.0, seed)) * 2.0 - 1.0) * REACH * strength * slides;

	// Red goes furthest and blue least, which is what puts a coloured edge on a band.
	// Where nothing slides all three are the same fetch, and the picture is untouched.
	vec2 at = SCREEN_UV;
	float red = texture(screen_tex, vec2(fract(at.x + distance_slid), at.y)).r;
	float green = texture(screen_tex, vec2(fract(at.x + distance_slid * 0.8), at.y)).g;
	float blue = texture(screen_tex, vec2(fract(at.x + distance_slid * 0.6), at.y)).b;
	float alpha = texture(screen_tex, vec2(fract(at.x + distance_slid * 0.8), at.y)).a;
	COLOR = vec4(red, green, blue, alpha);
}

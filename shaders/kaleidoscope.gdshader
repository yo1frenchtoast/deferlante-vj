shader_type canvas_item;

// Kaleidoscope: the screen is cut into equal wedges around the centre_uv, and each
// wedge replays the same slice of image, mirrored every other time. That is exactly
// what the mirrors of a real kaleidoscope produce.
//
// The effect re-reads the already-drawn image instead of duplicating geometry: the
// cost is one full-screen pass, whatever the number of strokes on screen.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform int segments : hint_range(2, 16) = 6;
uniform float rotation = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	// The fold is computed in square coordinates: on a 16:9 screen, working straight
	// in UV space would stretch the wedges and break the symmetry.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 centre_uv = uv - 0.5;
	centre_uv.x *= aspect;

	float angle = atan(centre_uv.y, centre_uv.x) + rotation;
	float radius = length(centre_uv);

	float wedge = TAU / float(segments);
	angle = mod(angle, wedge);
	// The mirrored fold inside the wedge: this is what creates the symmetry. A plain
	// modulo would merely repeat the pattern in rotation.
	angle = abs(angle - wedge * 0.5);

	vec2 folded = vec2(cos(angle), sin(angle)) * radius;
	folded.x /= aspect;
	folded += 0.5;

	// Off the edge, reflect rather than clamp: clamping smears the last row of
	// pixels into a flat panel, where a reflection carries the pattern on — which
	// reads as more mirror, and this effect is made of mirrors.
	folded = abs(mod(folded, 2.0));
	folded = min(folded, 2.0 - folded);

	// The fold is off or on: `kaleidoscope.gd` hides the whole pass at 0, so by the
	// time a fragment runs, the mirror is fully on. There is nothing to blend, and
	// nothing to pay for the unfolded fetch.
	//
	// There was a cross-fade here, and it is worth saying why it went rather than
	// letting somebody put it back. It was never blended between the two sets of
	// *coordinates*: that is the same thing as interpolating the angle, and `atan`
	// cuts the circle along the left-hand axis, where its value jumps by a full
	// turn. The jump cancels only at 0 and at 1, so every value in between wore a
	// seam running out from the centre. Mixing the two images fixed that seam — both
	// are continuous everywhere, so their mixture is too — and it was the right
	// answer to the question that was asked.
	//
	// It died on a different one. `mix` is an operator for opaque images, and these
	// strokes are additive light on black. At 0.5 it does not give half a mirror: it
	// gives the whole image at half brightness plus the whole fold at half
	// brightness. On a monitor that passes for a mirror opening. Through a projector
	// into haze it is a washed-out ghost, and a projector has no contrast to spare.
	COLOR = texture(screen_tex, folded);
}

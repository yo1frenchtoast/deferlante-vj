shader_type canvas_item;

// Chromatic aberration: the three colour channels are read from slightly different
// places, so that every edge grows a red fringe on one side and a blue one on the
// other. A cheap lens does exactly this, because glass bends each wavelength by a
// little more or less than the next.
//
// Green stays where it is, red moves one way and blue the other. Thus a stroke keeps
// its centre and gains two coloured edges, where shifting only one channel would drag
// the whole picture off to a side.
//
// It re-reads the frame that is already drawn, like the mirror does: one full-screen
// pass with three fetches, whatever the number of strokes on screen.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
// How far a channel is moved, as a fraction of the screen height. `chromatic_aberration.gd`
// computes it from the setting and hides the whole pass at 0.
uniform float shift = 0.0;
// 0 moves the channels the same way everywhere, along `angle`. 1 moves them along the
// line from the centre — a lens — and by more the further out, so that the middle of
// the picture stays clean and the edges carry the fringe.
uniform float radial : hint_range(0.0, 1.0) = 0.0;
// The direction of the uniform part, in radians.
uniform float angle = 0.0;

// A fetch that lands off the edge of the frame gives black, not the pixel at the edge.
// Clamped, it smears that last row of pixels out into a flat panel: on strokes that run
// into a corner it drew solid blocks of one colour. Additive light on black has nothing
// beyond the frame, so nothing is what it reads there — and the fringe simply stops at
// the edge.
vec4 fetch(vec2 uv) {
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return texture(screen_tex, uv) * inside.x * inside.y;
}

void fragment() {
	// Worked out in square coordinates, so that a direction means the same on a 16:9
	// screen as on a square one.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 centre_uv = SCREEN_UV - 0.5;
	centre_uv.x *= aspect;

	vec2 along = vec2(cos(angle), sin(angle));
	// Nought at the centre and about one at the corners of a 16:9 frame. A centre that
	// is exactly on the pixel has no direction, and `normalize` of nothing is not a
	// number.
	float distance_from_centre = length(centre_uv);
	vec2 outward = distance_from_centre > 0.0001 ? centre_uv / distance_from_centre : vec2(0.0);
	vec2 lens = outward * clamp(distance_from_centre * 2.0, 0.0, 1.5);

	vec2 move = mix(along, lens, radial) * shift;
	move.x /= aspect;

	vec4 red = fetch(SCREEN_UV + move);
	vec4 green = texture(screen_tex, SCREEN_UV);
	vec4 blue = fetch(SCREEN_UV - move);

	// Opaque where any of the three fetches was: a fringe that reaches past the edge
	// of a stroke must not be cut by the alpha of the pixel it landed on.
	COLOR = vec4(red.r, green.g, blue.b, max(red.a, max(green.a, blue.a)));
}

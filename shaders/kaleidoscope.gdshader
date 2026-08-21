shader_type canvas_item;

// Kaleidoscope: the screen is cut into equal wedges around the centre_uv, and each
// wedge replays the same slice of image, mirrored every other time. That is exactly
// what the mirrors of a real kaleidoscope produce.
//
// The effect re-reads the already-drawn image instead of duplicating geometry: the
// cost is one full-screen pass, whatever the number of strokes on screen.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
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
	// Which wedge this pixel is in, and where it sits inside it. Keeping the two
	// apart is what lets the effect open gradually without the image collapsing.
	float turn = floor(angle / wedge);
	float within = angle - turn * wedge;
	// The mirrored fold inside the wedge: this is what creates the symmetry. A plain
	// modulo would merely repeat the pattern in rotation.
	float mirrored = abs(within - wedge * 0.5);

	// Two motions, both continuous, both finished at 1. Each wedge folds onto its
	// own centre line, and every wedge turns towards the first one. At 0 they undo
	// each other exactly and the image is untouched; at 1 every wedge shows the
	// same mirrored slice, which is the kaleidoscope.
	//
	// Blending the *coordinates* instead — mix(uv, folded) — is what used to make
	// the middle of the range ugly: `folded` always lands in one narrow sector, so
	// half-way there the whole screen was squeezed into that corner rather than
	// folded. Angles have somewhere to travel; positions do not.
	angle = mix(within, mirrored, amount) + turn * wedge * (1.0 - amount);

	vec2 folded = vec2(cos(angle), sin(angle)) * radius;
	folded.x /= aspect;
	folded += 0.5;

	// Off the edge, reflect rather than clamp. Clamping smears the last row of
	// pixels into a flat panel — the dark wedge that used to sit in a corner
	// half-way through the range — where a reflection carries on the pattern and
	// reads as more mirror, which is what this effect is made of anyway.
	folded = abs(mod(folded, 2.0));
	folded = min(folded, 2.0 - folded);

	COLOR = texture(screen_tex, folded);
}

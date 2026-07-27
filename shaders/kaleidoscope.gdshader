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
	angle = mod(angle, wedge);
	// The mirrored fold inside the wedge: this is what creates the symmetry. A plain
	// modulo would merely repeat the pattern in rotation.
	angle = abs(angle - wedge * 0.5);

	vec2 folded = vec2(cos(angle), sin(angle)) * radius;
	folded.x /= aspect;
	folded += 0.5;

	// `amount` blends gradually between the original and the folded image, which
	// lets the effect be opened and closed smoothly during a set.
	vec2 final_uv = mix(uv, clamp(folded, vec2(0.0), vec2(1.0)), amount);
	COLOR = texture(screen_tex, final_uv);
}

shader_type canvas_item;

// Wave: the image is read from a place that swings from side to side, and up and down,
// as a sine of where you are looking. Straight lines come out as ripples: heat over
// asphalt, the view through water, a picture on a sheet that somebody is shaking.
//
// It re-reads the frame that is already drawn, like the mirror does: one full-screen
// pass with one fetch, whatever the number of strokes on screen.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
// How far a point is pulled, as a fraction of the screen. `wave.gd` computes it from the
// setting and hides the whole pass at 0.
uniform float amplitude = 0.0;
// Waves across the height of the screen.
uniform float count = 4.0;
uniform float phase = 0.0;

void fragment() {
	// In square coordinates, so a wave has the same length across as it has up and down
	// on a 16:9 screen.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = SCREEN_UV;
	p.x *= aspect;

	// Two waves that do not share a direction or a pace. One alone shears the picture
	// sideways and reads as a rendering fault; a second, across the first, makes it
	// read as a surface.
	vec2 pull;
	pull.x = sin(p.y * count * TAU + phase);
	pull.y = sin(p.x * count * TAU * 0.7 + phase * 1.3 + 1.7);
	pull.y *= 0.6;

	vec2 uv = SCREEN_UV + pull * amplitude;
	// Off the edge, reflect rather than clamp: clamping smears the last row of pixels
	// out into a flat panel, where a reflection carries the picture on.
	uv = abs(mod(uv, 2.0));
	uv = min(uv, 2.0 - uv);
	COLOR = texture(screen_tex, uv);
}

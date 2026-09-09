shader_type canvas_item;

// Motion blur, done the way a long exposure does it: the frame that was on screen
// is not thrown away, it is dimmed and drawn under the new one. What stands still
// is redrawn over its own ghost and looks untouched; what moves leaves the ghost
// behind, and the eye reads the smear as speed.
//
// The previous frame arrives as a texture of its own rather than as the screen
// texture, because the obvious version of this — tell the viewport not to clear
// itself and read back what is already in it — draws nothing at all under the
// Compatibility renderer this show runs on. `motion_blur.gd` keeps the copy.
//
// The pass writes an opaque colour rather than laying a black veil at some alpha,
// and the reason is the same arithmetic done in the wrong place. A veil is a
// blend, and a blend lands in 8 bits: once a pixel is dim enough that
// `value * keep` rounds back to `value`, no veil ever removes it, and a bright
// stroke leaves a permanent grey scar along its path — on stage, an hour into the
// set. `bias` is the answer: a floor taken off every frame, too small to see
// against a live stroke, large enough that the tail of one always reaches black.

uniform sampler2D echo_tex : filter_nearest;
// How much of the previous frame survives this frame. Computed per frame from the
// wanted decay time, so the trail lasts as long on a projector dropping frames as
// it does at 60.
uniform float keep : hint_range(0.0, 1.0) = 0.0;
uniform float bias = 0.006;
// How bright a trail is ever allowed to be. Without it the effects, which draw
// their strokes additively, land on top of their own ghost every frame: a stroke
// that barely moves adds itself to itself some thirty times, every channel pins at
// 1, and the spotlight — an orange ring one pixel wide — comes out a fat white
// band. Holding the ghost below the stroke that casts it is also just true to what
// this imitates: on a long exposure the trail is the dim part.
uniform float ceiling : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec3 previous = min(texture(echo_tex, UV).rgb, vec3(ceiling));
	COLOR = vec4(max(previous * keep - bias, vec3(0.0)), 1.0);
}

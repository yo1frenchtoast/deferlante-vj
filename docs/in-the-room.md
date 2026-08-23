# In the room

## A calm starting point

The defaults are deliberately quiet: three lasers, fourteen sphere circles, and a
spotlight that sweeps at half speed with long pauses and only a slight tremor. That is
about five stops in twenty seconds, where it made twenty in twenty-five before.

That is a setting to build up from, and a setting that you can debug in. With a busy
scene it is hard to tell which effect a change belongs to. The panel itself is also
hard to read over the top of it. Everything is one slider away from where it was.

## What starts switched off

`GLOW` and `GLITCH` start at 0, and both are genuinely off rather than set to zero
intensity. The same is true for `RANDOMIZER`, and for the `EFFECT` of the mirror, which
starts at `OFF` and has no setting between `OFF` and `ON`.

`STARS` starts at 0 as well, and for one more reason. This effect arrived after nine
preset slots had been filled on machines already in use. A preset saved before it
existed carries no value for it. A star field that lit itself up on launch would thus
appear in every one of those shows, uninvited, until each was saved again.

It is a stance. You switch an effect that makes a statement on when you want it, at
the moment that you choose. You do not let it run in the background. A scene that
starts sober leaves room to build. A scene that starts saturated has nowhere to go.

## The halo

With a haze machine the air diffuses the beam **physically**. A software halo then
does the same job two times: it softens the edges and takes the bite out of the
stroke. Thus it is 0 by default, and at 0 the show draws nothing at all for it rather
than draws it at zero intensity.

`GLOW` is no longer the post-process glow. Each stroke draws **two extra copies of
itself**, wider and much fainter, additively (`scripts/halo.gd`). In additive blending
they sum where they overlap, thus the core saturates towards white and the light steps
down towards the edges. It is two steps, not a Gaussian curve. Against a beam in haze,
nobody can tell.

The spread is in **pixels, not in multiples of the width of the stroke**. Light bleeds
a distance into the haze, and it does not bleed in proportion to how thick the beam
is. The multiplicative version was tried first. A 10 px laser then grew a 70 px slab
with a hard edge. That read as a second and wider line rather than as spill.

Why it changed. Measured on a machine with **no GPU** (llvmpipe, 1080p, a busy show —
20 strokes at 10 px, mirror on, 40 circles on the sphere):

| | post-process glow | two-ring halo |
| --- | --- | --- |
| Forward+ | 34.2 ms · 29 fps | — |
| Compatibility | not drawn at all | **10.7 ms · 93 fps** |

The old glow cost **21 ms per frame** on its own. That is two thirds of the whole
frame, and by a wide margin the most expensive control on the panel. The halo costs
3.3 ms for a comparable look, and every renderer draws it, unlike the glow. Thus it
works on the tablet build too.

On a GPU none of this was ever visible. The glow cost about 0.30 ms at 1080p on an
RTX 3060, which is why it stood unquestioned for so long. The setting keeps its name,
its 0–2 range and its OSC address. What changed is who does the work.

## Projection notes

A projector has much lower contrast than a monitor. If the beams lack bite in the
haze, decrease `SATURATION` towards 0.4–0.5. A near-white beam cuts through haze
better than a heavily saturated color.

Before the audience arrives, press `H` and then let the panel fade. The sliders are in
a `CanvasLayer`, thus the projector puts them on the wall with everything else.

## Measuring performance (F3)

The readout shows `FPS`, the **milliseconds per frame**, and the screen refresh rate
that the show found. The millisecond figure is the one that matters, not the FPS. At
1200 fps, 0.3 ms more costs 400 fps on the counter and weighs nothing at all. The only
question that counts in projection is this one: am I staying under the budget of one
frame on my projector? (16.7 ms at 60 Hz, 13.3 ms at 75 Hz.)

⚠️ CAUTION: Do not judge the behavior of the project from a `--write-movie` recording.
That mode writes one PNG per frame to disk and blocks rendering during the encode. That
costs up to 110 ms per frame with the halo on, because gradients compress badly. The
window then looks like it is in difficulty, and `Tween`-driven animations such as the
UI fade appear to stutter. Everything is perfectly steady in a normal run.

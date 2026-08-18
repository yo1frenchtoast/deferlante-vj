# In the room

## A calm starting point

The defaults are deliberately quiet: three lasers, fourteen sphere circles, and a
spotlight that sweeps at half speed with long pauses and only a slight tremor —
about five stops in twenty seconds where it used to make twenty in twenty-five.

That is a setting to build up from and a setting you can debug in: with a busy scene
it is hard to tell which effect a change belongs to, and the panel itself is hard to
read over the top of it. Everything is one slider away from where it was.

## What starts switched off

`GLOW` and `GLITCH` start at 0, and both are genuinely off rather than set to zero
intensity. Same for the mirror's `EFFECT` and for `RANDOMIZER`.

It is a stance: effects that make a statement are switched on when wanted, at the
chosen moment, rather than running in the background. A scene that starts sober
leaves room to build; a scene that starts saturated has nowhere to go.

## The halo

With a haze machine the beam is diffused **physically** in the air. A software halo
then does the same job twice: it softens the edges and takes the bite out of the
stroke. So it is 0 by default, and at 0 nothing is drawn for it at all rather than
drawn at zero intensity.

`GLOW` is no longer the post-process glow. Each stroke draws **two extra copies of
itself**, wider and much fainter, additively (`scripts/halo.gd`). In additive
blending they sum where they overlap, so the core saturates towards white and the
light steps down towards the edges. It is two steps, not a Gaussian curve — against
a beam in haze, nobody can tell.

The spread is in **pixels, not multiples of the stroke's width**: light bleeds a
distance into the haze, it does not bleed proportionally to how thick the beam is.
The multiplicative version was tried first and a 10 px laser grew a 70 px slab with
a hard edge, which read as a second, wider line rather than as spill.

Why it changed, measured on a machine with **no GPU** (llvmpipe, 1080p, a busy show
— 20 strokes at 10 px, mirror on, 40 circles on the sphere):

| | post-process glow | two-ring halo |
| --- | --- | --- |
| Forward+ | 34.2 ms · 29 fps | — |
| Compatibility | not drawn at all | **10.7 ms · 93 fps** |

The old glow cost **21 ms per frame** on its own — two thirds of the whole frame,
and by a wide margin the most expensive control on the desk. The halo costs 3.3 ms
for a comparable look, and unlike the glow it is drawn by *every* renderer, so it
works on the tablet build too.

On a GPU none of this was ever visible: the glow cost ~0.30 ms at 1080p on an
RTX 3060, which is why it stood unquestioned for so long. The setting keeps its
name, its 0–2 range and its OSC address — what changed is who does the work.

## Projection notes

A projector has far lower contrast than a monitor. If the beams lack bite in the
haze, bring `SATURATION` down towards 0.4–0.5: a near-white beam cuts through haze
better than a heavily saturated colour.

Remember `H`, then let the panel fade, before the audience arrives — the sliders live
in a `CanvasLayer`, so they are projected on the wall along with everything else.

## Measuring performance (F3)

The readout shows `FPS`, the **milliseconds per frame**, and the detected screen
refresh rate. It is the millisecond figure that matters, not the FPS: at 1200 fps,
0.3 ms more costs 400 fps on the counter without weighing anything at all. The only
question that counts in projection is: *am I staying under one frame's budget on my
projector?* (16.7 ms at 60 Hz, 13.3 ms at 75 Hz.)

⚠️ Never judge the project's behaviour from a `--write-movie` recording: that mode
writes one PNG per frame to disk and blocks rendering during the encode (up to 110 ms
per frame with the halo on, because gradients compress badly). The window then looks
like it is struggling, and `Tween`-driven animations — the UI fade, for instance —
appear to stutter, when everything is perfectly steady in a normal run.

# The effects

## The spotlight

The main circle does not drift: it moves like a moving head hunting for someone in
the room. Three things produce that reading:

1. **It alternates sweeps and stops** — roughly 40 % of the time moving, 60 % parked
   on a target. That ratio is what matters: continuous motion, however irregular,
   never looks like *searching*.
2. **It traces arcs, not straight lines** — the head pivots on two axes, so its beam
   describes a curve on a flat wall. It is the most recognisable signature of a
   motorised light, and it comes for free: it falls straight out of the `tan(pan)`,
   `tan(tilt) / cos(pan)` projection.
3. **It hesitates** — at rest the head trembles slightly, and one time in three it
   makes a small correction just beside instead of a wide sweep, as though it thought
   it had found something.

The tremor runs on **its own clock**, separate from the sweep speed: `SHAKE` sets its
amplitude, `FREQUENCY` its rate. A head can sweep fast while peering calmly, or cross
slowly while shivering hard. Only the global `SPEED` catches both, so that 0 truly
freezes everything.

On top of that sits the motor profile: brisk start, long braking, and a slight damped
overshoot at the end of travel as the head settles.

### Why the pool changes size

A real followspot's pool grows as it aims away from centre — the beam travels further
and lands at an angle. Taken literally that is **+61 % at the edge of the pan range and
+76 % in the corner**, which is a lot, and because the pool is scaled evenly rather
than stretched into an ellipse it reads as the circle resizing rather than as an
oblique beam.

`SPREAD` is the dose. At **0** the pool is the same size wherever it points; at **1**
you get the full physical effect. The default of **0.35** gives +22 % at the edge —
enough to feel like a light rather than a shape, without drawing attention to itself.

The spotlight's `SPEED` and `HOLD` drive all this live. `HOLD` at 0 gives a
continuous sweep with no stops; pushed to 3, a head that lingers on each target.
Travel range, throw distance (and therefore the curvature of the arcs) and the
frequency of small corrections are `@export`s in the inspector.

## The sphere effect

Circles are laid on a virtual sphere (Fibonacci distribution, so no clustering at
the poles) and projected onto the screen. The centre of the screen is the point
nearest the eye. Two effects compound as a circle moves away from it:

1. **It shrinks** — perspective, driven by `DEPTH`. At 1.2 the size difference
   between the centre circle and the edge ones is dramatic; at 10 the projection is
   near-orthographic and they are all the same size.
2. **It flattens into an ellipse** — the surface is seen at an angle. The minor axis
   points at the centre and is progressively crushed, down to a line at the edge.

It is **point 2 that makes it read as a sphere** rather than as circles of assorted
sizes. Without the flattening the eye sees a scattering of rings; with it, the volume
reconstructs itself immediately.

The far side is hidden by default (`GLASS` = 0): only the cap facing the eye shows.
That is deliberate — when both faces are visible the back circles project near the
centre too and front can no longer be told from back. Raising `GLASS` gives a glass
sphere, busier but stranger.

Measured cost: **+0.32 ms** at 40 circles (the default), **+0.77 ms** at 80. Circles
past the horizon are neither computed nor drawn.

## The kaleidoscope

`EFFECT` folds the image into symmetrical wedges around the centre, like the mirrors
of a kaleidoscope. The fold works on the **already-drawn frame**, not by duplicating
geometry: the cost is one full-screen pass whether you have 5 strokes or 40.

The layer sits above the visuals but **below the settings panel** — otherwise the
sliders would end up multiplied across the screen too.

Like the halo, at 0 the pass is genuinely switched off rather than left running as
an identity transform.

## Scanlines

`PARALLEL` does not tune the scatter, it crossfades between two different
behaviours. At **0** every stroke drifts and spins on its own, bouncing off the
edges — the original look. At **1** they all take a shared angle and an evenly
spaced place in a fan. In between the two are simply mixed, so it can be opened and
closed like any other effect.

`SCROLL` then walks that fan sideways, perpendicular to the shared angle, wrapping
around. That is what turns a set of parallel lines into scanlines: they have to be
*moving through* the frame, not just pointing the same way.

Two details do most of the work:

- **The spacing is reassigned whenever the count changes**, so the strokes are
  always evenly spread rather than keeping the random gaps they had as a scatter.
  Without that they read as lines that happen to be parallel, not as a raster.
- **The wrap happens off screen.** The fan spans the screen diagonal, so a stroke
  has completely left the frame before it reappears on the other side, whatever
  angle it is at — measured at 1101 px of travel against a 1101 px half-diagonal.

`SPIN` still turns the whole fan while it scrolls, which gives a raster slowly
rotating through the room.

## Chaos

`CHAOS` is a macro setting that **layers on top of** the others without overwriting
them: at 0 the picture is exactly what you dialled in, at 1 everything comes loose.
Its progression is deliberately uneven — discreet at first, then runaway.

What it does, effect by effect:

- **Lasers** — each stroke gradually recovers its own heading. This is the disorder
  that the `SPIN` direction setting removed, brought back through the side door: at
  1 the strokes cross in opposite directions again. Random swerves are added on top,
  making the paths zigzag.
- **Spotlight** — the head can no longer stay put (pauses eight times shorter),
  sweeps three times faster and trembles seven times harder. It does **not** touch
  the glitches: chaos unsettles *motion*, `GLITCH` keeps its own setting. A panicked
  head with no glitch, and a composed head that erupts now and then, are two
  different pictures.
- **Sphere** — each circle slides along its longitude at its own pace and its size
  starts to throb. The sphere stays legible, but its surface is no longer of a piece.

## Two-way speeds

`SPEED` runs from **-3 to 3**, both `SPIN` settings and the mirror's `ROTATION` from
**-1 to 1**. In every case the middle of the slider is a standstill and 1 is normal
speed — `SPEED` therefore keeps headroom above for passages that need to take off.

The sign gives the direction of rotation, the magnitude the speed. The screen shows
an arrow rather than a minus sign (`← 0.60`, `→ 0.60`, `·  0.00`): in the dark an
arrow reads at a glance.

For "leftwards / rightwards" to mean anything, each laser now draws the **magnitude**
of its spin at random, but no longer its direction: that comes from the global
setting. Before, half the strokes turned the other way and no single control could
have made them agree.

Signs combine: `SPEED` at -1 with `SPIN` at +1 turns the strokes leftwards —
reversing global time reverses rotation too. The spotlight's `SPEED` on the other
hand stays a positive rate: a followspot does not "un-search", it keeps sweeping
forwards even when everything else runs backwards.

## The two colour modes

**RANDOM** (the default) — every laser, every sphere circle and the spotlight draw
their own hue. `R` redraws them.

**MANUAL** — everyone takes the colour set by `RED` / `GREEN` / `BLUE`.

Three things make going back and forth painless:

- **Touching a colour switches to manual** automatically. Without it, moving `RED`
  in random mode would do nothing and the slider would look broken.
- **The random hues survive the trip into manual.** Going back to `RANDOM` finds
  them exactly as they were — manual mode hides them, it does not destroy them.
- **`R` returns to random** *and* draws fresh hues. It is the escape hatch you find
  without thinking mid-set.

`SATURATION` stays useful in both modes: it pulls the colour towards white. When
projecting into haze a near-white beam cuts through better than a saturated one —
drop it to 0.4–0.5 if the picture lacks bite.

## The auto-pilot

`RANDOMIZER` makes the visuals evolve by themselves: every 1 to 12 seconds depending
on its value, it picks one or two settings and puts them down somewhere else. One
time in four it also redraws the colours, but only if they are in random mode —
otherwise it would trample a manual choice.

Three precautions make it usable for real:

- **One or two settings at a time.** Beyond that it stops reading as a gesture and
  starts reading as a malfunction.
- **Values cluster towards the middle** of each range (the average of two draws),
  which avoids the extremes that either empty or saturate the screen.
- **Six settings are out of its reach**: `SPEED`, `GLOW`, `SATURATION` and the three
  colours. Those are decisions — the tempo of the track, the contrast of the room —
  not variations to be subjected to.

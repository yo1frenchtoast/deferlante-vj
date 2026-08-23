# The effects

## The spotlight

The main circle does not drift. It moves like a moving head that hunts for somebody in
the room. Three things give that reading:

1. **It alternates sweeps and stops.** It moves about 40 % of the time and stays on a
   target about 60 % of the time. That ratio is what matters. Continuous motion never
   looks like a *search*, even when it is irregular.
2. **It traces arcs, not straight lines.** The head pivots on two axes, thus its beam
   describes a curve on a flat wall. This is the signature of a motorized light that
   the eye knows best, and it costs nothing: it falls out of the `tan(pan)`,
   `tan(tilt) / cos(pan)` projection.
3. **It hesitates.** At rest the head trembles a little. One time in three it makes a
   small correction beside the target instead of a wide sweep. It looks as though it
   thought that it had found something.

The tremor runs on **its own clock**, separate from the sweep speed. `SHAKE` sets its
amplitude and `FREQUENCY` sets its rate. A head can sweep fast while it peers calmly,
or cross slowly while it shivers hard. Only the global `SPEED` catches both, thus 0
freezes everything.

On top of that is the motor profile: a brisk start, a long brake, and a small damped
overshoot at the end of travel as the head settles.

A gamepad takes the head off this behavior and aims it by hand. `AIMING`, `TRACKING`
and `HAND BACK` are that half of the spotlight. See
[the gamepad](external-control.md#gamepad).

### Why the pool changes size

The pool of a real followspot grows as it aims away from center, because the beam
travels further and lands at an angle. Taken literally that is **+61 % at the edge of
the pan range and +76 % in the corner**, which is a lot. The show scales the pool
evenly rather than stretches it into an ellipse. Thus it reads as a circle that changes
size, and not as an oblique beam.

`SPREAD` is the dose. At **0** the pool keeps the same size wherever it points. At
**1** you get the full physical effect. The default of **0.35** gives +22 % at the
edge. That is enough to read as a light rather than a shape, and it does not draw
attention to itself.

The `SPEED` and `HOLD` of the spotlight drive all of this live. `HOLD` at 0 gives a
continuous sweep with no stops. At 3 it gives a head that stays a long time on each
target. Travel range, throw distance and the frequency of the small corrections are
`@export`s in the inspector. Throw distance also sets the curvature of the arcs.

## The sphere effect

The show lays the circles on a virtual sphere and projects them onto the screen. The
distribution is a Fibonacci one, thus the circles do not group at the poles. The
center of the screen is the point nearest the eye. Two effects compound as a circle
moves away from that point:

1. **It shrinks.** This is perspective, and `DEPTH` drives it. At 1.2 the difference
   in size between the center circle and the edge ones is dramatic. At 10 the
   projection is near-orthographic and they are all the same size.
2. **It flattens into an ellipse.** The eye sees the surface at an angle. The minor
   axis points at the center and is progressively crushed, down to a line at the edge.

**Point 2 is what makes it read as a sphere** rather than as circles of assorted
sizes. Without the flattening the eye sees a scatter of rings. With it, the volume
reconstructs itself immediately.

The far side is hidden by default (`GLASS` = 0), thus only the cap that faces the eye
shows. That is deliberate. When both faces are visible, the back circles project near
the center too and the eye can no longer tell front from back. A higher `GLASS` gives
a glass sphere, which is busier but stranger.

Measured cost: **+0.32 ms** at 40 circles, **+0.77 ms** at 80. The show neither
computes nor draws the circles past the horizon.

## Hyperspace

`STARS` fills a tube ahead of the eye and flies down it. Each star holds a fixed
direction and a depth. Only the depth changes.

The show projects a star at `xy / z`. A star that comes nearer thus runs away from the
centre of the screen, slowly at first and then very fast. That acceleration is the
whole effect.

**Nothing here animates a streak that grows longer.** The streak grows because the
star is nearer. The show draws a line between where the star is and where it was a
moment ago, and the projection does the rest.

### STREAK is a shutter speed

`STREAK` is not a length. It is a **time**: how many seconds of travel to draw behind
each star. A camera works the same way.

That is one setting fewer to ride during a set. A field that flies fast streaks far on
its own, and the same value gives short dashes when you slow it down. A length in
pixels would need a correction every time you moved `SPEED`.

It also comes free in reverse. `SPEED` runs from -3 to 3, and at a negative value the
trail sits on the other side of the star with no special case, because the seconds of
travel are signed too.

### Two details that do the work

**The stars spread over a disc, not over a square.** The show draws a radius as the
square root of a random number. Without that square root the stars crowd the axis,
where they also move the least, and the middle of the screen silts up.

**A star fades in over the far quarter of the tube.** A star switched on at full
brightness pops. With three hundred of them that recycle constantly, the back of the
field twinkles like a fault. This is the same fade the sphere gives its circles at the
horizon, for the same reason.

`SPREAD` is the width of the tube at the far plane. A small value keeps the stars on
the axis and they come straight at you. A large value starts them wide and throws them
past the corners.

### Why it is one node

Every other effect gives each element its own `Line2D`. This one draws all of its
stars in a single canvas item. At 300 stars that is 300 nodes and 300 halos saved, and
a star is two points, thus there is no shape worth keeping between frames.

The halo is drawn here rather than hung off a `Halo` node, which needs a `Line2D` to
echo. It reads the same `RINGS` constant, thus the two cannot drift apart.

## The kaleidoscope

`EFFECT` folds the image into symmetrical wedges around the center, like the mirrors
of a kaleidoscope. The fold works on the **frame that is already drawn**, not by a
duplication of geometry. Thus the cost is one full-screen pass whether you have 5
strokes or 40.

The layer sits above the visuals but **below the settings panel**. Otherwise the fold
would multiply the sliders across the screen too.

Like the halo, at 0 the pass is genuinely switched off rather than left to run as an
identity transform.

Between 0 and 1 it **cross-fades**: it mixes the frame as drawn and the fully folded
frame. Both are continuous everywhere, thus their mixture is continuous too.

Two other methods were tried and both broke in the middle of the range. This is worth
a record, because each one looks obviously right. A blend of the sampled *coordinates*
squeezes the whole screen into the one narrow sector that the fold maps onto. The
middle then came out as a squashed amalgam in a corner. A blend of the **angle** avoids
that squeeze and is the same thing algebraically, but `atan` cuts the circle along the
left-hand axis. The angle jumps a full turn there. The jump cancels only at 0 and at 1,
and every value between wore a seam that ran out from the center. Measured across that
ray, the mismatch was four to six times what the cross-fade leaves.

Off the edge of the frame the lookup reflects rather than clamps. A clamp smears the
last row of pixels into a flat dark panel, where a reflection carries the pattern on
and reads as more mirror.

## Scanlines

`PARALLEL` does not tune the scatter. It crossfades between two different behaviors.
At **0** every stroke drifts and spins on its own and bounces off the edges, which is
the original look. At **1** they all take a shared angle and a place in a fan with
equal spacing. In between, the show mixes the two, thus you can open and close it like
any other effect.

`SCROLL` then walks that fan sideways, perpendicular to the shared angle, and wraps it
around. That is what turns a set of parallel lines into scanlines. They have to *move
through* the frame, not only point the same way.

Two details do most of the work:

- **The show reassigns the spacing whenever the count changes.** Thus the strokes keep
  an equal spread rather than the random gaps of a scatter. Without that they read as
  lines that happen to be parallel, not as a raster.
- **The wrap happens off screen.** The fan spans the screen diagonal. Thus a stroke has
  completely left the frame before it appears again on the other side, at every angle.
  Measured at 1101 px of travel against a 1101 px half-diagonal.

`SPIN` still turns the whole fan while it scrolls, which gives a raster that rotates
slowly through the room.

## Chaos

`CHAOS` is a macro setting that **layers on top of** the others without an overwrite.
At 0 the picture is exactly what you dialed in. At 1 everything comes loose. Its
progression is deliberately uneven: discreet at first, then runaway.

What it does, effect by effect:

- **Lasers.** Each stroke gradually recovers its own heading. This is the disorder
  that the `SPIN` direction setting removed, brought back through the side door: at 1
  the strokes cross in opposite directions again. The show adds random swerves on top,
  which makes the paths zigzag.
- **Spotlight.** The head can no longer stay put. Its pauses are eight times shorter,
  it sweeps three times faster and it trembles seven times harder. It does **not**
  touch the glitches. Chaos unsettles *motion*, and `GLITCH` keeps its own setting. A
  head in a panic with no glitch, and a composed head that erupts now and then, are
  two different pictures.
- **Sphere.** Each circle slides along its longitude at its own pace and its size
  starts to throb. The sphere stays legible, but its surface is no longer of a piece.
- **Hyperspace.** The vanishing point wanders, and each star takes its own pace. This
  is what stops the field reading as a screensaver: a ship on a heading rather than a
  fixed tunnel.

## Two-way speeds

`SPEED` runs from **-3 to 3**. Both `SPIN` settings and the `ROTATION` of the mirror
run from **-1 to 1**. In every case the middle of the slider is a standstill and 1 is
normal speed. Thus `SPEED` keeps headroom above 1 for passages that need to take off.

The sign gives the direction of rotation and the magnitude gives the speed. The screen
shows an arrow rather than a minus sign (`← 0.60`, `→ 0.60`, `·  0.00`), because an
arrow reads at a glance in the dark.

For "leftwards" and "rightwards" to mean anything, each laser now draws the
**magnitude** of its spin at random, but no longer its direction. The direction comes
from the global setting. Before, half the strokes turned the other way and no single
control could make them agree.

Signs combine. `SPEED` at -1 with `SPIN` at +1 turns the strokes leftwards, because a
reversal of global time reverses rotation too. The `SPEED` of the spotlight stays a
positive rate: a followspot does not "un-search", and it keeps sweeping forwards even
when everything else runs backwards.

## The two color modes

**RANDOM** (the default) — every laser, every sphere circle, every star and the
spotlight draw their own hue. `R` redraws them.

**MANUAL** — every element takes the color set by `RED` / `GREEN` / `BLUE`.

Three things make the move back and forth painless:

- **A touch on a color switches to manual** automatically. Without that, a move of
  `RED` in random mode would do nothing and the slider would look broken.
- **The random hues survive the trip into manual.** A return to `RANDOM` finds them
  exactly as they were. Manual mode hides them, it does not erase them.
- **`R` returns to random** *and* draws fresh hues. It is the escape hatch that you
  find without thought in the middle of a set.

`SATURATION` stays useful in both modes, because it pulls the color towards white.
When you project into haze, a near-white beam cuts through better than a saturated
one. If the picture lacks bite, decrease it to 0.4–0.5.

## The auto-pilot

`RANDOMIZER` makes the visuals evolve by themselves. Every 1 to 12 seconds, related to
its value, it picks one or two settings and puts them down somewhere else. One time in
four it also redraws the colors, but only if they are in random mode. Otherwise it
would trample a manual choice.

Three precautions make it usable for real:

- **One or two settings at a time.** Beyond that it stops reading as a gesture and
  starts reading as a malfunction.
- **Values group towards the middle** of each range (the average of two draws), which
  avoids the extremes that either empty or saturate the screen.
- **Thirteen settings are out of its reach**: `SPEED`, `GLOW`, `RECALL FADE`,
  `PANEL`, `AUTO DIM`, `RANDOMIZER`, `REACTIVITY`, `AIMING`, and the whole COLOR
  section (`MODE`, `SATURATION`, `RED`, `GREEN`, `BLUE`). Those are decisions — the
  tempo of the track, the contrast of the room, who holds the beam — not variations to
  be subjected to. COLOR has no randomizable setting left at all, thus its card on the
  phone carries no roll button.

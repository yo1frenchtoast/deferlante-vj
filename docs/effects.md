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

### The shutter

A followspot is not always a full circle. Put a blade across the lens and what
lands on the wall is an arc; put two and you get the bowtie a moving head throws
when it is half closed. `ARCS` and `LENGTH` are that blade.

`ARCS` is **how many pieces the ring is cut into** and `LENGTH` **how much of each
piece is lit**. So `ARCS` 1 with `LENGTH` 0.5 is a half pool and 0.25 a quarter,
while `ARCS` 4 at `LENGTH` 0.5 gives four blades with four gaps. Both default to
the whole circle, so nothing that exists changes until you reach for them.

The opening is **centred on its piece** rather than started at one edge. Closing it
therefore eats from both sides and the shape stays where the operator put it —
start it at an edge and every turn of the knob also slides the pool round, which
is unusable while a beam is on somebody.

`SPIN` turns the shutter **without moving the head**. That distinction is the whole
point: the pool stays on its target and the opening travels around it, which is a
blade turning in front of a lamp rather than a shape spinning in the air. It is
two-way, like the other spins, and sits at 0 by default.

Only one piece is really drawn. A `Line2D` is a single polyline and cannot have a
hole in it, so the rest are rotated copies parented to the first — position,
rotation and colour all come free from that one transform, and at `ARCS` 1 no copy
exists at all. Each copy carries its own halo, and a glitch whitens every blade
rather than one out of four.

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

Like the halo, at OFF the pass is genuinely switched off rather than left to run as an
identity transform.

### Why it has no middle

`EFFECT` is **off or on**. It was a 0 – 1 amount, and the middle of that range is gone
on purpose.

Three methods were tried for that middle. The first two broke on geometry, and this is
worth a record, because each one looks obviously right. A blend of the sampled
*coordinates* squeezes the whole screen into the one narrow sector that the fold maps
onto. The middle then came out as a squashed amalgam in a corner. A blend of the
**angle** avoids that squeeze and is the same thing algebraically, but `atan` cuts the
circle along the left-hand axis. The angle jumps a full turn there. The jump cancels
only at 0 and at 1, and every value between wore a seam that ran out from the center.
Measured across that ray, the mismatch was four to six times what the third method
leaves.

The third method was a **cross-fade of the two images**: `mix(frame, folded, amount)`.
Both are continuous everywhere, thus their mixture is too, and the seam went. It was
the right answer to the question that was asked.

It failed a different question. `mix` is an operator for opaque images, and these
strokes are **additive light on black**. At 0.5 it does not give half a mirror. It
gives the whole frame at half brightness, plus the whole fold at half brightness. On a
monitor that passes for a mirror that opens. Through a projector into haze it is a
washed-out ghost, and a projector has no contrast to spare. See
[projection notes](in-the-room.md#projection-notes).

Thus the middle went, and the pass got simpler with it. The shader no longer fetches
the unfolded frame at all. The gamepad had already settled the question in practice:
its `X` button has written 0 or 1 here since the day it got a mirror button.

Two consequences to know. A preset that recalls the mirror now **cuts** rather than
opens it, because a value that snaps has nothing to slide through. And the auto-pilot
can still pick this setting, where a pick is now a coin flip that throws the whole
screen into mirrors or out of them.

Off the edge of the frame the lookup reflects rather than clamps. A clamp smears the
last row of pixels into a flat dark panel, where a reflection carries the pattern on
and reads as more mirror.

## Motion blur

`TRAIL` keeps the frame that was on screen, dims it, and draws it under the new one.
What stands still is drawn over its own ghost and looks untouched. What moves leaves
the ghost behind, and the eye reads the smear as speed. It is a long exposure, done one
frame at a time.

The setting is a **time**, not a fraction. It runs from about two frames at the bottom,
which reads as a softened edge, to half a second at the top, where a laser sweep writes
a solid ribbon. The show computes how much of the last frame survives from that time
and the length of the frame it is in. Thus the trail lasts as long on a projector that
drops to 30 fps as it does at 60. At **0** the pass is switched off, not left to run as
an identity transform, and the copy below stops as well.

### Why it keeps a copy of the frame

The short way to write this effect is to tell the viewport never to clear itself, then
dim last frame's pixels where they already lie. Under the **Compatibility renderer**,
which is the one this show ships on, `CLEAR_MODE_NEVER` makes the viewport draw
nothing at all: not the trail, not the effects, not even a flat rectangle put on top of
it. The wall goes an even grey. Measured on Godot 4.7.2.

Thus the show keeps the frame by hand. A second viewport, `Echo`, holds a copy of the
show one frame behind, and the pass reads that copy. It costs one full-screen copy and
one more 1080p texture, which is why `Echo` stops updating at 0 rather than copies a
frame that nobody reads. On a software renderer with no GPU at all, the pass at full
trail measured inside the noise of the bench (±0.5 ms), in the same band as the
kaleidoscope.

### Why the trail has a ceiling

The strokes are **additive light on black**. A stroke that barely moves therefore lands
on top of its own ghost every frame, some thirty times over at a long trail. Every
channel pins at 1, and the spotlight — an orange ring a few pixels wide — comes out a
fat white band. That is the washed-out ghost that this show has no contrast to spare
for.

Thus the ghost is held **below the stroke that casts it**: the pass clamps the copy to
half scale before it dims it. The ring keeps its color and its width, and the trail
stays the dim part, which is also what a long exposure gives you.

The pass writes an opaque color rather than lays a black veil at some alpha, for the
same class of reason. A veil is a blend, and a blend lands in 8 bits. Once a pixel is
dim enough that the multiply rounds back to where it started, no veil ever removes it,
and a bright stroke leaves a permanent grey scar along its path — on stage, an hour
into the set. The pass takes a small floor off every channel each frame instead. It is
too small to see against a live stroke, and large enough that every tail reaches black.

### With the mirror on

The blur is drawn **below** every effect, and the mirror is drawn above them. Thus the
fold is already in the frame that the copy holds, and the trail is folded with it. A
turning mirror then walks the trail around the wedges, which reads as a spiral. Know it
before it surprises you. It cannot run away: the pass only samples and dims, thus it
creates no light, and the floor guarantees that each frame's leftovers reach black.

## The tunnel

`TUNNEL` is the trail with one change. The trail keeps the frame that was on screen and
draws it, dimmed, under the new one. The tunnel draws that ghost a little **bigger and a
little turned**, and the next frame does it again to the frame before. What was at the
centre a moment ago is further out now, and the picture falls away along a spiral. It is
what a camera does when it films its own monitor. A sphere is drawn out into a tube, and
a laser into a ribbed sheet.

The setting is a **speed**, and it has two signs. → moves the ghost outwards, as if you
were flying forward, and ← moves it inwards, which draws everything towards the centre.
The top of the slider is a plunge. It is measured in seconds, not in frames, so the fall
is as fast on a projector that drops to 30 fps as it is at 60. `TUNNEL TWIST` turns the
ghost as it falls, one way or the other. It does nothing while the tunnel is at 0.

It shares the trail's pass and its copy of the frame, so it costs what the trail costs,
and nothing at 0. It also brings a ghost of its own. A tunnel is made of ghosts, and one
that lasted two frames would be a zoom blur. So with `TRAIL` at 0 the ghost lasts 0.4 s,
and `TRAIL` can make it longer, up to its half second. It cannot make it shorter.

The brightness cannot run away, for the same reasons as the trail: the ghost is held below
the strokes that cast it, and a small floor is taken off every frame. What the ghost
never held, at the edge of a picture that is shrinking, is black. Reading the pixel at the
edge instead would smear it into a frame of solid colour.

Because the ghost is read smoothly while it moves, the trail softens a little as it falls.
With the tunnel at 0 the pass reads exactly the pixels that it always did.

## The wave

`WAVE` reads the frame from a place that swings from side to side, and up and down, as a
sine of where you are looking. A straight line comes out as a ripple: heat over asphalt,
the view through water, a picture on a sheet that somebody is shaking.

There are two waves, not one, and they share neither a direction nor a pace. A single wave
shears the picture sideways and reads as a rendering fault. A second one across the first
makes it read as a surface. `WAVE COUNT` is how many there are across the height of the
screen, and more of them are shorter. `WAVE SPEED` is signed: it says which way they
travel, and 0 holds them still. The speed follows the global speed, so a global speed of
0 freezes the ripple with the rest of the show.

The strength is a distance. At the top of the slider a point is pulled by 4 % of the
screen, about 77 pixels on a 1920 wide one. The top of a slider should be too much.

The pass is drawn above the mirror, so the ripple runs across the folded picture and a
kaleidoscope ripples as a whole. It is below the aberration, so the fringes follow the
waves, where the other order would wave the fringes themselves. Off the edge of the frame
it reflects rather than clamps, for the same reason as the mirror: a clamp smears the last
row of pixels into a flat panel.

It is off at 0 and costs nothing there. On, it is one full-screen pass with one fetch.

## The slice glitch

`SLICE` cuts the picture into horizontal bands and slides some of them sideways. Where a
band slides it takes its colours with it at slightly different paces: red goes furthest and
blue least. Each edge of a torn band then has a coloured fringe, which is how a damaged
video signal tears.

One value says two things. It is the **share of bands that slide**, and it is **how far
they go**. A low value is a few bands nudged, and the top is most of the picture torn.
`SLICE BANDS` is how many bands there are, and `SLICE RATE` is how many times a second the
tear changes into a new one. A band slides off one side of the frame and comes back on the
other. The edges of the bands move with each new tear as well. Bands that stayed where they
were would tear along the same seams every time and read as a grid. The tear follows the
global speed, so a global speed of 0 holds it still.

The kick can drive it. `SLICE ← BASS` in AUDIO adds to `SLICE`, and it is **0 by default**.
It adds and does not multiply, for the reason that the aberration does: this effect is off
at rest, and a kick that could only scale a zero would never show. The setting keeps
saying what the slider says, and only what is drawn moves.

The pass is drawn above the wave and below the aberration. The tear cuts the rippled
picture, and the fringes are put on what is left. It is off at 0 and costs nothing there.
On, it is one full-screen pass with four fetches.

## Chromatic aberration

`ABERRATION` reads each colour channel of the frame from a slightly different place.
Green stays where it is, red moves one way and blue the other. Every edge then grows a
red fringe on one side and a blue one on the other, which is what a cheap lens does,
because glass bends each wavelength by a little more or less than the next. A stroke
keeps its centre and gains two coloured edges. Moving only one channel would drag the
whole picture to a side instead.

The strength is a distance: 32 pixels on a 1080p screen at the top of the slider. The
top of a slider should be too much. The middle is where the set lives. At **0** the pass
is switched off, not left to run as an identity transform.

Two more settings say which way the channels move.

- `ABERRATION LENS` at **0** moves them the same way everywhere, along `ABERRATION
  ANGLE`. At **1** they move along the line from the centre, and by more the further
  out. The middle of the picture stays clean and the edges carry the fringe, like a
  real lens. Between the two, the direction is a mix.
- `ABERRATION ANGLE` is once round the dial. It does nothing at full `LENS`, where the
  direction comes from the position on screen.

The pass is drawn **above** the mirror and below the panel. The fringes therefore
follow the folded shapes, and the sliders are not part of the picture. Under a turning
mirror the fringes turn with the wedges, and that reads as one lens looking at a
kaleidoscope, which is the right picture. With the trail on, the ghost that it holds is
already fringed, and it is fringed again on every frame it lives. The older the tail,
the further its colours have parted, which is a smear that the aberration alone does not
make. At the top of both sliders it is long.

At the edge of the frame a channel that is read from beyond it gives black, and the
fringe simply stops there. Reading the pixel at the edge instead would smear it out
into a solid block, which is what it did at first: strokes that run into a corner drew
squares of one colour.

It is off by default, so a show saved before it existed comes up unchanged. It also
takes part in `SHUFFLE` like every other setting, under the section `fx`.

## What the full-screen passes cost

Every effect on this page that works on the whole picture is one pass over the frame, and
it costs nothing at 0. Measured with no GPU at all (llvmpipe, the Compatibility renderer,
a 1080p show, 12 lasers, 20 circles and 120 stars), the frame time in milliseconds was:

| Scenario | ms a frame | Added |
| --- | --- | --- |
| Nothing on | 6.1 | — |
| Wave | 9.0 | +2.9 |
| Mirror | 9.4 | +3.3 |
| Aberration | 9.8 | +3.7 |
| Aberration, in lens mode | 10.0 | +3.9 |
| Trail | 10.3 | +4.2 |
| Slice glitch | 10.4 | +4.3 |
| Tunnel (with its twist) | 10.5 | +4.4 |
| Mirror, wave, slice, aberration and tunnel together | 26.8 | +20.7 |

The passes add up. Five of them together are about five times one, and on a machine with
no GPU that is past the 16.7 ms of a frame at 60. Turn on the ones that the set needs.

Read the numbers for their order and not for their size. Software rendering is a bad model
of a graphics chip: it pays for every pixel that a pass reads, where a GPU pays much less.
The variation between two runs of the same scenario was about 0.2 ms. The new passes cost
what the mirror costs, within a millisecond, and the mirror has been shipping for a long
time. On the RTX 3060 of the machine this was developed on, the cost is not measurable
against a frame of a few milliseconds. It was not measured on the projector's own machine
or on an Android TV, and those are the weakest hardware that this show runs on.

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
- **Mirror.** The `ROTATION` of the fold no longer holds its pace. It speeds up, slows
  down, and at 1 it goes through a standstill and turns back the other way. Chaos only
  unsettles a turn that is already there: at `ROTATION` 0 the mirror stays still.

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
- **Sixteen settings are out of its reach**: `SPEED`, `GLOW`, `RECALL FADE`,
  `PANEL`, `AUTO DIM`, `RANDOMIZER`, `REACTIVITY`, `SHUFFLE ← KICK`, the three
  spotlight rows that only
  matter with a pad (`AIMING`, `TRACKING`, `HAND BACK`), and the whole COLOR section
  (`MODE`, `SATURATION`, `RED`, `GREEN`, `BLUE`). Those are decisions — the tempo of
  the track, the contrast of the room, who holds the beam — not variations to be
  subjected to. COLOR has no randomizable setting left at all, thus its card on the
  phone carries no roll button.

  `TRACKING` and `HAND BACK` are there for a reason worth stating. They are not a
  look, they are the feel of the handle. A roll of the tracking speed changes how the
  beam answers **while a hand is on the stick**, in the middle of a follow. A roll of
  the hand-back delay decides how long the beam then sits still. Neither shows on
  screen when nobody holds a pad, thus rolling them spends a move on nothing.

### On the beat

`SHUFFLE ← KICK`, in the AUDIO section, hands the shuffle to the music. The show
watches the bass for a rising edge and, on each kick, gives itself that much of a
chance of rolling. At 0 nothing happens, which is where it starts. It reads the
envelope before `PUNCH` is applied, so bending the picture harder does not also
retune the detector.

It presses the same handle as the button. The sound does not get its own kind of
move: it rolls the whole show exactly as `SHUFFLE` and the `RANDOMIZER` clock do,
thus everything above — one or two settings, values towards the middle, the sixteen
settings out of reach — holds here too.

Two things keep it musical:

- **No more than one move a second**, whatever the tempo and whatever the chance. It
  is what keeps a fast track from turning the show into a strobe of settings, and it
  is why the top of this slider is not a cut on every kick.
- **`RANDOMIZER` is not involved.** At 0 the clock is off and the music is the only
  thing moving the show, which is usually what you want. Run the two together and the
  show drifts on its own between kicks.

Measured at 128 bpm: the top of the slider moves the show every three kicks, half way
up is about one move a bar, and 0.1 is one every three bars. The detector itself is
exact — one beat per kick, from 100 to 174 bpm, and a held bass note counts once
rather than trembling into a stream of them.

It follows `REACTIVITY` like every other amount, thus the master still takes the whole
of the sound response out in one move. On a night with no sound, or with the capture
on the wrong source, nothing rolls — the status row says which. And like the rest of
the sound response it is out of the auto-pilot's own reach: a roll that could switch
on the thing that rolls the show is a loop, not a variation.

### Where it lands

The middle of a range is not always the middle of what the eye reads. Measured over
200 000 draws of the same distribution the auto-pilot uses:

| Setting | Default | Median pick | 10 – 90 % |
| --- | --- | --- | --- |
| `STARS` | 0 | 200 | 90 – 310 |
| `CIRCLES` | 14 | 40 | 18 – 62 |
| `COUNT` (lasers) | 3 | 20 | 9 – 31 |
| `GLITCH` | 0 | 0.025 | 0.011 – 0.039 |

The first three are looks. A field of 200 stars, or 20 strokes where there were 3, is
a scene change, and a scene change is what you asked for when you moved `RANDOMIZER`
off 0.

**`GLITCH` is the one to know about.** Its range is a probability *per frame*, thus its
middle is not tasteful the way the others are. At the 0.005 of the example above, the
head erupts about **one time every 3 s**. At the 0.025 that the auto-pilot usually
picks, it is **one time every 0.7 s**, and at the top of that band one time every
0.4 s. That is no longer a head that erupts now and then. Ride `RANDOMIZER` with
`GLITCH` in mind, or move `GLITCH` back down after a roll.

The ceiling stays where it is. A slider top that is past good taste is deliberate here,
as it is for the audio amounts: the top belongs to the hand of the operator, and a set
lives in the middle.

**Five settings can be picked and change nothing.** `PUNCH` and the four band amounts
do nothing while `REACTIVITY` is 0, which is where it starts and where it stays unless
you move it, because the auto-pilot cannot. On a night with no sound, five of the
thirty-six candidates are silent moves. `SHUFFLE ← KICK` is not among them: it is out
of reach for the reason given above.

### What starts off, and who may switch it on

`GLOW`, `GLITCH`, `RANDOMIZER`, `STARS` and the `EFFECT` of the mirror all start
switched off. See [what starts switched off](in-the-room.md#what-starts-switched-off)
for why. That stance is about **the launch**, not about the whole night. It says that
the show must not arrive with an opinion already formed.

The auto-pilot is the thing you hand that decision to on purpose. Thus it may switch
these on, and it does: `STARS` lands at 200, and the mirror is a coin flip that throws
the whole screen into wedges or out of them. If you want an effect to stay off for a
whole set, leave `RANDOMIZER` at 0 and switch the effect on yourself.

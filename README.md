# Déferlante

[![Build](https://github.com/yo1frenchtoast/deferlante/actions/workflows/build.yml/badge.svg)](https://github.com/yo1frenchtoast/deferlante/actions/workflows/build.yml)

VJ visuals in Godot 4: neon strokes on black, additively blended.
Built for video projection with a haze machine.

*Déferlante* is French for the breaking wave — the one that surges in and takes the
room. Pull the word apart in English and something else surfaces: **defer**, and a
*lante* one syllable short of *lantern*. A light that keeps putting off the moment
it finds you.

Which is exactly what the spotlight does here. It sweeps, it stops, it trembles as
though it had seen something, then it leaves. It never lands on anyone. Everything
else — the lasers, the sphere, the glitches — happens around that deferral: a room
swept by a light that is always about to arrive, and never does.

**Getting started** — [Run](#run) · [Drive it](#drive-it) · [Settings](#settings)
**External control** — [Gamepad](#gamepad) · [Web surface](#web-control-surface) · [REST API](#rest-api) · [OSC](#external-control-over-osc) · [Audio reactivity](#audio-reactivity)
**The effects** — [Spotlight](#the-spotlight) · [Sphere](#the-sphere-effect) · [Kaleidoscope](#the-kaleidoscope) · [Chaos](#chaos) · [Auto-pilot](#the-auto-pilot) · [Colour](#the-two-colour-modes)
**In the room** — [What starts off](#what-starts-switched-off) · [Glow](#the-glow) · [Projection notes](#projection-notes) · [Performance](#measuring-performance-f3)
**The code** — [Structure](#structure) · [Builds](#builds) · [Renderer](#a-note-on-the-renderer)

The on-screen interface speaks French or English — see `LANGUAGE` in the Global
section. Everything else (code, OSC addresses, this document) stays in English.

## Run

Open the project in Godot 4.7+ and press F5. The main scene is `scenes/main.tscn`.

## Drive it

The sliders **fade out on their own after 4 s of inactivity** (over 0.7 s) and come
back on any key press or mouse move. `H` pins them on screen while you dial things in.

| Key | Action |
| --- | --- |
| `↑` `↓` | Move between settings (the selected one is highlighted) |
| `←` `→` | Adjust — a fortieth of the range per press |
| `Shift` + `←` `→` | Fine adjust, one step at a time |
| `Space` | Fire a glitch immediately |
| `R` | Redraw every colour and trajectory |
| `H` | Pin / unpin the panel (stops it fading) |
| `F3` | FPS readout |
| `F11` | Fullscreen |
| `Esc` | Quit |

The mouse works on the sliders too, but the keyboard is safer live: no aiming in
the dark.

## Settings

The panel is arranged in six sections, the same as the Chataigne module's menus.
Labels below are the English ones.

### Global
| Setting | Range | Effect |
| --- | --- | --- |
| `SPEED` | -3 – 3 | Global speed. 1 is normal, 0 freezes, negative runs everything backwards. |
| `CHAOS` | 0 – 1 | Motion disorder. Does not touch `GLITCH`. See below. |
| `RANDOMIZER` | 0 – 1 | Auto-pilot. 0 is off, 1 is about one change per second. |
| `GLOW` | 0 – 2 | Halo. **0 by default**, see below. |
| `LANGUAGE` | FRANÇAIS / ENGLISH | On-screen language. Affects nothing else. |

### Colour
| Setting | Range | Effect |
| --- | --- | --- |
| `MODE` | RANDOM / MANUAL | Each element its own hue, or the chosen colour for all. |
| `SATURATION` | 0 – 1 | 0 is pure white, 1 a full colour. Works in both modes. |
| `RED` `GREEN` `BLUE` | 0 – 1 | The manual colour. Touching one switches to manual. |

### Mirror
| Setting | Range | Effect |
| --- | --- | --- |
| `EFFECT` | 0 – 1 | Kaleidoscope fold. 0 is off, and the pass is not paid for. |
| `SEGMENTS` | 2 – 16 | Number of wedges. 6 gives the classic star. |
| `ROTATION` | -1 – 1 | Turns the mirrors. ← left, → right. |

### Lasers
| Setting | Range | Effect |
| --- | --- | --- |
| `COUNT` | 0 – 40 | Number of strokes. Added and removed live. |
| `WIDTH` | 1 – 24 | Stroke width. |
| `LENGTH` | 0.1 – 2 | Scales the length (each stroke keeps its own). |
| `SPIN` | -1 – 1 | ← leftwards, → rightwards. |

### Spotlight
| Setting | Range | Effect |
| --- | --- | --- |
| `RADIUS` | 20 – 600 | Radius of the pool. |
| `PULSE` | 0 – 300 | How far the radius swells. 0 holds it steady. |
| `WIDTH` | 1 – 24 | Circle stroke width. |
| `SPEED` | 0 – 2 | Sweep speed (no direction to it). |
| `HOLD` | 0 – 3 | How long it rests on target. 0 sweeps without stopping. |
| `SHAKE` | 0 – 3 | Tremor amplitude at rest. 0 holds perfectly still. |
| `FREQUENCY` | 0 – 20 | Tremor rate, **independent of `SPEED`**. |
| `GLITCH` | 0 – 0.05 | Glitch chance per frame. **0 by default.** Independent of `CHAOS`. 0.005 ≈ one every 3 s. |

### Sphere
| Setting | Range | Effect |
| --- | --- | --- |
| `CIRCLES` | 0 – 80 | Number of circles. 0 switches the effect off. |
| `SIZE` | 0.03 – 0.8 | Size of one circle, in radians on the sphere. |
| `RADIUS` | 100 – 800 | Sphere radius on screen. |
| `SPIN` | -1 – 1 | ← leftwards, → rightwards. |
| `DEPTH` | 1.2 – 10 | Eye distance. Small means strong perspective. |
| `WIDTH` | 1 – 24 | Circle stroke width. |
| `GLASS` | 0 – 1 | 0 an opaque sphere, 1 shows the far side through it. |

Adding a setting takes one line in `_build_params()` of `vj_controller.gd`: the
section, the UI row, the slider, the number formatting, the keyboard handling and
the OSC address all follow. Its label goes in `scripts/lang.gd`.

## Gamepad

An Xbox pad is picked up automatically when plugged in — nothing to configure. It is
the only surface that can **take the spotlight off auto-pilot and aim it by hand**.

| Control | Effect |
| --- | --- |
| **Left stick** | Aim the spotlight. Absolute: stick centre is room centre. |
| **LT / RT** | Shrink / grow the pool. Analogue — a light squeeze creeps, a full pull sweeps. |
| **A** | Fire a glitch |
| **B** | Redraw colours (same as `R`) |
| **X** | Mirror on / off, back to the amount it had |
| **Y** | Glow on / off |
| **LB** *(hold)* | Freeze — everything stops while held |
| **RB** *(hold)* | Boost — 2.5× speed while held |
| **Right stick** ←→ | Laser spin |
| **Right stick** ↑↓ | Chaos |
| **D-pad** ↑↓ | Laser count |
| **D-pad** ←→ | Mirror segments |
| **Start** | Pin / unpin the panel |
| **Back** | Hand the spotlight back to auto |

### Letting go

The interesting part is not grabbing the spotlight, it is releasing it. Let the stick
centre and the head **holds exactly where you left it**, takes its normal pause, then
resumes hunting from there. Nothing snaps back, nothing jumps — the same rest it takes
after any sweep of its own. You can hand it over mid-gesture and the audience cannot
tell where the operator stopped and the machine resumed.

`Back` does the same without waiting for the stick to centre.

### Why the shoulders are momentary

`LB` and `RB` are held, not latched. In a set you lean on a button for four bars and
want it to let go by itself — a latch is one more thing to remember to undo. Both
remember the speed you were at and put it back on release, so they can be used over
any tempo rather than only from 1.0.

### Two deliberate choices

**The pad does not wake the on-screen panel**, unlike the keyboard. It is a
performance surface like OSC: holding a stick for a whole track would otherwise leave
the sliders on screen — and projected on the wall. `Start` shows them when you want
them.

**Everything except the aim goes through `VJParam.set_value()`**, the same entry point
as the sliders, OSC and the web page. Squeeze a trigger and the radius moves on the
panel, on every connected phone, and in any console reading back over the API.

## Web control surface

Godot serves a control page on port **7331**. Open `http://<machine-ip>:7331` from a
phone or tablet on the same network — the address is printed at startup.

It gives you, on top of every setting as a touch slider:

- **Two XY pads** whose axes are assignable from dropdowns, each entry naming its
  section as well as the setting (`X · SPOTLIGHT WIDTH`) — three sections have a
  `WIDTH`, and on a pad you pick blind from a list rather than reading a labelled
  row. Which pair is worth playing with changes from one track to the next, so they
  are not hard-wired; they default to chaos × speed and spotlight radius × pulse.
- **GLITCH** and **COLORS** buttons.
- **Live mirroring**: a value changed on the keyboard, over OSC or by the auto-pilot
  moves on the phone too, and vice versa.

The page **builds itself from a schema** Godot sends on connect. It holds no list of
settings of its own, so adding one in `_build_params()` makes it appear on the phone
with no change to the HTML. Switching the interface language relabels it as well.

Two ports rather than one, deliberately: the page is served over HTTP on 7331 and
the control channel is a WebSocket on **7332**. `WebSocketPeer.accept_stream()` does
the handshake itself and needs the stream untouched, which rules out reading the
request first to tell an upgrade from a page request.

A sleeping phone drops the socket; the page reconnects on its own without a reload.

⚠️ There is **no authentication**: anyone on the network can drive the visuals. That
is fine on a private Wi-Fi and a bad idea on a public one.

## REST API

The same HTTP server that carries the control page also exposes the settings as a
REST API, described by an OpenAPI 3.0 specification.

| | |
| --- | --- |
| `http://<machine-ip>:7331/docs` | Swagger UI, with *Try it out* wired up |
| `http://<machine-ip>:7331/openapi.json` | the specification itself |

| Endpoint | |
| --- | --- |
| `GET /api/params` | every setting, with bounds and current values |
| `GET /api/params/{section}/{setting}` | one setting, e.g. `/api/params/spot/hold` |
| `PUT /api/params/{section}/{setting}` | body `{"value": 2.5}` |
| `POST /api/actions/glitch` | fire one glitch |
| `POST /api/actions/randomize` | redraw colours and trajectories |

A `PUT` goes through `VJParam.set_value()` like everything else, so the value is
clamped and snapped, the on-screen panel follows, and every connected phone follows
too. Sending `999` to a setting bounded at 3 returns `3` rather than an error — the
response body is always the setting as it ended up.

```
curl -X PUT http://192.168.10.17:7331/api/params/global/chaos \
     -H 'Content-Type: application/json' -d '{"value": 0.8}'

curl -X POST http://192.168.10.17:7331/api/actions/glitch
```

**The specification is generated from the settings**, not written beside them: the
`{setting}` parameter carries an enum of all 32 addresses, so Swagger UI offers them
as a dropdown and cannot list one that no longer exists.

⚠️ The Swagger UI page pulls its JavaScript from a CDN, so `/docs` needs an internet
connection — which a venue often lacks. The API and the spec do not: they are served
entirely by Déferlante. Without internet, `/docs` says so and points at
`/openapi.json`, which any OpenAPI tool will read.

As with everything else on this server, **there is no authentication**.

## External control over OSC

Godot listens for OSC on port **9000** (UDP), on every interface. Every setting can
be driven remotely from Chataigne, TouchOSC, a sequencer, or any script at all.

### How an address is built

`/deferlante/<section>/<setting>` — the section is part of the path because three
sections have a `WIDTH` and two have a `ROTATION`; without it the addresses would
collide.

The address and the label are **decoupled** in the code: `slug` carries the address,
`Lang` carries what is displayed. Rewording a label, or switching the interface to
French, can never break a console already wired to an address.

### Arguments

One argument, a **float** or an **int**; anything else is ignored. The value is
clamped to the setting's bounds and snapped to its step, so a console sending `999`
lands on the maximum rather than breaking anything.

**Bundles are supported.** Chataigne sends one when several values leave in the same
frame. The timetag is deliberately ignored and the contents applied at once: when
VJing you want the value now, not at a scheduled time.

### Two forms, and why

| Form | Argument |
| --- | --- |
| `/deferlante/<section>/<setting>` | the value, in the setting's own units |
| `/deferlante/norm/<section>/<setting>` | 0 → 1, spread over the setting's range |

The `norm` form is for surfaces that can only send 0 → 1 — MIDI faders, TouchOSC —
and have no business knowing that `spot/radius` runs from 20 to 600.

### Actions

| Address | Effect |
| --- | --- |
| `/deferlante/glitch_now` | fires one glitch (no argument needed) |
| `/deferlante/randomize` | redraws colours and trajectories, and returns colour to random mode |
| `/deferlante/color/rgb` | three floats 0 → 1: the whole colour in one message, and switches to manual |

### Every address

Generated from the settings themselves, so this table cannot drift:

```
python3 tools/build_chataigne_module.py --addresses
```

| Address | Range | Default | On screen |
| --- | --- | --- | --- |
| `/deferlante/global/speed` | -3 – 3 | 1 | GLOBAL › SPEED |
| `/deferlante/global/chaos` | 0 – 1 | 0 | GLOBAL › CHAOS |
| `/deferlante/global/randomizer` | 0 – 1 | 0 | GLOBAL › RANDOMIZER |
| `/deferlante/global/glow` | 0 – 2 | 0 | GLOBAL › GLOW |
| `/deferlante/global/language` | 0 – 1 | 0 | GLOBAL › LANGUAGE |
| `/deferlante/color/mode` | 0 – 1 | 0 | COLOR › MODE |
| `/deferlante/color/saturation` | 0 – 1 | 0.7 | COLOR › SATURATION |
| `/deferlante/color/red` | 0 – 1 | 1 | COLOR › RED |
| `/deferlante/color/green` | 0 – 1 | 0.25 | COLOR › GREEN |
| `/deferlante/color/blue` | 0 – 1 | 0.1 | COLOR › BLUE |
| `/deferlante/mirror/effect` | 0 – 1 | 0 | MIRROR › EFFECT |
| `/deferlante/mirror/segments` | 2 – 16 | 6 | MIRROR › SEGMENTS |
| `/deferlante/mirror/rotation` | -1 – 1 | 0 | MIRROR › ROTATION |
| `/deferlante/lasers/count` | 0 – 40 | 5 | LASERS › COUNT |
| `/deferlante/lasers/width` | 1 – 24 | 5 | LASERS › WIDTH |
| `/deferlante/lasers/length` | 0.1 – 2 | 1 | LASERS › LENGTH |
| `/deferlante/lasers/spin` | -1 – 1 | 1 | LASERS › SPIN |
| `/deferlante/spot/radius` | 20 – 600 | 200 | SPOTLIGHT › RADIUS |
| `/deferlante/spot/pulse` | 0 – 300 | 50 | SPOTLIGHT › PULSE |
| `/deferlante/spot/width` | 1 – 24 | 3 | SPOTLIGHT › WIDTH |
| `/deferlante/spot/speed` | 0 – 2 | 1 | SPOTLIGHT › SPEED |
| `/deferlante/spot/hold` | 0 – 3 | 0.9 | SPOTLIGHT › HOLD |
| `/deferlante/spot/shake` | 0 – 3 | 1 | SPOTLIGHT › SHAKE |
| `/deferlante/spot/frequency` | 0 – 20 | 6 | SPOTLIGHT › FREQUENCY |
| `/deferlante/spot/glitch` | 0 – 0.05 | 0 | SPOTLIGHT › GLITCH |
| `/deferlante/sphere/count` | 0 – 80 | 40 | SPHERE › CIRCLES |
| `/deferlante/sphere/size` | 0.03 – 0.8 | 0.13 | SPHERE › SIZE |
| `/deferlante/sphere/radius` | 100 – 800 | 400 | SPHERE › RADIUS |
| `/deferlante/sphere/spin` | -1 – 1 | 0.6 | SPHERE › SPIN |
| `/deferlante/sphere/depth` | 1.2 – 10 | 2 | SPHERE › DEPTH |
| `/deferlante/sphere/width` | 1 – 24 | 3 | SPHERE › WIDTH |
| `/deferlante/sphere/glass` | 0 – 1 | 0 | SPHERE › GLASS |

### What it does not do

**Nothing comes back.** Godot never sends OSC out, so a motorised console will not
follow a change made on the keyboard or by the auto-pilot. The web surface does get
that mirroring, over its own WebSocket — if you need it over OSC, that is the piece
to add.

There is also **no OSCQuery**: the table above is the discovery mechanism.

### Trying it without a console

```
oscsend 127.0.0.1 9000 /deferlante/global/chaos f 0.8
oscsend 127.0.0.1 9000 /deferlante/glitch_now
```

Or with no tooling at all, straight from Python:

```python
import socket, struct

def osc(address, *args):
    pad = lambda b: b + b"\0" * ((4 - len(b) % 4) % 4)
    tags, body = ",", b""
    for value in args:
        tags += "f"
        body += struct.pack(">f", float(value))
    return pad(address.encode() + b"\0") + pad(tags.encode() + b"\0") + body

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(osc("/deferlante/sphere/spin", -0.8), ("127.0.0.1", 9000))
```

A value arriving over OSC **does not wake the on-screen panel**. That is deliberate:
an automation sending continuously would otherwise leave the sliders on screen — and
therefore projected on the wall — for the whole set.

A ready-made Chataigne module ships in `chataigne/Deferlante/`, with its own install
notes. It is a convenience only: Chataigne's generic OSC module drives the same
addresses.

## Audio reactivity

Nothing is implemented on the Godot side yet. This section records what has been
checked, so it does not have to be rediscovered.

### The path that already works: Chataigne

Chataigne has an **Audio** module that does the spectral analysis, and any band can
be mapped onto any Deferlante command. **No code is needed**: it is the shortest way
to try reactions out and see which ones hold up.

### If the analysis were to happen inside Godot

The building blocks exist (`AudioStreamMicrophone` + `AudioEffectSpectrumAnalyzer`
on a bus, both confirmed present in 4.7), but three obstacles come first:

1. **`audio/driver/enable_input` is `false`** in `project.godot`. That is the first
   switch; without it there is no capture at all.
2. **Godot captures an input, and music is an output.** If the sound comes from an
   interface (a Focusrite, a mixing desk), you capture its input and all is well. If
   the music plays out of the computer, you need to capture the output's *monitor* —
   PipeWire routing (`pw-link`, qpwgraph) and `AudioServer.input_device` pointed at
   the right source. That is the real trap, and it decides the ergonomics: in that
   case a `DEVICE` setting becomes necessary in the interface.
3. **Levels vary too much between tracks** for a fixed gain: it would need adaptive
   normalisation, with a fast attack and a slow release.

### The shape it should take

Whatever the source, the modulation should **add to** the settings rather than
overwrite them — the way `CHAOS` already does. Your values stay where you put them,
and the sound adds a pulse on top.

Band levels would also be worth exposing over OSC (`/deferlante/audio/bass`…), so
Chataigne can feed the *same* modulation system instead of driving each setting
separately. One mechanism, two possible sources.

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
- **Seven settings are out of its reach**: `SPEED`, `GLOW`, `SATURATION`, the three
  colours and `LANGUAGE`. Those are decisions — the tempo of the track, the contrast
  of the room — not variations to be subjected to.

## The kaleidoscope

`EFFECT` folds the image into symmetrical wedges around the centre, like the mirrors
of a kaleidoscope. The fold works on the **already-drawn frame**, not by duplicating
geometry: the cost is one full-screen pass whether you have 5 strokes or 40.

The layer sits above the visuals but **below the settings panel** — otherwise the
sliders would end up multiplied across the screen too.

Like the glow, at 0 the pass is genuinely switched off rather than left running as
an identity transform.

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

On top of that sit the motor profile (brisk start, long braking, slight damped
overshoot at the end of travel) and the widening of the pool when the head aims far
out to the sides: the beam travels further, so the pool is wider.

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

## What starts switched off

`GLOW` and `GLITCH` start at 0, and both are genuinely off rather than set to zero
intensity. Same for the mirror's `EFFECT` and for `RANDOMIZER`.

It is a stance: effects that make a statement are switched on when wanted, at the
chosen moment, rather than running in the background. A scene that starts sober
leaves room to build; a scene that starts saturated has nowhere to go.

## The glow

With a haze machine the beam is diffused **physically** in the air. Software glow
then does the same job twice: it softens the edges and takes the bite out of the
stroke. So it is 0 by default, and at 0 the post-process pass is genuinely off
(`glow_enabled = false`) rather than merely set to zero intensity.

Measured cost (RTX 3060, vsync off): **~0.30 ms per frame at 1080p**, ~0.68 ms at 4K.
In raw FPS that looks enormous (1884 → 1203 fps) but it is only 1.8 % of a frame's
budget at 60 Hz. It is not a performance problem, it is an aesthetic choice.

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
per frame with the glow on, because gradients compress badly). The window then looks
like it is struggling, and `Tween`-driven animations — the UI fade, for instance —
appear to stutter, when everything is perfectly steady in a normal run.

## Structure

```
tools/
  build_chataigne_module.py   Regenerates the Chataigne module from the settings
scenes/
  main.tscn      Main scene: WorldEnvironment + controller + UI
  laser.tscn     One stroke, instanced N times by the controller
chataigne/
  Deferlante/    Chataigne module, ready to install
web/
  index.html     Touch control surface, built from the schema Godot sends
shaders/
  kaleidoscope.gdshader   Polar fold into symmetrical wedges
scripts/
  gamepad.gd        Xbox pad: aims the spotlight, drives the rest through VJParam
  lang.gd           On-screen translations, keyed by OSC address
  kaleidoscope.gd   Drives the mirror's full-screen pass
  palette.gd        Colour state, shared by reference with the three effects
  vj_controller.gd  Settings declaration, lasers, OSC routing
  vj_param.gd       One setting: bounds, step, application, formatting
  control_panel.gd  Panel: rows, keyboard, auto-hide, FPS readout
  glitch_circle.gd  The followspot circle (a head that searches) + random glitches
  laser_line.gd     A stroke that spins and bounces off the edges
  osc_server.gd     OSC receiver (UDP), messages and bundles
  web_server.gd     Serves the page and the WebSocket control channel
  sphere_circles.gd Circles projected onto a virtual sphere
```

The UI is built at runtime from the list of settings: the scene holds nothing but an
empty `VBoxContainer`, not 32 pairs of nodes to maintain by hand.

A setting that only writes a property is declared in one line
(`_prop("spot/pulse", 0, 300, 5, 50.0, circle, "fluctuation_range")`); only those
needing logic get their own function. `VJParam` is the single point every change goes
through — slider, keyboard and OSC alike — which spares the rest of the code from
having to know where a change came from.

## Builds

Every push to `main` builds for **Linux, Windows and Android** on GitHub Actions and
uploads the three as artifacts. Pushing a tag like `v1.0` attaches them to a release.

One Linux runner covers all three: Godot cross-exports from a single headless binary,
so a matrix of operating systems would buy nothing.

Linux and Windows come out as **one self-contained file** each (`embed_pck=true`);
Android as an APK for `arm64-v8a`, which is every tablet made in the last decade.

`export_presets.cfg` is committed on purpose — CI cannot export without it. Its
export paths are relative (`build/linux/…`) so nothing machine-specific leaks. If you
export locally to somewhere else, change the path in the editor and take care not to
commit it back.

### Android specifics

The APK is signed with a **throwaway key generated during the build**. That is enough
to sideload onto a tablet and it keeps the build properly optimised — a release export
refuses to run without a release key, and falling back to a debug build would cost
performance where it is least affordable. It is *not* suitable for a store listing:
that needs a key you own, added as a repository secret.

Two things to expect on a tablet, neither of them tested on a device:

- **`GLOW` does nothing.** The mobile renderer is `gl_compatibility`, and 2D glow is
  not rendered there — the same limitation documented below for the desktop.
- The **web control surface and OSC still work** (`INTERNET` permission is set in the
  preset), so a tablet can run the visuals while a phone drives them.

### The one thing CI actually checks

Beyond "the export succeeded", the workflow launches the Linux build and fetches
`http://127.0.0.1:7331/`. The control page ships through the export *filter*, not
through the code, so it is the one piece that can silently go missing while every
build still passes. If the page is absent, or the built-in "Page missing" fallback
comes back instead, the build fails.

## A note on the renderer

The project uses **Forward+**. 2D glow is not rendered by the Compatibility renderer:
switching back to it would leave `GLOW` with no effect at all.

# Déferlante

[![Build](https://github.com/yo1frenchtoast/deferlante-vj/actions/workflows/build.yml/badge.svg)](https://github.com/yo1frenchtoast/deferlante-vj/actions/workflows/build.yml)

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

**Getting started** — [Run](#run) · [Launcher](#the-launcher) · [Drive it](#drive-it) · [Settings](#settings) · [Presets](#presets)
**External control** — [Sound](#audio-reactivity) · [Gamepad](#gamepad) · [Web surface](#web-control-surface) · [REST API](#rest-api) · [OSC](#external-control-over-osc) · [Audio reactivity](#audio-reactivity)
**The effects** — [Spotlight](#the-spotlight) · [Sphere](#the-sphere-effect) · [Kaleidoscope](#the-kaleidoscope) · [Chaos](#chaos) · [Auto-pilot](#the-auto-pilot) · [Colour](#the-two-colour-modes)
**In the room** — [What starts off](#what-starts-switched-off) · [Halo](#the-halo) · [Projection notes](#projection-notes) · [Performance](#measuring-performance-f3)
**The code** — [Structure](#structure) · [Builds](#builds) · [Renderer](#a-note-on-the-renderer)

The on-screen interface speaks French or English — picked at the [launcher](#the-launcher),
before the show. Everything else (code, OSC addresses, this document) stays in English.

## Run

Open the project in Godot 4.7+ and press F5. The main scene is `scenes/launcher.tscn`,
which asks a handful of questions and then hands over to `scenes/main.tscn`.

## The launcher

Almost everything in this project is adjustable live, on purpose: a setting you
cannot reach mid-set may as well not exist. The launcher holds the exceptions — the
handful of things the engine will not let you change once the show is running.

| | | |
| --- | --- | --- |
| `LANGUAGE` | FRANÇAIS / ENGLISH | First, because it decides what every other row says. |
| `RENDERER` | Compatibility / Forward+ | Compatibility is twice as fast; Forward+ is the only one that antialiases. **Restarts the app.** |
| `ANTIALIASING` | none / MSAA 2× 4× 8× | Forward+ only — the Compatibility renderer ignores 2D MSAA entirely. |
| `RESOLUTION` | the screen's own, or a fixed size | |
| `FULLSCREEN` | | `F11` still toggles it during the show. |
| `VSYNC` | | |
| `MAX FPS` | uncapped, or a refresh rate | Frames past the projector's refresh cost the same to draw and nobody sees them. |
| `AUDIO INPUT` | automatic, or a named source | Bound once and never re-opened. Greyed out where Godot ignores the choice, which is every PulseAudio build — see [audio reactivity](#audio-reactivity). |
| `PANEL` | hidden for the whole set | For a machine that only projects, driven from a phone. `F3` still works. |
| `WEB PORT` · `OSC PORT` | | Bound at start-up, so they cannot be moved later. |

Answers are kept in `user://launch.cfg`, so the screen opens on last night's and
`LANCER` is usually the only key. The `PANEL` and `LANGUAGE` rows used to be settings
on the desk; they are decisions about the room and about who is standing in front of
the machine, so they moved here — which also means `LANGUAGE` no longer has an OSC
address.

### Why the renderer restarts the app

Godot fixes the renderer before a single script runs, so it cannot be swapped in
place. Choosing the other one launches the process again with
`--rendering-method`, and the new one skips this screen. If that relaunch fails, the
show starts anyway on the renderer already running and says so in the console —
a black screen ten minutes before doors is worse than the wrong renderer.

### Skipping it

`-- --skip-launcher` goes straight to the show on the saved settings. The bare `--`
matters: Godot treats anything it does not recognise before that point as a fatal
argument error, and hands everything after it to the project.

A `--headless` run skips it too, without being asked — there is nobody there to
answer. That is what keeps [the CI check](#the-one-thing-ci-actually-checks) working.

## Drive it

The panel sits in the bottom-left corner, in one or more columns depending on how many
settings there are. The sliders **fade out on their own after 4 s of inactivity** (over 0.7 s) and come
back on any key press or mouse move. `H` pins them on screen while you dial things in.

| Key | Action |
| --- | --- |
| `↑` `↓` | Move between settings (the selected one is highlighted) |
| `←` `→` | Adjust — a fortieth of the range per press |
| `Shift` + `←` `→` | Fine adjust, one step at a time |
| `Space` | Fire a glitch immediately |
| `R` | Redraw every colour and trajectory |
| `1` – `9` | Recall a preset (also on the numeric keypad) |
| `Ctrl` + `1` – `9` | Store the current look into that slot |
| `H` | Pin / unpin the panel (stops it fading) |
| `F2` | Duck the panel down to discreet, and back |
| `F3` | FPS readout |
| `F11` | Fullscreen |
| `Esc` | Quit |

The mouse works on the sliders too, but the keyboard is safer live: no aiming in
the dark.

Under the sliders sits a status line — **the web address to type into a phone**, the
OSC port, and which pad is plugged in — followed by the shortcuts. The address is
something you look up rather than remember, so it belongs on screen and not only in
the console, where it scrolls away long before anyone needs it.

## Settings

The panel is arranged in six sections, the same as the Chataigne module's menus.
Labels below are the English ones.

### Global
| Setting | Range | Effect |
| --- | --- | --- |
| `SPEED` | -3 – 3 | Global speed. 1 is normal, 0 freezes, negative runs everything backwards. |
| `CHAOS` | 0 – 1 | Motion disorder. Does not touch `GLITCH`. See below. |
| `RANDOMIZER` | 0 – 1 | Auto-pilot. 0 is off, 1 is about one change per second. |
| `RECALL FADE` | 0 – 10 | Seconds a preset takes to crossfade in. 0 snaps. |
| `PANEL` | 0.05 – 1 | Panel brightness. `F2` toggles it. See below. |
| `AUTO DIM` | OFF / ON | Duck the panel automatically when something else takes over. |
| `GLOW` | 0 – 2 | Halo, drawn by the strokes themselves. **0 by default**, see below. |

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
| `COUNT` | 0 – 40 | Number of strokes. Added and removed live. Starts at 3. |
| `WIDTH` | 1 – 24 | Stroke width. |
| `LENGTH` | 0.1 – 2 | Scales the length (each stroke keeps its own). |
| `SPIN` | -1 – 1 | ← leftwards, → rightwards. |
| `PARALLEL` | 0 – 1 | 0 a scatter, 1 an evenly spaced fan. See below. |
| `SCROLL` | -1 – 1 | Walks that fan sideways. ← one way, → the other. |

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
| `SPREAD` | 0 – 1 | How much the pool grows when aiming off-centre. See below. |
| `GLITCH` | 0 – 0.05 | Glitch chance per frame. **0 by default.** Independent of `CHAOS`. 0.005 ≈ one every 3 s. |

### Audio
| Setting | Range | Effect |
| --- | --- | --- |
| `REACTIVITY` | 0 – 1 | Master amount. **0 by default** — nothing moves until asked. |
| `PUNCH` | 0 – 1 | Response curve. Higher pushes the middle down so only hits show. |
| `LASERS ← MID` | 0 – 6 | Mids drive the laser strokes. |
| `SPOT ← BASS` | 0 – 6 | The kick drives the spotlight. |
| `SPHERE ← TREBLE` | 0 – 6 | Treble drives the sphere. |

### Sphere
| Setting | Range | Effect |
| --- | --- | --- |
| `CIRCLES` | 0 – 80 | Number of circles. 0 switches the effect off. Starts at 14. |
| `SIZE` | 0.03 – 0.8 | Size of one circle, in radians on the sphere. |
| `RADIUS` | 100 – 800 | Sphere radius on screen. |
| `SPIN` | -1 – 1 | ← leftwards, → rightwards. |
| `DEPTH` | 1.2 – 10 | Eye distance. Small means strong perspective. |
| `WIDTH` | 1 – 24 | Circle stroke width. |
| `GLASS` | 0 – 1 | 0 an opaque sphere, 1 shows the far side through it. |

Adding a setting takes one line in `_build_params()` of `vj_controller.gd`: the
section, the UI row, the slider, the number formatting, the keyboard handling and
the OSC address all follow. Its label goes in `scripts/lang.gd`.

### Working discreetly

The panel is projected on the wall along with the visuals, so anything you do to it
is on show. `PANEL` turns its brightness down: at the default **1** it looks as it
always has, and `F2` ducks it to **0.15**, where it stays perfectly readable at
arm's length on the operator's screen while the room barely registers it through the
haze. The slider covers everything between if 0.15 is too far.

It is a preference, not part of a look, so it is left out of presets and out of the
auto-pilot's reach — recalling a preset will not light the panel back up on the wall
after you have deliberately dimmed it.

`H` and `F2` answer different problems and combine: `H` keeps the panel from fading
away while you work, `F2` makes that work invisible.

### Getting out of the way on its own

With `AUTO DIM` on — it is, by default — the panel ducks to discreet the moment
**anything else moves a setting**: the phone, the gamepad, OSC, an API call. Any
keypress takes the wheel back and restores the brightness you had chosen, not a
blanket 1: if you were working at 0.5, 0.5 is what returns.

While an external surface has control the panel also **stops accepting the mouse**.
That is the half that matters: dimming alone hides the sliders without making them
any harder to nudge by accident, and a stray brush on a projected panel is exactly
the accident worth designing out.

Moving the mouse does not end it — but **clicking does**, along with any keypress. A
brush of the trackpad is not a decision; a click is. That first click is swallowed
rather than passed on, so the gesture that takes the panel back cannot also move a
slider, the same way clicking an unfocused window activates it without pressing
whatever sits under the pointer.

The `PANEL` setting keeps reading the brightness *you* chose while this is going on:
the auto-dim is a temporary override, not a change to your preference.

## Presets

Nine slots hold a snapshot of every setting, saved to disk and recalled live.

| Where | Recall | Save |
| --- | --- | --- |
| Keyboard | `1` – `9`, or the numeric keypad | `Ctrl` + the same |
| Phone | tap a slot | hold it |
| OSC | `/deferlante/preset/recall` *(int)* | `/deferlante/preset/save` *(int)* |
| API | `POST /api/presets/{n}/recall` | `POST /api/presets/{n}/save` |
| Chataigne | `Presets › Recall Preset` | `Presets › Save Preset` |

### A recall is a crossfade

Every setting slides from where it is to where the preset wants it, over
`RECALL FADE` seconds. That is the difference between a preset being a scene change
and a preset being an edit: at 4 seconds the room moves from one look to another and
nobody sees a cut. Set it to **0** to snap, which is what you want for a stab.

The curve is a smoothstep, not linear — a linear crossfade starts and stops abruptly,
and on a slow move that beginning is exactly what gives it away.

The number keys are read by **physical position**, not by the character they type,
so the top row works the same on AZERTY, QWERTY or Dvorak. (Read as characters, an
AZERTY top row gives `& é " ' ( - è _ ç`, and only the three non-ASCII ones happened
to fall through to a digit — six slots out of nine were unreachable.)

### What is and is not saved

Every setting except `PANEL`, which is a preference rather than part of a look:
recalling a preset must not light the panel back up on the wall after the operator
has deliberately dimmed it.

A preset saved before a setting existed simply leaves that setting alone, so old
presets keep working after the project gains new ones.

Slots live in `user://presets.json` — on Linux,
`~/.local/share/godot/app_userdata/Déferlante/`. They belong to the machine, not to
the project, so they survive a rebuild and are not committed.

## Gamepad

An Xbox pad is picked up automatically when plugged in — nothing to configure. It is
the only surface that can **take the spotlight off auto-pilot and aim it by hand**.

| Control | Effect |
| --- | --- |
| **Left stick** | Walk the beam. A *rate*, not a position — see below. |
| **LT / RT** | Shrink / grow the pool. Analogue — a light squeeze creeps, a full pull sweeps. |
| **A** | Fire a glitch |
| **B** | Redraw colours (same as `R`) |
| **X** | Mirror fully on / off |
| **Y** | Glow on / off |
| **LB** *(hold)* | Freeze — everything stops while held |
| **RB** *(hold)* | Boost — 2.5× speed while held |
| **Right stick** ←→ | Laser spin |
| **Right stick** ↑↓ | Chaos |
| **D-pad** ↑↓ | Laser count |
| **D-pad** ←→ | Global speed, a quarter-step per tap |
| **Start** | Pin / unpin the panel |
| **Back** | Hand the spotlight back to auto now |

### It is a handle, not a pointer

The stick sets a **rate**: push and the beam travels, stop pushing and it stays exactly
where you stopped. That is how a real followspot works, and it is the only way to walk
a beam alongside someone crossing a stage — an absolute stick would snap the beam back
to centre the moment you let go, which is useless for following anyone.

The response is squared, so the same stick gives fine tracking near centre and fast
repositioning at the edge. `TRACKING` sets how fast the handle moves at full
deflection: too slow and you lose your actor, too fast and you cannot hold him.

Aiming works even at `SPEED` 0. Freezing the show must not take the handle out of the
operator's hands.

### Handing back, progressively

Stop pushing and the beam stays put for `HAND BACK` seconds — 30 by default, long on
purpose: an actor stops moving, the operator stops pushing, and the beam must not
wander off during the monologue.

After that the automatic sweep **fades back in over a few seconds** rather than
switching on. Under the hood the state machine never stopped: it kept picking targets
and sweeping the whole time, and what you see is a blend between where the operator
left the beam and where the machine wants it. The blend weight slides from 1 to 0, so
there is no moment where control visibly changes hands.

Grabbing the stick again takes over from wherever the beam currently is, never from
where it was last left — so it never teleports.

`AIMING` is the cursor: leave it on `AUTO` for the behaviour above, or set it to
`STICK` and the beam is yours until you say otherwise. `Back` forces the hand-back
without waiting out the delay, and it is still progressive — it does not cut.

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

It is built for **landscape**. A **preset bar** sits across the top, above the tabs
and visible from both pages — presets are what you reach for most in a set, so they
should never be a tab away. Empty slots are outlined in dashes, filled ones in solid
amber, and a slot saved from one phone lights up on every other one at once.

Below that, two pages.

**RÉGLAGES** — every setting as a touch slider, with each section a card. The cards
flow into as many columns as the screen can take: one on a phone held upright, three
or four across a tablet in landscape. Nothing is nested and nothing scrolls sideways.

**SURFACES** — the things you play rather than set, given the whole screen:

- **Two XY pads**, now full height instead of squeezed under the sliders. Their axes
  are assignable from dropdowns, each entry naming its section as well as the setting
  (`X · SPOTLIGHT WIDTH`) — three sections have a `WIDTH`, and on a pad you pick
  blind from a list rather than reading a labelled row. They default to chaos × speed
  and spotlight radius × pulse.
- **GLITCH** and **COLORS**.

Splitting them is the point: the pads need the whole screen to be playable and the
grid needs it to be readable, and neither works squeezed above the other.

**Live mirroring** applies across both: a value changed on the keyboard, over OSC, by
the auto-pilot or from the gamepad moves on the phone too, and vice versa.

The page **builds itself from a schema** Godot sends on connect. It holds no list of
settings of its own, so adding one in `_build_params()` makes it appear on the phone
with no change to the HTML. It arrives in whichever language the launcher was set
to.

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

Déferlante listens to **what is coming out of the machine**, not to a microphone, so
it follows the track being played rather than the room.

### Setting it up

```
tools/listen-to-output.sh          # start listening
tools/listen-to-output.sh --stop   # put everything back
```

**Run it before launching** — that part is not optional. Godot binds to whatever the
default source was when it started and never looks again: run the script afterwards
and the app stays deaf, with nothing on screen to say so. Stopping and restarting the
capture stream does not recover it either; measured, that leaves the analyser reading
exactly zero. If the levels are dead, restart Déferlante.

**Run it again after every reboot.** `pactl load-module` lasts as long as the sound
server does, and no longer. When it goes, the default source falls back to whatever
it was before — often a physical input with nothing plugged into it, which reads as
perfect silence rather than as an error. Everything looks healthy: the app says it is
capturing, the bars simply never move. This is the single most likely reason for
"the sound stopped working".

It taps the output; it does not reroute it, so playback is untouched.

If your sound arrives through an interface instead — a Focusrite, a desk — you do
not need the script at all: that is already an input, and Déferlante reads the
default one.

### Why a script is needed at all

Godot captures an *input*, and music is an *output*. PipeWire does publish the
output's monitor as a source, but **Godot's PulseAudio backend filters monitors out
of its device list**, so it cannot be picked from inside the app.

Worse, `AudioServer.input_device` does not hold in this build: assigned during
`_ready` it reads back `"Default"`, one frame later it reads back empty, and the
capture follows neither. So the script wraps the monitor in an ordinary source *and
makes it the default* — pointing Godot at it by giving it no choice. `--stop`
restores the source you had.

Measured again since, and precisely. `AudioServer.get_input_device_list()` does
enumerate properly — every source on the machine, monitors excepted. It is the
*setter* that goes nowhere: pointed at a source measured at a peak of exactly zero,
Godot still read the music off the system default, at -55 dB, with a second and a
half to settle in between. The assignment reads back empty, then `"Default"`.

So the launcher's `AUDIO INPUT` row lists the real sources but is greyed out, with
the reason on screen. It is not hardcoded to Linux: the launcher assigns a device,
reads it back and disables the row only if it did not stick, which is safe there
because no capture is open yet. Same story for `preferred_device` in
`audio_reactor.gd` — best-effort, not the mechanism.

⚠️ Audio cannot be measured under `--headless`: that mode loads the dummy audio
driver, where the device list really *is* `["Default"]` and every band reads `-inf`.
Both look exactly like a broken capture. Any audio check has to run windowed, and
not under `--write-movie` either, which takes the audio driver over to write its
`.wav`.

### What the sound drives

Three bands, one per effect: **the kick drives the spotlight**, mids drive the
lasers, treble the sphere. Three effects breathing on one envelope read as a single
thing pumping; on separate bands they pick out different parts of the track and the
picture comes apart into layers. The kick goes to the spotlight because it is the
biggest shape on screen, so it is what carries the beat.

Each amount moves both the **thickness and the size** of its effect — the stroke
width, and the spotlight's radius, the sphere's circle size, the lasers' length.
Thickness alone tops out quickly: a stroke twice as wide is still the same shape in
the same place, while a spotlight that swells on the kick changes the whole picture.
Size moves at a third of the amount, since a radius reads far more strongly than a
width. Measured at the default 1.5: laser strokes 6.1–10.6 px, spotlight radius
208–274 px, spotlight stroke 3.4–6.4 px.

The sound **adds to** the widths rather than setting them. The sliders keep meaning
what they say, turning `REACTIVITY` back to 0 restores exactly the look that was
there, and nothing the sound does is written to a setting — so it never lands in a
preset and never fights you for a slider.

### Levels, not volume

Everything is done in decibels, against a **running peak** per band rather than a
fixed gain. A fixed gain that suits one track sits flat or clips on the next; and
normalising the compressed 0–1 value instead of the decibels pinned bass and mid at
0.99 on real music, which looks like a constant rather than a pulse.

The three bands live at completely different levels. Measured on a techno set: bass
around −35 dB, hi-hats between −60 and −100. So there is no shared floor — each band
scales against its own peak, and only an absolute silence gate stops room noise being
amplified when nothing is playing. An earlier floor tight enough to gate a quiet room
flattened the treble into a dead constant.

Each band is read at its **loudest point** rather than averaged. Averaging a narrow
tone across a wide band divides it by the silence either side: a 6 kHz tone read as
nothing at all in a 2–12 kHz band until that changed.

**Both ends of the scale follow the music**, not just the top. Tracking only the peak
and sitting a fixed number of decibels below it is adaptive on paper and a constant in
practice: a track with six decibels of movement spends all its time at the top of the
range. The reference is a running average over a few bars, so the ordinary level of
the track maps to zero and only what rises above it shows.

Two things had to be right for that to work. The scale is primed on the first frame
that actually carries sound — primed on the first frame at all, it starts at −130 dB
and crawls upwards for a minute while every band reads 0.95. And the response curve is
applied on the way out, never written back into the smoothed state, where it compounds
frame after frame and collapses every band to zero within a second.

`PUNCH` is the taste control on top. Adaptive scaling gets the *range* right, but how
much of a busy track should read as "pulsing" rather than "loud" is a judgement.
Measured on a techno set: at 0 the bass swings 0.39–0.87, at 0.5 it swings 0.12–0.40.

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

## Structure

```
tools/
  build_chataigne_module.py   Regenerates the Chataigne module from the settings
scenes/
  launcher.tscn  Start-up settings, then hands over to main.tscn
  main.tscn      The show: WorldEnvironment + controller + UI
  laser.tscn     One stroke, instanced N times by the controller
chataigne/
  Deferlante/    Chataigne module, ready to install
web/
  index.html     Touch control surface, built from the schema Godot sends
shaders/
  kaleidoscope.gdshader   Polar fold into symmetrical wedges
scripts/
  launcher.gd       The start-up screen, and the relaunch that changes renderer
  launch_config.gd  The `Launch` autoload: user://launch.cfg, read by whoever needs it
  gamepad.gd        Xbox pad: aims the spotlight, drives the rest through VJParam
  lang.gd           On-screen translations, keyed by OSC address
  kaleidoscope.gd   Drives the mirror's full-screen pass
  palette.gd        Colour state, shared by reference with the three effects
  vj_controller.gd  Settings declaration, lasers, OSC routing
  vj_param.gd       One setting: bounds, step, application, formatting
  control_panel.gd  Panel: rows, keyboard, auto-hide, FPS readout
  glitch_circle.gd  The followspot circle (a head that searches) + random glitches
  laser_line.gd     A stroke that spins and bounces off the edges
  halo.gd           The wide additive echoes that stand in for the glow
  osc_server.gd     OSC receiver (UDP), messages and bundles
  web_server.gd     Serves the page and the WebSocket control channel
  rest_api.gd       The /api endpoints and the OpenAPI document
  sphere_circles.gd Circles projected onto a virtual sphere
  presets.gd        Nine slots on disk, recalled as a crossfade
  audio_reactor.gd  Captures the output, reads bass / mid / treble
  autopilot.gd      Moves settings on its own, at the pace you set
```

The controller is the only script that knows the others exist. `rest_api.gd`,
`autopilot.gd` and `presets.gd` are handed the few callables they need — find a
setting, list them all — and are otherwise self-contained, which is what keeps the
controller about running a show rather than about serving JSON.

The UI is built at runtime from the list of settings: the scene holds nothing but an
empty `VBoxContainer`, not 35 pairs of nodes to maintain by hand.

It also **lays itself out in as many columns as it takes to fit the screen**, breaking
only between sections so a section is never split in two, and balancing the columns
rather than filling the first to the brim. The panel had been growing by one row per
setting and had just started running off the bottom of a 1080p screen; this way it
cannot, however many settings get added.

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

One thing to expect on a tablet, not tested on a device: the **web control surface
and OSC still work** (`INTERNET` permission is set in the preset), so a tablet can
run the visuals while a phone drives them.

`GLOW` used to be listed here as doing nothing on a tablet, because the mobile
renderer draws no 2D glow. It works now — the halo is ordinary geometry, and the
desktop runs the same renderer as the tablet.

### The one thing CI actually checks

Beyond "the export succeeded", the workflow launches the Linux build and fetches
`http://127.0.0.1:7331/`. The control page ships through the export *filter*, not
through the code, so it is the one piece that can silently go missing while every
build still passes. If the page is absent, or the built-in "Page missing" fallback
comes back instead, the build fails.

## A note on the renderer

The project ships **Compatibility** (`gl_compatibility`) and offers Forward+ at the
[launcher](#the-launcher). It is a per-machine decision, not a project-wide one: the
laptop with a graphics card and the one without want different answers.

It used to be Forward+ for everyone, for one reason: 2D glow is not drawn by the
Compatibility renderer. That was worth it for as long as the show only ever ran on a
machine with a GPU. It stopped being worth it the day it had to run on one without.

Measured on llvmpipe at 1080p — a GPU-less machine, in other words — same project,
same show:

| | Forward+ | Compatibility |
| --- | --- | --- |
| at launch | 9.1 ms · 110 fps | **6.8 ms · 147 fps** |
| a busy show, halo off | 13.3 ms · 75 fps | **7.3 ms · 136 fps** |

A factor of two, for a project that draws nothing but lines. Forward+ is a clustered
renderer built for 3D lighting; none of that is ever asked of it here, and it charges
for the pipeline regardless. The one thing it did give — 2D glow — now comes from
`scripts/halo.gd` instead, cheaper and on every platform.

Everything else survives the switch unchanged; the kaleidoscope's screen texture was
the one thing worth checking and it folds identically.

### Antialiasing

There is no cheap antialiasing here, and it is worth writing down exactly how that
was established, because two of the options *look* free and are free only because
they do nothing at all.

Each was measured against the same seeded frame, so the comparison is the same image
with and without — comparing two random frames is what made MSAA look like it was
working when it was not.

| | cost, busy show at 1080p in software | what it actually changes |
| --- | --- | --- |
| nothing | 10.3 ms · 97 fps | — |
| `Line2D.antialiased` | free | **0.00 % of pixels** — a no-op under Compatibility |
| MSAA 2D under Compatibility | free | **0.00 % of pixels** — not applied either |
| a permanent faint outline on every stroke | +1.2 ms | staircase unchanged, merely brighter |
| Forward+ with MSAA 2× | 20.0 ms · 50 fps | softened |
| Forward+ with MSAA 4× | 24.0 ms · 42 fps | softened, not removed |
| rendering at 2× and downscaling | 23.3 ms · 43 fps | the cleanest of the lot |

So antialiasing costs somewhere between two and two-and-a-half times the whole
frame budget — exactly what the switch to Compatibility had just won back. On a
machine with a GPU it costs nothing worth counting, which is why the choice belongs
at the launcher rather than in this file.

Note that even MSAA 4× only *softens* the staircase. The strokes are long shallow
diagonals, where a single step spans several pixels; no amount of edge sampling
turns that into a smooth line.

### What is *not* worth optimising

Measured on the same setup, so nobody repeats the search:

- **Geometry is free.** Going from 3 strokes to 20, or from 14 circles on the sphere
  to 40, costs **nothing measurable** in software rendering. Rebuilding the `Line2D`
  point arrays wholesale instead of point by point — the obvious first instinct —
  buys nothing, because that was never where the time went.
- **No script is hot.** Audio analysis, the web server, OSC, the settings panel and
  the gamepad were each disabled in turn: not one of them moved the frame time.
- **Resolution barely matters.** 720p instead of 1080p saved 0.5 ms. The cost is not
  fill rate.
- **Dropping the `WorldEnvironment` makes it *slower*** (8.7 ms against 7.3 ms),
  which is the opposite of what you would expect. It stays.

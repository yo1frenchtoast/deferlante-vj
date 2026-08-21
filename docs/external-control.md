# External control

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

Godot serves a control page on port **7331**, and out of the box it serves it to
**this machine only** — `http://127.0.0.1:7331`. Nothing on this surface asks for a
password, and neither does the API behind it: anyone who can reach the port can drive
the show. On a venue's wifi that is not a footnote, so the room is let in on purpose
rather than by default.

To drive it from a phone, pick one of the machine's own addresses in the launcher's
`WEB ACCESS` row. The surface then answers on that address — printed at startup, and
shown in the panel's status line — and on that one alone: choosing a network address
means `127.0.0.1` stops working on the machine itself. An address that has since gone
(DHCP hands out a new one often enough) falls back to this machine rather than failing
to bind and leaving the surface silently off; the launcher says so when it reopens.

It is built for **landscape**. A **preset bar** sits across the top, above the tabs
and visible from both pages — presets are what you reach for most in a set, so they
should never be a tab away. Empty slots are outlined in dashes, filled ones in solid
amber, and a slot saved from one phone lights up on every other one at once.

Below that, three pages.

**RÉGLAGES** — every setting as a touch slider, with each section a card. The cards
flow into as many columns as the screen can take: one on a phone held upright, three
or four across a tablet in landscape. Nothing is nested and nothing scrolls sideways.

The cards can be **reordered**: drag one by its title — the amber heading is the
handle, since everything below it is a slider and a card that moved when you grabbed
a fader would be unusable. The order is kept in that browser and reapplied on every
connect, so the phone taped to the desk and the tablet in your hand can be laid out
differently for the same show. Godot is never told; this is a property of the surface
you happen to be holding, not of the show. A section added to Godot after an order
was saved lands at the end rather than disappearing. `ordre par défaut` appears under
the grid once anything has been moved, and puts Godot's own order back.

**SURFACES** — the things you play rather than set, given the whole screen:

- **Two XY pads**, now full height instead of squeezed under the sliders. Their axes
  are assignable from dropdowns, each entry naming its section as well as the setting
  (`X · SPOTLIGHT WIDTH`) — three sections have a `WIDTH`, and on a pad you pick
  blind from a list rather than reading a labelled row. They default to chaos × speed
  and spotlight radius × pulse.
- **GLITCH** and **COLORS**.

**DÉMARRAGE** — the launcher's own rows, offered from wherever the phone is. The
machine running the show is usually the one nobody can reach: projecting from a
shelf, or an Android box with a remote and no keyboard. Yet every one of these has to
be answered *before* the show starts, which is precisely when nobody is standing at
it.

Renderer, antialiasing, resolution, fullscreen, vsync, max FPS, the panel, both
access rows, both ports and the language — each saved to `launch.cfg` the moment it
is touched, so a restart by any route comes up on what was asked for. The audio rows
are deliberately absent: which output the show listens to is bound when capture opens
and cannot be moved afterwards, and answering it honestly needs a live meter and a
subprocess per candidate. That question stays in the launcher.

None of it touches the running show — Godot fixes the renderer before a script runs
and binds the ports before anything can listen, which is the whole reason these are
start-up settings. **REDÉMARRER** at the bottom starts the process again on them,
going straight to the show rather than back through the launcher. It arms on the
first press and fires on the second, because it ends the show for a few seconds and a
thumb brushing past it mid-set would be unforgivable.

Two of those rows can cut the page off from the show it is driving — the web access
and the web port — and the surface says so above the button rather than letting you
find out.

**On Android there is no button**, and the tab says why instead. `OS.create_process`
there is not a second process at all: it is the activity being told to restart
itself, and the engine tears the fragment down while the GL thread is still stepping
it. The SIGSEGV that follows kills the app before Android can bring it back, so the
show does not restart — it vanishes, and somebody walks to the projector. Measured
across repeated presses, with and without quitting afterwards and with the render
loop stopped first: the crash lands in `GodotLib_step` every time and a clean
restart is a coin toss. It is a bug below this project, so the surface refuses
rather than gambles. The settings are still saved; the app has to be started again
by hand for them to take. That is one walk, against the alternative of an empty
screen mid-set.

Splitting the pages is the point: the pads need the whole screen to be playable, the
grid needs it to be readable, and the start-up rows are read and considered rather
than played with. None of the three works squeezed above the others.

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

| Address | What it serves |
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
curl -X PUT http://192.168.1.20:7331/api/params/global/chaos \
     -H 'Content-Type: application/json' -d '{"value": 0.8}'

curl -X POST http://192.168.1.20:7331/api/actions/glitch
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

Godot listens for OSC on port **9000** (UDP), and — like the web surface — on **this
machine only** until told otherwise. OSC carries no credentials of any kind: a message
that reaches the port is obeyed. A console on another machine is let in through the
launcher's `OSC ACCESS` row, which offers the same list of addresses as `WEB ACCESS`
and is answered separately: a phone driving the surface and a desk sending OSC are
rarely the same machine, and letting one in is no reason to let the other. Every
setting can be driven remotely from Chataigne, TouchOSC, a sequencer, or any script
at all.

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

Pick it on the launcher, under **`SON ÉCOUTÉ` / `SOUND LISTENED TO`**. The default —
*the output playing at launch* — is right on a machine with one sound card and stays
right when that changes.

The row asks one question at two depths. **Listen to an output** and the show taps its
monitor: the ordinary answer, and the one that needs nothing arranged beforehand.
**Capture an input** and it taps nothing at all, it listens where it is told — which is
what you want the moment something else on the machine insists on standing in the
middle. `easyeffects_source` appears in that half, and naming it makes EasyEffects a
link in the chain rather than a thing to be fought.

Under the row is a **meter**, live, showing what the line you have selected is
actually carrying — and saying `rien n'entre` when the answer is nothing. Every wrong
answer used to look exactly like every right one until the show was running; this is
the difference.

That is all. The show taps the chosen output's monitor and points the machine's
capture at it, **on every launch**, including the launches that walk straight past
the launcher with `--skip-launcher`. Re-doing it every time is the point: the tap
outlives nothing in particular, and a tap left on last night's interface is the most
likely reason for "the sound stopped working".

It taps the output; it does not reroute it, so playback is untouched.

The old script still exists and does the same thing from a terminal, which is what
you want when the show is not the thing being launched:

```
tools/listen-to-output.sh          # start listening
tools/listen-to-output.sh --stop   # put the machine's capture back the way it was
```

`--stop` is the undo for both — the launcher notes the previous default source in the
same place the script does. Nothing puts it back on its own: a routing that
half-restores after a crash is worse than one that stays put.

If your sound arrives through an interface instead — a Focusrite, a desk — none of
this is needed: that is already an input, and Déferlante reads the default one.

### Telling whether it hears anything

Three states that used to look alike on flat bars, and the status line now says which:

| on screen | meaning |
| --- | --- |
| `son  pas de capture` | no analyser at all — the capture never opened |
| `son  silence — rien n'entre` | open, and carrying nothing for ten seconds straight |
| `son ▁▂▃ 0%` | hearing it perfectly well; `REACTIVITY` is simply at zero |

Ten seconds is longer than any gap in a set and shorter than the time it takes to
start wondering. The web surface shows the same three states in its vu-mètre. The
middle row is also what triggers the diagnosis below.

### When something else is listening first

A sound server is free to put a recording stream wherever its own policy says, and
some do. Measured on the machine this was written on: **EasyEffects in service mode
pulls every capture onto its own source**, `parecord` included, and undoes a
`pactl move-source-output` within the second. Nothing the show does at the Pulse
level survives that.

It is not necessarily a fault. EasyEffects also latched onto the tap itself and
passed the music through — the show heard everything, one link further down the
chain than it thought. It only breaks when EasyEffects is pointed somewhere else,
typically the built-in microphone after the default source moved, and then the show
reads a silent room while the music plays.

So the show does not fight it, it reports it. When every band has been flat for ten
seconds, `audio_reactor.gd` asks whether anything is reading the tap at all, and if
nothing is, says so by name in the log. That turns the failure with no symptom into
one line naming the likely culprit.

Two ways round it. Name its source in the launcher's audio row, which accepts the
interception and listens one link further down — its meter will tell you at once
whether that link carries anything. Or quit it before the show,
`flatpak kill com.github.wwmm.easyeffects`, which is the only arrangement measured
end to end here. Its input blocklist was tried and did not take.

### Windows

There is nothing to route: Windows has no monitor to wrap. What the launcher offers
there is the old `AUDIO INPUT` row — Godot's own input list, which the WASAPI backend
does honour, unlike PulseAudio — and what has to exist first is an input carrying the
output. Two ways, both outside this project:

- **Stereo Mix**, if the chipset's driver still exposes it. Enable it in the sound
  control panel, then pick it in the row.
- **A virtual cable** — VB-Audio Cable, VoiceMeeter — which appears as an ordinary
  input device and is the answer when Stereo Mix is not offered.

Not measured: written from how the pieces are documented to behave, with no Windows
machine to check it on. The launcher probes rather than assumes — it assigns a
device, reads it back, and greys the row out if it did not stick — so a build that
turns out not to honour the choice says so on screen instead of pretending.

### Android

The system's own output cannot be captured. Android puts that behind `MediaProjection`
and `AudioPlaybackCapture`, which needs consent per session, which any app playing
audio is allowed to refuse, and which Godot exposes no binding for. There is no
version of the Linux trick that works here.

What does work is the **microphone**, and in a room it is not the poor relation it
sounds like: a phone on a table hears the PA perfectly well, and a phone is a
secondary screen at best anyway.

That needs two things, both now in place: `RECORD_AUDIO` in the export preset, and
the runtime grant, which `audio_reactor.gd` asks for before it opens the capture. The
manifest entry alone is not enough — without the grant the stream opens quite happily
and carries nothing, which is the failure this whole page keeps circling. Untested on
a phone.

### Why it has to go round the outside

Godot captures an *input*, and music is an *output*. PipeWire does publish the
output's monitor as a source, but **Godot's PulseAudio backend filters monitors out
of its device list**, so it cannot be picked from inside the app.

Worse, `AudioServer.input_device` does not hold in this build: assigned during
`_ready` it reads back `"Default"`, one frame later it reads back empty, and the
capture follows neither. So the monitor is wrapped in an ordinary source *and made
the default* — pointing Godot at it by giving it no choice. `AudioRouting` does that
through `pactl`, and `tools/listen-to-output.sh --stop` restores the source you had.

Measured again since, and precisely. `AudioServer.get_input_device_list()` does
enumerate properly — every source on the machine, monitors excepted. It is the
*setter* that goes nowhere: pointed at a source measured at a peak of exactly zero,
Godot still read the music off the system default, at -55 dB, with a second and a
half to settle in between. The assignment reads back empty, then `"Default"`.

So on Linux the launcher stops offering inputs and offers outputs instead, and the
old `AUDIO INPUT` row survives only for the platforms where picking an input is the
answer. Which row appears is probed, not hardcoded: `pactl info` decides the first,
and for the second the launcher assigns a device, reads it back and disables the row
if it did not stick — safe there because no capture is open yet. Same story for
`preferred_device` in `audio_reactor.gd` — best-effort, not the mechanism.

The meter does not use the engine to listen, and cannot. Godot binds a capture to the
default source when the stream opens and never looks again; freeing the player and
making another changes nothing, and `AudioServer.input_device`, which does force the
driver to reopen its input, kills the capture outright — measured, the first reading
comes through at 0.68 with music playing and every reopening after it reads 0.000 with
`pa_stream_disconnect: Bad state`. So `audio_probe.gd` shells out to `parecord` and
reads the tail of the raw file it writes. What that measures is what a recording client
on this machine actually receives, policy and all — which is the point, and the reason
it is trustworthy about the EasyEffects case.

One trap for anyone adding to `AudioRouting`: what it hands to `sh -c` is parsed
twice. Measured, `awk '$2 == "x"'` arrives at awk as `awk == x`, quotes stripped and
fields expanded away to nothing. Every listing is therefore fetched whole and picked
apart in GDScript, and the shell lines carry no quotes, no `$` and no pipelines that
need either.

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

### How nervous it is

Sharpened deliberately, and every step of it measured off the app's own level
broadcast — mean level, peak, and the average change from one packet to the next,
which is the number that says "nervous".

- **`release` 0.9 → 0.3 s.** This is where the nervousness comes from. A long decay
  is still coming down when the next kick lands, so hits merge into a swell; a short
  one separates them. On its own it took the average change per sample from 0.021 to
  0.044 on the bass and from 0.073 to 0.174 on the treble. `attack` went 0.06 → 0.03
  to match.
- **`min_range_db` 9 → 5 dB.** The bigger surprise, and the one that fixed the kick.
  This is the ceiling on the automatic gain: a band whose loud and quiet moments sit
  closer together than this is divided by a range it never uses. A bass line is
  nearly continuous, so it lived entirely inside the old floor and topped out around
  **0.45** — the spotlight it drives barely moved, on the *original* settings. At
  5 dB the same passage reaches 0.99, and spends 22 % of its time low instead of
  63 %. 3 dB was measured too and adds almost nothing (1.00 against 0.99) while
  expanding more of whatever hum is in the room, so 5 it is.
- **The two changes that did not survive measurement.** Shortening `average_window`
  to 2 s, on the theory that a reference following the track more closely would show
  more, showed *less* — a reference that chases the signal rises to meet it and
  flattens what it was meant to reveal. And `PUNCH` at 0.5 compounded with the
  shorter decay: the bass fell to 0.09 with 89 % of its time on the floor, so the
  kick stopped registering entirely. Both were put back.

End to end, all three bands now reach full scale and move three to five times as
much per sample as they did.
Measured on a techno set: at 0 the bass swings 0.39–0.87, at 0.5 it swings 0.12–0.40.

# External control

## Gamepad

The show finds an Xbox pad automatically when you connect it. There is nothing to
configure. It is the only surface that can **take the spotlight off auto-pilot and aim
it by hand**.

| Control | Effect |
| --- | --- |
| **Left stick** | Walk the beam. It is a *rate*, not a position. |
| **LT / RT** | Shrink or grow the pool. It is analog: a light squeeze creeps, a full pull sweeps. |
| **A** | Fire a glitch |
| **B** | Redraw colors (the same as `R`) |
| **X** | Mirror fully on or off |
| **Y** | Glow on or off |
| **LB** *(hold)* | Freeze — everything stops while you hold it |
| **RB** *(hold)* | Boost — 2.5× speed while you hold it |
| **Right stick** ←→ | Laser spin |
| **Right stick** ↑↓ | Chaos |
| **D-pad** ↑↓ | Laser count |
| **D-pad** ←→ | Global speed, a quarter-step per tap |
| **Start** | Pin or unpin the panel |
| **Back** | Hand the spotlight back to auto now |

### It is a handle, not a pointer

The stick sets a **rate**. Push it and the beam travels. Stop the push and the beam
stays exactly where you stopped it. That is how a real followspot works, and it is the
only way to walk a beam beside somebody who crosses a stage. An absolute stick would
snap the beam back to center the moment that you let go, which is of no use for a
follow.

The response is squared, thus the same stick gives fine tracking near center and fast
repositioning at the edge. `TRACKING` sets how fast the handle moves at full
deflection. Too slow and you lose your actor. Too fast and you cannot hold them.

Aiming works even at `SPEED` 0. A freeze of the show must not take the handle out of
the hands of the operator.

### Handing back, progressively

Stop the push and the beam stays put for `HAND BACK` seconds. It is 30 by default, and
long on purpose: an actor stops moving, the operator stops pushing, and the beam must
not wander off during the monologue.

After that, the automatic sweep **fades back in across a few seconds** rather than
switches on. Internally the state machine never stopped. It kept picking targets and
sweeping the whole time. What you see is a blend between where the operator left the
beam and where the machine wants it. The blend weight slides from 1 to 0, thus there is
no moment where control visibly changes hands.

If you take the stick again, control starts from where the beam is at that moment,
never from where you last left it. Thus it never teleports.

`AIMING` is the cursor. Leave it on `AUTO` for the behavior above, or set it to
`STICK` and the beam is yours until you say otherwise. `Back` forces the hand-back
without the delay, and it is still progressive: it does not cut.

### Why the shoulders are momentary

`LB` and `RB` are held, not latched. In a set you lean on a button for four bars and
you want it to let go by itself. A latch is one more thing to remember to undo. Both
remember the speed that you were at and put it back on release. Thus you can use them
over any tempo, and not only from 1.0.

### Two deliberate choices

**The pad does not wake the on-screen panel**, unlike the keyboard. It is a
performance surface like OSC. If it did, a stick held for a whole track would leave
the sliders on screen, and projected on the wall. `Start` shows them when you want
them.

**Everything except the aim goes through `VJParam.set_value()`**, the same entry point
as the sliders, OSC and the web page. Squeeze a trigger and the radius moves on the
panel, on every connected phone, and in any console that reads back over the API.

## Web control surface

Godot serves a control page on port **7331**, and by default it serves it to **this
machine only** — `http://127.0.0.1:7331`. Nothing on this surface asks for a password,
and neither does the API behind it. Anybody who can reach the port can drive the show.
On the wifi of a venue that is not a footnote, thus you let the room in on purpose
rather than by default.

To drive it from a phone, pick one of the addresses of the machine in the `WEB ACCESS`
row of the launcher. The surface then answers on that address, and on that one alone.
The show prints it at start-up and shows it in the status line of the panel. A choice
of a network address means that `127.0.0.1` stops working on the machine itself. An
address that has since gone (DHCP hands out a new one often enough) falls back to this
machine. It does not fail to bind and leave the surface silently off. The launcher says
so when it opens again.

The page is built for **landscape**. A **preset bar** sits across the top, above the
tabs and visible from both pages. Presets are what you reach for most in a set, thus
they must never be a tab away. Empty slots are outlined in dashes and filled ones in
solid amber. A slot saved from one phone lights up on every other one at once.

Below that are three pages.

**RÉGLAGES** — every setting as a touch slider, with each section as a card. The cards
flow into as many columns as the screen can take: one on a phone held upright, three
or four across a tablet in landscape. Nothing is nested and nothing scrolls sideways.

Most cards carry a small **roll button** in their title bar, which re-rolls that
section alone. The lasers take a new shape while the spotlight carries on with what it
was asked to do. It is the same move that the auto-pilot makes on its own, but aimed.
The strips at the top of RÉGLAGES and SURFACES hold the whole-show version beside
GLITCH and the colors.

A section that the auto-pilot is not allowed to touch gets no button, rather than one
that does nothing. Today that means COULEUR, whose five settings are all decisions
about the room rather than variations to play with.

You can **reorder the cards**. Drag one by its title. The amber heading is the handle.
Everything below it is a slider, and a card that moved when you grabbed a fader would
be unusable. The browser keeps the order and applies it on every connect. Thus the
phone taped to the desk and the tablet in your hand can be laid out differently for the
same show. Godot is never told. This is a property of the surface that you hold, not of
the show. A section added to Godot after an order was saved lands at the end rather
than disappears. Once anything has moved, `ordre par défaut` appears under the grid,
and it puts the order of Godot back.

**SURFACES** — the things that you play rather than set, given the whole screen:

- **Two XY pads**, now full height instead of squeezed under the sliders. You assign
  their axes from dropdowns. Each entry names its section as well as the setting
  (`X · SPOTLIGHT WIDTH`). Four sections have a `WIDTH`, and on a pad you pick blind
  from a list rather than read a labeled row. They default to chaos × speed and to
  spotlight radius × pulse.
- **GLITCH** and **COLORS**.

**DÉMARRAGE** — the rows of the launcher, offered from wherever the phone is. The
machine that runs the show is usually the one that nobody can reach: it projects from
a shelf, or it is an Android box with a remote and no keyboard. Yet every one of these
rows has to be answered *before* the show starts, which is precisely when nobody
stands at it.

The tab offers the renderer, antialiasing, resolution, fullscreen, vsync, max FPS, the
panel, the preset to start on, both access rows, both ports and the language. The list
of slots is read from the show rather than from disk, thus a slot saved from a phone a
moment ago can be chosen without a restart. It saves each one to
`launch.cfg` the moment that you touch it, thus a restart by any route comes up on
what you asked for. The audio rows are deliberately absent. Which output the show
listens to is bound when capture opens, and cannot be moved afterwards. An honest
answer also needs a live meter and a subprocess per candidate. That question stays in
the launcher.

None of it touches the running show. Godot fixes the renderer before a script runs and
binds the ports before anything can listen. That is the whole reason that these are
start-up settings. **REDÉMARRER** at the bottom starts the process again on them, and
goes directly to the show rather than back through the launcher. It arms on the first
press and fires on the second. It ends the show for a few seconds, and a thumb that
brushes past it in the middle of a set would be unforgivable.

Two of those rows can cut the page off from the show that it drives — the web access
and the web port. The surface says so above the button rather than lets you find out.

**On Android there is no button**, and the tab says why instead. `OS.create_process`
there is not a second process at all. It is the activity told to restart itself, and
the engine tears the fragment down while the GL thread still steps it. The SIGSEGV
that follows kills the app before Android can bring it back. Thus the show does not
restart, it disappears, and somebody walks to the projector. Measured across repeated
presses, with and without a quit afterwards and with the render loop stopped first:
the crash lands in `GodotLib_step` every time, and a clean restart is a coin toss. It
is a fault below this project, thus the surface refuses rather than gambles. The
settings are still saved. Somebody has to start the app again by hand for them to
take. That is one walk, against the alternative of an empty screen in the middle of a
set.

The split into pages is the point. The pads need the whole screen to be playable, and
the grid needs it to be readable. You read and consider the start-up rows rather than
play with them. None of the three works squeezed above the others.

**Live mirroring** applies across both. A value changed on the keyboard, over OSC, by
the auto-pilot or from the gamepad moves on the phone too, and the other way round.

The page **builds itself from a schema** that Godot sends on connect. It holds no list
of settings of its own, thus a new setting in `_build_params()` appears on the phone
with no change to the HTML. It arrives in whichever language the launcher was set to.

Two ports rather than one, deliberately: HTTP carries the page on 7331 and a WebSocket
carries the control channel on **7332**. `WebSocketPeer.accept_stream()` does the
handshake itself and needs the stream untouched. That rules out a read of the request
first to tell an upgrade from a page request.

A phone that sleeps drops the socket. The page connects again on its own without a
reload.

⚠️ CAUTION: There is **no authentication**. Anybody on the network can drive the
visuals. That is acceptable on a private Wi-Fi and a bad idea on a public one.

## REST API

The same HTTP server that carries the control page also exposes the settings as a REST
API, described by an OpenAPI 3.0 specification.

| Address | What it serves |
| --- | --- |
| `http://<machine-ip>:7331/docs` | Swagger UI, with *Try it out* wired up |
| `http://<machine-ip>:7331/openapi.json` | the specification itself |

| Endpoint | |
| --- | --- |
| `GET /api/params` | every setting, with bounds and current values |
| `GET /api/params/{section}/{setting}` | one setting, for example `/api/params/spot/hold` |
| `PUT /api/params/{section}/{setting}` | body `{"value": 2.5}` |
| `POST /api/actions/glitch` | fire one glitch |
| `POST /api/actions/randomize` | redraw colors and trajectories |
| `POST /api/actions/shuffle` | one move of the auto-pilot, now |
| `POST /api/actions/shuffle:<section>` | the same, confined to one section |

A `PUT` goes through `VJParam.set_value()` like everything else. Thus the show clamps
and snaps the value, the on-screen panel follows, and every connected phone follows
too. A `999` sent to a setting bounded at 3 returns `3` rather than an error. The
response body is always the setting as it ended up.

```
curl -X PUT http://192.168.1.20:7331/api/params/global/chaos \
     -H 'Content-Type: application/json' -d '{"value": 0.8}'

curl -X POST http://192.168.1.20:7331/api/actions/glitch
```

**The show generates the specification from the settings**, rather than somebody
writes it beside them. The `{setting}` parameter carries an enum of every address,
thus Swagger UI offers them as a dropdown and cannot list one that no longer exists.

⚠️ The Swagger UI page pulls its JavaScript from a CDN, thus `/docs` needs an internet
connection, which a venue often lacks. The API and the specification do not: Déferlante
serves them entirely. Without internet, `/docs` says so and points at `/openapi.json`,
which any OpenAPI tool can read.

As with everything else on this server, **there is no authentication**.

## External control over OSC

Godot listens for OSC on port **9000** (UDP) and, like the web surface, on **this
machine only** until you tell it otherwise. OSC carries no credentials of any kind: the
show obeys a message that reaches the port. You let a console on another machine in
through the `OSC ACCESS` row of the launcher. That row offers the same list of
addresses as `WEB ACCESS`, and you answer it separately. A phone that drives the
surface and a console that sends OSC are rarely the same machine. Access for one is no
reason to give access to the other. Every setting can be driven remotely from
Chataigne, TouchOSC, a sequencer, or any script at all.

### How an address is built

`/deferlante/<section>/<setting>` — the section is part of the path because four
sections have a `WIDTH` and three have a `SPEED`. Without the section, those addresses
collide.

The address and the label are **decoupled** in the code. `slug` carries the address and
`Lang` carries what the screen shows. A new label, or a switch of the interface to
French, can never break a console that is already wired to an address.

### Arguments

One argument, a **float** or an **int**. The show ignores anything else. It clamps the
value to the bounds of the setting and snaps it to its step. Thus a console that sends
`999` lands on the maximum rather than breaks anything.

**Bundles are supported.** Chataigne sends one when several values leave in the same
frame. The show deliberately ignores the timetag and applies the contents at once. When
you VJ you want the value now, not at a scheduled time.

### Two forms, and why

| Form | Argument |
| --- | --- |
| `/deferlante/<section>/<setting>` | the value, in the units of the setting |
| `/deferlante/norm/<section>/<setting>` | 0 → 1, spread over the range of the setting |

The `norm` form is for surfaces that can only send 0 → 1, such as MIDI faders and
TouchOSC. They have no business with the knowledge that `spot/radius` runs from 20 to
600.

### Actions

| Address | Effect |
| --- | --- |
| `/deferlante/glitch_now` | fires one glitch (no argument needed) |
| `/deferlante/randomize` | redraws colors and trajectories, and returns color to random mode |
| `/deferlante/shuffle` | one move of the auto-pilot, now, whatever pace it is set to |
| `/deferlante/shuffle/<section>` | the same, confined to one section: `global`, `color`, `mirror`, `lasers`, `spot`, `audio`, `sphere`, `warp` |
| `/deferlante/color/rgb` | three floats 0 → 1: the whole color in one message, and a switch to manual |

### Every address

The show generates this table from the settings themselves, thus it cannot drift:

```
python3 tools/build_chataigne_module.py --addresses
```

| Address | Range | Default | On screen |
| --- | --- | --- | --- |
| `/deferlante/global/speed` | -3 – 3 | 1 | GLOBAL › SPEED |
| `/deferlante/global/chaos` | 0 – 1 | 0 | GLOBAL › CHAOS |
| `/deferlante/global/randomizer` | 0 – 1 | 0 | GLOBAL › RANDOMIZER |
| `/deferlante/global/glow` | 0 – 2 | 0 | GLOBAL › GLOW |
| `/deferlante/global/recall` | 0 – 10 | 0 | GLOBAL › RECALL FADE |
| `/deferlante/global/panel` | 0.05 – 1 | 1 | GLOBAL › PANEL |
| `/deferlante/global/autodim` | 0 – 1 | 1 | GLOBAL › AUTO DIM |
| `/deferlante/color/mode` | 0 – 1 | 0 | COLOR › MODE |
| `/deferlante/color/saturation` | 0 – 1 | 0.7 | COLOR › SATURATION |
| `/deferlante/color/red` | 0 – 1 | 1 | COLOR › RED |
| `/deferlante/color/green` | 0 – 1 | 0.25 | COLOR › GREEN |
| `/deferlante/color/blue` | 0 – 1 | 0.1 | COLOR › BLUE |
| `/deferlante/mirror/effect` | 0 – 1 | 0 | MIRROR › EFFECT |
| `/deferlante/mirror/segments` | 2 – 16 | 5 | MIRROR › SEGMENTS |
| `/deferlante/mirror/rotation` | -1 – 1 | 0 | MIRROR › ROTATION |
| `/deferlante/lasers/count` | 0 – 40 | 3 | LASERS › COUNT |
| `/deferlante/lasers/width` | 1 – 24 | 5 | LASERS › WIDTH |
| `/deferlante/lasers/length` | 0.1 – 2 | 1 | LASERS › LENGTH |
| `/deferlante/lasers/spin` | -1 – 1 | 1 | LASERS › SPIN |
| `/deferlante/lasers/parallel` | 0 – 1 | 0 | LASERS › PARALLEL |
| `/deferlante/lasers/scroll` | -1 – 1 | 0 | LASERS › SCROLL |
| `/deferlante/spot/radius` | 20 – 600 | 200 | SPOTLIGHT › RADIUS |
| `/deferlante/spot/pulse` | 0 – 300 | 25 | SPOTLIGHT › PULSE |
| `/deferlante/spot/width` | 1 – 24 | 3 | SPOTLIGHT › WIDTH |
| `/deferlante/spot/speed` | 0 – 2 | 0.5 | SPOTLIGHT › SPEED |
| `/deferlante/spot/hold` | 0 – 3 | 1.8 | SPOTLIGHT › HOLD |
| `/deferlante/spot/shake` | 0 – 3 | 0.4 | SPOTLIGHT › SHAKE |
| `/deferlante/spot/frequency` | 0 – 20 | 6 | SPOTLIGHT › FREQUENCY |
| `/deferlante/spot/spread` | 0 – 1 | 0.35 | SPOTLIGHT › SPREAD |
| `/deferlante/spot/glitch` | 0 – 0.05 | 0 | SPOTLIGHT › GLITCH |
| `/deferlante/spot/manual` | 0 – 1 | 0 | SPOTLIGHT › AIMING |
| `/deferlante/spot/track` | 0.2 – 3 | 0.9 | SPOTLIGHT › TRACKING |
| `/deferlante/spot/handback` | 2 – 120 | 30 | SPOTLIGHT › HAND BACK |
| `/deferlante/audio/reactivity` | 0 – 1 | 0 | AUDIO › REACTIVITY |
| `/deferlante/audio/punch` | 0 – 1 | 0.35 | AUDIO › PUNCH |
| `/deferlante/audio/spot` | 0 – 12 | 2.5 | AUDIO › SPOT ← BASS |
| `/deferlante/audio/warp` | 0 – 12 | 2.5 | AUDIO › HYPERSPACE ← BASS |
| `/deferlante/audio/lasers` | 0 – 12 | 2.5 | AUDIO › LASERS ← MID |
| `/deferlante/audio/sphere` | 0 – 12 | 2.5 | AUDIO › SPHERE ← TREBLE |
| `/deferlante/sphere/count` | 0 – 80 | 14 | SPHERE › COUNT |
| `/deferlante/sphere/size` | 0.03 – 0.8 | 0.13 | SPHERE › SIZE |
| `/deferlante/sphere/sides` | 0 – 12 | 0 | SPHERE › SIDES |
| `/deferlante/sphere/radius` | 100 – 800 | 400 | SPHERE › RADIUS |
| `/deferlante/sphere/spin` | -1 – 1 | 0.6 | SPHERE › SPIN |
| `/deferlante/sphere/depth` | 1.2 – 10 | 2 | SPHERE › DEPTH |
| `/deferlante/sphere/width` | 1 – 24 | 3 | SPHERE › WIDTH |
| `/deferlante/sphere/glass` | 0 – 1 | 0 | SPHERE › GLASS |
| `/deferlante/warp/count` | 0 – 400 | 0 | HYPERSPACE › STARS |
| `/deferlante/warp/speed` | 0 – 4 | 1 | HYPERSPACE › SPEED |
| `/deferlante/warp/streak` | 0 – 0.4 | 0.12 | HYPERSPACE › STREAK |
| `/deferlante/warp/width` | 0.5 – 12 | 2 | HYPERSPACE › WIDTH |
| `/deferlante/warp/spread` | 0.1 – 2 | 0.7 | HYPERSPACE › SPREAD |


### What it does not do

**Nothing comes back.** Godot never sends OSC out, thus a motorized console cannot
follow a change made on the keyboard or by the auto-pilot. The web surface does get
that mirroring, over its own WebSocket. If you need it over OSC, that is the piece to
add.

There is also **no OSCQuery**. The table above is the discovery mechanism.

### Trying it without a console

```
oscsend 127.0.0.1 9000 /deferlante/global/chaos f 0.8
oscsend 127.0.0.1 9000 /deferlante/glitch_now
```

Or with no tooling at all, directly from Python:

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

A value that arrives over OSC **does not wake the on-screen panel**. That is
deliberate. If it did, an automation that sends continuously would leave the sliders on
screen, and thus projected on the wall, for the whole set.

A ready-made Chataigne module ships in `chataigne/Deferlante/`, with its own install
notes. It is a convenience only, because the generic OSC module of Chataigne drives the
same addresses.

## Audio reactivity

Déferlante listens to **what comes out of the machine**, not to a microphone. Thus it
follows the track that plays rather than the room.

### Setting it up

Pick it on the launcher, under **`SON ÉCOUTÉ` / `SOUND LISTENED TO`**. The default is
*the output playing at launch*. It is right on a machine with one sound card, and it
stays right when that changes.

The row asks one question at two depths. **Listen to an output** and the show taps its
monitor. That is the ordinary answer, and the one that needs nothing arranged
beforehand. **Capture an input** and the show taps nothing at all: it listens where you
tell it. That is what you want the moment that something else on the machine insists on
standing in the middle. `easyeffects_source` appears in that half, and if you name it,
EasyEffects becomes a link in the chain rather than a thing to fight.

Under the row is a live **meter**. It shows what the line that you selected actually
carries, and says `rien n'entre` when the answer is nothing. Every wrong answer used to
look exactly like every right one until the show was running. This is the difference.

That is all. The show taps the monitor of the chosen output and points the capture of
the machine at it, **on every launch**. That includes the launches that walk straight
past the launcher with `--skip-launcher`. To do it again every time is the point. The
tap outlives nothing in particular, and a tap left on last night's interface is the most
likely reason for "the sound stopped working".

It taps the output. It does not reroute it, thus playback is untouched.

The old script still exists and does the same thing from a terminal. That is what you
want when the show is not the thing that you start:

```
tools/listen-to-output.sh          # start listening
tools/listen-to-output.sh --stop   # put the machine's capture back the way it was
```

`--stop` is the undo for both, because the launcher notes the previous default source
in the same place that the script does. Nothing puts it back on its own: a routing that
half-restores after a crash is worse than one that stays put.

If your sound arrives through an interface instead — a Focusrite, a console — none of
this is needed. That is already an input, and Déferlante reads the default one.

### Telling whether it hears anything

Three states used to look alike on flat bars. The status line now says which one it is:

| on screen | meaning |
| --- | --- |
| `son  pas de capture` | no analyzer at all — the capture never opened |
| `son  silence — rien n'entre` | open, and carrying nothing for ten seconds straight |
| `son ▁▂▃ 0%` | hearing it perfectly well. `REACTIVITY` is at zero |

Ten seconds is longer than any gap in a set and shorter than the time that it takes to
start wondering. The web surface shows the same three states in its vu-mètre. The
middle row is also what triggers the diagnosis that follows.

### When something else is listening first

A sound server is free to put a recording stream wherever its own policy says, and some
do. Measured on the machine that this was written on: **EasyEffects in service mode
pulls every capture onto its own source**, `parecord` included, and undoes a
`pactl move-source-output` within the second. Nothing that the show does at the Pulse
level survives that.

It is not necessarily a fault. EasyEffects also latched onto the tap itself and passed
the music through. Thus the show heard everything, one link further down the chain than
it thought. It only breaks when EasyEffects points somewhere else, typically the
built-in microphone after the default source moved. The show then reads a silent room
while the music plays.

Thus the show does not fight it, it reports it. When every band is flat for ten
seconds, `audio_reactor.gd` asks whether anything reads the tap at all. If nothing
does, it says so by name in the log. That turns a failure with no symptom into one line
that names the likely culprit.

Two ways round it. Name its source in the audio row of the launcher, which accepts the
interception and listens one link further down. Its meter tells you at once whether
that link carries anything. Or quit it before the show with
`flatpak kill com.github.wwmm.easyeffects`, which is the only arrangement measured end
to end here. Its input blocklist was tried and did not take.

### Windows

There is nothing to route, because Windows has no monitor to wrap. What the launcher
offers there is the old `AUDIO INPUT` row — the input list of Godot, which the WASAPI
backend does honor, unlike PulseAudio. What has to exist first is an input that carries
the output. Two ways, both outside this project:

- **Stereo Mix**, if the driver of the chipset still exposes it. Enable it in the sound
  control panel, then pick it in the row.
- **A virtual cable** — VB-Audio Cable, VoiceMeeter — which appears as an ordinary
  input device. It is the answer when Stereo Mix is not offered.

Not measured. This is written from how the pieces are documented to behave, with no
Windows machine to make sure of it. The launcher probes rather than assumes: it assigns
a device, reads it back, and disables the row if it did not hold. Thus a build that
turns out not to honor the choice says so on screen instead of pretends.

### Android

The system cannot capture its own output. Android puts that behind `MediaProjection`
and `AudioPlaybackCapture`. That pair needs consent per session, any app that plays
audio can refuse it, and Godot exposes no binding for it. There is no version of the
Linux trick that works here.

What does work is the **microphone**, and in a room it is not the poor relation that it
sounds like. A phone on a table hears the PA perfectly well, and a phone is a secondary
screen at best anyway.

That needs two things, both now in place: `RECORD_AUDIO` in the export preset, and the
runtime grant, which `audio_reactor.gd` asks for before it opens the capture. The
manifest entry alone is not enough. Without the grant the stream opens quite happily
and carries nothing, which is the failure that this whole page keeps circling. Untested
on a phone.

### Why it has to go round the outside

Godot captures an *input*, and music is an *output*. PipeWire does publish the monitor
of the output as a source. But **the PulseAudio backend of Godot filters monitors out
of its device list**, thus you cannot pick one from inside the app.

Worse, `AudioServer.input_device` does not hold in this build. Assigned during
`_ready`, it reads back `"Default"`. One frame later it reads back empty, and the
capture follows neither. Thus the show wraps the monitor in an ordinary source *and
makes it the default*, which points Godot at it by giving it no choice. `AudioRouting`
does that through `pactl`, and `tools/listen-to-output.sh --stop` restores the source
that you had.

Measured again since, and precisely. `AudioServer.get_input_device_list()` does
enumerate properly — every source on the machine, monitors excepted. It is the *setter*
that goes nowhere. Pointed at a source measured at a peak of exactly zero, Godot still
read the music off the system default, at -55 dB. It was given a second and a half to
settle in between. The assignment reads back empty, then `"Default"`.

Thus on Linux the launcher stops offering inputs and offers outputs instead. The old
`AUDIO INPUT` row survives only for the platforms where a choice of input is the answer.
Which row appears is probed, not hardcoded. `pactl info` decides the first one. For the
second one the launcher assigns a device, reads it back and disables the row if it did
not hold. That is safe there, because no capture is open yet. The same story applies to
`preferred_device` in `audio_reactor.gd`: it is best-effort, not the mechanism.

The meter does not use the engine to listen, and cannot. Godot binds a capture to the
default source when the stream opens and never looks again. To free the player and make
another changes nothing, and `AudioServer.input_device`, which does force the driver to
reopen its input, kills the capture outright. Measured: the first reading comes through
at 0.68 with music playing, and every reopening after it reads 0.000 with
`pa_stream_disconnect: Bad state`. Thus `audio_probe.gd` shells out to `parecord` and
reads the tail of the raw file that it writes. What that measures is what a recording
client on this machine actually receives, policy and all. That is the point, and the
reason that it is trustworthy about the EasyEffects case.

One trap for anybody who adds to `AudioRouting`: what it hands to `sh -c` is parsed two
times. Measured, `awk '$2 == "x"'` arrives at awk as `awk == x`, with the quotes
stripped and the fields expanded away to nothing. Thus the show fetches every listing
whole and picks it apart in GDScript. The shell lines carry no quotes, no `$` and no
pipelines that need either.

⚠️ CAUTION: Do not measure audio under `--headless`. That mode loads the dummy audio
driver, where the device list really *is* `["Default"]` and every band reads `-inf`.
Both look exactly like a broken capture. Any audio check has to run windowed, and not
under `--write-movie` either, which takes the audio driver over to write its `.wav`.

### What the sound drives

Three bands and four destinations: **the kick drives the spotlight and the star
field**, mids drive the lasers, and treble drives the sphere. Effects that breathe on
one envelope read as a single thing that pumps. On separate bands they pick out
different parts of the track and the picture comes apart into layers. The kick goes to
the spotlight because the spotlight is the biggest shape on screen, thus it is what
carries the beat.

Four effects and three bands leave no choice about the fourth, and the kick is where a
jump to light speed belongs. The two that share the bass do not share a *property*.
The spotlight takes it as a size and the star field takes it as a speed. Thus they read
as two layers rather than as one pump. Each destination has its own amount, and one of
them at 0 takes that effect out of the sound entirely.

Each amount moves both the **thickness and the size** of its effect: the stroke width,
and the radius of the spotlight, the circle size of the sphere, the length of the
lasers. Thickness alone tops out quickly. A stroke two times as wide is still the same
shape in the same place. A spotlight that swells on the kick changes the whole picture.
Size moves at a third of the amount, because a radius reads far more strongly than a
width. Measured at an amount of 1.5: laser strokes 6.1–10.6 px, spotlight radius
208–274 px, spotlight stroke 3.4–6.4 px.

The sound **adds to** the widths rather than sets them. The sliders continue to mean
what they say, and a return of `REACTIVITY` to 0 restores exactly the look that was
there. Nothing that the sound does is written to a setting. Thus it never lands in a
preset and never fights you for a slider.

### Levels, not volume

Everything is done in decibels, against a **running peak** per band rather than a fixed
gain. A fixed gain that suits one track sits flat or clips on the next. An earlier
version normalized the compressed 0–1 value instead of the decibels. That pinned bass
and mid at 0.99 on real music, which looks like a constant rather than a pulse.

The three bands live at completely different levels. Measured on a techno set: bass
around −35 dB, hi-hats between −60 and −100. Thus there is no shared floor. Each band
scales against its own peak, and only an absolute silence gate stops the show from
amplifying room noise when nothing plays. An earlier floor tight enough to gate a quiet
room flattened the treble into a dead constant.

The show reads each band at its **loudest point** rather than averages it. To average a
narrow tone across a wide band divides it by the silence on either side. A 6 kHz tone
read as nothing at all in a 2–12 kHz band until that changed.

**Both ends of the scale follow the music**, not only the top. To track only the peak
and sit a fixed number of decibels below it is adaptive on paper and a constant in
practice: a track with six decibels of movement spends all its time at the top of the
range. The reference is a running average over a few bars. Thus the ordinary level of
the track maps to zero, and only what rises above it shows.

Two things had to be right for that to work. The show primes the scale on the first
frame that actually carries sound. Primed on the first frame at all, it starts at
−130 dB and crawls upwards for a minute while every band reads 0.95. It also applies
the response curve on the way out, never back into the smoothed state. In that state it
compounds frame after frame and collapses every band to zero within a second.

`PUNCH` is the taste control on top. Adaptive scaling gets the *range* right, but how
much of a busy track must read as "pulsing" rather than "loud" is a judgement.

### How nervous it is

Sharpened deliberately, and every step of it measured off the level broadcast of the
app itself: mean level, peak, and the average change from one packet to the next, which
is the number that says "nervous".

- **`release` 0.9 → 0.3 s.** This is where the nervousness comes from. A long decay is
  still coming down when the next kick lands, thus hits merge into a swell. A short one
  separates them. On its own it took the average change per sample from 0.021 to 0.044
  on the bass and from 0.073 to 0.174 on the treble. `attack` went 0.06 → 0.03 to match.
- **`min_range_db` 9 → 5 dB.** The bigger surprise, and the one that fixed the kick.
  This is the ceiling on the automatic gain. A band whose loud and quiet moments sit
  closer together than this is divided by a range that it never uses. A bass line is
  nearly continuous, thus it lived entirely inside the old floor and topped out around
  **0.45**. The spotlight that it drives barely moved, on the *original* settings. At
  5 dB the same passage reaches 0.99, and spends 22 % of its time low instead of 63 %.
  3 dB was measured too. It adds almost nothing (1.00 against 0.99) while it expands
  more of whatever hum is in the room, thus 5 dB it is.
- **The two changes that did not survive measurement.** The first was a shorter
  `average_window` of 2 s. The theory was that a closer reference would show more. It
  showed *less*. A reference that chases the signal rises to meet it and flattens what
  it was meant to reveal. The second was `PUNCH` at 0.5, which compounded with the
  shorter decay. The bass fell to 0.09, with 89 % of its time on the floor, thus the
  kick stopped registering entirely. Both were put back.

End to end, all three bands now reach full scale and move three to five times as much
per sample as they did. Measured on a techno set: at 0 the bass swings 0.39–0.87, at
0.5 it swings 0.12–0.40.

# Getting started

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
| `SOUND LISTENED TO` | the output playing at launch, a named output, or a named input | An output is tapped on its way past; an input is listened to as it is, for when something else on the machine sits in the middle. A live meter under the row says what the choice actually carries. Re-done at every launch, so it cannot be left pointing at last night's interface. Linux with PipeWire or PulseAudio. |
| `AUDIO INPUT` | automatic, or a named source | The same row, on a machine where the sound cannot be routed from here — Windows, mainly. Greyed out where Godot ignores the choice too. Both are explained under [audio reactivity](external-control.md#audio-reactivity). |
| `PANEL` | hidden for the whole set | For a machine that only projects, driven from a phone. `F3` still works. |
| `WEB ACCESS` | this machine only, or one of its addresses | Loopback by default: the control surface has no password, so being reachable from the room is opt-in. Pick an address here to let a phone in. |
| `OSC ACCESS` | this machine only, or one of its addresses | The same decision for OSC, answered separately. See [OSC](external-control.md#external-control-over-osc). |
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
answer. That is what keeps [the CI check](the-code.md#the-one-thing-ci-actually-checks) working.

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
address a console has to aim OSC at, and which pad is plugged in — followed by the
shortcuts. Both addresses are shown in full, host and port: since each is a choice
made at the launcher, a bare port number would no longer tell anyone whether the
phone or the desk across the room will be heard. They are what you look up rather
than remember, so they belong on screen and not only in the console, where they
scroll away long before anyone needs them.

## Settings

The panel is arranged in six sections, the same as the Chataigne module's menus.
Labels below are the English ones.

### Global
| Setting | Range | Effect |
| --- | --- | --- |
| `SPEED` | -3 – 3 | Global speed. 1 is normal, 0 freezes, negative runs everything backwards. |
| `CHAOS` | 0 – 1 | Motion disorder. Does not touch `GLITCH`. See [Chaos](effects.md#chaos). |
| `RANDOMIZER` | 0 – 1 | Auto-pilot. 0 is off, 1 is about one change per second. |
| `RECALL FADE` | 0 – 10 | Seconds a preset takes to crossfade in. 0 snaps. |
| `PANEL` | 0.05 – 1 | Panel brightness. `F2` toggles it. See below. |
| `AUTO DIM` | OFF / ON | Duck the panel automatically when something else takes over. |
| `GLOW` | 0 – 2 | Halo, drawn by the strokes themselves. **0 by default**, see [the halo](in-the-room.md#the-halo). |

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
| `LENGTH` | 0.1 – 2 | **1 crosses the frame** whatever the resolution — twice its diagonal, so the ends stay outside wherever a stroke wanders. Below 1 the tips come into view, which is now something you ask for rather than something that happens. |
| `SPIN` | -1 – 1 | ← leftwards, → rightwards. |
| `PARALLEL` | 0 – 1 | 0 a scatter, 1 an evenly spaced fan. See [Scanlines](effects.md#scanlines). |
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
| `SPREAD` | 0 – 1 | How much the pool grows when aiming off-centre. See [why the pool changes size](effects.md#why-the-pool-changes-size). |
| `GLITCH` | 0 – 0.05 | Glitch chance per frame. **0 by default.** Independent of `CHAOS`. 0.005 ≈ one every 3 s. |

### Audio
| Setting | Range | Effect |
| --- | --- | --- |
| `REACTIVITY` | 0 – 1 | Master amount. **0 by default** — nothing moves until asked. |
| `PUNCH` | 0 – 1 | Response curve. Higher pushes the middle down so only hits show. |
| `SPOT ← BASS` | 0 – 12 | The kick drives the spotlight. |
| `LASERS ← MID` | 0 – 12 | Mids drive the laser strokes. |
| `SPHERE ← TREBLE` | 0 – 12 | Treble drives the sphere. |

The top of those three is deliberately past the point of good taste — see
[how nervous it is](external-control.md#how-nervous-it-is). The middle is where a set lives.

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

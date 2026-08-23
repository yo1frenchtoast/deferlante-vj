# Getting started

## Run

Open the project in Godot 4.7+. Press F5. The main scene is `scenes/launcher.tscn`.
It asks a few questions, then it hands over to `scenes/main.tscn`.

## The launcher

You can adjust almost everything in this project while the show runs, on purpose. A
setting that you cannot reach in the middle of a set is of no use. The launcher holds
the exceptions. These are the few settings that the engine cannot change after the
show starts.

| Row | Choices | |
| --- | --- | --- |
| `LANGUAGE` | FRANÇAIS / ENGLISH | This row is first, because it decides the words of every other row. |
| `RENDERER` | Compatibility / Forward+ | Compatibility is two times as fast. Only Forward+ does antialiasing. **This row restarts the app.** |
| `ANTIALIASING` | none / MSAA 2× 4× 8× | Forward+ only. The Compatibility renderer ignores 2D MSAA. |
| `RESOLUTION` | the screen's own, or a fixed size | |
| `FULLSCREEN` | | `F11` also toggles it during the show. |
| `VSYNC` | | |
| `MAX FPS` | uncapped, or a refresh rate | Frames above the refresh rate of the projector cost the same to draw. Nobody sees them. |
| `SOUND LISTENED TO` | the output playing at launch, a named output, or a named input | The show taps an output on its way past. It listens to an input as it is, for when something else on the machine sits in the middle. A live meter under the row shows what the choice carries. The show does this again at every launch, thus it cannot point at last night's interface. Linux with PipeWire or PulseAudio only. |
| `AUDIO INPUT` | automatic, or a named source | The same row, on a machine where the show cannot route the sound — Windows, mainly. The row is disabled where Godot ignores the choice too. [Audio reactivity](external-control.md#audio-reactivity) explains both rows. |
| `PANEL` | hidden for the whole set | For a machine that only projects, and that a phone drives. `F3` still works. |
| `WEB ACCESS` | this machine only, or one of its addresses | Loopback by default. The control surface has no password, thus you let the room in on purpose. To let a phone in, pick an address here. |
| `OSC ACCESS` | this machine only, or one of its addresses | The same decision for OSC, answered separately. See [OSC](external-control.md#external-control-over-osc). |
| `WEB PORT` · `OSC PORT` | | The show binds these ports at start-up, thus you cannot move them later. |

The show keeps the answers in `user://launch.cfg`. Thus the screen opens on last
night's answers, and `LANCER` is usually the only key you press. The `PANEL` and
`LANGUAGE` rows were settings on the panel before. They are decisions about the room
and about who stands in front of the machine, thus they moved here. As a result,
`LANGUAGE` no longer has an OSC address.

### Why the renderer restarts the app

Godot sets the renderer before the first script runs, thus the show cannot change it
in place. If you choose the other renderer, the show starts the process again with
`--rendering-method`, and the new process skips this screen. If that restart fails,
the show starts on the renderer that already runs and says so in the console. A black
screen ten minutes before the doors open is worse than the wrong renderer.

### Skipping it

`-- --skip-launcher` goes directly to the show, on the saved settings. The bare `--`
is necessary. Godot reads an argument that it does not know before that point as a
fatal argument error. It gives everything after the `--` to the project.

A `--headless` run also skips the launcher, without an option, because there is
nobody there to answer it. This is what keeps
[the CI check](the-code.md#what-ci-actually-checks-beyond-it-exported) in operation.

## Drive it

The panel is in the bottom-left corner. It has one or more columns, related to the
number of settings. The sliders **fade out after 4 s with no input** (across 0.7 s).
They come back on a key press or a mouse move. `H` pins them on screen while you
adjust the settings.

| Key | Action |
| --- | --- |
| `↑` `↓` | Move between settings (the panel highlights the selected one) |
| `←` `→` | Adjust — a fortieth of the range per press |
| `Shift` + `←` `→` | Fine adjust, one step at a time |
| `Space` | Fire a glitch immediately |
| `R` | Redraw every color and trajectory |
| `1` – `9` | Recall a preset (also on the numeric keypad) |
| `Ctrl` + `1` – `9` | Store the current look into that slot |
| `H` | Pin or unpin the panel (it stops the fade) |
| `F2` | Dim the panel to discreet, and back |
| `F3` | FPS readout |
| `F11` | Fullscreen |
| `Esc` | Quit |

The mouse also works on the sliders. But the keyboard is safer during a show, because
you do not aim in the dark.

Below the sliders is a status line. It shows three things, then the shortcuts:

- **The web address that you type into a phone.**
- The address that a console must send OSC to.
- The name of the gamepad that is connected.

The line shows both addresses in full, with host and port. Each one is a choice made
at the launcher. Thus a bare port number can no longer tell you whether the show hears
the phone or the console across the room. You look these addresses up rather than
remember them. Thus they belong on screen, and not only in the console, where they
scroll away long before you need them.

## Settings

The panel has six sections, the same as the menus of the Chataigne module. The labels
that follow are the English ones.

### Global
| Setting | Range | Effect |
| --- | --- | --- |
| `SPEED` | -3 – 3 | Global speed. 1 is normal, 0 freezes. A negative value runs everything backwards. |
| `CHAOS` | 0 – 1 | Motion disorder. It does not touch `GLITCH`. See [Chaos](effects.md#chaos). |
| `RANDOMIZER` | 0 – 1 | Auto-pilot. 0 is off, 1 is about one change per second. |
| `RECALL FADE` | 0 – 10 | The time in seconds for a preset to crossfade in. 0 snaps. |
| `PANEL` | 0.05 – 1 | Panel brightness. `F2` toggles it. See [Working discreetly](#working-discreetly). |
| `AUTO DIM` | OFF / ON | Dim the panel automatically when something else takes control. |
| `GLOW` | 0 – 2 | Halo, drawn by the strokes themselves. **0 by default**, see [the halo](in-the-room.md#the-halo). |

### Color
| Setting | Range | Effect |
| --- | --- | --- |
| `MODE` | RANDOM / MANUAL | Each element takes its own hue, or all elements take the chosen color. |
| `SATURATION` | 0 – 1 | 0 is pure white, 1 is a full color. It works in both modes. |
| `RED` `GREEN` `BLUE` | 0 – 1 | The manual color. If you move one, the mode changes to manual. |

### Mirror
| Setting | Range | Effect |
| --- | --- | --- |
| `EFFECT` | 0 – 1 | Kaleidoscope fold. 0 is off, and the show does not pay for the pass. |
| `SEGMENTS` | 2 – 16 | Number of wedges. 6 gives the classic star. |
| `ROTATION` | -1 – 1 | Turns the mirrors. ← left, → right. |

### Lasers
| Setting | Range | Effect |
| --- | --- | --- |
| `COUNT` | 0 – 40 | Number of strokes. The show adds and removes them live. It starts at 3. |
| `WIDTH` | 1 – 24 | Stroke width. |
| `LENGTH` | 0.1 – 2 | **1 crosses the frame** at every resolution. The stroke is two times the diagonal, thus its ends stay outside the frame wherever it goes. At less than 1 the tips come into view, which you now ask for rather than get by accident. |
| `SPIN` | -1 – 1 | ← leftwards, → rightwards. |
| `PARALLEL` | 0 – 1 | 0 is a scatter, 1 is a fan with equal spacing. See [Scanlines](effects.md#scanlines). |
| `SCROLL` | -1 – 1 | Walks that fan sideways. ← one way, → the other. |

### Spotlight
| Setting | Range | Effect |
| --- | --- | --- |
| `RADIUS` | 20 – 600 | Radius of the pool. |
| `PULSE` | 0 – 300 | How far the radius swells. 0 holds it steady. |
| `WIDTH` | 1 – 24 | Circle stroke width. |
| `SPEED` | 0 – 2 | Sweep speed (it has no direction). |
| `HOLD` | 0 – 3 | How long it rests on a target. 0 sweeps without stops. |
| `SHAKE` | 0 – 3 | Tremor amplitude at rest. 0 holds it perfectly still. |
| `FREQUENCY` | 0 – 20 | Tremor rate, **independent of `SPEED`**. |
| `SPREAD` | 0 – 1 | How much the pool grows when the head aims away from center. See [why the pool changes size](effects.md#why-the-pool-changes-size). |
| `GLITCH` | 0 – 0.05 | Glitch chance per frame. **0 by default.** Independent of `CHAOS`. 0.005 ≈ one every 3 s. |

### Audio
| Setting | Range | Effect |
| --- | --- | --- |
| `REACTIVITY` | 0 – 1 | Master amount. **0 by default.** Nothing moves until you ask for it. |
| `PUNCH` | 0 – 1 | Response curve. A higher value pushes the middle down, thus only the hits show. |
| `SPOT ← BASS` | 0 – 12 | The kick drives the spotlight. |
| `LASERS ← MID` | 0 – 12 | Mids drive the laser strokes. |
| `SPHERE ← TREBLE` | 0 – 12 | Treble drives the sphere. |
| `HYPERSPACE ← BASS` | 0 – 12 | The kick drives the star field. |

The top of those three ranges is deliberately past good taste. See
[how nervous it is](external-control.md#how-nervous-it-is). A set lives in the middle
of the range.

### Sphere
| Setting | Range | Effect |
| --- | --- | --- |
| `CIRCLES` | 0 – 80 | Number of circles. 0 switches the effect off. It starts at 14. |
| `SIZE` | 0.03 – 0.8 | Size of one circle, in radians on the sphere. |
| `RADIUS` | 100 – 800 | Sphere radius on screen. |
| `SPIN` | -1 – 1 | ← leftwards, → rightwards. |
| `DEPTH` | 1.2 – 10 | Eye distance. A small value gives strong perspective. |
| `WIDTH` | 1 – 24 | Circle stroke width. |
| `GLASS` | 0 – 1 | 0 is an opaque sphere, 1 shows the far side through it. |

### Hyperspace
| Setting | Range | Effect |
| --- | --- | --- |
| `STARS` | 0 – 400 | Number of stars. **0 by default**, and 0 switches the effect off. |
| `SPEED` | 0 – 4 | How fast the field flies past. The global `SPEED` catches it too, and reverses it. |
| `STREAK` | 0 – 0.4 | Length of the trail, in **seconds of travel**. See [why it is a shutter speed](effects.md#streak-is-a-shutter-speed). |
| `WIDTH` | 0.5 – 12 | Streak thickness at the far plane. Near stars are drawn thicker. |
| `SPREAD` | 0.1 – 2 | Width of the tube. Small comes straight at you, large throws the stars past the corners. |

To add a setting, write one line in `_build_params()` of `vj_controller.gd`. The
section, the UI row, the slider, the number format, the keyboard handling and the OSC
address all follow from it. Put its label in `scripts/lang.gd`.

### Working discreetly

The projector shows the panel on the wall with the visuals. Thus the audience sees
everything that you do to it. `PANEL` decreases its brightness. At the default **1**
the panel looks as it always has. `F2` dims it to **0.15**. At 0.15 it stays readable
at arm's length on the operator's screen, and the room hardly sees it through the
haze. If 0.15 is too dark, the slider gives every value between.

The brightness is a preference, not part of a look. Thus it stays out of presets and
out of reach of the auto-pilot. A preset recall cannot light the panel up on the wall
again after you dimmed it deliberately.

`H` and `F2` answer different problems, and you can use them together. `H` prevents
the panel from fading while you work. `F2` makes that work invisible.

### Getting out of the way on its own

`AUTO DIM` is on by default. With it on, the panel dims to discreet as soon as
**something else moves a setting**: the phone, the gamepad, OSC, or an API call. A key
press takes control back and restores the brightness that you chose, not a blanket 1.
If you worked at 0.5, the panel returns to 0.5.

While an external surface has control, the panel also **refuses the mouse**. This is
the half that matters. A dim panel hides the sliders, but it is no harder to move one
by accident. A stray touch on a projected panel is exactly the accident to prevent.

A mouse move does not end the override. A **click** ends it, and so does a key press.
A brush of the trackpad is not a decision. A click is a decision. The panel absorbs
that first click rather than passes it on. Thus the gesture that takes the panel back
cannot also move a slider. A click on an unfocused window works the same way: it
activates the window without a press on what is under the pointer.

During the override, the `PANEL` setting continues to show the brightness that *you*
chose. The auto-dim is a temporary override, not a change to your preference.

## Presets

Nine slots hold a snapshot of every setting. The show writes them to disk and recalls
them live.

| Where | Recall | Save |
| --- | --- | --- |
| Keyboard | `1` – `9`, or the numeric keypad | `Ctrl` + the same |
| Phone | tap a slot | hold it |
| OSC | `/deferlante/preset/recall` *(int)* | `/deferlante/preset/save` *(int)* |
| API | `POST /api/presets/{n}/recall` | `POST /api/presets/{n}/save` |
| Chataigne | `Presets › Recall Preset` | `Presets › Save Preset` |

### A recall is a crossfade

Every setting moves from its current value to the value in the preset, across
`RECALL FADE` seconds. This is the difference between a preset that is a scene change
and a preset that is an edit. At 4 seconds the room moves from one look to another and
nobody sees a cut. For a stab, set it to **0** to snap.

The curve is a smoothstep, not linear. A linear crossfade starts and stops abruptly,
and on a slow move that start is exactly what the eye catches.

The show reads the number keys by **physical position**, not by the character that
they type. Thus the top row works the same on AZERTY, QWERTY and Dvorak. (Read as
characters, an AZERTY top row gives `& é " ' ( - è _ ç`. Only the three non-ASCII keys
fell through to a digit, thus six slots out of nine could not be reached.)

### What is and is not saved

A preset holds every setting except `PANEL`, which is a preference rather than part of
a look. A preset recall must not light the panel up on the wall again after the
operator dimmed it deliberately.

A preset saved before a setting existed leaves that setting alone. Thus old presets
continue to work after the project gets new ones.

The slots are in `user://presets.json`. On Linux this is
`~/.local/share/godot/app_userdata/Déferlante/`. They belong to the machine, not to
the project. Thus they survive a rebuild, and git does not hold them.

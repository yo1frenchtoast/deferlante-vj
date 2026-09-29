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
| `RESOLUTION` | the screen's own, or a fixed size | 16:9 and 16:10 sizes, from 720p to 4K. The show fills the shape that it is given, thus a 16:10 screen gets no black borders. |
| `FULLSCREEN` | | `F11` also toggles it during the show. |
| `VSYNC` | | |
| `MAX FPS` | uncapped, or a refresh rate | Frames above the refresh rate of the projector cost the same to draw. Nobody sees them. |
| `SOUND LISTENED TO` | the output playing at launch, a named output, or a named input | The show taps an output on its way past. It listens to an input as it is, for when something else on the machine sits in the middle. A live meter under the row shows what the choice carries. The show does this again at every launch, thus it cannot point at last night's interface. Linux with PipeWire or PulseAudio only. |
| `AUDIO INPUT` | automatic, or a named source | The same row, on a machine where the show cannot route the sound — Windows, mainly. The row is disabled where Godot ignores the choice too. [Audio reactivity](external-control.md#audio-reactivity) explains both rows. |
| `SPOUT` | off, or the show sent out | Windows only, and only on the Forward+ renderer. The show becomes a Spout source named `Déferlante`, which Resolume, TouchDesigner or OBS take live. The row says so where the build has no Spout extension. See [sending the show out](in-the-room.md#sending-the-show-out). |
| `PANEL` | hidden for the whole set | For a machine that only projects, and that a phone drives. `F3` still works. |
| `CONSOLE` | panel and preview in a window of their own | For two screens: this window projects, the console drives. `F4` opens and closes it during the show. See [two screens](#two-screens-the-console-window). |
| `START ON` | the defaults, or a preset slot | The state the show comes up in. See [starting on a preset](#starting-on-a-preset). |
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

### Starting on a preset

Every other row here answers *how* the machine runs. `START ON` answers **what the
show is doing when it comes up**, which is the one decision no surface can make. At
that moment no console has sent anything, no phone has connected, and nobody is at the
keyboard.

Pick a slot and the show recalls it at start-up, before the first frame. Save a slot
with `RANDOMIZER` up and the machine starts a show that runs itself. Save one with a
look you like and it starts there instead. Both matter on a projector on a shelf, or
on an Android box with a remote and no keyboard.

The recall is **instant, not a crossfade**, whatever `RECALL FADE` says. A fade from
the defaults is a fade from a look that nobody chose, and there is no audience yet to
fade for.

The row names the nine slots and says which ones are empty. An empty slot is still
offered, because you can save into it once the show is up. If the chosen slot holds
nothing when the show starts, the defaults stand and nothing is said about it. A
preset saved before a setting existed leaves that setting alone, exactly as a recall
during the show does.

`START ON` is not a copy of the `RANDOMIZER` slider. That slider stays where it always
was, reachable from every surface at any moment. This row decides where it starts.

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
| `F4` | Open or close the console window. See [two screens](#two-screens-the-console-window) |
| `F6` | Arrange the panel. See [arranging the panel](#arranging-the-panel) |
| `F11` | Fullscreen |
| `Esc` | Quit |

The mouse also works on the sliders. **A double click on a slider, or on its name or its
number, puts its setting back to the value that it was declared with**, the one that the show starts on. It is not the
value that a preset or the auto-pilot last left. But the keyboard is safer during a
show, because you do not aim in the dark.

Below the sliders is a status line. It shows four things, then the shortcuts:

- **The web address that you type into a phone.**
- The address that a console must send OSC to.
- What the sound capture hears. See [telling whether it hears anything](external-control.md#telling-whether-it-hears-anything).
- The name of the gamepad that is connected.

The line shows both addresses in full, with host and port. Each one is a choice made
at the launcher. Thus a bare port number can no longer tell you whether the show hears
the phone or the console across the room. You look these addresses up rather than
remember them. Thus they belong on screen, and not only in the console, where they
scroll away long before you need them.

## Settings

The panel has nine sections. It groups them by **when you touch a setting**, not by
what the setting drives. The four that you settle before a set come first: GLOBAL,
COLOR, MIRROR and AUDIO. What you play follows: the four instruments, SPOTLIGHT, LASERS,
SPHERE and HYPERSPACE, and then EFFECTS, which you turn during a set like they are. `↑` and `↓` walk the panel in that order. The Chataigne module
carries the same nine sections as menus, in the order that the code declares them. The labels that
follow are the English ones.

### Global
| Setting | Range | Effect |
| --- | --- | --- |
| `SPEED` | -3 – 3 | Global speed. 1 is normal, 0 freezes. A negative value runs everything backwards. |
| `CHAOS` | 0 – 1 | Motion disorder. It does not touch `GLITCH`. See [Chaos](effects.md#chaos). |
| `RANDOMIZER` | 0 – 1 | Auto-pilot. 0 is off, 1 is about one change per second. |
| `GLOW` | 0 – 2 | Halo, drawn by the strokes themselves. **0 by default**, see [the halo](in-the-room.md#the-halo). |
| `RECALL FADE` | 0 – 10 | The time in seconds for a preset to crossfade in. 0 snaps. |
| `PANEL` | 0.05 – 1 | Panel brightness. `F2` toggles it. See [Working discreetly](#working-discreetly). |
| `AUTO DIM` | OFF / ON | Dim the panel automatically when something else takes control. |

### Color
| Setting | Range | Effect |
| --- | --- | --- |
| `MODE` | RANDOM / MANUAL | Each element takes its own hue, or all elements take the chosen color. |
| `SATURATION` | 0 – 1 | 0 is pure white, 1 is a full color. It works in both modes. |
| `RED` `GREEN` `BLUE` | 0 – 1 | The manual color. If you move one, the mode changes to manual. |

### Mirror
| Setting | Range | Effect |
| --- | --- | --- |
| `EFFECT` | OFF / ON | Kaleidoscope fold. At `OFF` the show does not pay for the pass. It has no middle: see [why](effects.md#why-it-has-no-middle). |
| `SEGMENTS` | 2 – 16 | Number of wedges. It starts at 5. 6 gives the classic star. |
| `ROTATION` | -1 – 1 | Turns the mirrors. ← left, → right. |

### Effects
This section held only the motion blur, and was called MOTION BLUR. It holds the effects
that work on the whole picture. Every one of them is **off at 0**, and a pass that is off
costs nothing.

| Setting | Range | Effect |
| --- | --- | --- |
| `TRAIL` | 0 – 1 | How long the image stays on screen behind itself. 1 holds a trail for half a second. See [motion blur](effects.md#motion-blur). |
| `TUNNEL` | -1 – 1 | The picture falls away from the centre, or into it, like a camera that films its own screen. → flies forward, ← backward. **0 is off.** See [the tunnel](effects.md#the-tunnel). |
| `TUNNEL TWIST` | -1 – 1 | How much the tunnel turns as it falls, one way or the other. No effect while `TUNNEL` is 0. |
| `WAVE` | 0 – 1 | The picture ripples, like heat over asphalt or a view through water. **0 is off.** See [the wave](effects.md#the-wave). |
| `WAVE COUNT` | 1 – 16 | How many waves across the height of the screen. |
| `WAVE SPEED` | -1 – 1 | Which way the waves travel, and how fast. 0 holds them still. It follows the global speed. |
| `SLICE` | 0 – 1 | The picture is cut into bands and some of them slide sideways, fringed like a damaged video signal. **0 is off.** See [the slice glitch](effects.md#the-slice-glitch). |
| `SLICE BANDS` | 2 – 40 | How many bands the picture is cut into. |
| `SLICE RATE` | 1 – 30 | How many times a second the tear changes into a new one. It follows the global speed. |
| `ABERRATION` | 0 – 1 | Splits the colour channels at the edges: a red fringe on one side, a blue one on the other. See [chromatic aberration](effects.md#chromatic-aberration). |
| `ABERRATION LENS` | 0 – 1 | 0 moves the channels the same way everywhere. 1 spreads them from the centre, and the middle stays clean. |
| `ABERRATION ANGLE` | 0 – 1 | Which way the channels move apart, once round the dial. No effect at full `LENS`. |

### Audio
The rows run in the order that the ear takes the bands, low to high. That is also the
order that the vu-meter draws them.

| Setting | Range | Effect |
| --- | --- | --- |
| `REACTIVITY` | 0 – 1 | Master amount. **0 by default.** Nothing moves until you ask for it. |
| `PUNCH` | 0 – 1 | Response curve. A higher value pushes the middle down, thus only the hits show. |
| `SPOT ← BASS` | 0 – 12 | The kick drives the spotlight. |
| `HYPERSPACE ← BASS` | 0 – 12 | The kick drives the star field. |
| `SLICE ← BASS` | 0 – 12 | The kick tears the picture with [the slice glitch](effects.md#the-slice-glitch). **0 by default**, and it adds to `SLICE`, so it plays from 0. |
| `ABERRATION ← BASS` | 0 – 12 | The kick opens the [chromatic aberration](effects.md#chromatic-aberration) fringes. **0 by default**, and it adds to `ABERRATION`, so it plays from 0. |
| `LASERS ← MID` | 0 – 12 | Mids drive the laser strokes. |
| `SPHERE ← TREBLE` | 0 – 12 | Treble drives the sphere. |
| `SHUFFLE ← KICK` | 0 – 1 | The kick shuffles the show. **0 by default.** Half way up is about one move a bar. See [the auto-pilot](effects.md#on-the-beat). |

The top of the band ranges is deliberately past good taste. See
[how nervous it is](external-control.md#how-nervous-it-is). A set lives in the middle
of the range.

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
| `AIMING` | AUTO / STICK | `AUTO` hands the beam back on its own. `STICK` keeps it on the gamepad. |
| `TRACKING` | 0.2 – 3 | Beam speed at full stick. See [the gamepad](external-control.md#gamepad). |
| `HAND BACK` | 2 – 120 | Seconds before the automatic sweep takes the beam back. It starts at 30. |

The last three rows only matter with a pad connected. See
[Handing back](external-control.md#handing-back-progressively).

### Lasers
| Setting | Range | Effect |
| --- | --- | --- |
| `COUNT` | 0 – 40 | Number of strokes. The show adds and removes them live. It starts at 3. |
| `WIDTH` | 1 – 24 | Stroke width. |
| `LENGTH` | 0.1 – 2 | **1 crosses the frame** at every resolution. The stroke is two times the diagonal, thus its ends stay outside the frame wherever it goes. At less than 1 the tips come into view, which you now ask for rather than get by accident. |
| `SPIN` | -1 – 1 | ← leftwards, → rightwards. |
| `PARALLEL` | 0 – 1 | 0 is a scatter, 1 is a fan with equal spacing. See [Scanlines](effects.md#scanlines). |
| `SCROLL` | -1 – 1 | Walks that fan sideways. ← one way, → the other. |

### Sphere
| Setting | Range | Effect |
| --- | --- | --- |
| `COUNT` | 0 – 80 | Number of shapes. 0 switches the effect off. It starts at 14. |
| `SIZE` | 0.03 – 0.8 | Size of one shape, in radians on the sphere. |
| `SIDES` | 0 – 12 | 0 draws circles, 3 and above polygons of that many sides. **0 by default.** |
| `RADIUS` | 100 – 800 | Sphere radius on screen. |
| `SPIN` | -1 – 1 | ← leftwards, → rightwards. |
| `DEPTH` | 1.2 – 10 | Eye distance. A small value gives strong perspective. |
| `WIDTH` | 1 – 24 | Shape stroke width. |
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

### Two screens: the console window

With two screens, you do not have to choose between a panel that you can read and a
wall that stays clean. `CONSOLE` at the launcher, or `F4` at any moment, opens a
second window: **the projection keeps this window and loses the panel, and the
console gets the panel with a live picture of the projection behind it.**

The console is the same panel, in the same corner, with the same keys. Only the
screen changes. A thin frame marks the edge of the projection, because the show is
neon on black in a window that is black around it, and where the edge falls is the
one thing the preview exists to answer.

It opens maximised on the screen that the projection is *not* on. On one screen it
opens over the show, which is what a rehearsal at a desk wants. You can move it,
resize it, or put it behind something: it is an ordinary window. Close it with its own
button or with `F4`, and the panel goes back over the projection.

Three habits of the panel change while it is on the console, and all three exist only
because it is normally on the wall:

- it no longer **fades out** after four seconds;
- it no longer **dims** when a phone or a console takes over (`AUTO DIM`);
- `PANEL` `hidden for the whole set` no longer hides it — that row is about the wall,
  and there is no wall here.

The keyboard reaches the window that has the focus. **Both windows answer to every
key**, thus it does not matter which one you clicked last.

The preview costs a second window to draw each frame. On a GPU, measured, the console
open costs about **1.5 ms a frame** at 2560 × 1020; on a machine with no GPU at all it
costs far more, around 14 ms. Make the window smaller if the frame rate matters more
than the size of the preview.

### Arranging the panel

The panel lays itself out by default: the settings that you settle before a set in the
first column, and the instruments beside them. `F6` lets you arrange it yourself.

| Key | In arrange mode |
| --- | --- |
| `↑` `↓` | Choose a section (a click on its name also works) |
| `Shift` + `↑` `↓` | Move the section up or down in its column |
| `←` `→` | Move the section to the column on the left or right. Past the last column, it opens a new one |
| `Enter` | Hide the section, or bring it back |
| `Backspace` | Go back to the automatic layout, with every section shown |
| Mouse | Take a section by its name and drag it. Let go where it must go |
| Double click, or right button | On a name: hide the section, or bring it back. The same as `Enter` |
| `F6` | Done |

A bar shows where the section will land, and shows nothing where letting go would change
nothing. A drag past the last column opens a new column on the right. The right button
cancels a drag that is under way. (`Esc` does not: it quits the show.) A click on a name, without moving,
only chooses the section. The keys and the mouse do the same thing, and you can mix them.

A hidden section stays on screen while you arrange, dimmed, so that you can bring it
back. When you are done it is gone from the panel. **Hiding changes the display and
nothing else.** Its settings still answer to OSC, MIDI, the phone and the presets, and
they stay in the Chataigne module.

Your first move turns the automatic layout into one of your own, starting from what was
on screen. From then on the columns stay where you put them. The panel still scales
itself down when a window is too small, so a layout made on the projector also fits the
[console](#two-screens-the-console-window). `Backspace` gives the automatic layout back.

The arrangement is saved as you make it, in `panel_layout.json` next to the presets. It
is a preference of the operator, not part of a look: a preset does not hold it. It also
does not change the phone page, which has its own order. A projector that shows no panel
(`PANEL` at the launcher) cannot be arranged, because there is nothing to see. Open the
console with `F4` and arrange it there.

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
fell through to a digit, thus the show never saw six slots out of nine.)

### What is and is not saved

A preset holds every setting except `PANEL`, which is a preference rather than part of
a look. A preset recall must not light the panel up on the wall again after the
operator dimmed it deliberately.

A preset saved before a setting existed leaves that setting alone. Thus old presets
continue to work after the project gets new ones.

A slot can also be what the show starts on. See
[starting on a preset](#starting-on-a-preset).

The slots are in `user://presets.json`. On Linux this is
`~/.local/share/godot/app_userdata/Déferlante/`. They belong to the machine, not to
the project. Thus they survive a rebuild, and git does not hold them.

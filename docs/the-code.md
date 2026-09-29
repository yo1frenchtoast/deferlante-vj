# The code

## Structure

```
tests/
  run.sh, run.tscn            Runs every case in cases/ against the real show, headless
  cases/                      One file per part; `test_` methods, no addon
tools/
  build_chataigne_module.py   Regenerates the Chataigne module from the settings
  listen-to-output.sh         Wraps the output's monitor as a source Godot will list
scenes/
  launcher.tscn  Start-up settings, then hands over to main.tscn
  main.tscn      The show: WorldEnvironment + controller + UI
  laser.tscn     One stroke, instanced N times by the controller
chataigne/
  Deferlante/    Chataigne module, ready to install
addons/
  godot-spout/   The Spout GDExtension, DLLs included (Windows exports only)
web/
  index.html     Touch control surface, built from the schema Godot sends
  docs.html      Swagger UI for the REST API, served at /docs
shaders/
  kaleidoscope.gdshader   Polar fold into symmetrical wedges
scripts/
  launcher.gd       The start-up screen, and the relaunch that changes renderer
  launch_config.gd  The `Launch` autoload: user://launch.cfg, read by whoever needs it
  gamepad.gd        Xbox pad: aims the spotlight, drives the rest through VJParam
  lang.gd           On-screen translations, keyed by OSC address
  kaleidoscope.gd   Drives the mirror's full-screen pass
  palette.gd        Color state, shared by reference with the four effects
  vj_controller.gd  Settings declaration, and the wiring of everything below
  param_registry.gd Every setting, in order, found by slug
  show_actions.gd   The one-shots, and the one door they go through
  osc_router.gd     An OSC address in, a setting moved or an action fired
  web_bridge.gd     What the phones are told, and what they may ask for
  launch_surface.gd The start-up tab of the web page
  laser_rig.gd      The strokes, and the settings they inherit
  audio_modulation.gd  What each band of the sound does to which setting
  midi_input.gd     The MIDI device: finding it, choosing its profile
  midi_map.gd       What a controller's controls do — no hardware in it
  midi_control.gd   One line of a profile, typed and checked
  show_dump.gd      Describes the show to a generator, then quits
  vj_param.gd       One setting: bounds, step, application, formatting
  control_panel.gd  Panel: rows, keyboard, auto-hide, FPS readout
  panel_layout.gd   Which section sits in which column, and which are put away
  glitch_circle.gd  The followspot circle (a head that searches) + random glitches
  laser_line.gd     A stroke that spins and bounces off the edges
  halo.gd           The wide additive echoes that stand in for the glow
  osc_server.gd     OSC receiver (UDP), messages and bundles
  web_server.gd     Serves the page and the WebSocket control channel
  rest_api.gd       The /api endpoints and the OpenAPI document
  sphere_circles.gd Circles projected onto a virtual sphere
  hyperspace.gd     A star field rushing past the eye, drawn as streaks
  presets.gd        Nine slots on disk, recalled as a crossfade
  audio_reactor.gd  Captures the output, reads bass / mid / treble
  audio_routing.gd  Points the machine's capture at the output being played
  audio_probe.gd    Meters a source for the launcher, without the engine's help
  autopilot.gd      Moves settings on its own, at the pace you set
  spout_sender.gd   Sends the show out as a Spout source, where the platform allows it
```

The controller is the only script that knows that the others exist. `rest_api.gd`,
`autopilot.gd`, `presets.gd`, `midi_input.gd` and `gamepad.gd` get the `ParamRegistry`
— find a setting, list them all — and are otherwise self-contained. That is what keeps
the controller about a show rather than about JSON.

The show builds the UI at runtime from the list of settings. The scene holds nothing
but an empty `VBoxContainer`, not 51 pairs of nodes to maintain by hand.

The panel also **lays itself out in as many columns as it takes to fit the screen**.
It breaks only between sections, thus it never splits a section in two. It also
balances the columns rather than fills the first one to the brim. The panel grew by one
row per setting, and it had started to run off the bottom of a 1080p screen. This way
it cannot, at any number of settings.

**The panel is grouped by when you touch a setting, not by what it drives.** The first
column holds GLOBAL, COLOR, MIRROR, MOTION BLUR and AUDIO — what you settle before a set
and then
leave alone. The instruments follow: SPOTLIGHT, LASERS, SPHERE, HYPERSPACE. Thus the
hand goes to the same place every night, whatever effects the show has gained since.
The two runs are named in `panel_layout.gd`, and a section in neither list joins the
instruments at the end rather than disappears.

**The operator can rearrange all of this.** `F6` opens an edit mode: sections move up
and down, across columns, and can be put away. `PanelLayout` holds the result and works
on lists of section keys, with no nodes in it, so that its rules are tested without a
screen. The automatic layout is one of its two ways to make a plan, and it is the
algorithm above, unchanged. The first move adopts what was on screen as the operator's
own layout; from then on the columns stay where they were put, and the panel still
scales itself down when a window is too small. Hiding is separate from both, and it is
display only: the settings still answer to OSC, MIDI, the web page and the presets. The
file is `user://panel_layout.json`. A missing or damaged file gives the automatic
layout, because the panel must come up whatever is in there.

The instrument columns are **capped at the height of the first column**, and spread
sideways past it rather than grow taller. Without the cap they make one column as tall
as the screen allows. That is legal, and it puts the top of the panel level with the
help text while the width beside it stays empty. The panel belongs in the bottom band
of the screen, where the hand and the eye both go.

### The console window

`console_window.gd` opens a second, native window and **moves the panel into it**. The
panel is not copied and not rebuilt from a description: it is the same node, reparented
into the other window, thus the two screens can never disagree about what a slider says.
Behind it hangs `ShowViewport`'s own texture — the one the Spout sender has been sending
out for versions — so the preview costs no second render of the show.

Two things do not survive the trip, and both are handled at the seam:

- **The layout.** The column count is measured against the height of the window that
  the panel is in, and the console is a different shape from the projector. The panel
  lays itself out again on every move and on every resize, and scales itself down when
  even that does not fit. It only ever shrinks: a panel blown up to fill a large window
  would be a different instrument from the one the operator used last night.
- **The keyboard.** Input stops at the window that has the focus, and with the console
  open the panel is in one window and the show's nodes are in the other. Thus neither
  window handles keys of its own. Both hand every key to `VJController.route_key()`,
  which offers it to the panel first and then to the show. Either window answers to
  every key, and which one was clicked last does not matter.

`↑` and `↓` walk the panel in the order it reads on screen, which is no longer the
order the settings are declared in.

A setting that only writes a property is one line
(`_prop("spot/pulse", 0, 300, 5, 50.0, circle, "fluctuation_range")`). Only the
settings that need logic get their own function. `VJParam` is the single point that
every change goes through, for the slider, the keyboard and OSC alike. That spares the
rest of the code from knowledge of where a change came from.

## Builds

Every push to `main` builds for **Linux, Windows and Android** on GitHub Actions and
uploads the three as artifacts. A tag such as `v1.0` attaches them to a release.

One Linux runner covers all three. Godot cross-exports from a single headless binary,
thus a matrix of operating systems would buy nothing.

Linux and Windows come out as **one self-contained file** each (`embed_pck=true`).
Android comes out as an APK that carries both `arm64-v8a` and `armeabi-v7a`. The
second one is not legacy padding. The projector that this was last set up on runs
Android 14, reports Vulkan, and still has nothing but `armeabi-v7a` in its ABI list.
An arm64-only APK installs on it perfectly and starts into nothing.

`export_presets.cfg` is committed on purpose, because CI cannot export without it. Its
export paths are relative (`build/linux/…`), thus nothing machine-specific leaks. If
you export locally to somewhere else, change the path in the editor and take care not
to commit it back.

### Android specifics

The build signs the APK with a **throwaway key that it generates during the build**.
That is enough to sideload onto a tablet, and it keeps the build properly optimized. A
release export refuses to run without a release key, and a fallback to a debug build
would cost performance where it is least affordable. It is *not* suitable for a store
listing. That needs a key that you own, added as a repository secret.

The **web control surface and OSC work there too**, because `INTERNET` is set in the
preset. Thus the box can run the visuals while a phone drives them.

`GLOW` was listed here as inert on a tablet, because the mobile renderer draws no 2D
glow. It works now: the halo is ordinary geometry, and the desktop runs the same
renderer as the tablet.

#### Measured on an Android TV projector

A TCL ProjectorC1: Android 14, Mali-G52, 1080p, driven by nothing but the four arrows
and OK on its remote. **60 fps, median 16.6 ms, p95 17.2 ms**, panel hidden, identical
in the debug and release builds. With the panel up it decreases to 30 in places. That
is the posture for setup, not for a set.

To measure it at all, use SurfaceFlinger. `dumpsys gfxinfo` does not see the
SurfaceView of Godot, and F3 never gets to the app.

```
adb shell dumpsys SurfaceFlinger --latency "SurfaceView[<package>/com.godot.game.GodotApp](BLAST)#N"
```

Three things this platform needs that no other does:

- **The gradle build is not optional.** `show_in_android_tv` is silently inert without
  it. The manifest of the prebuilt template carries no `LEANBACK_LAUNCHER` category,
  and Godot cannot patch a new one into a binary manifest. The option is accepted and
  dropped, and the app installs but never appears in the menu of the projector. Only
  `adb` can then start it, which is of no use to somebody who holds a remote. Examine
  the APK rather than the preset:
  `aapt2 dump xmltree <apk> --file AndroidManifest.xml | grep -i leanback`.
- **`rendering_method.mobile`** is what Android reads, not `rendering_method`. Its
  default is Forward Mobile. Thus the engine came up on Vulkan while the saved file
  asked for Compatibility, and the launcher restarted the whole process to settle it.
  That cost fifteen seconds and a black screen on every start. It *worked*, which is
  what made it easy to miss.
- **The show cannot restart itself here.** `OS.create_process` on Android is not a
  second process. It is this activity told to restart itself, and the engine tears the
  fragment down while the GL thread still steps it. The SIGSEGV lands in
  `GodotLib_step` and kills the app before Android can bring it back. Thus the show
  does not restart, it disappears. Measured across repeated presses, with and without
  a quit afterwards and with the render loop stopped first: a clean restart is a coin
  toss. Thus `Launch.can_relaunch()` refuses outright, and the surfaces ask it *before*
  they draw a button.

Two `adb` traps are worth knowing before you lose an hour to either. `adb exec-out
screencap -p` returns a corrupt PNG, because the shell of the device prefixes a line
of its own. Go through a file and `adb pull`. And an export piped into `tail` never
returns, because the gradle daemon holds the pipe open long after the APK is finished
and signed. Redirect to a file instead.

### What CI actually checks, beyond "it exported"

Two things, both chosen because they can go wrong while every build still passes.

**The control page ships through the export *filter*, not through the code.** Thus it
is the one piece that can silently go missing. The workflow starts the Linux build and
fetches `http://127.0.0.1:7331/`. If the page is absent, or the built-in "Page missing"
fallback comes back instead, the build fails.

That check spent some time unable to fail, and the shape of the mistake is worth a
record. It was written as:

```bash
printf '%s' "$page" | grep -q "DÉFERLANTE" || { echo "control page missing"; exit 1; }
```

Under `set -euo pipefail`, `grep -q` exits the moment that it matches. `printf` then
takes an EPIPE for the rest of the page, and `pipefail` reports the pipeline as failed
*because* the pattern was found. It only bites once the page outgrows a pipe buffer,
thus it sat there and passed until the day that the page grew. The "Page missing" check
beside it, written the same way, had never been able to fire at all. Both are `case`
now, which cannot race and does not care about the locale.

**The Chataigne module is generated.** Thus a setting added without a regeneration
leaves the two describing different shows: a knob on the console that drives nothing,
or bounds that have quietly drifted apart. `--check` rebuilds the module from Godot and
fails if what is committed does not match.

The generator also refuses to write a module that is not **level with the show**. That
means every setting, every action, every section of the aimed shuffle, the presets and
the color picker. It makes sure of this both ways. Thus an address that the module
sends and that nothing in Godot answers fails just as loudly. The console is meant to
stay a complete surface rather than a convenient subset, and that promise only holds if
something enforces it.

## Describing the show to other tools

Anything that must know which settings exist asks the show rather than reads it:

```
deferlante --headless -- --dump-params <file>
```

It builds its settings, writes them down and quits without a frame drawn. The file
carries every setting with its bounds, step, default and English name. It also carries
the OSC prefix, the one-shot actions and the number of preset slots. It is English
throughout, like the REST API and for the same reason: what reads it is a program, not
a person who stands in a room.

That is where the Chataigne module comes from. Thus one line in `_build_params()` gives
a new setting all of the following:

- Its slider and its keyboard row on the panel.
- Its OSC address.
- Its REST endpoint.
- Its line on the phone.
- Its command on the console.

It came from regular expressions run over `vj_controller.gd` and `lang.gd` before.
That made the *shape* of a declaration part of the contract, and it left the tool with
lists of its own beside them. One of those lists had drifted in both directions
unnoticed. Six settings that only ever land on whole numbers were offered to the console
as floats. And one named there had not existed in Godot for months. To derive the list
costs a headless run and cannot drift.

## The show has its own viewport

The visuals draw into a `SubViewport` (`ShowLayer` in `main.tscn`), and the panel sits
above it on its own `CanvasLayer`. The projector shows both, one on top of the other.
`SpoutSender` is given the texture of that viewport, thus what leaves the machine is
the show without a slider on it.

The container has to be inside a `CanvasLayer` of its own. A `SubViewportContainer`
put directly under `VJController` — a `Node2D`, not a `CanvasLayer` — draws nothing at
all. `ControlPanel` and the kaleidoscope were already wrapped the same way.

The kaleidoscope keeps its `hint_screen_texture` pass unchanged. It stayed in the same
viewport as the strokes that it folds.

`SpoutSender` never names `SpoutOutput` as a type. It asks `ClassDB` for the class and
stays off where there is none, the same way `audio_routing.gd` guards the other
platform-only surface here. Thus the Linux and Android exports, which never get the
DLLs, load `main.tscn` with nothing missing.

The addon's own OpenGL backend was measured on this project and does not work: it
fails with `Could not get OpenGL texture handle` on every frame. Thus the sender asks
`RenderingServer.get_rendering_device()` first, which is null under Compatibility, and
it starts on Forward+ only.

## A note on the renderer

The project ships **Compatibility** (`gl_compatibility`) and offers Forward+ at the
[launcher](getting-started.md#the-launcher). It is a per-machine decision, not a
project-wide one, because the laptop with a graphics card and the one without want
different answers.

It was Forward+ for everyone before, for one reason: the Compatibility renderer does
not draw 2D glow. That was worth it for as long as the show only ever ran on a machine
with a GPU. It stopped being worth it the day that it had to run on one without.

Measured on llvmpipe at 1080p — a machine with no GPU, in other words — same project
and same show:

| | Forward+ | Compatibility |
| --- | --- | --- |
| at launch | 9.1 ms · 110 fps | **6.8 ms · 147 fps** |
| a busy show, halo off | 13.3 ms · 75 fps | **7.3 ms · 136 fps** |

A factor of two, for a project that draws nothing but lines. Forward+ is a clustered
renderer built for 3D lighting. The show never asks for any of that, and Forward+
charges for the pipeline regardless. The one thing that it did give — 2D glow — now
comes from `scripts/halo.gd` instead, cheaper and on every platform.

Everything else survives the switch unchanged. The screen texture of the kaleidoscope
was the one thing worth a check, and it folds identically.

### Antialiasing

There is no cheap antialiasing here. It is worth a record of exactly how that was
established. Two of the options *look* free, and are free only because they do nothing
at all.

Each one was measured against the same seeded frame, thus the comparison is the same
image with and without. A comparison of two random frames is what made MSAA look like
it worked when it did not.

| | cost, busy show at 1080p in software | what it actually changes |
| --- | --- | --- |
| nothing | 10.3 ms · 97 fps | — |
| `Line2D.antialiased` | free | **0.00 % of pixels** — a no-op under Compatibility |
| MSAA 2D under Compatibility | free | **0.00 % of pixels** — not applied either |
| a permanent faint outline on every stroke | +1.2 ms | staircase unchanged, merely brighter |
| Forward+ with MSAA 2× | 20.0 ms · 50 fps | softened |
| Forward+ with MSAA 4× | 24.0 ms · 42 fps | softened, not removed |
| rendering at 2× and downscaling | 23.3 ms · 43 fps | the cleanest of the lot |

Thus antialiasing costs between two and two-and-a-half times the whole frame budget,
which is exactly what the switch to Compatibility had just won back. On a machine with
a GPU it costs nothing worth counting, which is why the choice belongs at the launcher
rather than in this file.

Note that even MSAA 4× only *softens* the staircase. The strokes are long shallow
diagonals, where a single step spans several pixels. No amount of edge sampling turns
that into a smooth line.

### What is *not* worth optimizing

Measured on the same setup, thus nobody repeats the search:

- **Geometry is free.** A move from 3 strokes to 20, or from 14 circles on the sphere
  to 40, costs **nothing measurable** in software rendering. A wholesale rebuild of the
  `Line2D` point arrays instead of point by point is the obvious first instinct. It buys
  nothing, because that was never where the time went.
- **No script is hot.** Audio analysis, the web server, OSC, the settings panel and
  the gamepad were each disabled in turn. Not one of them moved the frame time.
- **Resolution hardly matters.** 720p instead of 1080p saved 0.5 ms. The cost is not
  fill rate.
- **A drop of the `WorldEnvironment` makes it *slower*** (8.7 ms against 7.3 ms),
  which is the opposite of what you expect. It stays.

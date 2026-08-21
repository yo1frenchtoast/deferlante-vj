# The code

## Structure

```
tools/
  build_chataigne_module.py   Regenerates the Chataigne module from the settings
  listen-to-output.sh         Wraps the output's monitor as a source Godot will list
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
  audio_routing.gd  Points the machine's capture at the output being played
  audio_probe.gd    Meters a source for the launcher, without the engine's help
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
Android as an APK carrying both `arm64-v8a` and `armeabi-v7a`. The second is not
legacy padding: the projector this was last set up on runs Android 14, reports
Vulkan, and still has nothing but `armeabi-v7a` in its ABI list. An arm64-only APK
installs on it perfectly and launches into nothing.

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

The **web control surface and OSC work there too** (`INTERNET` is set in the
preset), so the box can run the visuals while a phone drives them.

`GLOW` used to be listed here as doing nothing on a tablet, because the mobile
renderer draws no 2D glow. It works now — the halo is ordinary geometry, and the
desktop runs the same renderer as the tablet.

#### Measured on an Android TV projector

A TCL ProjectorC1: Android 14, Mali-G52, 1080p, driven by nothing but the four
arrows and OK on its remote. **60 fps, median 16.6 ms, p95 17.2 ms**, panel hidden,
identical in the debug and release builds. With the panel up it drops to 30 in
places — that is the posture for setting up, not for a set.

To measure it at all, use SurfaceFlinger: `dumpsys gfxinfo` does not see Godot's
SurfaceView, and F3 never reaches the app.

```
adb shell dumpsys SurfaceFlinger --latency "SurfaceView[<package>/com.godot.game.GodotApp](BLAST)#N"
```

Three things this platform needs that no other does:

- **The gradle build is not optional.** `show_in_android_tv` is silently inert
  without it: the prebuilt template's manifest carries no `LEANBACK_LAUNCHER`
  category, and Godot cannot patch a new one into a binary manifest. The option is
  accepted and dropped, and the app installs but never appears in the projector's
  menu — only `adb` can start it, which is no use to somebody holding a remote.
  Check the APK rather than the preset:
  `aapt2 dump xmltree <apk> --file AndroidManifest.xml | grep -i leanback`.
- **`rendering_method.mobile`** is what Android reads, not `rendering_method`. Its
  default is Forward Mobile, so the engine came up on Vulkan while the saved file
  asked for Compatibility, and the launcher relaunched the whole process to settle
  it — fifteen seconds and a black screen on every start. It *worked*, which is
  what made it easy to miss.
- **The show cannot restart itself here.** `OS.create_process` on Android is not a
  second process: it is this activity being told to restart itself, and the engine
  tears the fragment down while the GL thread is still stepping it. The SIGSEGV
  lands in `GodotLib_step` and kills the app before Android can bring it back, so
  the show does not restart — it vanishes. Measured across repeated presses, with
  and without quitting afterwards and with the render loop stopped first: a clean
  restart is a coin toss. `Launch.can_relaunch()` therefore refuses outright, and
  the surfaces ask it *before* drawing a button.

Two `adb` traps worth knowing before losing an hour to either. `adb exec-out
screencap -p` returns a corrupt PNG, because the device's shell prefixes a line of
its own — go through a file and `adb pull`. And an export piped into `tail` never
returns: the gradle daemon holds the pipe open long after the APK is finished and
signed, so redirect to a file instead.

### What CI actually checks, beyond "it exported"

Two things, both chosen because they can go wrong while every build still passes.

**The control page ships through the export *filter*, not through the code**, so it
is the one piece that can silently go missing. The workflow launches the Linux build
and fetches `http://127.0.0.1:7331/`; if the page is absent, or the built-in "Page
missing" fallback comes back instead, the build fails.

That check spent some time being incapable of failing, and the shape of the mistake
is worth keeping. It was written as:

```bash
printf '%s' "$page" | grep -q "DÉFERLANTE" || { echo "control page missing"; exit 1; }
```

Under `set -euo pipefail`, `grep -q` exits the moment it matches, `printf` takes an
EPIPE for the rest of the page, and `pipefail` then reports the pipeline as failed
*because* the pattern was found. It only bites once the page outgrows a pipe buffer,
so it sat there passing until the day the page grew — and the "Page missing" check
beside it, written the same way, had never been able to fire at all. Both are `case`
now, which cannot race and does not care about the locale.

**The Chataigne module is generated**, so a setting added without regenerating it
leaves the two describing different shows: a knob on the console that drives
nothing, or bounds that have quietly drifted apart. `--check` rebuilds it from Godot
and fails if what is committed does not match.

The generator also refuses to write a module that is not **level with the show** —
every setting, every action, every section of the aimed shuffle, the presets and the
colour picker — checked both ways, so an address the module sends that nothing in
Godot answers fails just as loudly. The console is meant to stay a complete surface
rather than a convenient subset, and that is the sort of promise which only holds if
something enforces it.

## Describing the show to other tools

Anything that needs to know what settings exist asks the show rather than reading
it:

```
deferlante --headless -- --dump-params <file>
```

It builds its settings, writes them down and quits without drawing a frame. The file
carries every setting with its bounds, step, default and English name, plus the OSC
prefix, the one-shot actions and how many preset slots there are. English throughout,
like the REST API and for the same reason: what reads it is a program, not a person
standing in a room.

That is where the Chataigne module comes from, and adding a setting therefore adds
its slider, its keyboard row, its OSC address, its REST endpoint, its line on the
phone *and* its console command — all from the one line in `_build_params()`.

It used to come from regular expressions run over `vj_controller.gd` and `lang.gd`,
which made the *shape* of a declaration part of the contract, and left the tool
keeping lists of its own beside them. One of those lists had drifted in both
directions unnoticed: six settings that only ever land on whole numbers were being
offered to the console as floats, and one named there had not existed in Godot for
months. Deriving costs a headless run and cannot drift.

## A note on the renderer

The project ships **Compatibility** (`gl_compatibility`) and offers Forward+ at the
[launcher](getting-started.md#the-launcher). It is a per-machine decision, not a project-wide one: the
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

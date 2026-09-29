# Developing

How the pieces fit, how to add to them, and how to see what is going on. For the
measurements and the decisions behind the code — why Compatibility, why no
antialiasing, what the projector needs — see [the code](the-code.md).

## The shape of it

One idea holds the project together: **you declare a setting once, and every surface
derives from that declaration.** One line in `_build_params()` of
`scripts/vj_controller.gd` creates all of the following:

- A row in the on-screen panel, with its keyboard navigation.
- An OSC address, plus its normalized `0..1` twin.
- A REST endpoint, and its entry in the OpenAPI specification.
- A slider on the web surface.
- A command in the Chataigne module, after you regenerate it.

That is the property to protect. Anything that must know which settings exist has to
derive that list, and never keep a copy. The failure mode of a copy is silence, and
this project has already been bitten by one. See [Describing the
show](the-code.md#describing-the-show-to-other-tools).

### Who knows whom

```
                    ┌─────────────────┐
   keyboard ───────▶│                 │
   gamepad  ───────▶│    VJParam      │──── changed ──▶ panel row
   OSC      ───────▶│  set_value()    │                 web surface
   REST     ───────▶│                 │──── _apply ───▶ the effect itself
   web      ───────▶└─────────────────┘
```

`vj_controller.gd` is the only script that knows that the others exist. It declares
the settings into a `ParamRegistry`, builds the small objects that do the work, and
hands each collaborator what it needs. `rest_api.gd`, `presets.gd`, `autopilot.gd`,
`midi_input.gd` and `gamepad.gd` get the registry. None of them can reach back, which
is what keeps the controller about a show rather than about JSON.

What the controller builds, and where each one lives:

| Object | Does |
| --- | --- |
| `ParamRegistry` | Holds the settings in declaration order. Finds one by slug. |
| `ShowActions` | The one-shots, and the one door they go through: `fire(name)`. |
| `OscRouter` | An OSC address in, a setting moved or an action fired. |
| `WebBridge` | The schema, the values that moved, the meter, and what a phone may ask for. |
| `LaunchSurface` | The start-up tab of the web page: describes it, applies a change. |
| `LaserRig` | The strokes, the settings they inherit, and the fan's angle. |
| `AudioModulation` | What each band of the sound does to which setting. |
| `MidiMap` | What a controller's controls do. No hardware in it. |
| `ShowDump` | Describes the show to a generator, then quits. |

All of these except the last one are plain objects (`RefCounted`) that take what they
need in their constructor. That is deliberate: you can build one in a test with
stand-ins, and you cannot forget to give it something. A `Callable` made from a method
of a `RefCounted` does **not** keep that object alive, so whoever binds one must also
hold the object in a variable.

The effects (`glitch_circle.gd`, `laser_line.gd`, `sphere_circles.gd`,
`kaleidoscope.gd`, `halo.gd`) know nothing about settings at all. They expose
properties and methods, and the controller points settings at them.

### VJParam is the one door

Every change goes through `VJParam.set_value()` — slider, key press, OSC packet, HTTP
request, and phone. It clamps to the bounds, it snaps to the step, it applies the
value, and it emits `changed`. Nothing downstream has to know where a change came
from, and nothing upstream has to know who listens.

The `slug` is the stable identity, and it becomes the OSC address. Thus **a new label
can never break a console that is already wired to an address**. The words are in
`Lang.LABELS`, keyed by that same slug.

## Recipes

### Add a setting

Two edits, then regenerate.

1. Write a line in `_build_params()`. If it only writes a property on a node, use
   `_prop`. If it needs logic, use `_fn` and give it a function.

   ```gdscript
   _prop("sphere/wobble", 0, 100, 1, 10.0, sphere, "wobble_amount")
   _fn("global/tempo", 20, 240, 1, 120.0, _set_tempo)
   ```

   Both are `(slug, min, max, step, default, …, signed = false)`. Pass `true` for
   `signed` when the sign means a *direction* rather than a smaller number. The panel
   then shows an arrow, which reads at a glance in the dark.

   `_prop` writes through `Object.set()`, which **fails silently on a property that
   does not exist**. This was measured: no error, no warning, and `get()` comes back
   null. A typo there gives you a slider that moves and drives nothing. It is the one
   fault in this list that looks like a broken effect rather than a misspelled
   setting.

2. Write its words in `Lang.LABELS`, English first and French second:

   ```gdscript
   "sphere/wobble": ["WOBBLE", "OSCILLATION"],
   ```

   English is first in every table because the source is English throughout.
   Which tongue the operator meets first is a different question, and `Lang.ORDER`
   answers it: the launcher still lists FRANÇAIS at the top.

   A missing label falls back to the slug rather than crashes. Thus you can try a
   setting out before you name it, but it reads `sphere/wobble` on screen and in the
   Chataigne command.

3. Run `python3 tools/build_chataigne_module.py`, and commit what it writes. CI fails
   if you forget.

Both helpers return the `VJParam`, thus you can refine anything unusual on the spot:

```gdscript
var mode := _fn("color/mode", 0, 1, 1, 0.0, _set_color_mode)
mode.choices = PackedStringArray(["mode.random", "mode.manual"])   # Lang keys
mode.randomizable = false                                          # auto-pilot keeps off
_fn("color/red", 0, 1, 0.02, 1.0, _set_channel.bind(0)).tint = Color(1, 0.45, 0.4)
```

Use `randomizable = false` for anything that is a decision about the room or the
track — glow, saturation, tempo — rather than a variation to play with.

### Add a section

Write `_section("section.sphere")` before the settings that belong to it, and put the
key in `Lang.TEXTS`. Sections are panel groupings and Chataigne menus. The panel breaks
into columns between them and never splits one in two.

### Add a one-shot action

Actions are not settings. They have no value, they only happen. This one costs three
edits, because the wiring is genuinely per-surface.

1. Name it in `ShowActions.LIST`, and give it a `match` arm in `ShowActions.fire()`.
   The REST specification, the web page, the MIDI profiles and the Chataigne module
   all read that list, thus none of them can advertise something that the show does
   not have.
2. Add its label to `Lang.TEXTS` as `action.<name>`.
3. Wire its OSC address in `OscRouter.handle()`.

The web page and the REST API need no edit: they go through `ShowActions.fire()`.

The show then generates the Chataigne command. If you want it to read as something
other than its slug on the console, add a line to `ACTION_NAMES` in the generator.
That table exists to *keep* names that people have already mapped, not to invent them.

### Add a start-up setting

This one is expensive, and deliberately so. These are the few things that Godot fixes
before a script runs, or binds before anything can listen. To add one, edit four
places: `launch_config.gd` (the variable, plus `load_from_disk()` and `save()`),
`lang.gd`, the row of the launcher in `launcher.gd`, and the controller. In
`launch_surface.gd`, edit `describe()` and `apply()` so that the web tab offers the
setting too.

If a setting *can* live among the ordinary ones, put it there. A setting that you
cannot reach in the middle of a set is of no use.

### Add an effect

Give it a scene and a script that exposes plain properties. Add it to `main.tscn`.
Then point settings at it from `_build_params()`. It must not import anything about
settings, OSC or the panel. If it needs the palette, take it by reference like the
others (`use_palette`).

To make it react to sound, add an entry to `AudioModulation._build()`: a slug, a band
(`BASS` / `MID` / `TREBLE`), the amount that governs it, a weight, and a setter.

## Releases

A push to `main` builds and checks. A **tag** that starts with `v` builds the three
exports again and attaches them to a GitHub release. So a release is: change the version,
push, tag, write the notes.

1. In `export_presets.cfg`, in the Android preset, set `version/name` and `version/code`.
2. Commit it as `Call the next build 1.10.1` and push `main`.
3. Tag it, `git tag v1.10.1`, and push the tag. Watch the run: the release appears when it
   ends, with the four files.
4. Write the notes on the release, with the title `v1.10.1`, the same as the tag.

### Minor and patch versions

- **A minor version (`1.11`)** is for a new feature, or anything that changes what an
  operator sees or has to learn again. Automatic layouts are the example: if the panel
  does not look the same when you install it, it is a minor version, and the notes say so
  in their first lines.
- **A patch version (`1.10.1`)** is for a fix, or for a small addition that stands on its
  own and changes nothing that was already there: a new gesture, a corrected behaviour. A
  show saved with the version before it comes up the same. You can install it over the top
  without reading anything first, and the notes say only what changed. It can come out
  alone, the day it is needed, so there is no reason to keep a fix waiting for a feature.
- **Not every commit is a release.** A change to the tests, the documentation or the
  tooling alone does not need one. A patch is worth cutting when somebody who downloads the
  release gets something out of it.

The Android `version/code` has to grow with every release, and that is all it has to do.
It has been `major × 100 + minor × 10 + patch` (`1.4.1` is 141, `1.10` is 200). Add **1**
for a patch and **10** for a minor version, and round up to the next hundred for a major
one, so that it never goes down.

## The pictures of the README

The two clips and the still at the top of the README are played by the show itself, and not
filmed. They come from three small scenes in `tools/demo/`:

```
tools/make_demo.sh                  # the opening clip, docs/demo.gif
tools/make_demo.sh kaleidoscope     # the second clip, docs/kaleidoscope.gif
tools/make_demo.sh screenshot       # the still, docs/screenshot.png
tools/make_demo.sh all
```

Each scene sets the show up and then does something at chosen times, and the script films
it with `--write-movie` and turns the frames into a GIF. Two things to know before you
change one:

- **Every beat is a timer or a tween on game time.** A movie is rendered on its own clock,
  and a script that drives the show over HTTP drifts. It drifted by eight seconds against a
  fifteen-second plan the first time.
- **A GIF pays for every pixel that changes.** The picture is strokes on black, so the black
  is what makes it cheap. The wave and the tunnel change almost every pixel, and the first
  take of the opening clip was 13 MB. The clip is kept short, at 8 frames a second and with
  few strokes, and it is 5 MB. Check the size before you commit one: GitHub loads it every
  time somebody opens the page.

`sphere/count` cannot be swept in a scene, because its setter rebuilds every circle and the
sphere renders as nothing. Step it once.

If you change the recipe under the second clip in the README, change
`tools/demo/kaleidoscope.gd` with it.

## Tests

```
tests/run.sh                        # all of them; needs `godot` on the PATH
tests/run.sh --only=test_osc        # one file
```

With Flatpak: `GODOT="flatpak run --command=godot org.godotengine.Godot" tests/run.sh`.

The cases in `tests/cases/` run the real show headless. There is no test addon to
install, and the CI runs the same script before the exports. A file is a class that
extends `TestCase`, and a method named `test_…` is a test. Declare
`const NEEDS_SHOW := false` in a file that builds its own objects, so that it cannot
depend on the show by accident.

What they hold in place:

- The settings: unique slugs, a label in both languages, a section, and every string
  in the code that *looks like* a slug must be one. `param()` answers null for a typo,
  and the compiler cannot see that a string is an address.
- The surfaces that write to a setting: OSC, REST and the web bridge.
- The MIDI behaviour (takeover, toggles, held pads), with no controller plugged in.
- The MIDI profiles, against the settings, and the checker's lists against the
  engine's.

To check a refactor that must change nothing, photograph the show before and after
and compare: `tests/run.sh --only=zz_snapshot --snap=/tmp/before.json`. The seed is
fixed, so two photographs of the same code are identical.

## Running it

From the editor, press F5. From a terminal, a headless run is usually what you want,
because it starts the servers without a screen:

```
godot --headless --path .                       # from source
./build/linux/deferlante.x86_64 --headless      # from an export
```

`--headless` skips the launcher on its own, because there is nobody to answer it. To
skip it with a window, pass `-- --skip-launcher`. After a bare `--`, Godot stops
interpreting and gives the rest to the project.

**The ports are the trap.** The show binds 7331 (page), 7332 (WebSocket) and 9000
(OSC). A copy that still runs in the editor holds them. The second copy warns
`cannot listen on ports 7331/7332` and then quietly serves nothing. The *first* one
continues to answer your requests, with its own older copy of the page. When something
that you just changed does not appear, examine that first:

```
ss -tlnp | grep 7331
```

## Debugging

### Poking it from a terminal

```
curl -s localhost:7331/api/params | python3 -m json.tool | head
curl -s -X PUT localhost:7331/api/params/global/chaos -d '{"value": 0.4}'
curl -s -X POST localhost:7331/api/actions/glitch
```

The API answers in English whatever language the screen is in. The page and the panel
follow the launcher. That is on purpose: nobody can write a client against a
specification whose labels change with the room.

`/docs` serves Swagger against the live show, which is the fastest way to see what the
endpoints do.

### Asking what settings exist

```
godot --headless --path . -- --dump-params /some/where/params.json
```

This builds the settings, writes them down and quits without a frame drawn. It is what
the Chataigne generator consumes. It is also a quick way to make sure that a new
setting came out with the bounds that you meant.

### On an Android device

```
adb connect <ip>:5555
adb install -r build/android/deferlante-release.apk
adb shell monkey -p org.deferlante.vj -c android.intent.category.LAUNCHER 1
adb logcat -s godot                       # push_error / push_warning land here
adb shell input keyevent DPAD_DOWN        # the remote, from your desk
```

Screenshots need a file. `adb exec-out screencap -p` comes back corrupt, because the
shell of the device prints a line of its own first.

```
adb shell screencap -p /sdcard/s.png && adb pull /sdcard/s.png
```

If the show binds to loopback there, `adb forward tcp:8331 tcp:7331` cannot get to it.
The show listens on the address of the device, not on `127.0.0.1`. Read
`/proc/net/tcp` to see which one, or point curl at the IP of the device.

Frame times: `dumpsys gfxinfo` does not see the SurfaceView of Godot, and F3 never
gets to the app. Use SurfaceFlinger, second column, differences between rows. See
[the code](the-code.md#android-specifics).

### Things that have wasted an afternoon

- **The flatpak build of Godot cannot see the `/tmp` of the host.** Write anywhere
  under `~/Godot/` instead. This silently produces "no output file" rather than an
  error.
- **An export piped into `tail` never returns.** The gradle daemon holds the pipe open
  long after the APK is finished and signed. Redirect to a file.
- **`pkill -f deferlante` kills your own shell**, whose command line holds the
  pattern. Match on the process name instead: `ps -eo pid,comm`.
- **A new `class_name` needs a re-import** before anything else can parse it:
  `godot --headless --path . --import`.

## Before pushing

```
godot --headless --path . --import                      # resolves .uid files
python3 tools/build_chataigne_module.py --check          # module still current?
```

CI runs on every push. It exports Linux, Windows and Android, and it makes sure that
the module matches the settings. It also starts the Linux build to make sure that the
build serves the control page. That page ships through the export *filter* rather than
through the code. Thus it is the one piece that can go missing while every build
passes.

Commit messages here explain the *why*, and say what was measured. The history is
meant to read as an account of the decisions, not as a list of changes.

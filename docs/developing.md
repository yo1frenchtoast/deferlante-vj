# Developing

How the pieces fit, how to add to them, and how to see what is going on. For the
measurements and the decisions behind the code — why Compatibility, why no
antialiasing, what the projector needs — see [the code](the-code.md).

## The shape of it

One idea holds the project together: **a setting is declared once, and every
surface derives from that declaration.** Adding a line to `_build_params()` in
`scripts/vj_controller.gd` creates, without another edit anywhere:

- a row in the on-screen panel, with its keyboard navigation
- an OSC address, plus its normalised `0..1` twin
- a REST endpoint, and its entry in the OpenAPI spec
- a slider on the web surface
- a command in the Chataigne module, once regenerated

That is the property to protect. Anything that needs to know what settings exist
should derive it, never keep a copy — the failure mode of a copy is silence, and
this project has already been bitten by one (see [Describing the
show](the-code.md#describing-the-show-to-other-tools)).

### Who knows whom

```
                    ┌─────────────────┐
   keyboard ───────▶│                 │
   gamepad  ───────▶│    VJParam      │──── changed ──▶ panel row
   OSC      ───────▶│  set_value()    │                 web surface
   REST     ───────▶│                 │──── _apply ───▶ the effect itself
   web      ───────▶└─────────────────┘
```

`vj_controller.gd` is the only script that knows the others exist. It declares the
settings, spawns the lasers, and hands each collaborator the few callables it
needs — `rest_api.gd` gets "find a setting, list them all, describe one";
`presets.gd` gets "give me the parameters"; `autopilot.gd` gets an amount. None of
them can reach back, which is what keeps the controller about running a show rather
than about serving JSON.

The effects (`glitch_circle.gd`, `laser_line.gd`, `sphere_circles.gd`,
`kaleidoscope.gd`, `halo.gd`) know nothing about settings at all. They expose
properties and methods; the controller points settings at them.

### VJParam is the one door

Every change goes through `VJParam.set_value()` — slider, keypress, OSC packet,
HTTP request, phone. It clamps to the bounds, snaps to the step, applies, and emits
`changed`. Nothing downstream has to know where a change came from, and nothing
upstream has to know who is listening.

The `slug` is the stable identity. It becomes the OSC address, so **rewording a
label can never break a console already wired to one** — the words live in
`Lang.LABELS`, keyed by that same slug.

## Recipes

### Add a setting

Two edits, then regenerate.

1. A line in `_build_params()`. If it only writes a property on a node, use
   `_prop`; if it needs logic, use `_fn` and give it a function.

   ```gdscript
   _prop("sphere/wobble", 0, 100, 1, 10.0, sphere, "wobble_amount")
   _fn("global/tempo", 20, 240, 1, 120.0, _set_tempo)
   ```

   Both are `(slug, min, max, step, default, …, signed = false)`. Pass `true` for
   `signed` when the sign means a *direction* rather than a smaller number: the
   panel then shows an arrow, which reads at a glance in the dark.

   `_prop` writes through `Object.set()`, which **fails silently on a property
   that does not exist** — verified: no error, no warning, and `get()` comes back
   null. A typo there gives you a slider that moves and drives nothing, which is
   the one bug in this list that looks like an effect being broken rather than a
   setting being misspelled.

2. Its words in `Lang.LABELS`, French first, English second:

   ```gdscript
   "sphere/wobble": ["OSCILLATION", "WOBBLE"],
   ```

   A missing label falls back to the slug rather than crashing — so a setting can
   be tried out before it is named, but it will read `sphere/wobble` on screen and
   in the Chataigne command.

3. `python3 tools/build_chataigne_module.py`, and commit what it writes. CI fails
   if you forget.

Both helpers return the `VJParam`, so anything unusual is refined on the spot:

```gdscript
var mode := _fn("color/mode", 0, 1, 1, 0.0, _set_color_mode)
mode.choices = PackedStringArray(["mode.random", "mode.manual"])   # Lang keys
mode.randomizable = false                                          # auto-pilot keeps off
_fn("color/red", 0, 1, 0.02, 1.0, _set_channel.bind(0)).tint = Color(1, 0.45, 0.4)
```

`randomizable = false` is for anything that is a decision about the room or the
track — glow, saturation, tempo — rather than a variation to be played with.

### Add a section

`_section("section.sphere")` before the settings that belong to it, and the key in
`Lang.TEXTS`. Sections are panel groupings and Chataigne menus; the panel breaks
into columns between them and never splits one in two.

### Add a one-shot action

Actions are not settings — they have no value, they just happen. This one costs
three edits, because the wiring is genuinely per-surface:

1. Name it in `ACTIONS` at the top of the controller. The REST spec and the
   Chataigne module both read that list, so neither can advertise something the
   show does not have.
2. Wire it in `_on_web_action()`, in the `match`.
3. Wire its OSC address in `_on_osc_message()`.

The Chataigne command is then generated. If you want it to read as something other
than its slug on the console, add a line to `ACTION_NAMES` in the generator —
that table exists to *preserve* names people have already mapped, not to invent
them.

### Add a start-up setting

The expensive one, and deliberately so: these are the handful of things Godot
fixes before a script runs or binds before anything can listen. Adding one touches
`launch_config.gd` (the variable, plus `load_from_disk()` and `save()`),
`lang.gd`, the launcher's row in `launcher.gd`, and `_describe_launch()` +
`_on_web_launch_set()` in the controller so the web tab offers it too.

If a setting *can* live among the ordinary ones, it should. A setting you cannot
reach mid-set may as well not exist.

### Add an effect

Give it a scene and a script that exposes plain properties, add it to
`main.tscn`, then point settings at it from `_build_params()`. It should not
import anything about settings, OSC or the panel. If it needs the palette, take it
by reference like the others (`use_palette`).

To make it react to sound, add an entry to `_build_modulations()`: a slug, a band
(`BASS` / `MID` / `TREBLE`), which amount governs it, a weight, and a setter.

## Running it

From the editor, F5. From a terminal, a headless run is usually what you want,
because it starts the servers without taking over a screen:

```
godot --headless --path .                       # from source
./build/linux/deferlante.x86_64 --headless      # from an export
```

`--headless` skips the launcher on its own (there is nobody to answer it). To skip
it with a window, pass `-- --skip-launcher`: after a bare `--`, Godot stops
interpreting and hands the rest to the project.

**The ports are the trap.** The show binds 7331 (page), 7332 (WebSocket) and 9000
(OSC). A copy still running in the editor holds them, and the second one warns
`cannot listen on ports 7331/7332` and then quietly serves nothing — while the
*first* one keeps answering your requests, with its own older copy of the page.
When something you just changed does not show up, check that first:

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

The API answers in English whatever language the screen is in; the page and the
panel follow the launcher. That is on purpose — a spec whose labels change with
the room is one nobody can write a client against.

`/docs` serves Swagger against the live show, which is the fastest way to see what
the endpoints do.

### Asking what settings exist

```
godot --headless --path . -- --dump-params /some/where/params.json
```

Builds the settings, writes them down and quits without drawing a frame. That is
what the Chataigne generator consumes, and it is a quick way to check that a new
setting came out with the bounds you meant.

### On an Android device

```
adb connect <ip>:5555
adb install -r build/android/deferlante-release.apk
adb shell monkey -p org.deferlante.vj -c android.intent.category.LAUNCHER 1
adb logcat -s godot                       # push_error / push_warning land here
adb shell input keyevent DPAD_DOWN        # the remote, from your desk
```

Screenshots need a file: `adb exec-out screencap -p` comes back corrupt, because
the device's shell prints a line of its own first.

```
adb shell screencap -p /sdcard/s.png && adb pull /sdcard/s.png
```

If the show binds to loopback there, `adb forward tcp:8331 tcp:7331` will not
reach it — it is listening on the device's own address, not on `127.0.0.1`. Read
`/proc/net/tcp` to see which, or just point curl at the device's IP.

Frame times: `dumpsys gfxinfo` does not see Godot's SurfaceView, and F3 never
reaches the app. Use SurfaceFlinger, second column, differences between rows —
see [the code](the-code.md#android-specifics).

### Things that have wasted an afternoon

- **The flatpak build of Godot cannot see the host's `/tmp`.** Write anywhere
  under `~/Godot/` instead. This silently produces "no output file" rather than an
  error.
- **An export piped into `tail` never returns.** The gradle daemon keeps the pipe
  open long after the APK is finished and signed. Redirect to a file.
- **`pkill -f deferlante` kills your own shell**, whose command line contains the
  pattern. Match on the process name instead: `ps -eo pid,comm`.
- **Adding a `class_name` needs a re-import** before anything else will parse it:
  `godot --headless --path . --import`.

## Before pushing

```
godot --headless --path . --import                      # resolves .uid files
python3 tools/build_chataigne_module.py --check          # module still current?
```

CI runs on every push: it exports Linux, Windows and Android, checks the module
against the settings, and launches the Linux build to confirm it actually serves
the control page — that page ships through the export *filter* rather than through
the code, so it is the one piece that can go missing while every build passes.

Commit messages here explain the *why*, and say what was measured. The history is
meant to be readable as an account of the decisions, not as a list of changes.

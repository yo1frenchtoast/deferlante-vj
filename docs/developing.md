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
the settings, it spawns the lasers, and it hands each collaborator the few callables
that it needs. `rest_api.gd` gets "find a setting, list them all, describe one".
`presets.gd` gets "give me the parameters". `autopilot.gd` gets an amount. None of
them can reach back, which is what keeps the controller about a show rather than about
JSON.

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

1. Name it in `ACTIONS` at the top of the controller. The REST specification and the
   Chataigne module both read that list, thus neither can advertise something that the
   show does not have.
2. Wire it in `_on_web_action()`, in the `match`.
3. Wire its OSC address in `_on_osc_message()`.

The show then generates the Chataigne command. If you want it to read as something
other than its slug on the console, add a line to `ACTION_NAMES` in the generator.
That table exists to *keep* names that people have already mapped, not to invent them.

### Add a start-up setting

This one is expensive, and deliberately so. These are the few things that Godot fixes
before a script runs, or binds before anything can listen. To add one, edit four
places: `launch_config.gd` (the variable, plus `load_from_disk()` and `save()`),
`lang.gd`, the row of the launcher in `launcher.gd`, and the controller. In the
controller, edit `_describe_launch()` and `_on_web_launch_set()` so that the web tab
offers the setting too.

If a setting *can* live among the ordinary ones, put it there. A setting that you
cannot reach in the middle of a set is of no use.

### Add an effect

Give it a scene and a script that exposes plain properties. Add it to `main.tscn`.
Then point settings at it from `_build_params()`. It must not import anything about
settings, OSC or the panel. If it needs the palette, take it by reference like the
others (`use_palette`).

To make it react to sound, add an entry to `_build_modulations()`: a slug, a band
(`BASS` / `MID` / `TREBLE`), the amount that governs it, a weight, and a setter.

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

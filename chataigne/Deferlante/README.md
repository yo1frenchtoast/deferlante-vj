# Chataigne module — Deferlante

Drives the [Deferlante](../../README.md) visuals from
[Chataigne](https://github.com/benkuper/Chataigne) over OSC.

## Install

1. Copy the `Deferlante/` folder (the one that holds `module.json`) into the modules
   folder of Chataigne:

   | System | Path |
   | --- | --- |
   | Linux | `~/Documents/Chataigne/modules/` |
   | Windows | `C:\\Users\\<name>\\Documents\\Chataigne\\modules\\` |
   | macOS | `~/Documents/Chataigne/modules/` |

   Look at where your existing modules already are. That is the folder, not another
   one.
2. Restart Chataigne.
3. Select **Add Module → Software → Deferlante**.

> NOTE: If Chataigne freezes when it creates a new project, delete the `Deferlante/`
> folder and restart. The crash seen on one machine came from a different module whose
> thread refused to stop, but it is worth ruling this one out first.

## Configure

The module defaults to `127.0.0.1:9000`, which works as it is when Chataigne and Godot
run on the same machine. Otherwise, set `remoteHost` to the IP of the machine that
shows the visuals, and make sure that nothing blocks UDP port 9000.

On the Godot side, the port is on the `OscServer` node in `scenes/main.tscn`.

## Use

Every setting is a command, filed by menu (Global, Color, Mirror, Lasers, Spotlight,
Sphere), with the **same bounds as the on-screen sliders**. Thus a Chataigne mapping
sweeps exactly the same range, with no conversion.

Every command carries `mappingIndex: 0`, thus you can use it directly as the target of
a Mapping, an LFO, a MIDI fader or an audio follower.

Two commands are in the **Actions** menu: `Trigger Glitch` and `Randomize Colors`.
`Color Picker`, in the Color menu, is a real color picker that sends its three
components in one message.

Two settings are worth an automation. **Global Chaos** is a single fader that takes the
scene from tidy to overflowing. **Mirror Effect** opens and closes the kaleidoscope.

For audio reactivity, the **Audio** module of Chataigne does the spectral analysis, and
its bands map straight onto any of these commands. There is nothing to add on the Godot
side.

## Without this module

The module is a convenience. Godot listens for plain OSC, thus any sender will do: the
generic OSC module of Chataigne, TouchOSC, or a script. The addresses are documented in
[docs/external-control.md](../../docs/external-control.md#external-control-over-osc).

## This module is generated

Do not edit it by hand. `tools/build_chataigne_module.py` produces it from the list of
settings of Godot. After you add a setting, run:

```
python3 tools/build_chataigne_module.py
```

Two format rules are encoded in it, learned by breaking things. Every command needs a
**non-empty** `parameters` block. And an OSC module declares `hasInput: true` with an
`OSC Input` section even when that section is disabled. No module that works departs
from either rule.

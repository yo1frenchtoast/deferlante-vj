# Chataigne module — Deferlante

Drives the [Deferlante](../../README.md) visuals from
[Chataigne](https://github.com/benkuper/Chataigne) over OSC.

## Install

Copy the `Deferlante/` folder (the one holding `module.json`) into Chataigne's
modules folder:

| System | Path |
| --- | --- |
| Linux | `~/Documents/Chataigne/modules/` |
| Windows | `C:\\Users\\<name>\\Documents\\Chataigne\\modules\\` |
| macOS | `~/Documents/Chataigne/modules/` |

Check where your existing modules already live: that is the folder, not another one.

Restart Chataigne, then **Add Module → Software → Deferlante**.

> **If Chataigne freezes when creating a new project**, delete the `Deferlante/`
> folder and restart. The crash seen on one machine actually came from a different
> module whose thread refused to stop, but it is worth ruling this one out first.

## Configure

The module defaults to `127.0.0.1:9000`, which works as-is when Chataigne and Godot
run on the same machine. Otherwise set `remoteHost` to the IP of the machine showing
the visuals, and check that UDP port 9000 is not blocked.

On the Godot side the port lives on the `OscServer` node in `scenes/main.tscn`.

## Use

Every setting is a command, filed by menu (Global, Color, Mirror, Lasers, Spotlight,
Sphere), with the **same bounds as the on-screen sliders**: a Chataigne mapping
sweeps exactly the same range, with no conversion.

Every command carries `mappingIndex: 0`, so they can be used directly as the target
of a Mapping, an LFO, a MIDI fader or an audio follower.

Two commands sit in the **Actions** menu: `Trigger Glitch` and `Randomize Colors`.
`Color Picker`, in the Color menu, is a real colour picker that sends its three
components in one message.

Two settings are worth automating: **Global Chaos**, a single fader that takes the
scene from tidy to overflowing, and **Mirror Effect**, which opens and closes the
kaleidoscope.

For audio reactivity, Chataigne's **Audio** module does the spectral analysis and its
bands map straight onto any of these commands — nothing to add on the Godot side.

## Without this module

The module is a convenience. Godot listens for plain OSC, so any sender will do —
Chataigne's generic OSC module, TouchOSC, a script. The addresses are documented in
[docs/external-control.md](../../docs/external-control.md#external-control-over-osc).

## This module is generated

Do not edit it by hand: it is produced by `tools/build_chataigne_module.py` from
Godot's list of settings. After adding a setting:

```
python3 tools/build_chataigne_module.py
```

Two format rules are encoded in it, learned by breaking things: every command needs
a **non-empty** `parameters` block, and an OSC module declares `hasInput: true` with
an `OSC Input` section even when disabled. No module that works departs from either.

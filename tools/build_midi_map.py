#!/usr/bin/env python3
"""Check the MIDI profiles against the show, and render what people have to type.

    python3 tools/build_midi_map.py --check            # do the profiles still fit?
    python3 tools/build_midi_map.py --table            # the reference for docs/midi.md
    python3 tools/build_midi_map.py --sheet apc64      # what to type into the editor

A profile in `midi/` is data, so nothing stops it naming a setting that has been
renamed, a value outside a setting's bounds, or the same pad twice. None of those
announce themselves: the pad simply does nothing, or something slightly wrong, on
the night. So the same question the Chataigne module is held to gets asked here —
is this still level with the show? — against Godot's own description rather than
against a list kept beside it.

`midi_control.gd` and `midi_map.gd` repeat the structural half of these checks when
it loads a profile, because a profile edited on the machine that runs the show
never sees CI.
This tool goes further: it can also see that a value would be snapped or clamped
on the way in, which the engine does silently and which would leave a pad's
printed label saying something the pad no longer does.
"""

import argparse
import json
import math
import sys
from pathlib import Path

from build_chataigne_module import describe

ROOT = Path(__file__).resolve().parent.parent
PROFILES = ROOT / "midi"

MODES = ["norm", "relative", "set", "toggle", "momentary", "hold", "action", "rgb"]
NEEDS_VALUE = ["set", "toggle", "momentary", "rgb"]
CONTINUOUS = ["norm", "relative"]

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def note_name(note: int) -> str:
    """MIDI 0 is C-2, the way both makers' editors label their lowest pad."""
    return f"{NOTE_NAMES[note % 12]}{note // 12 - 2}"


def load_profiles() -> list:
    out = []
    for path in sorted(PROFILES.glob("*.json")):
        try:
            profile = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as broken:
            sys.exit(f"{path.name} is not readable JSON: {broken}")
        profile["id"] = path.stem
        out.append(profile)
    if not out:
        sys.exit(f"No profiles in {PROFILES.relative_to(ROOT)}/")
    return out


def valid_actions(described: dict) -> set:
    """Every one-shot a profile may name, built from what the show says it has."""
    out = set(described["actions"])
    sections = []
    for setting in described["params"]:
        section = setting["slug"].split("/")[0]
        if section not in sections:
            sections.append(section)
    if "shuffle" in described["actions"]:
        out |= {f"shuffle:{section}" for section in sections}
    for slot in range(1, described["presets"]["count"] + 1):
        out |= {f"preset:recall:{slot}", f"preset:save:{slot}"}
    return out


def snapped(setting: dict, value: float) -> float:
    """What `VJParam.set_value()` would make of it: `snappedf` then `clampf`.

    Godot's own snap is `floor(value / step + 0.5) * step`, which rounds a
    half-step *up* rather than away from zero. Guessing at that instead of copying
    it is how a checker ends up disagreeing with the engine about negative values.
    """
    step = setting["step"]
    if step > 0:
        value = math.floor(value / step + 0.5) * step
    return min(max(value, setting["min"]), setting["max"])


def check(profile: dict, described: dict) -> list:
    """Everything wrong with one profile, named so it can be found and fixed."""
    settings = {s["slug"]: s for s in described["params"]}
    actions = valid_actions(described)
    problems = []
    seen = {}

    for control in profile.get("controls", []):
        label = control.get("label", "?")
        where = f"{profile['id']}: {label}"
        mode = control.get("mode")
        target = control.get("target", "")

        if mode not in MODES:
            problems.append(f"{where} has no usable mode ({mode!r})")
            continue
        if mode in NEEDS_VALUE and "value" not in control:
            problems.append(f"{where} is a {mode} and needs a value")
            continue

        # One address, one control. A pad claimed twice is a pad whose behaviour
        # depends on which line was read last.
        if "cc" in control:
            key = ("cc", int(control["cc"]))
            if not 0 <= key[1] <= 127:
                problems.append(f"{where} is on CC {key[1]}, which is not a CC")
        elif "note" in control:
            key = ("note", int(control["note"]))
            if not 0 <= key[1] <= 127:
                problems.append(f"{where} is on note {key[1]}, which is not a note")
        else:
            problems.append(f"{where} is on neither a note nor a CC")
            continue
        if key in seen:
            problems.append(f"{where} claims {key[0]} {key[1]}, already taken by {seen[key]}")
        seen[key] = label

        # Only the continuous modes truly need a CC. A button may be either: pads
        # send notes, and the Launch Control's own custom mode puts all sixteen of
        # its buttons on CCs, where 127 is a press and 0 a release.
        if key[0] == "note" and mode in CONTINUOUS:
            problems.append(f"{where} is a {mode}, which needs a CC rather than a note")

        if mode in ("action", "hold"):
            if target not in actions:
                problems.append(f"{where} fires \"{target}\", which the show does not offer")
            if mode == "hold":
                if float(control.get("hold_ms", 0)) <= 0:
                    problems.append(f"{where} is a hold with no hold_ms")
                if control.get("latching"):
                    problems.append(f"{where} is a hold on a latching button, which"
                                    " never lets go and so can never be held")
            continue

        if mode == "rgb":
            value = control.get("value")
            if not isinstance(value, list) or len(value) != 3:
                problems.append(f"{where} needs three components, not {value!r}")
            elif not all(isinstance(c, (int, float)) and 0 <= c <= 1 for c in value):
                problems.append(f"{where} has a component outside 0–1: {value!r}")
            elif target != "color/rgb":
                problems.append(f"{where} is an rgb control but aims at \"{target}\"")
            else:
                _check_led_matches(control, problems, where)
            continue

        setting = settings.get(target)
        if setting is None:
            problems.append(f"{where} aims at \"{target}\", which is not a setting")
            continue

        # A value the show would quietly move is a label that lies: the pad says
        # SEGMENTS 12 and the room gets something else.
        if "value" in control:
            asked = float(control["value"])
            landed = snapped(setting, asked)
            if abs(landed - asked) > 1e-9:
                problems.append(
                    f"{where} asks for {asked:g} on {target}, which lands on {landed:g}"
                    f" (range {setting['min']:g}–{setting['max']:g}, step {setting['step']:g})")

        if "style" in control and control["style"] not in ("volume", "pan"):
            problems.append(f"{where} has an unknown fader style {control['style']!r}")

        if control.get("latching") and mode in CONTINUOUS:
            problems.append(f"{where} is a {mode}; only a button can latch")

    for field in ("led", "led_on"):
        for control in profile.get("controls", []):
            colour = control.get(field)
            if colour is not None and not _is_hex(colour):
                problems.append(f"{profile['id']}: {control.get('label', '?')}"
                                f" has {field} {colour!r}, which is not #RRGGBB")
    return problems


def _is_hex(colour) -> bool:
    if not isinstance(colour, str) or len(colour) != 7 or not colour.startswith("#"):
        return False
    return all(c in "0123456789abcdefABCDEF" for c in colour[1:])


def _check_led_matches(control: dict, problems: list, where: str):
    """A palette pad whose LED is not the colour it sends is a legend that lies —
    and that row exists only because the legend is the whole feedback we get."""
    led = control.get("led")
    if not _is_hex(led):
        return
    wanted = "#" + "".join(f"{round(c * 255):02X}" for c in control["value"])
    if led.upper() != wanted:
        problems.append(f"{where} sends {wanted} but lights {led.upper()}")


# ---------------------------------------------------------------------------
# What people read
# ---------------------------------------------------------------------------

def effect(control: dict, described: dict) -> str:
    settings = {s["slug"]: s for s in described["params"]}
    mode, target = control["mode"], control["target"]
    if mode == "action":
        return f"fires `{target}`"
    if mode == "rgb":
        r, g, b = control["value"]
        return f"colour → {r:g} {g:g} {b:g}, and manual"
    if mode == "norm":
        setting = settings[target]
        return f"`{target}` over {setting['min']:g} – {setting['max']:g}"
    if mode == "relative":
        return f"`{target}`, one step a tick"
    if mode == "set":
        return f"`{target}` → {float(control['value']):g}"
    if mode == "toggle":
        return f"`{target}` ↔ {float(control['value']):g}"
    if mode == "momentary":
        return f"`{target}` → {float(control['value']):g} while held"
    if mode == "hold":
        return f"fires `{target}` after {int(control['hold_ms'])} ms held"
    return target


def table(profile: dict, described: dict) -> str:
    lines = [
        f"### {profile['name']}",
        "",
        f"{profile.get('surface', '')}  ",
        f"Profile `midi/{profile['id']}.json`, channel {profile.get('channel', 1)}.",
        "",
        "| Control | Sends | Does |",
        "| --- | --- | --- |",
    ]
    for control in profile["controls"]:
        if "cc" in control:
            sends = f"CC {control['cc']}"
        else:
            sends = f"note {control['note']} ({note_name(control['note'])})"
        lines.append(f"| {control.get('label', '')} | {sends} | {effect(control, described)} |")
    return "\n".join(lines)


def sheet(profile: dict) -> str:
    """What to type into the maker's editor, in the order the editor asks for it."""
    channel = profile.get("channel", 1)
    lines = [
        f"{profile['name']} — custom mode entry sheet",
        f"{profile.get('surface', '')}",
        f"Everything on MIDI channel {channel}. Every button momentary: the show"
        " decides what toggles, not the surface.",
        "",
    ]
    faders = [c for c in profile["controls"] if "cc" in c]
    if faders:
        # The style column only exists where the maker's editor asks for one, and
        # a default printed for a controller that has no such field is a line
        # somebody would go looking for.
        styled = any("style" in c for c in faders)
        head = f"{'control':<12} {'CC':>4}" + ("  style  " if styled else "  ") + "target"
        lines += ["CONTINUOUS", head, ""]
        for c in faders:
            style = f"  {c.get('style', '-'):<7}" if styled else "  "
            lines.append(f"{c.get('label', ''):<12} {c['cc']:>4}{style}{c['target']}")
        lines.append("")
    pads = [c for c in profile["controls"] if "note" in c]
    if pads:
        lines += ["NOTES",
                  f"{'control':<22} {'note':>4} {'name':>5}  {'on colour':<9} "
                  f"{'off colour':<10} does", ""]
        for c in pads:
            lines.append(
                f"{c.get('label', ''):<22} {c['note']:>4} {note_name(c['note']):>5}  "
                f"{c.get('led', '-'):<9} {c.get('led_on', c.get('led', '-')):<10} "
                f"{c['target']}")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true",
                        help="fail if a profile no longer fits the show")
    parser.add_argument("--table", action="store_true",
                        help="print the reference tables for docs/midi.md")
    parser.add_argument("--sheet", metavar="PROFILE",
                        help="print what to type into that controller's editor")
    parser.add_argument("--params", metavar="FILE",
                        help="use a description already dumped, instead of running Godot")
    args = parser.parse_args()

    profiles = load_profiles()

    if args.sheet:
        for profile in profiles:
            if profile["id"] == args.sheet:
                print(sheet(profile))
                return
        sys.exit(f"No profile {args.sheet!r}: have {', '.join(p['id'] for p in profiles)}")

    described = (json.loads(Path(args.params).read_text(encoding="utf-8"))
                 if args.params else describe())

    problems = []
    for profile in profiles:
        problems += check(profile, described)
    if problems:
        sys.exit("The profiles are not level with the show:\n  " + "\n  ".join(problems))

    if args.table:
        print("\n\n".join(table(p, described) for p in profiles))
        return

    for profile in profiles:
        print(f"{profile['id']:<24} {len(profile['controls']):>3} controls  "
              f"{profile['name']}")
    print(f"level with {len(described['params'])} settings")


if __name__ == "__main__":
    main()

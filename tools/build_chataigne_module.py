#!/usr/bin/env python3
"""Generate the Chataigne module from Godot's list of settings.

    python3 tools/build_chataigne_module.py              # write the module
    python3 tools/build_chataigne_module.py --addresses  # print the OSC reference

The module mirrors `_build_params()` in `scripts/vj_controller.gd`: same settings,
same bounds, same defaults. Generating it rather than maintaining it by hand rules
out the one failure that never shows — a setting added on the Godot side and
forgotten on the console, or worse, bounds that quietly drift apart.

Command names come from the English labels in `scripts/lang.gd`, so the console
reads like the English UI.

The script stops dead if it cannot read every setting: a loud error beats a module
silently missing two commands.
"""

import collections
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTROLLER = ROOT / "scripts" / "vj_controller.gd"
LANG = ROOT / "scripts" / "lang.gd"
OUTPUT = ROOT / "chataigne" / "Deferlante"

VERSION = "6.0.0"
OSC_PORT = 9000

# Settings that count in whole numbers rather than floats.
INTEGERS = {
    "lasers/count",
    "sphere/count",
    "color/mode",
    "mirror/segments",
    "global/language",
}

DECLARATION = re.compile(
    r'_(?:fn|prop)\("([^"]+)", ([-\d.]+), ([-\d.]+), ([\d.]+), ([-\w.]+)'
)
# "spot/hold": ["ARRÊTS", "HOLD"],  ->  slug, english label
LABEL = re.compile(r'"([\w/.]+)":\s*\["[^"]*",\s*"([^"]*)"\]')


def read_labels() -> dict:
    """English labels and section names, straight from the translation table."""
    return dict(LABEL.findall(LANG.read_text(encoding="utf-8")))


def read_settings(source: str):
    """Pull (slug, min, max, step, default) out of every declared setting."""
    # A default may be a literal or an exported variable: resolve both.
    constants = {
        name: float(value)
        for name, value in re.findall(r"var (\w+):\s*\w+\s*=\s*([-\d.]+)", source)
    }

    settings = []
    for slug, low, high, step, default in DECLARATION.findall(source):
        try:
            value = float(default)
        except ValueError:
            if default not in constants:
                sys.exit(f"No default found for {slug}: {default}")
            value = constants[default]
        settings.append((slug, float(low), float(high), float(step), value))

    # The guard: as many settings read as declared. Otherwise the regex missed a
    # form we did not anticipate and the module would come out incomplete.
    expected = len(re.findall(r'_(?:fn|prop)\("', source))
    if len(settings) != expected:
        sys.exit(f"Regex incomplete: read {len(settings)} settings out of {expected}")
    return settings


def callback(slug: str) -> str:
    """"sphere/spin" -> "sphereSpin": the name of the JS function."""
    section, name = slug.split("/")
    return section + name.capitalize()


def ascii_only(text: str) -> str:
    for accented, plain in (("É", "E"), ("Ê", "E"), ("À", "A"), ("Ô", "O"), ("Ç", "C")):
        text = text.replace(accented, plain)
    return text


def menu_of(slug: str, labels: dict) -> str:
    section = slug.split("/")[0]
    return labels.get(f"section.{section}", section).title()


def command_name(slug: str, labels: dict) -> str:
    """Menu plus label, in English: "spot/hold" -> "Spotlight Hold"."""
    return f"{menu_of(slug, labels)} {ascii_only(labels.get(slug, slug)).title()}"


def build(settings, labels):
    commands = collections.OrderedDict()

    for slug, low, high, _step, default in settings:
        commands[command_name(slug, labels)] = collections.OrderedDict(
            [
                ("menu", menu_of(slug, labels)),
                ("callback", callback(slug)),
                (
                    "parameters",
                    {
                        "Value": collections.OrderedDict(
                            [
                                ("type", "Integer" if slug in INTEGERS else "Float"),
                                ("ui", "slider"),
                                ("min", low),
                                ("max", high),
                                ("default", default),
                                ("mappingIndex", 0),
                            ]
                        )
                    },
                ),
            ]
        )

    # A real colour picker, sending its components in one go.
    commands["Color Picker"] = collections.OrderedDict(
        [
            ("menu", "Color"),
            ("callback", "colorRgb"),
            (
                "parameters",
                {
                    "Color": collections.OrderedDict(
                        [("type", "Color"), ("default", [1, 0.25, 0.1, 1]), ("mappingIndex", 0)]
                    )
                },
            ),
        ]
    )

    # Presets take a slot number rather than a trigger, so they are declared apart.
    for name, function in (("Recall Preset", "recallPreset"), ("Save Preset", "savePreset")):
        commands[name] = collections.OrderedDict(
            [
                ("menu", "Presets"),
                ("callback", function),
                (
                    "parameters",
                    {
                        "Slot": collections.OrderedDict(
                            [("type", "Integer"), ("min", 1), ("max", 9),
                             ("default", 1), ("mappingIndex", 0)]
                        )
                    },
                ),
            ]
        )

    for name, function in (("Trigger Glitch", "triggerGlitch"), ("Randomize Colors", "randomizeColors")):
        commands[name] = collections.OrderedDict(
            [
                ("menu", "Actions"),
                ("callback", function),
                # Every command needs a non-empty `parameters` block: a command
                # without parameters has already crashed Chataigne on scan.
                (
                    "parameters",
                    {
                        "Trigger": collections.OrderedDict(
                            [("type", "Boolean"), ("default", True), ("mappingIndex", 0)]
                        )
                    },
                ),
            ]
        )

    module = collections.OrderedDict(
        [
            ("name", "Deferlante"),
            ("type", "OSC"),
            ("path", "Software"),
            ("version", VERSION),
            ("description", "Control the Deferlante VJ visuals (Godot) over OSC."),
            ("hasInput", True),
            ("hasOutput", True),
            ("hideDefaultCommands", True),
            (
                "defaults",
                collections.OrderedDict(
                    [
                        ("autoAdd", False),
                        (
                            "OSC Outputs",
                            {
                                "OSC Output": {
                                    "local": True,
                                    "remoteHost": "127.0.0.1",
                                    "remotePort": OSC_PORT,
                                }
                            },
                        ),
                        # Input declared but disabled: an OSC module without an
                        # `OSC Input` section departs from every one that works.
                        ("OSC Input", {"enabled": False, "localPort": OSC_PORT + 1}),
                    ]
                ),
            ),
            ("scripts", ["deferlante.js"]),
            ("commands", commands),
        ]
    )

    lines = [
        "// Chataigne module -> Deferlante visuals (Godot).",
        "// Generated by tools/build_chataigne_module.py, do not edit by hand.",
        "",
        "function init() {",
        '\tscript.log("Deferlante module ready");',
        "}",
        "",
    ]
    for slug, *_ in settings:
        lines += [
            f"function {callback(slug)}(value) {{",
            f'\tlocal.send("/deferlante/{slug}", value);',
            "}",
            "",
        ]
    lines += [
        "function recallPreset(slot) {",
        '\tlocal.send("/deferlante/preset/recall", slot);',
        "}",
        "",
        "function savePreset(slot) {",
        '\tlocal.send("/deferlante/preset/save", slot);',
        "}",
        "",
        "// The colour picker arrives as an array [r, g, b, a].",
        "function colorRgb(color) {",
        '\tlocal.send("/deferlante/color/rgb", color[0], color[1], color[2]);',
        "}",
        "",
        "function triggerGlitch(value) {",
        '\tlocal.send("/deferlante/glitch_now");',
        "}",
        "",
        "function randomizeColors(value) {",
        '\tlocal.send("/deferlante/randomize");',
        "}",
        "",
    ]
    return module, "\n".join(lines)


def address_table(settings, labels) -> str:
    """The OSC reference as a markdown table, pasted into docs/external-control.md so
    the prose cannot drift from the addresses either."""
    lines = ["| Address | Range | Default | On screen |", "| --- | --- | --- | --- |"]
    for slug, low, high, step, default in settings:
        fmt = (lambda v: f"{v:g}")
        shown = labels.get(slug, slug)
        section = labels.get("section." + slug.split("/")[0], "")
        lines.append(
            f"| `/deferlante/{slug}` | {fmt(low)} – {fmt(high)} | {fmt(default)} |"
            f" {section} › {shown} |"
        )
    return "\n".join(lines)


def main():
    labels = read_labels()
    settings = read_settings(CONTROLLER.read_text(encoding="utf-8"))

    if "--addresses" in sys.argv:
        print(address_table(settings, labels))
        return

    addresses = [slug for slug, *_ in settings]
    if len(addresses) != len(set(addresses)):
        duplicates = [a for a in addresses if addresses.count(a) > 1]
        sys.exit(f"Colliding OSC addresses: {sorted(set(duplicates))}")

    module, javascript = build(settings, labels)

    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "module.json").write_text(
        json.dumps(module, indent=2, ensure_ascii=True) + "\n", encoding="utf-8"
    )
    (OUTPUT / "deferlante.js").write_text(javascript, encoding="utf-8")

    # Last safety net: every declared callback must have its JS function.
    functions = set(re.findall(r"function (\w+)\(", javascript))
    orphans = [c["callback"] for c in module["commands"].values() if c["callback"] not in functions]
    if orphans:
        sys.exit(f"Callbacks with no JS function: {orphans}")

    print(f"{len(settings)} settings -> {len(module['commands'])} commands")
    print(f"written to {OUTPUT.relative_to(ROOT)}/")


if __name__ == "__main__":
    main()

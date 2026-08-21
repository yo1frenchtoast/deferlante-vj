#!/usr/bin/env python3
"""Generate the Chataigne module from Godot's own description of the show.

    python3 tools/build_chataigne_module.py              # write the module
    python3 tools/build_chataigne_module.py --check      # is the committed one current?
    python3 tools/build_chataigne_module.py --addresses  # print the OSC reference

The module mirrors the settings Godot declares: same names, same bounds, same
defaults. Generating it rather than keeping it by hand rules out the one failure
that never announces itself — a setting added on the Godot side and forgotten on
the console, or bounds that quietly drift apart.

It used to read that list by running regular expressions over `vj_controller.gd`
and `lang.gd`, which made the *shape* of a declaration part of the contract: a
setting wrapped onto two lines would have been missed. Worse, what the regexes
could not express was kept in lists here instead, and one of those had already
drifted in both directions unnoticed — six settings offered to the console as
floats when they only ever land on whole numbers, and one named here that Godot
had not had for months.

So the show is asked instead. `--dump-params` runs it headless, long enough to
build its settings and write them down, and everything below is derived from that
one answer. Names arrive in English, as the API does and for the same reason:
what reads this is a program, not a person standing in a room.
"""

import argparse
import collections
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "chataigne" / "Deferlante"
# Inside `.godot/`, which is already ignored — and, unlike /tmp, a directory the
# flatpak build of Godot can actually see.
DUMP = ROOT / ".godot" / "params-dump.json"

# Which actions exist comes from Godot. What they are *called* on the console does
# not: these names have been in people's Chataigne files for versions, and renaming
# a command silently unbinds whatever was mapped to it. Anything Godot gains later
# is named from its own slug and appears without a line here.
ACTION_NAMES = {
    "glitch": ("Trigger Glitch", "triggerGlitch", "glitch_now"),
    "randomize": ("Randomize Colors", "randomizeColors", "randomize"),
}

VERSION = "6.0.0"
# The module's own default, not the running show's: `launch.cfg` is one machine's
# answer, and this file is meant to be handed to somebody else's console.
OSC_PORT = 9000


# ---------------------------------------------------------------------------
# Asking the show what it has
# ---------------------------------------------------------------------------

def godot_command() -> list:
    """However Godot can be run here.

    `GODOT` wins if it is set — a specific build, or a wrapper. Otherwise a godot
    on the PATH, which is what CI installs, and failing that the flatpak, which is
    what this project is developed against.
    """
    override = os.environ.get("GODOT")
    if override:
        return override.split()
    found = shutil.which("godot")
    if found:
        return [found]
    if shutil.which("flatpak"):
        return ["flatpak", "run", "--command=godot", "org.godotengine.Godot"]
    sys.exit("No Godot found: put one on the PATH or set GODOT=/path/to/godot")


def describe() -> dict:
    """Run the show headless until it has written its description down."""
    DUMP.parent.mkdir(parents=True, exist_ok=True)
    DUMP.unlink(missing_ok=True)
    command = godot_command() + [
        "--headless", "--path", str(ROOT), "--", "--dump-params", str(DUMP),
    ]
    result = subprocess.run(command, capture_output=True, text=True, timeout=600)
    if not DUMP.exists():
        sys.exit(
            "Godot wrote no description.\n"
            f"  command: {' '.join(command)}\n"
            f"  exit:    {result.returncode}\n"
            f"{result.stdout[-2000:]}{result.stderr[-2000:]}"
        )
    try:
        return json.loads(DUMP.read_text(encoding="utf-8"))
    finally:
        DUMP.unlink(missing_ok=True)


def load(args) -> dict:
    described = json.loads(Path(args.params).read_text(encoding="utf-8")) if args.params else describe()
    settings = described["params"]
    if not settings:
        sys.exit("The show described no settings at all")
    slugs = [s["slug"] for s in settings]
    if len(slugs) != len(set(slugs)):
        clashing = sorted({s for s in slugs if slugs.count(s) > 1})
        sys.exit(f"Colliding OSC addresses: {clashing}")
    return described


# ---------------------------------------------------------------------------
# Turning it into a module
# ---------------------------------------------------------------------------

def is_whole(setting: dict) -> bool:
    """Whether a setting only ever lands on whole numbers.

    A step of 5 from a start of 20 is as whole as a step of 1: what matters is
    that nothing between the stops can be reached.
    """
    return setting["step"] >= 1 and float(setting["min"]).is_integer()


def callback(slug: str) -> str:
    """"sphere/spin" -> "sphereSpin": the name of the JS function."""
    section, name = slug.split("/")
    return section + name.capitalize()


def ascii_only(text: str) -> str:
    for accented, plain in (("É", "E"), ("Ê", "E"), ("À", "A"), ("Ô", "O"), ("Ç", "C")):
        text = text.replace(accented, plain)
    return text


def action_command(action: str):
    """Console name, JS function and OSC address for a one-shot action.

    `glitch` is sent as `glitch_now`: the OSC side names the moment rather than the
    setting, and there is already a `glitch` amount among the settings.
    """
    return ACTION_NAMES.get(action, (action.title(), action, action))


def menu_of(setting: dict) -> str:
    return ascii_only(setting["section"]).title()


def command_name(setting: dict) -> str:
    """Menu plus label: "spot/hold" -> "Spotlight Hold"."""
    return f"{menu_of(setting)} {ascii_only(setting['label']).title()}"


def slider(setting: dict) -> collections.OrderedDict:
    return collections.OrderedDict([
        ("type", "Integer" if is_whole(setting) else "Float"),
        ("ui", "slider"),
        ("min", setting["min"]),
        ("max", setting["max"]),
        ("default", setting["value"]),
        ("mappingIndex", 0),
    ])


def build(described: dict):
    settings = described["params"]
    prefix = described["osc_prefix"]
    commands = collections.OrderedDict()

    for setting in settings:
        commands[command_name(setting)] = collections.OrderedDict([
            ("menu", menu_of(setting)),
            ("callback", callback(setting["slug"])),
            ("parameters", {"Value": slider(setting)}),
        ])

    # A real colour picker, sending its components in one go.
    commands["Color Picker"] = collections.OrderedDict([
        ("menu", "Color"),
        ("callback", "colorRgb"),
        ("parameters", {"Color": collections.OrderedDict([
            ("type", "Color"), ("default", [1, 0.25, 0.1, 1]), ("mappingIndex", 0),
        ])}),
    ])

    # Presets take a slot number rather than a trigger, so they are declared apart.
    slots = described["presets"]["count"]
    for name, function in (("Recall Preset", "recallPreset"), ("Save Preset", "savePreset")):
        commands[name] = collections.OrderedDict([
            ("menu", "Presets"),
            ("callback", function),
            ("parameters", {"Slot": collections.OrderedDict([
                ("type", "Integer"), ("min", 1), ("max", slots),
                ("default", 1), ("mappingIndex", 0),
            ])}),
        ])

    for action in described["actions"]:
        name, function, _address = action_command(action)
        commands[name] = collections.OrderedDict([
            ("menu", "Actions"),
            ("callback", function),
            # Every command needs a non-empty `parameters` block: a command with
            # none has already crashed Chataigne on scan.
            ("parameters", {"Trigger": collections.OrderedDict([
                ("type", "Boolean"), ("default", True), ("mappingIndex", 0),
            ])}),
        ])

    module = collections.OrderedDict([
        ("name", "Deferlante"),
        ("type", "OSC"),
        ("path", "Software"),
        ("version", VERSION),
        ("description", "Control the Deferlante VJ visuals (Godot) over OSC."),
        ("hasInput", True),
        ("hasOutput", True),
        ("hideDefaultCommands", True),
        ("defaults", collections.OrderedDict([
            ("autoAdd", False),
            ("OSC Outputs", {"OSC Output": {
                "local": True, "remoteHost": "127.0.0.1", "remotePort": OSC_PORT,
            }}),
            # Input declared but disabled: an OSC module without an `OSC Input`
            # section departs from every one that works.
            ("OSC Input", {"enabled": False, "localPort": OSC_PORT + 1}),
        ])),
        ("scripts", ["deferlante.js"]),
        ("commands", commands),
    ])

    lines = [
        "// Chataigne module -> Deferlante visuals (Godot).",
        "// Generated by tools/build_chataigne_module.py, do not edit by hand.",
        "",
        "function init() {",
        '\tscript.log("Deferlante module ready");',
        "}",
        "",
    ]
    for setting in settings:
        lines += [
            f"function {callback(setting['slug'])}(value) {{",
            f'\tlocal.send("{prefix}{setting["slug"]}", value);',
            "}",
            "",
        ]
    lines += [
        "function recallPreset(slot) {",
        f'\tlocal.send("{prefix}preset/recall", slot);',
        "}",
        "",
        "function savePreset(slot) {",
        f'\tlocal.send("{prefix}preset/save", slot);',
        "}",
        "",
        "// The colour picker arrives as an array [r, g, b, a].",
        "function colorRgb(color) {",
        f'\tlocal.send("{prefix}color/rgb", color[0], color[1], color[2]);',
        "}",
        "",
    ]
    for action in described["actions"]:
        _name, function, address = action_command(action)
        lines += [
            f"function {function}(value) {{",
            f'\tlocal.send("{prefix}{address}");',
            "}",
            "",
        ]
    return module, "\n".join(lines)


def address_table(described: dict) -> str:
    """The OSC reference as a markdown table, pasted into docs/external-control.md
    so the prose cannot drift from the addresses either."""
    fmt = lambda v: f"{v:g}"
    lines = ["| Address | Range | Default | On screen |", "| --- | --- | --- | --- |"]
    for s in described["params"]:
        lines.append(
            f"| `{described['osc_prefix']}{s['slug']}` |"
            f" {fmt(s['min'])} – {fmt(s['max'])} | {fmt(s['value'])} |"
            f" {s['section']} › {s['label']} |"
        )
    return "\n".join(lines)


def render(module, javascript):
    return json.dumps(module, indent=2, ensure_ascii=True) + "\n", javascript


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addresses", action="store_true",
                        help="print the OSC reference table and stop")
    parser.add_argument("--check", action="store_true",
                        help="fail if the committed module is not what Godot describes")
    parser.add_argument("--params", metavar="FILE",
                        help="use a description already dumped, instead of running Godot")
    args = parser.parse_args()

    described = load(args)

    if args.addresses:
        print(address_table(described))
        return

    module, javascript = build(described)
    module_text, script_text = render(module, javascript)

    # Last safety net: every declared callback must have its JS function.
    functions = set(re.findall(r"function (\w+)\(", javascript))
    orphans = [c["callback"] for c in module["commands"].values() if c["callback"] not in functions]
    if orphans:
        sys.exit(f"Callbacks with no JS function: {orphans}")

    if args.check:
        stale = [
            name for name, current in (
                ("module.json", module_text), ("deferlante.js", script_text),
            )
            if not (OUTPUT / name).exists()
            or (OUTPUT / name).read_text(encoding="utf-8") != current
        ]
        if stale:
            sys.exit(
                f"The committed module is behind the settings: {', '.join(stale)}\n"
                "Run: python3 tools/build_chataigne_module.py"
            )
        print(f"module is current: {len(described['params'])} settings, "
              f"{len(module['commands'])} commands")
        return

    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "module.json").write_text(module_text, encoding="utf-8")
    (OUTPUT / "deferlante.js").write_text(script_text, encoding="utf-8")

    print(f"{len(described['params'])} settings -> {len(module['commands'])} commands")
    print(f"written to {OUTPUT.relative_to(ROOT)}/")


if __name__ == "__main__":
    main()

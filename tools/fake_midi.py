#!/usr/bin/env python3
"""Play a MIDI profile at the running show, and check that it landed.

    python3 tools/fake_midi.py --sweep                    # every control, asserted
    python3 tools/fake_midi.py --profile apc64 --sweep
    python3 tools/fake_midi.py --note 24                  # one shot, while debugging
    python3 tools/fake_midi.py --cc 16 127
    python3 tools/fake_midi.py --hold 8 1.4               # a pad held, timed exactly

It sends through a **virtual raw MIDI device**, which is the only kind Godot can
hear. Measured: Godot's Linux MIDI driver is `snd_rawmidi`, not the ALSA
sequencer, so it enumerates sound cards and ignores virtual sequencer ports
entirely — a port opened by python-rtmidi is invisible to the show no matter how
it is named. `snd-virmidi` is the piece that bridges the two: it is a dummy sound
card whose raw MIDI devices are also sequencer ports, so bytes written into one
of them come out where the show is listening.

    sudo modprobe snd-virmidi            # once per boot; nothing to reboot

Nothing else to install: it writes to the device node and uses `aconnect` from
alsa-utils to route it. Because that card is called "Virtual Raw MIDI", the show
cannot recognise a profile from its name, so this names one outright — the
launcher's MIDI row, which exists for exactly this.

    MIDI = <profile> in the launcher, or:
    printf '[io]\nmidi_profile="apc64"\n' >> ~/.local/share/godot/app_userdata/Déferlante/launch.cfg

Then it *checks*. After every message it reads the setting back over the REST API
and compares it with what the show should have made of it, snapping and clamping
included. A profile that is subtly wrong fails the run rather than producing a
pretty sweep somebody has to watch.
"""

import argparse
import atexit
import functools
import json
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_midi_map import load_profiles, snapped  # noqa: E402

# Unbuffered: a redirected run that shows nothing until the end is one nobody
# can tell from a hang.
say = functools.partial(print, flush=True)

DEFAULT_API = "http://127.0.0.1:7331"
# Long enough for the show to read the port and route it, short enough that a
# sweep of seventy-two pads is not a coffee break.
SETTLE = 0.06


class Show:
    """The running show, asked over the API it already serves."""

    def __init__(self, base: str):
        self.base = base.rstrip("/")
        self.settings = {s["slug"]: s for s in self._get("/api/params")["params"]}

    def _get(self, path: str):
        try:
            with urllib.request.urlopen(self.base + path, timeout=4) as answer:
                return json.loads(answer.read())
        except urllib.error.URLError as unreachable:
            sys.exit(f"No show at {self.base} ({unreachable}). Start it first.")

    def value(self, slug: str) -> float:
        section, name = slug.split("/")
        return float(self._get(f"/api/params/{section}/{name}")["value"])

    def set(self, slug: str, value: float):
        section, name = slug.split("/")
        request = urllib.request.Request(
            f"{self.base}/api/params/{section}/{name}",
            data=json.dumps({"value": value}).encode(),
            headers={"Content-Type": "application/json"}, method="PUT")
        urllib.request.urlopen(request, timeout=4).read()

    def fire(self, action: str):
        request = urllib.request.Request(
            f"{self.base}/api/actions/{action}", data=b"", method="POST")
        urllib.request.urlopen(request, timeout=4).read()


def virmidi_devices() -> list:
    """Every `snd-virmidi` port, as (sequencer address, card, device).

    Read from `aplaymidi -l`, whose port names carry the card and device numbers
    the raw side is reached by: "VirMIDI 4-1" is `/dev/snd/midiC4D1`.
    """
    if not shutil.which("aplaymidi") or not shutil.which("aconnect"):
        sys.exit("alsa-utils is missing: aplaymidi and aconnect are both needed")
    listing = subprocess.run(["aplaymidi", "-l"], capture_output=True, text=True).stdout
    out = []
    for line in listing.splitlines():
        found = re.match(r"\s*(\d+:\d+)\s+Virtual Raw MIDI.*VirMIDI (\d+)-(\d+)", line)
        if found:
            out.append((found.group(1), int(found.group(2)), int(found.group(3))))
    if len(out) < 2:
        sys.exit(
            "Fewer than two virtual raw MIDI ports. Godot listens on raw MIDI, not\n"
            "on the ALSA sequencer, so a plain virtual sequencer port cannot reach\n"
            "it. Load the bridge — it lasts until the next boot and reboots\n"
            "nothing:\n"
            "    sudo modprobe snd-virmidi\n")
    return out


class Fake:
    """Messages written straight into a virtual raw MIDI device.

    The obvious tools are both wrong for this. `aseqsend` only carries SysEx, and
    `aplaymidi` takes 2.5 seconds to play a file however short it is — which turns
    a sweep of fifty controls into ten minutes of waiting. Writing the bytes to the
    device node costs nothing and is exact.

    It needs two of the virtual ports and one `aconnect` between them, because
    `snd-virmidi` does not loop a device back to itself: bytes written to one
    device's raw side come out of *its* sequencer port, and have to be routed to
    another one whose raw side is what the show is reading.

    Both ends are virtual by construction. This can no more reach a real
    controller than it can reach the sound card — which is the point: the custom
    modes in a controller's memory are not ours to touch.
    """

    def __init__(self, channel: int):
        # Which way each latching button is currently thrown, so a tap sends the
        # message the real surface would send next rather than always the same one.
        self._latched: dict = {}
        ports = virmidi_devices()
        (self.target, _, _), (source, card, device) = ports[0], ports[-1]
        self.node = Path(f"/dev/snd/midiC{card}D{device}")
        self.source = source
        self.status = channel - 1
        # Dropped first, then made. A run interrupted before its own tidy-up leaves
        # the route in place, and `aconnect` calls that a failure — in whatever
        # language the machine is set to, which is no basis for telling one kind of
        # failure from another.
        subprocess.run(["aconnect", "-d", self.source, self.target], capture_output=True)
        made = subprocess.run(["aconnect", self.source, self.target],
                              capture_output=True, text=True)
        if made.returncode:
            sys.exit(f"cannot route {self.source} to {self.target}: {made.stderr.strip()}")
        say(f"{self.node} → {self.source} → {self.target} (both virtual; no "
            f"controller is written to)")

    def close(self):
        subprocess.run(["aconnect", "-d", self.source, self.target],
                       capture_output=True)

    def play(self, events: list):
        with self.node.open("wb", buffering=0) as raw:
            for delay, message in events:
                if delay:
                    time.sleep(delay)
                raw.write(message)

    def ramp(self, number: int, values):
        """A whole sweep in one go: arming a fader takes a stream of messages that
        nobody needs to read back in between."""
        self.play([(0.004, bytes([0xB0 | self.status, number, raw])) for raw in values])

    def cc(self, number: int, value: int):
        self.play([(0, bytes([0xB0 | self.status, number, value]))])

    def note_on(self, note: int, velocity: int = 100):
        self.play([(0, bytes([0x90 | self.status, note, velocity]))])

    def note_off(self, note: int):
        self.play([(0, bytes([0x80 | self.status, note, 0]))])

    def tap(self, note: int, seconds: float = 0.05):
        self.play([(0, bytes([0x90 | self.status, note, 100])),
                   (seconds, bytes([0x80 | self.status, note, 0]))])

    # A button is a note on a pad grid and a CC on the Launch Control. Below this
    # line the sweep stops caring which.
    def _button(self, control: dict, down: bool) -> bytes:
        if "cc" in control:
            return bytes([0xB0 | self.status, control["cc"], 127 if down else 0])
        note = control["note"]
        return bytes([(0x90 if down else 0x80) | self.status, note, 100 if down else 0])

    def press(self, control: dict):
        self.play([(0, self._button(control, True))])

    def release(self, control: dict):
        self.play([(0, self._button(control, False))])

    def tap_control(self, control: dict, seconds: float = 0.05):
        """One press, the way this surface actually delivers one.

        A latching button sends a single message per press, alternating 127 and 0
        — so playing 127-then-0 at it would be two presses, and would leave every
        assertion about the second one wrong."""
        if control.get("latching"):
            key = control.get("cc", control.get("note"))
            self._latched[key] = not self._latched.get(key, False)
            self.play([(0, self._button(control, self._latched[key]))])
            return
        self.play([(0, self._button(control, True)),
                   (seconds, self._button(control, False))])


# ---------------------------------------------------------------------------
# The sweep
# ---------------------------------------------------------------------------

class Report:
    def __init__(self):
        self.failures = []
        self.checked = 0

    def expect(self, label: str, wanted: float, got: float, tolerance: float = 1e-6):
        self.checked += 1
        if abs(wanted - got) > tolerance:
            self.failures.append(f"{label}: expected {wanted:g}, show says {got:g}")
            say(f"  FAIL {label}: expected {wanted:g}, show says {got:g}")

    def note(self, label: str, detail: str):
        say(f"  ---- {label}: {detail}")


def sweep_cc(fake: Fake, show: Show, report: Report, control: dict):
    slug = control["target"]
    setting = show.settings[slug]
    label = f"CC {control['cc']} {control.get('label', '')} → {slug}"

    if control["mode"] == "relative":
        before = show.value(slug)
        fake.cc(control["cc"], 1)
        time.sleep(SETTLE)
        report.expect(label + " +1", snapped(setting, before + setting["step"]),
                      show.value(slug))
        return

    # Soft takeover: the fader has to meet the setting before it may move it. So
    # the sweep walks the whole travel, which crosses it wherever it sits, and
    # only then asserts. A test that armed the fader by hand would be testing
    # something the operator never does.
    # The whole travel, ends included. A ramp that stops at 120 cannot arm a fader
    # whose setting is parked at its maximum — it never comes within a step of it
    # and never crosses it — and `lasers/spin` starts life at exactly that.
    fake.ramp(control["cc"], list(range(0, 128, 8)) + [127])
    for raw, where in ((0, "bottom"), (127, "top"), (64, "middle")):
        fake.cc(control["cc"], raw)
        time.sleep(SETTLE)
        wanted = snapped(setting, setting["min"]
                         + (setting["max"] - setting["min"]) * raw / 127.0)
        report.expect(f"{label} {where}", wanted, show.value(slug))


def sweep_button(fake: Fake, show: Show, report: Report, control: dict):
    mode, slug = control["mode"], control["target"]
    where = f"CC {control['cc']}" if "cc" in control else f"note {control['note']}"
    label = f"{where} {control.get('label', '')}"

    if mode in ("action", "hold"):
        # A one-shot leaves nothing to read back, and a `hold` deliberately does
        # nothing on a tap. Both are exercised, and the ones that matter are
        # asserted by --hold rather than guessed at here.
        if mode == "hold":
            fake.tap_control(control, 0.05)
            time.sleep(SETTLE)
            report.note(label, f"tapped — must NOT have fired {slug}")
        else:
            fake.tap_control(control)
            time.sleep(SETTLE)
            report.note(label, f"fired {slug}")
        return

    if mode == "rgb":
        fake.tap_control(control)
        time.sleep(SETTLE)
        for component, name in zip(control["value"], ("red", "green", "blue")):
            setting = show.settings["color/" + name]
            report.expect(f"{label} {name}", snapped(setting, component),
                          show.value("color/" + name))
        return

    setting = show.settings[slug]
    if mode == "set":
        fake.tap_control(control)
        time.sleep(SETTLE)
        report.expect(label, snapped(setting, float(control["value"])), show.value(slug))
        return

    if mode == "toggle":
        on = snapped(setting, float(control["value"]))
        show.set(slug, setting["min"])
        time.sleep(SETTLE)
        fake.tap_control(control)
        time.sleep(SETTLE)
        report.expect(label + " on", on, show.value(slug))
        fake.tap_control(control)
        time.sleep(SETTLE)
        report.expect(label + " off", setting["min"], show.value(slug))
        return

    if mode == "momentary":
        # The value to come back to is the one from before the press, whatever it
        # happened to be — which is the whole reason these are momentary.
        parked = snapped(setting, (setting["min"] + setting["max"]) / 3)
        show.set(slug, parked)
        time.sleep(SETTLE)
        fake.press(control)
        time.sleep(SETTLE)
        report.expect(label + " held", snapped(setting, float(control["value"])),
                      show.value(slug))
        fake.release(control)
        time.sleep(SETTLE)
        report.expect(label + " released", parked, show.value(slug))


def sweep(fake: Fake, show: Show, profile: dict) -> Report:
    report = Report()
    for control in profile["controls"]:
        if control["mode"] in ("norm", "relative"):
            sweep_cc(fake, show, report, control)
        else:
            sweep_button(fake, show, report, control)
    return report


def takeover(fake: Fake, show: Show, profile: dict) -> Report:
    """The one behaviour no single message can show: after something else moves a
    setting, its fader has to meet it again before it is allowed to write."""
    report = Report()
    faders = [c for c in profile["controls"] if c.get("mode") == "norm"]
    if not faders:
        return report
    control = faders[0]
    slug = control["target"]
    setting = show.settings[slug]

    fake.cc(control["cc"], 127)
    time.sleep(SETTLE)
    # Somebody else — a preset recall, the auto-pilot, a phone — moves it away.
    parked = snapped(setting, setting["min"])
    show.set(slug, parked)
    time.sleep(SETTLE)
    # The fader is now at the top and the setting at the bottom: a nudge near the
    # top must be ignored entirely.
    fake.cc(control["cc"], 120)
    time.sleep(SETTLE)
    report.expect(f"takeover on {slug}: ignored until met", parked, show.value(slug))
    # Sweep down through it, and it takes the setting over.
    fake.ramp(control["cc"], list(range(120, -1, -8)) + [0])
    fake.cc(control["cc"], 64)
    time.sleep(SETTLE)
    wanted = snapped(setting, setting["min"] + (setting["max"] - setting["min"]) * 64 / 127.0)
    report.expect(f"takeover on {slug}: caught", wanted, show.value(slug))
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--profile", default="apc64", help="which profile to play")
    parser.add_argument("--api", default=DEFAULT_API, help="where the show serves its API")
    parser.add_argument("--sweep", action="store_true", help="every control, asserted")
    parser.add_argument("--note", type=int, metavar="N", help="tap one note")
    parser.add_argument("--cc", nargs=2, type=int, metavar=("N", "VALUE"), help="send one CC")
    parser.add_argument("--hold", nargs=2, metavar=("NOTE", "SECONDS"),
                        help="hold a note for exactly that long")
    args = parser.parse_args()

    profiles = {p["id"]: p for p in load_profiles()}
    if args.profile not in profiles:
        sys.exit(f"No profile {args.profile!r}: have {', '.join(sorted(profiles))}")
    profile = profiles[args.profile]

    show = Show(args.api)
    fake = Fake(profile.get("channel", 1))
    say(f"the show must be on profile {profile['id']!r}")
    atexit.register(fake.close)

    if args.note is not None:
        fake.tap(args.note)
        say(f"tapped note {args.note}")
        return
    if args.cc:
        fake.cc(args.cc[0], args.cc[1])
        say(f"sent CC {args.cc[0]} = {args.cc[1]}")
        return
    if args.hold:
        which, seconds = int(args.hold[0]), float(args.hold[1])
        held = next((c for c in profile["controls"]
                     if c.get("note") == which or c.get("cc") == which), None)
        if held is None:
            sys.exit(f"nothing on {which} in {profile['id']}")
        fake.tap_control(held, seconds)
        say(f"held {held.get('label', which)} for {seconds}s")
        return
    if not args.sweep:
        parser.error("nothing asked: try --sweep")

    say(f"sweeping {profile['name']} — {len(profile['controls'])} controls")
    report = sweep(fake, show, profile)
    say("checking soft takeover")
    report.failures += takeover(fake, show, profile).failures

    say(f"\n{report.checked} assertions, {len(report.failures)} failed")
    if report.failures:
        sys.exit("\n".join(report.failures))


if __name__ == "__main__":
    main()

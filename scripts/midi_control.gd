class_name MidiControl
extends RefCounted

## One line of a MIDI profile, typed.
##
## A profile is JSON, so a control arrives as a dictionary whose keys nobody checks.
## This is where it is read once: what is here has a mode the map knows, a value when
## its mode needs one, and exactly one way to be reached — a CC or a note. What it
## *aims at* is not checked here, because that needs the show; `MidiMap` does it.

const MODES := ["norm", "relative", "set", "toggle", "momentary", "hold", "action", "rgb"]
## The modes that write something, and so have to say what.
const NEEDS_VALUE := ["set", "toggle", "momentary", "rgb"]

var label: String = "?"
var mode: String = ""
var target: String = ""
var cc: int = -1
var note: int = -1
## A number, or three of them for `rgb`.
var value: Variant = null
## A button on a CC that never springs back: 127 on the first press, 0 on the next.
var latching: bool = false
var hold_ms: int = 1000


## The control, or null with the reason in `error` when the line cannot work.
static func parse(data: Dictionary, error: Array) -> MidiControl:
	var c := MidiControl.new()
	c.label = data.get("label", "?")
	c.mode = data.get("mode", "")
	c.target = data.get("target", "")
	c.latching = data.get("latching", false)
	c.hold_ms = int(data.get("hold_ms", 1000))
	c.value = data.get("value")

	if not MODES.has(c.mode):
		error.append("%s has no usable mode (%s)" % [c.label, c.mode])
		return null
	if NEEDS_VALUE.has(c.mode) and not data.has("value"):
		error.append("%s is a %s and needs a value" % [c.label, c.mode])
		return null
	# Only the continuous modes truly need a CC. Everything else is a button, and a
	# button is not always a note: the Launch Control's own custom mode puts all
	# sixteen of them on CCs, where 127 is a press and 0 a release.
	if data.has("cc"):
		c.cc = int(data["cc"])
	elif data.has("note"):
		c.note = int(data["note"])
	if c.is_continuous() and c.cc < 0:
		error.append("%s is a %s, which needs a CC rather than a note" % [c.label, c.mode])
		return null
	if c.cc < 0 and c.note < 0:
		error.append("%s is on neither a note nor a CC" % c.label)
		return null
	return c


## A fader or an encoder, as opposed to a button.
func is_continuous() -> bool:
	return mode == "norm" or mode == "relative"

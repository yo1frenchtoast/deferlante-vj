class_name MidiInput
extends Node

## MIDI control surface, driven by a profile rather than by code.
##
## Godot gives us note and controller events and nothing else — there is no MIDI
## *out* in the engine — so a surface here can never be told what the show is doing.
## It cannot light up to follow a preset recall, and it has no business having pages
## or banks, because nothing could say which page you are on. Every profile is
## therefore flat: fixed functions, all live at once, and the controller's own LED
## colours are set once in the maker's editor as a legend.
##
## What a controller sends is a choice, not a fact: both of the shipped devices let
## you assign every note, CC and channel. So the profiles in `res://midi/` describe
## one dialect that several devices speak, and adding a third controller is a third
## file — no GDScript, no export.
##
## Everything lands in `VJParam.set_value()` and `ShowActions.fire()`, the same doors the
## keyboard, OSC and the web surface use.

signal surface_changed

@export var enabled: bool = true

const DIR := "res://midi/"

## How often we look for a controller that was plugged in — or unplugged — after
## the show started. `OS.open_midi_inputs()` reads the device list once, so a cable
## pushed in during a set is invisible until we ask again.
const RESCAN_SECONDS := 2.0

## Relative encoders speak two's complement: 0x41 is one tick clockwise, 0x3F one
## tick back. Anything at or below this is a positive tick.
const RELATIVE_PIVOT := 64

## Where a button on a CC stops being let go and starts being pressed.
const BUTTON_PRESSED := 64

## How close, in fractions of the full travel, a fader has to come to the value it
## is about to take over. One MIDI step either side: closer than that and a coarse
## fader could sweep past its target without ever landing inside the window.
const TAKEOVER_WINDOW := 1.5 / 127.0

const MODES := ["norm", "relative", "set", "toggle", "momentary", "hold", "action", "rgb"]
const NEEDS_VALUE := ["set", "toggle", "momentary", "rgb"]

## Set by the controller, the same way `presets` and `api` are.
var registry: ParamRegistry
var fire: Callable
var touched: Callable
var actions: Array = []
var preset_count: int = 0

var _notes: Dictionary = {}
var _ccs: Dictionary = {}
var _channel: int = 0
var _profile: Dictionary = {}
var _ports: PackedStringArray = []
var _device: String = ""
var _rescan: float = 0.0
## Whether we ever got as far as opening the inputs, which decides whether there
## is anything to close or to re-open.
var _open: bool = false
## Whether a scan has ever run, so the first one always says what it found.
var _scanned: bool = false

## Soft takeover, per CC: false until the fader has met the value it is about to
## move. Without it, the first touch of an absolute fader after a preset recall
## throws the setting to wherever the operator's finger happens to be.
var _armed: Dictionary = {}
var _last_seen: Dictionary = {}
## True while we are the ones writing, so our own values do not disarm us.
var _writing: bool = false

## Momentary holds, by slug rather than by note: FREEZE and BOOST both sit on
## `global/speed`, and the value to come back to is the one from before the first
## of them was pressed, not the one the other left behind.
var _held_from: Dictionary = {}
var _holders: Dictionary = {}
## Notes still down in a `hold` control, waiting for their timer.
var _holding: Dictionary = {}


func _ready():
	set_process(false)


## Started by the controller once it can answer questions about settings and
## actions, rather than in `_ready()`: a child is ready before its parent, and a
## profile validated against an empty show would reject every line it has.
func start():
	if not enabled or Launch.midi_profile == "off":
		return

	# Godot has no MIDI driver on Android: the call is harmless there but can never
	# return anything, so we do not pretend to look.
	if OS.get_name() == "Android":
		return

	# Measured on 4.7.2: `OS.open_midi_inputs()` under `--headless` segfaults
	# outright — that build registers no MIDI driver and the call reaches through a
	# null singleton. A generator dumping the settings, or a render written with
	# `--write-movie`, must not take the show down with it.
	if DisplayServer.get_name() == "headless":
		print("MIDI: not opened — this build has no MIDI driver without a display")
		return

	OS.open_midi_inputs()
	_open = true
	set_process(true)
	_scan()


func _exit_tree():
	# Only what we opened: closing inputs that were never opened reaches the same
	# missing driver that crashes opening them.
	if _open:
		OS.close_midi_inputs()


## The device now driving the show, or empty. Looked up rather than remembered, and
## put on the status line for the same reason the OSC address is: a surface that is
## silently absent is the failure this project refuses everywhere else.
func surface() -> String:
	if _profile.is_empty():
		return ""
	return _profile.get("name", "")


func profile_id() -> String:
	return _profile.get("id", "")


func device() -> String:
	return _device


func _process(delta: float):
	_rescan += delta
	if _rescan < RESCAN_SECONDS:
		return
	_rescan = 0.0
	if OS.get_connected_midi_inputs() != _ports:
		# Re-opening is what makes a cable pushed in mid-set work at all.
		OS.close_midi_inputs()
		OS.open_midi_inputs()
		_scan()



# --------------------------------------------------------------------------
# Profiles
# --------------------------------------------------------------------------

func _scan():
	_ports = OS.get_connected_midi_inputs()
	var chosen := _pick(_ports)
	# Nothing has changed hands: same profile, same port. Said this way rather than
	# by comparing to an empty profile, so the very first scan still reports that it
	# found nothing — which is the answer somebody is most likely standing there
	# waiting for.
	if _scanned and chosen.get("id", "") == profile_id() and _device == chosen.get("device", ""):
		return
	_scanned = true

	_notes.clear()
	_ccs.clear()
	_armed.clear()
	_last_seen.clear()
	_profile = chosen
	_device = chosen.get("device", "")

	if _profile.is_empty():
		if _ports.is_empty():
			print("MIDI: nothing plugged in")
		else:
			print("MIDI: no profile matches %s" % ", ".join(_ports))
		surface_changed.emit()
		return

	_channel = maxi(0, int(_profile.get("channel", 1)) - 1)
	_index(_profile.get("controls", []))
	# A forced profile with nothing matching it is the ordinary state of a test rig,
	# and printing `on ""` would read like a fault rather than an answer.
	var where := "on \"%s\"" % _device if _device != "" else "forced, nothing plugged in"
	print("MIDI: %s %s — %d controls on channel %d"
		% [_profile.get("name", "?"), where, _notes.size() + _ccs.size(), _channel + 1])
	surface_changed.emit()


## The profile whose `match` appears in the name of a port that is actually there,
## unless the launcher named one outright. A forced profile is honoured even with
## nothing plugged in: it is the row you reach for precisely when the automatic
## answer is the wrong one.
func _pick(ports: PackedStringArray) -> Dictionary:
	var forced := Launch.midi_profile
	for profile in profiles_on_disk():
		var id: String = profile["id"]
		if forced != "" and forced != "auto":
			if id == forced:
				profile["device"] = _first_match(profile, ports)
				return profile
			continue
		var port := _first_match(profile, ports)
		if port != "":
			profile["device"] = port
			return profile
	return {}


func _first_match(profile: Dictionary, ports: PackedStringArray) -> String:
	for port in ports:
		for needle in profile.get("match", []):
			if port.to_lower().contains(String(needle).to_lower()):
				return port
	return ""


## Every profile shipped in `res://midi/`, sorted so the pick is the same on every
## machine rather than whatever order the filesystem hands back.
##
## Static, and read without a node, for the same reason `Presets.slots_on_disk()`
## is: the launcher has to offer this list in a scene that runs long before the
## show exists, and where the profiles live should stay knowledge of this script.
static func profiles_on_disk() -> Array:
	var out: Array = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		push_warning("MIDI: cannot read %s" % DIR)
		return out
	var names := dir.get_files()
	names.sort()
	for name in names:
		# An exported project serves `file.json` as `file.json.remap` when the
		# resource was converted; the name we want is the one without it.
		var plain := name.trim_suffix(".remap")
		if not plain.ends_with(".json"):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIR + plain))
		if typeof(parsed) != TYPE_DICTIONARY:
			push_warning("MIDI: %s is not a profile" % plain)
			continue
		parsed["id"] = plain.trim_suffix(".json")
		out.append(parsed)
	return out


## Build the two lookup tables, refusing what cannot work rather than discovering it
## at the third song. This is the local half of the guard `build_midi_map.py --check`
## runs in CI: a profile edited on the machine that runs the show never sees CI.
func _index(controls: Array):
	for control in controls:
		if typeof(control) != TYPE_DICTIONARY:
			continue
		var label: String = control.get("label", "?")
		var mode: String = control.get("mode", "")
		if not MODES.has(mode):
			push_error("MIDI: %s has no usable mode (%s)" % [label, mode])
			continue
		if NEEDS_VALUE.has(mode) and not control.has("value"):
			push_error("MIDI: %s is a %s and needs a value" % [label, mode])
			continue
		if not _target_exists(control):
			push_error("MIDI: %s aims at \"%s\", which nothing answers to"
				% [label, control.get("target", "")])
			continue

		# Only the continuous modes truly need a CC. Everything else is a button, and
		# a button is not always a note: the Launch Control's own custom mode puts
		# all sixteen of them on CCs, where 127 is a press and 0 a release.
		if mode in ["norm", "relative"] and not control.has("cc"):
			push_error("MIDI: %s is a %s, which needs a CC rather than a note"
				% [label, mode])
			continue

		if control.has("cc"):
			var cc := int(control["cc"])
			if _ccs.has(cc):
				push_error("MIDI: CC %d is claimed twice (%s)" % [cc, label])
				continue
			_ccs[cc] = control
		elif control.has("note"):
			var note := int(control["note"])
			if _notes.has(note):
				push_error("MIDI: note %d is claimed twice (%s)" % [note, label])
				continue
			_notes[note] = control
		else:
			push_error("MIDI: %s is on neither a note nor a CC" % label)


func _target_exists(control: Dictionary) -> bool:
	var target: String = control.get("target", "")
	if target == "":
		return false
	# `hold` fires a one-shot too — it only waits first — so its target lives in
	# the same namespace as an action's.
	if control.get("mode", "") in ["action", "hold"]:
		return _valid_actions().has(target)
	if target == "color/rgb":
		return control.get("mode", "") == "rgb"
	return registry != null and registry.has(target)


## Every one-shot a profile may name, built from what the show actually offers
## rather than from a list kept beside it: `ShowActions.LIST`, one shuffle per section, and
## the preset slots that exist.
func _valid_actions() -> PackedStringArray:
	var out := PackedStringArray(actions)
	if registry != null:
		for section in registry.groups():
			out.append("shuffle:" + section)
	for slot in range(1, preset_count + 1):
		out.append("preset:recall:%d" % slot)
		out.append("preset:save:%d" % slot)
	return out


# --------------------------------------------------------------------------
# Playing
# --------------------------------------------------------------------------

func _input(event: InputEvent):
	if not (event is InputEventMIDI):
		return
	var midi := event as InputEventMIDI
	if midi.channel != _channel:
		return
	match midi.message:
		MIDI_MESSAGE_CONTROL_CHANGE:
			_on_cc(midi.controller_number, midi.controller_value)
		MIDI_MESSAGE_NOTE_ON:
			# A note on at zero velocity is a note off; plenty of surfaces send it
			# that way, and a pad stuck down is not a bug we want to chase in a set.
			if midi.velocity > 0:
				_on_note_on(midi.pitch)
			else:
				_on_note_off(midi.pitch)
		MIDI_MESSAGE_NOTE_OFF:
			_on_note_off(midi.pitch)


func _on_cc(number: int, raw: int):
	var control = _ccs.get(number)
	if control == null:
		return

	# A button on a CC: half travel is the line between pressed and let go, which is
	# what every surface that does this means by it.
	if not (control["mode"] in ["norm", "relative"]):
		_button(control, raw, "cc%d" % number)
		return

	var p: VJParam = registry.find(control["target"])
	if p == null:
		return

	if control["mode"] == "relative":
		var ticks := raw if raw < RELATIVE_PIVOT else raw - 128
		if ticks != 0:
			_write(p, p.value + ticks * p.step)
		return

	var incoming := raw / 127.0
	var current := inverse_lerp(p.min_value, p.max_value, p.value)
	if not _armed.get(number, false):
		if not _caught_up(number, incoming, current):
			_last_seen[number] = incoming
			return
		_armed[number] = true
	_last_seen[number] = incoming
	_write(p, lerpf(p.min_value, p.max_value, incoming))


## Has this fader met the setting yet? Either it is already within a step of it, or
## it has crossed it since the last reading. Until then the fader is read and
## nothing is written, which is the whole point: after a preset recall the position
## of an absolute fader is a lie, and honouring it would throw the setting.
func _caught_up(number: int, incoming: float, current: float) -> bool:
	if absf(incoming - current) <= TAKEOVER_WINDOW:
		return true
	if not _last_seen.has(number):
		return false
	var was: float = _last_seen[number]
	return (was - current) * (incoming - current) < 0.0


func _on_note_on(note: int):
	var control = _notes.get(note)
	if control != null:
		_press(control, note)


func _on_note_off(note: int):
	var control = _notes.get(note)
	if control != null:
		_release(control, note)


## A button that arrived on a CC, springing or latching.
##
## A **springing** button sends 127 then 0 for one press, and reads as a press and a
## release. A **latching** one sends 127 on the first press and 0 on the next, so it
## never releases — measured on the Launch Control's factory custom mode, where all
## sixteen behave that way.
##
## That difference is not cosmetic. On a latching button a one-shot would fire on
## every *other* press, which is the kind of fault an operator blames on themselves.
## So the modes that only care that something happened act on every message, and the
## ones that have two states read the value rather than count presses.
func _button(control: Dictionary, raw: int, key: String):
	var down := raw >= BUTTON_PRESSED
	if not control.get("latching", false):
		if down:
			_press(control, key)
		else:
			_release(control, key)
		return

	match control["mode"]:
		"action", "set", "rgb":
			# Every press counts, whichever value the surface happens to be on.
			_press(control, key)
		"hold":
			# A button that never lets go cannot be held. Left inert rather than
			# turned into a delayed one-shot: `hold` exists so that a brush past a
			# pad cannot overwrite tonight's look, and a delay would restore the
			# danger while looking like the guard. The checker refuses it outright.
			push_warning("MIDI: %s is a hold on a latching button, which cannot be held"
				% control.get("label", "?"))
		"toggle":
			# The surface already alternates, so follow it rather than flip again:
			# its own lamp and the show then agree about which state this is.
			var p: VJParam = registry.find(control["target"])
			if p:
				_write(p, float(control["value"]) if down else p.min_value)
		"momentary":
			# One press to take it, one to give it back. Not what a held pad does,
			# but the only honest reading of a button that does not spring back.
			if down:
				_press(control, key)
			else:
				_release(control, key)


## `key` is whatever the press came in on — a note number, or "cc37". It only has
## to tell one held control from another, so that a pad and a button behave the
## same way once they are through the door.
func _press(control: Dictionary, key):
	var target: String = control["target"]

	match control["mode"]:
		"action":
			if touched.is_valid():
				touched.call()
			fire.call(target)
		"hold":
			_holding[key] = true
			var wait := float(control.get("hold_ms", 1000)) / 1000.0
			get_tree().create_timer(wait).timeout.connect(_hold_elapsed.bind(key, target))
		"rgb":
			_write_rgb(control["value"])
		"set":
			var p: VJParam = registry.find(target)
			if p:
				_write(p, float(control["value"]))
		"toggle":
			var p: VJParam = registry.find(target)
			if p:
				# Back to the bottom of the range rather than to a second stored
				# value: every setting worth a toggle here is an on/off whose off
				# is its minimum, and one number is one fewer to get wrong.
				var on := float(control["value"])
				_write(p, p.min_value if is_equal_approx(p.value, on) else on)
		"momentary":
			var p: VJParam = registry.find(target)
			if p == null:
				return
			var holders: Array = _holders.get(target, [])
			if holders.is_empty():
				_held_from[target] = p.value
			if not holders.has(key):
				holders.append(key)
			_holders[target] = holders
			_write(p, float(control["value"]))


func _release(control: Dictionary, key):
	var target: String = control["target"]

	if control["mode"] == "hold":
		_holding.erase(key)
		return
	if control["mode"] != "momentary":
		return

	var holders: Array = _holders.get(target, [])
	holders.erase(key)
	_holders[target] = holders
	if not holders.is_empty():
		return
	# The last finger off puts back the value from before the first one landed, so
	# leaning on FREEZE then BOOST and letting go of both is not a way to lose the
	# speed you were playing at.
	var p: VJParam = registry.find(target)
	if p and _held_from.has(target):
		_write(p, _held_from[target])
	_held_from.erase(target)


func _hold_elapsed(key, target: String):
	if not _holding.get(key, false):
		return
	_holding.erase(key)
	fire.call(target)


func _write_rgb(components):
	if typeof(components) != TYPE_ARRAY or components.size() < 3:
		return
	for i in range(3):
		var p: VJParam = registry.find(["color/red", "color/green", "color/blue"][i])
		if p:
			_write(p, float(components[i]))


func _write(p: VJParam, value: float):
	if touched.is_valid():
		touched.call()
	_writing = true
	p.set_value(value)
	_writing = false


## Somebody else moved a setting a fader is holding: a preset recall, the auto-pilot,
## a phone. The fader is now lying about where that setting is, so it has to earn it
## back before it writes again.
func on_param_changed(slug: String):
	if _writing:
		return
	for number in _ccs:
		var control: Dictionary = _ccs[number]
		if control["target"] == slug and control["mode"] == "norm":
			_armed[number] = false

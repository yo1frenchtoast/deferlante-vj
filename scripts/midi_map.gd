class_name MidiMap
extends RefCounted

## What a controller's controls do to the show. No hardware in here.
##
## `midi_input.gd` owns the device: finding it, picking its profile, and turning
## engine events into calls on this. All of the behaviour lives here, so that soft
## takeover, toggles, held pads and the rest can be exercised without a controller
## plugged in — which, on a machine that also holds the real one, is worth more than
## it sounds.

## Relative encoders speak two's complement: 0x41 is one tick clockwise, 0x3F one
## tick back. Anything at or below this is a positive tick.
const RELATIVE_PIVOT := 64

## Where a button on a CC stops being let go and starts being pressed.
const BUTTON_PRESSED := 64

## How close, in fractions of the full travel, a fader has to come to the value it
## is about to take over. One MIDI step either side: closer than that and a coarse
## fader could sweep past its target without ever landing inside the window.
const TAKEOVER_WINDOW := 1.5 / 127.0

## Set by the controller, through `MidiInput.setup()`.
var registry: ParamRegistry
var fire: Callable
var touched: Callable
var actions: Array = []
var preset_count: int = 0

var _notes: Dictionary = {}
var _ccs: Dictionary = {}

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


func size() -> int:
	return _notes.size() + _ccs.size()


func clear():
	_notes.clear()
	_ccs.clear()
	_armed.clear()
	_last_seen.clear()


## Build the two lookup tables, refusing what cannot work rather than discovering it
## at the third song. This is the local half of the guard `build_midi_map.py --check`
## runs in CI: a profile edited on the machine that runs the show never sees CI.
func index(controls: Array):
	for data in controls:
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var why := []
		var control := MidiControl.parse(data, why)
		if control == null:
			push_error("MIDI: " + why[0])
			continue
		if not _target_exists(control):
			push_error("MIDI: %s aims at \"%s\", which nothing answers to"
				% [control.label, control.target])
			continue

		if control.cc >= 0:
			if _ccs.has(control.cc):
				push_error("MIDI: CC %d is claimed twice (%s)" % [control.cc, control.label])
				continue
			_ccs[control.cc] = control
		else:
			if _notes.has(control.note):
				push_error("MIDI: note %d is claimed twice (%s)" % [control.note, control.label])
				continue
			_notes[control.note] = control


func _target_exists(control: MidiControl) -> bool:
	if control.target == "":
		return false
	# `hold` fires a one-shot too — it only waits first — so its target lives in
	# the same namespace as an action's.
	if control.mode in ["action", "hold"]:
		return valid_actions().has(control.target)
	if control.target == "color/rgb":
		return control.mode == "rgb"
	return registry != null and registry.has(control.target)


## Every one-shot a profile may name, built from what the show actually offers
## rather than from a list kept beside it: `ShowActions.LIST`, one shuffle per
## section, and the preset slots that exist.
func valid_actions() -> PackedStringArray:
	var out := PackedStringArray(actions)
	if registry != null:
		for section in registry.groups():
			out.append("shuffle:" + section)
	for slot in range(1, preset_count + 1):
		out.append("preset:recall:%d" % slot)
		out.append("preset:save:%d" % slot)
	return out


func on_cc(number: int, raw: int):
	var control: MidiControl = _ccs.get(number)
	if control == null:
		return

	# A button on a CC: half travel is the line between pressed and let go, which is
	# what every surface that does this means by it.
	if not control.is_continuous():
		_button(control, raw, "cc%d" % number)
		return

	var p := registry.find(control.target)
	if p == null:
		return

	if control.mode == "relative":
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


func on_note_on(note: int):
	var control: MidiControl = _notes.get(note)
	if control != null:
		_press(control, note)


func on_note_off(note: int):
	var control: MidiControl = _notes.get(note)
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
func _button(control: MidiControl, raw: int, key: String):
	var down := raw >= BUTTON_PRESSED
	if not control.latching:
		if down:
			_press(control, key)
		else:
			_release(control, key)
		return

	match control.mode:
		"action", "set", "rgb":
			# Every press counts, whichever value the surface happens to be on.
			_press(control, key)
		"hold":
			# A button that never lets go cannot be held. Left inert rather than
			# turned into a delayed one-shot: `hold` exists so that a brush past a
			# pad cannot overwrite tonight's look, and a delay would restore the
			# danger while looking like the guard. The checker refuses it outright.
			push_warning("MIDI: %s is a hold on a latching button, which cannot be held"
				% control.label)
		"toggle":
			# The surface already alternates, so follow it rather than flip again:
			# its own lamp and the show then agree about which state this is.
			var p := registry.find(control.target)
			if p:
				_write(p, float(control.value) if down else p.min_value)
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
func _press(control: MidiControl, key):
	var target := control.target

	match control.mode:
		"action":
			if touched.is_valid():
				touched.call()
			fire.call(target)
		"hold":
			_holding[key] = true
			var wait := control.hold_ms / 1000.0
			Engine.get_main_loop().create_timer(wait).timeout.connect(_hold_elapsed.bind(key, target))
		"rgb":
			_write_rgb(control.value)
		"set":
			var p := registry.find(target)
			if p:
				_write(p, float(control.value))
		"toggle":
			var p := registry.find(target)
			if p:
				# Back to the bottom of the range rather than to a second stored
				# value: every setting worth a toggle here is an on/off whose off
				# is its minimum, and one number is one fewer to get wrong.
				var on := float(control.value)
				_write(p, p.min_value if is_equal_approx(p.value, on) else on)
		"momentary":
			var p := registry.find(target)
			if p == null:
				return
			var holders: Array = _holders.get(target, [])
			if holders.is_empty():
				_held_from[target] = p.value
			if not holders.has(key):
				holders.append(key)
			_holders[target] = holders
			_write(p, float(control.value))


func _release(control: MidiControl, key):
	var target := control.target

	if control.mode == "hold":
		_holding.erase(key)
		return
	if control.mode != "momentary":
		return

	var holders: Array = _holders.get(target, [])
	holders.erase(key)
	_holders[target] = holders
	if not holders.is_empty():
		return
	# The last finger off puts back the value from before the first one landed, so
	# leaning on FREEZE then BOOST and letting go of both is not a way to lose the
	# speed you were playing at.
	var p := registry.find(target)
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
		var p := registry.find(["color/red", "color/green", "color/blue"][i])
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
		var control: MidiControl = _ccs[number]
		if control.target == slug and control.mode == "norm":
			_armed[number] = false

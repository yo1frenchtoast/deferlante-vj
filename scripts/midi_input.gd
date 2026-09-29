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
## This script owns the device: finding it, choosing its profile, and turning the
## engine's events into calls on `MidiMap`. Everything lands in
## `VJParam.set_value()` and `ShowActions.fire()`, the same doors the keyboard, OSC
## and the web surface use.

signal surface_changed

@export var enabled: bool = true

const DIR := "res://midi/"

## How often we look for a controller that was plugged in — or unplugged — after
## the show started. `OS.open_midi_inputs()` reads the device list once, so a cable
## pushed in during a set is invisible until we ask again.
const RESCAN_SECONDS := 2.0

## What the controls do. Everything about a press lives there, and nothing about a
## device does.
var map := MidiMap.new()

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



func _ready():
	set_process(false)


## What the controller can answer for, handed over once it can. See `start()`.
func setup(registry: ParamRegistry, fire: Callable, touched: Callable,
		actions: Array, preset_count: int):
	map.registry = registry
	map.fire = fire
	map.touched = touched
	map.actions = actions
	map.preset_count = preset_count


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

	map.clear()
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
	map.index(_profile.get("controls", []))
	# A forced profile with nothing matching it is the ordinary state of a test rig,
	# and printing `on ""` would read like a fault rather than an answer.
	var where := "on \"%s\"" % _device if _device != "" else "forced, nothing plugged in"
	print("MIDI: %s %s — %d controls on channel %d"
		% [_profile.get("name", "?"), where, map.size(), _channel + 1])
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
			map.on_cc(midi.controller_number, midi.controller_value)
		MIDI_MESSAGE_NOTE_ON:
			# A note on at zero velocity is a note off; plenty of surfaces send it
			# that way, and a pad stuck down is not a bug we want to chase in a set.
			if midi.velocity > 0:
				map.on_note_on(midi.pitch)
			else:
				map.on_note_off(midi.pitch)
		MIDI_MESSAGE_NOTE_OFF:
			map.on_note_off(midi.pitch)


## Somebody else moved a setting: see `MidiMap.on_param_changed()`.
func on_param_changed(slug: String):
	map.on_param_changed(slug)

class_name Presets
extends Node

## Named snapshots of every setting, saved to disk and recalled live.
##
## A recall is a **crossfade**, not a jump: every setting slides from where it is
## to where the preset wants it, over `recall_time`. That is the difference between
## a preset being a scene change and a preset being an edit — at 4 seconds the room
## moves from one look to another and the audience never sees a cut. Set the time
## to 0 and it snaps, which is what you want for a stab.
##
## Slots are saved to `user://presets.json`, so they survive a restart and travel
## with the machine rather than with the project.

signal slots_changed

const SLOTS := 9
const PATH := "user://presets.json"

## A preference rather than part of a look. Recalling a preset must not light the
## panel back up on the wall after the operator has deliberately dimmed it.
const EXCLUDED := ["global/panel"]

@export var recall_time: float = 2.0

## Set by the controller: called as () -> Array[VJParam].
var all_params: Callable

## True while a slot is being applied. Rules that react to one setting changing —
## "touching a colour means you want manual" — must stay quiet during a recall,
## or a preset's own values fight each other as they land.
var applying: bool = false

var _slots: Dictionary = {}
var _from: Dictionary = {}
var _to: Dictionary = {}
var _fade: float = -1.0
var _fade_length: float = 1.0


func _ready():
	_load()


func has_slot(slot: int) -> bool:
	return _slots.has(str(slot))


## Which slots are on disk, read without a node. The launcher runs in its own
## scene, long before this one exists, and it has to say which slots it can offer
## to start on. It reads the file rather than keeps a list beside it: the path and
## the shape of the file stay knowledge of this script alone.
static func slots_on_disk() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var text := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var used: Array = []
	for i in range(1, SLOTS + 1):
		if parsed.has(str(i)):
			used.append(i)
	return used


func used_slots() -> Array:
	var used: Array = []
	for i in range(1, SLOTS + 1):
		if has_slot(i):
			used.append(i)
	return used


# --------------------------------------------------------------------------
# Saving
# --------------------------------------------------------------------------

func save_slot(slot: int) -> bool:
	if slot < 1 or slot > SLOTS or not all_params.is_valid():
		return false
	var snapshot := {}
	for p in all_params.call():
		if not EXCLUDED.has(p.slug):
			snapshot[p.slug] = p.value
	_slots[str(slot)] = snapshot
	_write()
	slots_changed.emit()
	print("Preset %d saved (%d settings)" % [slot, snapshot.size()])
	return true


func clear_slot(slot: int) -> bool:
	if not has_slot(slot):
		return false
	_slots.erase(str(slot))
	_write()
	slots_changed.emit()
	return true


# --------------------------------------------------------------------------
# Recalling
# --------------------------------------------------------------------------

## `instant` lands the preset in one frame whatever `recall_time` says. The show
## uses it to start on a slot: a crossfade from the defaults is a fade from a look
## nobody chose, and there is no audience yet to fade for.
func recall(slot: int, instant: bool = false) -> bool:
	if not has_slot(slot) or not all_params.is_valid():
		return false

	var target: Dictionary = _slots[str(slot)]
	_from.clear()
	_to.clear()
	for p in all_params.call():
		# A setting saved before this one existed is simply left alone, so an old
		# preset keeps working after new settings are added.
		if target.has(p.slug):
			_from[p.slug] = p.value
			_to[p.slug] = float(target[p.slug])

	if instant or recall_time <= 0.0:
		_apply(1.0)
		_fade = -1.0
	else:
		_fade = 0.0
		_fade_length = recall_time
	return true


func is_fading() -> bool:
	return _fade >= 0.0


func _process(delta: float):
	if _fade < 0.0:
		return
	_fade += delta
	var t := clampf(_fade / _fade_length, 0.0, 1.0)
	# Smoothstep rather than linear: a linear crossfade starts and stops abruptly,
	# and on a slow move that beginning is exactly what gives the cut away.
	_apply(t * t * (3.0 - 2.0 * t))
	if t >= 1.0:
		_fade = -1.0


func _apply(t: float):
	if not all_params.is_valid():
		return
	applying = true
	for p in all_params.call():
		if _to.has(p.slug):
			p.set_value(lerpf(_from[p.slug], _to[p.slug], t))
	applying = false


# --------------------------------------------------------------------------
# Disk
# --------------------------------------------------------------------------

func _write():
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Presets: cannot write %s" % PATH)
		return
	file.store_string(JSON.stringify(_slots, "\t"))


func _load():
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_slots = parsed
		print("Presets: %d loaded from %s" % [_slots.size(), PATH])

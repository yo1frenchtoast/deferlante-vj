class_name ShowActions
extends RefCounted

## The one-shots the show offers, and the one door they go through.
##
## Every surface routes here: OSC, the REST API, the web page, the MIDI profiles.
## The REST spec advertises `LIST`, and for a while the API itself matched on a
## hand-written list beside it. They came apart the moment an action was added — the
## spec offered `shuffle` and the endpoint answered "unknown action". One door now,
## and it is the same list that describes it.

## Named once: the REST spec advertises these, the Chataigne module is built from
## them, and the web page draws a button for each.
const LIST := ["glitch", "randomize", "shuffle"]

var _circle: Node
var _autopilot: Node
var _presets: Node
var _randomize_all: Callable


func _init(circle: Node, autopilot: Node, presets: Node, randomize_all: Callable):
	_circle = circle
	_autopilot = autopilot
	_presets = presets
	_randomize_all = randomize_all


## Fire a one-shot action by name, or answer false if there is no such thing.
func fire(name: String) -> bool:
	if name.begins_with("preset:"):
		var bits := name.split(":")
		if bits.size() < 3:
			return false
		if bits[1] == "save":
			_presets.save_slot(int(bits[2]))
		else:
			_presets.recall(int(bits[2]))
		return true

	# "shuffle:lasers" rolls one section; bare "shuffle" rolls the whole show.
	if name.begins_with("shuffle:"):
		_autopilot.roll_now(name.substr("shuffle:".length()))
		return true

	if not LIST.has(name):
		return false
	match name:
		"glitch":
			_circle.apply_glitch()
		"randomize":
			_randomize_all.call()
		"shuffle":
			_autopilot.roll_now()
	return true

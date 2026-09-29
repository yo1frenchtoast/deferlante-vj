class_name AudioModulation
extends RefCounted

## What the sound does to the picture.
##
## The master is REACTIVITY, and it is zero by default, so nothing moves until asked.
## The four amounts scale it per effect; the fifth is the chance that a kick rolls
## the show, which is not a multiplier at all.

enum { BASS, MID, TREBLE }

## The master. Public because the status line and the phones show it.
var react: float = 0.0
var amounts := {"lasers": 2.5, "spot": 2.5, "sphere": 2.5, "warp": 2.5,
	"randomizer": 0.0}

var _registry: ParamRegistry
var _audio: Node
## Held, not only bound: a Callable made from a RefCounted's method does not keep the
## object alive, and the rig would be freed under the targets that draw through it.
var _rig: LaserRig
var _targets: Array = []
var _was_active: bool = false


func _init(registry: ParamRegistry, audio: Node, rig: LaserRig,
		circle: Node, sphere: Node, warp: Node):
	_registry = registry
	_audio = audio
	_rig = rig
	_targets = _build(rig, circle, sphere, warp)


## What the sound moves, one line per target.
##
## Each entry names the setting that holds the *base* value, the band that drives
## it, the amount slider that scales it, and how strongly. Reading the base from the
## setting rather than from a copy is the point: adding a target used to mean a
## shadow variable, a modified setter, and a line in each of two hand-written loops,
## and the four could drift apart.
##
## Size moves at a third of the weight of thickness — a radius reads far more
## strongly than a width, and matching them made every hit look like a blowout.
func _build(rig: LaserRig, circle: Node, sphere: Node, warp: Node) -> Array:
	return [
		{"slug": "lasers/width", "band": MID, "amount": "lasers", "weight": 1.0,
			"set": rig.draw_width},
		{"slug": "lasers/length", "band": MID, "amount": "lasers", "weight": 0.33,
			"set": rig.draw_length},
		{"slug": "spot/width", "band": BASS, "amount": "spot", "weight": 1.0,
			"set": circle.set_line_width},
		{"slug": "spot/radius", "band": BASS, "amount": "spot", "weight": 0.33,
			"set": func(v: float): circle.base_radius = v},
		{"slug": "sphere/width", "band": TREBLE, "amount": "sphere", "weight": 1.0,
			"set": func(v: float): sphere.line_width = v},
		{"slug": "sphere/size", "band": TREBLE, "amount": "sphere", "weight": 0.33,
			"set": func(v: float): sphere.circle_size = v},
		{"slug": "warp/speed", "band": BASS, "amount": "warp", "weight": 1.0,
			"set": func(v: float): warp.approach = v},
		{"slug": "warp/width", "band": BASS, "amount": "warp", "weight": 0.33,
			"set": func(v: float): warp.line_width = v},
	]


## The chance that a kick rolls the show. Scaled by REACTIVITY like every other
## amount, so the master still switches the whole of the sound response off in one
## move.
func beat_chance() -> float:
	return react * amounts["randomizer"]


## The sound *adds* to each target rather than setting it, and nothing here writes
## to a VJParam — so the sliders keep meaning what they say, REACTIVITY back to 0
## restores exactly the look that was there, and the sound never lands in a preset
## or fights the operator for a slider.
##
## Each effect follows a different band. Three effects breathing on one envelope
## read as a single thing pumping; on separate bands the picture comes apart into
## layers. The kick drives the spotlight, the biggest shape on screen.
func apply():
	if react <= 0.0 or not _audio.capturing:
		if _was_active:
			_was_active = false
			_reset()
		return
	_was_active = true

	var bands := [_audio.bass, _audio.mid, _audio.treble]
	for m in _targets:
		var base: float = _registry.find(m["slug"]).value
		var drive: float = react * amounts[m["amount"]] * bands[m["band"]]
		m["set"].call(base * (1.0 + drive * m["weight"]))


func _reset():
	for m in _targets:
		m["set"].call(_registry.find(m["slug"]).value)

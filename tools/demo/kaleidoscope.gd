extends Node

## The second clip of the README: one setup, held. It is the recipe written out under the
## clip, and nothing else — one colour, folded twelve ways, strokes long and thin so the
## mirror has something to repeat.
##
##     tools/make_demo.sh kaleidoscope
##
## If the recipe in the README changes, this changes with it, and the other way round.

const LENGTH := 5.6

var show: Node
var reg: ParamRegistry


func _ready():
	seed(12)
	Launch.console_window = false
	Launch.spout_enabled = false
	Launch.hide_panel = true

	var root: Node = load("res://scenes/main.tscn").instantiate()
	root.get_node("VJController/MidiInput").enabled = false
	add_child(root)
	show = root.get_node("VJController")
	reg = show.registry
	show.panel.hidden_for_good = true
	show.panel.rows.visible = false
	show.panel.help_box.visible = false

	# COLOR first, then the mode: writing a channel flips the mode to manual by itself.
	_put("color/red", 1.0)
	_put("color/green", 0.0)
	_put("color/blue", 0.0)
	_put("color/saturation", 1.0)
	_put("color/mode", 1.0)
	# MIRROR
	_put("mirror/segments", 12)
	_put("mirror/rotation", 0.22)
	_put("mirror/effect", 1.0)
	# LASERS
	_put("lasers/count", 18)
	_put("lasers/width", 1.0)
	_put("lasers/length", 2.0)
	_put("lasers/spin", -0.6)
	_put("lasers/parallel", 0.58)
	_put("lasers/scroll", 1.0)
	# SPOTLIGHT
	_put("spot/radius", 295)
	_put("spot/width", 17.0)
	_put("spot/hold", 0.6)
	_put("spot/frequency", 13.5)
	# SPHERE
	_put("sphere/count", 18)
	_put("sphere/sides", 6)
	_put("sphere/glass", 1.0)
	# GLOBAL
	_put("global/speed", 0.4)
	_put("global/chaos", 0.56)
	_put("global/glow", 1.25)


func _put(slug: String, value: float):
	reg.find(slug).set_value(value)

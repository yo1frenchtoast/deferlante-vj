extends Node

## The still under the clips of the README: the room, and the panel open beside it.
##
##     tools/make_demo.sh screenshot
##
## The last frame of a short take. The panel is pinned open, in English, and it reads a layout file
## of its own, so the picture is the panel as it comes out of the box and not the way that
## whoever runs this has arranged theirs.

const LENGTH := 4.0


func _ready():
	seed(31)
	Launch.console_window = false
	Launch.spout_enabled = false
	Launch.hide_panel = false
	# The README is in English, whatever this machine is set to.
	Launch.language = Lang.EN

	var root: Node = load("res://scenes/main.tscn").instantiate()
	root.get_node("VJController/MidiInput").enabled = false
	root.get_node("VJController/ControlPanel").layout_path = "user://demo_layout.json"
	add_child(root)
	var show := root.get_node("VJController")
	show.panel.pinned = true
	var reg: ParamRegistry = show.registry
	reg.find("global/glow").set_value(0.85)
	reg.find("lasers/count").set_value(12)
	reg.find("lasers/width").set_value(3.0)
	reg.find("lasers/length").set_value(1.3)
	reg.find("sphere/count").set_value(26)
	reg.find("spot/radius").set_value(250)

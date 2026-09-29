extends Node

## The clip at the top of the README, played by the show itself.
##
##     tools/make_demo.sh
##
## Run under `--write-movie`, which renders on its own clock and not on the wall's.
## That is why every beat is a timer or a tween on game time: they stay in step with the
## movie writer, where a script that drove the show over HTTP drifted by eight seconds
## against a fifteen-second plan.
##
## Kept sparse on purpose. A GIF pays for every pixel that changes, and this is strokes on
## black, so the black is what makes it cheap: few strokes, and GLOW at 0 throughout — a
## halo is a wide soft gradient, the most expensive thing on screen.
##
## Two things that cost a re-shoot to learn. `sphere/count` cannot be swept: its setter
## rebuilds every circle, so a tween writing it each frame frees them before they are ever
## drawn and the sphere renders as nothing. It is stepped, once, here. And `sphere/size`
## is what makes the sphere read as a ball, not the count and not the depth: at the
## shipping 0.13, forty circles are forty faint rings, and at 0.26 it is a sphere.

## The length of the whole take, in seconds. `make_demo.sh` reads it from here.
const LENGTH := 17.5

var show: Node
var reg: ParamRegistry


func _ready():
	seed(2026)
	# What the film must not depend on: this machine's launcher settings.
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

	_set_up()
	_score()


func _set_up():
	_put("global/glow", 0.0)
	_put("lasers/count", 10)
	_put("lasers/width", 3.0)
	_put("lasers/length", 1.4)
	_put("sphere/count", 0)
	_put("sphere/size", 0.26)
	_put("sphere/spin", 0.8)
	_put("spot/radius", 230)
	_put("color/saturation", 0.85)


## What happens, and when. One line each.
func _score():
	# The strokes and the spotlight, then lined up into a curtain.
	_at(1.2, func(): _ramp("lasers/parallel", 1.0, 1.2); _ramp("lasers/scroll", 0.7, 1.2))
	# The sphere, turning with depth.
	_at(3.0, func(): _put("sphere/count", 20); _ramp("lasers/parallel", 0.0, 0.8); _ramp("lasers/scroll", 0.0, 0.8))
	# The mirror opens.
	_at(5.0, func(): _put("mirror/segments", 8); _put("mirror/effect", 1); _ramp("mirror/rotation", 0.22, 1.2))
	_at(6.4, func(): _put("mirror/segments", 12))
	# The wave.
	_at(7.0, func(): _put("fx/wave_count", 6); _ramp("fx/wave", 0.9, 0.9))
	_at(8.8, func(): _ramp("fx/wave", 0.0, 0.6))
	# The aberration opens from a plain fringe to a lens.
	_at(9.2, func(): _ramp("fx/aberration", 0.7, 0.6); _ramp("fx/aberration_radial", 1.0, 1.2))
	_at(10.6, func(): _ramp("fx/aberration", 0.0, 0.5))
	# The slice glitch, in bursts, each with a glitch of the spotlight.
	for t in [11.0, 11.6, 12.2]:
		_at(t, func(): _burst("fx/slice", 0.7, 0.14); show.circle.apply_glitch())
	# The tunnel, with its twist, and back out.
	_at(12.8, func(): _ramp("fx/tunnel", 0.6, 0.8); _ramp("fx/tunnel_twist", 0.5, 1.2))
	_at(14.8, func(): _ramp("fx/tunnel", 0.0, 0.8); _ramp("fx/tunnel_twist", 0.0, 0.8))
	# A last breath of everything, and the fold closes.
	_at(15.4, func(): _ramp("fx/wave", 0.3, 0.5); _ramp("fx/aberration", 0.3, 0.5))
	_at(16.0, func(): _ramp("mirror/rotation", 0.0, 0.6); _put("mirror/effect", 0))
	_at(16.4, func(): _ramp("fx/wave", 0.0, 0.4); _ramp("fx/aberration", 0.0, 0.4))


func _put(slug: String, value: float):
	reg.find(slug).set_value(value)


func _at(seconds: float, action: Callable):
	get_tree().create_timer(seconds).timeout.connect(action)


func _ramp(slug: String, to: float, seconds: float):
	var p := reg.find(slug)
	create_tween().tween_method(func(v): p.set_value(v), p.value, to, seconds)


## Up for a moment, then straight back down.
func _burst(slug: String, to: float, seconds: float):
	_put(slug, to)
	get_tree().create_timer(seconds).timeout.connect(func(): _put(slug, 0.0))

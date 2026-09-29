class_name LaserRig
extends RefCounted

## The strokes that sweep the screen, as one instrument.
##
## They are instanced from `scenes/laser.tscn`, and there are as many as the LASERS
## COUNT setting says. Every setting here is applied to all of them and remembered,
## so that a stroke spawned mid-set comes up looking like the ones already there.
##
## The fan's angle and its scrolling phase live here rather than in each stroke, so
## that they agree even when a stroke is spawned in the middle of a set.

var lasers: Array[Line2D] = []

var speed: float = 1.0
var chaos: float = 0.0
var width: float = 5.0
var halo: float = 0.0
var length: float = 1.0
var spin: float = 1.0
var align: float = 0.0
## How fast the parallel fan drifts sideways, signed.
var scroll: float = 0.0

var _scene: PackedScene
var _parent: Node
var _palette: Palette
var _area: Callable
var _align_angle: float = 0.0
var _scroll_phase: float = 0.0


## `area` answers with the size strokes are scattered over when they spawn. It is a
## callable rather than a number because the window can change size under us.
func _init(scene: PackedScene, parent: Node, palette: Palette, area: Callable):
	_scene = scene
	_parent = parent
	_palette = palette
	_area = area


func spawn(count: int):
	var screen_size: Vector2 = _area.call()
	for i in range(count):
		var laser: Line2D = _scene.instantiate()
		_parent.add_child(laser)
		laser.position = Vector2(
			randf_range(0, screen_size.x),
			randf_range(0, screen_size.y)
		)
		# A laser spawned mid-set must inherit the current settings.
		laser.speed_scale = speed
		laser.spin_scale = spin
		laser.chaos = chaos
		laser.width = width
		laser.use_palette(_palette)
		laser.set_length_scale(length)
		laser.align = align
		laser.set_halo(halo)
		lasers.append(laser)


func set_count(target: int):
	while lasers.size() > target:
		lasers.pop_back().queue_free()
	if lasers.size() < target:
		spawn(target - lasers.size())
	_reslot()


## Spreads the strokes evenly across the fan. Without this the scanlines would
## inherit the random spacing they had as a scatter, which is most of what makes
## them read as scanlines rather than as parallel lines that happen to coincide.
func _reslot():
	for i in range(lasers.size()):
		lasers[i].slot = float(i) / maxf(1.0, float(lasers.size()))


func set_speed(value: float):
	speed = value
	for l in lasers:
		l.speed_scale = value


func set_chaos(value: float):
	chaos = value
	for l in lasers:
		l.chaos = value


func set_halo(value: float):
	halo = value
	for l in lasers:
		l.set_halo(value)


func set_width(value: float):
	width = value
	for l in lasers:
		l.width = value


func set_length(value: float):
	length = value
	for l in lasers:
		l.set_length_scale(value)


func set_spin(value: float):
	spin = value
	for l in lasers:
		l.spin_scale = value


func set_align(value: float):
	align = value
	for l in lasers:
		l.align = value


## What the sound writes. Not `set_width()` and `set_length()`: those are the
## settings, and the sound must never change what a setting says — it only leans on
## what is drawn.
func draw_width(value: float):
	for l in lasers:
		l.width = value


func draw_length(value: float):
	for l in lasers:
		l.set_length_scale(value)


func randomize_look():
	for l in lasers:
		l.randomize_look()


## The fan turns and scrolls once per frame, and every stroke reads the same two
## numbers — that is what keeps them parallel and evenly spaced.
func process(delta: float):
	if align <= 0.0:
		return
	var step := delta * speed
	_align_angle += spin * step * 0.4
	_scroll_phase += scroll * step * 0.25
	for l in lasers:
		l.align_angle = _align_angle
		l.scroll_phase = _scroll_phase

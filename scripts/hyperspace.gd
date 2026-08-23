extends Node2D

## A star field rushing past the eye, drawn as streaks.
##
## Stars live in a tube ahead of the viewer. Each one holds a fixed direction
## `(x, y)` and a depth `z`, and only the depth changes: the star walks towards the
## eye and its projection `xy / z` runs away from the centre of the screen, slowly
## at first and then very fast. That acceleration is the whole effect. Nothing here
## animates a streak growing longer — the streak grows because the star is nearer.
##
## Unlike the other effects this one draws itself in a single canvas item rather
## than one `Line2D` per element. At 300 stars that is 300 nodes and 300 halos
## saved; and a star is two points, so there is no shape worth keeping between
## frames anyway.

## Depth at which a star has passed the eye and is recycled. Not 0: the projection
## divides by it, and the last few centimetres are off screen in any case.
const NEAR := 0.04

## Number of stars. 0 switches the effect off outright — no work, no draw.
@export var star_count: int = 0:
	set(value):
		star_count = maxi(0, value)
		if is_inside_tree():
			_rebuild()
## Depths crossed per second. At 1 a star takes about a second to come the whole way.
@export var approach: float = 1.0
## How long a trail to draw, in **seconds of travel**. It is a shutter speed, not a
## length: the same setting gives short dashes at low speed and long streaks at high
## speed, which is what the eye expects and one less setting to ride during a set.
@export var shutter: float = 0.12
## Radius of the tube at the far plane, in half-screens. Small keeps the stars
## coming straight at you; large starts them wide and throws them past the corners.
@export var field: float = 0.7
@export var line_width: float = 2.0

## Mirrors the HALO setting, like every other effect.
var halo_amount: float = 0.0
var speed_scale: float = 1.0
## 0 flies dead ahead. Raising it swerves the vanishing point and lets each star
## keep its own pace, so the field stops moving as one block.
var chaos: float = 0.0
## Shared reference to the colour state: nothing is copied.
var palette: Palette

var _time: float = 0.0
var _x: PackedFloat32Array = []
var _y: PackedFloat32Array = []
var _z: PackedFloat32Array = []
var _hues: PackedFloat32Array = []
## Per-star pace offset in [-0.5, 0.5], scaled by CHAOS and otherwise unused.
var _wobble: PackedFloat32Array = []


func _ready():
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	_rebuild()


func _rebuild():
	_x.resize(star_count)
	_y.resize(star_count)
	_z.resize(star_count)
	_hues.resize(star_count)
	_wobble.resize(star_count)
	for i in range(star_count):
		_spawn(i, randf())
	# A field of nought stars must not cost a frame of anything.
	set_process(star_count > 0)
	queue_redraw()


## Places star `i` on a fresh line of sight at depth `depth`. Called both to build
## the field and to recycle a star that has gone past the eye.
func _spawn(index: int, depth: float):
	# sqrt of a uniform draw spreads the stars evenly over the disc. Without it
	# they crowd the axis, where they also happen to move the least, and the middle
	# of the screen silts up.
	var radius := sqrt(randf()) * field
	var angle := randf() * TAU
	_x[index] = cos(angle) * radius
	_y[index] = sin(angle) * radius
	_z[index] = depth
	_hues[index] = randf()
	_wobble[index] = randf() - 0.5


func randomize_look():
	for i in range(star_count):
		_hues[i] = randf()


func _process(delta: float):
	_time += delta
	var rate := approach * speed_scale
	for i in range(star_count):
		_z[i] -= delta * rate * (1.0 + _wobble[i] * chaos * 1.5)
		# Both ends wrap, so a negative SPEED backs the field out again rather than
		# emptying the screen: the show reverses everything else the same way.
		if _z[i] <= NEAR:
			_spawn(i, 1.0)
		elif _z[i] > 1.0:
			_spawn(i, NEAR)
	queue_redraw()


func _draw():
	if star_count == 0 or palette == null:
		return

	var viewport := get_viewport_rect().size
	# The projection is expressed in half-screens, so a field set for a 16:9 wall
	# reads the same on a 4:3 one.
	var unit := viewport.y / 2.0
	var centre := viewport / 2.0
	if chaos > 0.0:
		# The vanishing point wanders. It is the one thing that stops the effect
		# reading as a screensaver: a ship on a heading, not a fixed tunnel.
		centre += Vector2(sin(_time * 0.7), cos(_time * 0.53)) * chaos * 0.25 * unit

	var rate := approach * speed_scale
	for i in range(star_count):
		var z := _z[i]
		# Where the star was `shutter` seconds ago. Signed, so the trail sits behind
		# the star whichever way the field is running.
		var tail := maxf(NEAR, z + shutter * rate * (1.0 + _wobble[i] * chaos * 1.5))
		var dir := Vector2(_x[i], _y[i]) * unit

		# Fade in over the far quarter of the tube. A star switched on at full
		# brightness pops, and with a hundred of them recycling the whole field
		# twinkles at the back.
		var tint := palette.resolve(_hues[i])
		tint.a = smoothstep(1.0, 0.75, z)
		if tint.a <= 0.004:
			continue
		# Perspective on the thickness as well: a streak about to pass the ear is
		# wider than one still at the back.
		var width := line_width * clampf(0.6 / (z + 0.4), 0.5, 2.0)

		var head := centre + dir / z
		var back := centre + dir / tail
		# The halo is drawn here rather than hung off a `Halo` node, which needs a
		# Line2D to echo. Same rings, same widths, read from the same constant, so
		# the two cannot drift apart. Additive blending is a sum, so drawing the
		# rings after the core rather than under it changes nothing.
		if halo_amount > 0.0:
			for ring in Halo.RINGS:
				draw_line(back, head,
					Color(tint.r, tint.g, tint.b,
						tint.a * clampf(ring[1] * halo_amount, 0.0, 1.0)),
					width + ring[0] * halo_amount)
		draw_line(back, head, tint, width)


func use_palette(p: Palette):
	palette = p

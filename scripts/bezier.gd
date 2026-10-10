extends Node2D

## Cubic curves that bounce around the screen, in the manner of the old Windows
## screensaver.
##
## Each curve is four control points, and each point is a ball with a velocity that
## bounces off the edges of the picture. The curve is whatever those four balls
## happen to describe: it folds, unfolds and loops without anything being animated
## as a shape.
##
## The effect keeps **no history**. The ghost of the old screensaver — the same curve
## repeated a little further back — is the TRAIL setting's job (`motion_blur.gd`),
## which echoes everything in the picture and does it for one pass instead of one
## copy per curve. Here a curve is drawn once, where it is now.
##
## Like `hyperspace.gd` it draws itself in a single canvas item rather than one
## `Line2D` per curve: a curve is one polyline of a few dozen points, and there is no
## shape worth keeping between frames.

## Points sampled along each curve. Enough that a tight loop still reads as a curve
## at 4K, few enough that twelve curves and their halos stay a trifle.
const SEGMENTS := 48
## Control points per curve. A cubic: the two in the middle pull, the two at the ends
## hold.
const POINTS := 4
## Slowest and fastest a point travels, in screens per second. A point is never
## still: a curve with a stationary end looks like a fault, not a choice.
const SPEED_MIN := 0.12
const SPEED_MAX := 0.34
## A frame longer than this is a hitch, not a long step. Without the cap a stall
## flings the points a whole screen at once and they cross the edge twice.
const MAX_STEP := 0.1

## Number of curves. 0 switches the effect off outright — no work, no draw.
@export var count: int = 0:
	set(value):
		# Only a real change rebuilds, for the reason given in `hyperspace.gd`: a preset
		# crossfade writes every setting every frame, and respawning the curves on each
		# write would restart them sixty times a second.
		var wanted := maxi(0, value)
		if wanted == count:
			return
		count = wanted
		if is_inside_tree():
			_rebuild()
## How fast the points travel, as a multiple of their own pace. The global SPEED
## scales it again, and a negative one runs the curves backwards.
@export var pace: float = 1.0
@export var line_width: float = 2.0
## How much of each curve is drawn, as a fraction of its whole length, taken from the
## middle. 1 is the full curve between its two end points; a small value leaves a short
## stretch of it, which still follows every fold of the four points. The control
## points keep moving the whole time, so this is a window on the curve and not a
## smaller curve. Above 1 the curve is carried on past its two end points, along the
## line the polynomial already draws: it reaches for the edges of the picture and
## leaves them, which is the point of asking for it.
@export_range(0.05, 2.0) var length: float = 1.0
## How fast the colours slide through the palette, in turns of the wheel per ten
## seconds. 0 leaves each curve the colour it was born with.
@export var hue_drift: float = 0.3

## Mirrors the HALO setting, like every other effect.
var halo_amount: float = 0.0
var speed_scale: float = 1.0
## 0 keeps every point at its own steady pace. Raising it lets them accelerate and
## hang back independently, so the curve stops moving as one body.
var chaos: float = 0.0
## Shared reference to the colour state: nothing is copied.
var palette: Palette

## Control points, `POINTS` per curve, in screens (0..1 both ways). Kept off pixels so
## a resize of the window does not leave the curves outside the picture.
var _pos: PackedVector2Array = []
## Velocity of each point, in screens per second.
var _vel: PackedVector2Array = []
## Per-point pace offset in [-0.5, 0.5], scaled by CHAOS and otherwise unused.
var _wobble: PackedFloat32Array = []
var _hues: PackedFloat32Array = []


func _ready():
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	_rebuild()


## Only the curves that are new get placed. Resizing keeps what the arrays already
## hold, so a count that moves during a crossfade does not teleport the ones on screen.
func _rebuild():
	var had := _hues.size()
	_pos.resize(count * POINTS)
	_vel.resize(count * POINTS)
	_wobble.resize(count * POINTS)
	_hues.resize(count)
	for i in range(had, count):
		_spawn(i)
	# No curves must not cost a frame of anything.
	set_process(count > 0)
	queue_redraw()


## Places curve `index` at random, with four points each heading its own way.
func _spawn(index: int):
	for k in range(POINTS):
		var at := index * POINTS + k
		_pos[at] = Vector2(randf(), randf())
		_vel[at] = Vector2.from_angle(randf() * TAU) * randf_range(SPEED_MIN, SPEED_MAX)
		_wobble[at] = randf() - 0.5
	_hues[index] = randf()


func randomize_look():
	for i in range(count):
		_hues[i] = randf()


func _process(delta: float):
	var step := minf(delta, MAX_STEP) * pace * speed_scale
	for at in range(count * POINTS):
		var moved := _pos[at] + _vel[at] * step * (1.0 + _wobble[at] * chaos * 1.5)
		# Reflect rather than clamp: a point that is pinned to the wall for a frame
		# is a point that sticks, and a row of them draws a straight edge.
		var v := _vel[at]
		if moved.x < 0.0 or moved.x > 1.0:
			moved.x = clampf(-moved.x if moved.x < 0.0 else 2.0 - moved.x, 0.0, 1.0)
			v.x = -v.x
		if moved.y < 0.0 or moved.y > 1.0:
			moved.y = clampf(-moved.y if moved.y < 0.0 else 2.0 - moved.y, 0.0, 1.0)
			v.y = -v.y
		_pos[at] = moved
		_vel[at] = v
	if hue_drift > 0.0:
		var slide := delta * hue_drift * 0.1
		for i in range(count):
			_hues[i] = fposmod(_hues[i] + slide, 1.0)
	queue_redraw()


func _draw():
	if count == 0 or palette == null:
		return

	var size := get_viewport_rect().size
	var curve := PackedVector2Array()
	curve.resize(SEGMENTS + 1)
	# Centred on the curve, so shortening it trims both ends and leaves the bulge,
	# which is what the eye reads as the curve, where it is.
	var from := (1.0 - length) / 2.0
	for i in range(count):
		var base := i * POINTS
		var a := _pos[base] * size
		var b := _pos[base + 1] * size
		var c := _pos[base + 2] * size
		var d := _pos[base + 3] * size
		for s in range(SEGMENTS + 1):
			curve[s] = a.bezier_interpolate(b, c, d, from + length * float(s) / SEGMENTS)

		var tint := palette.resolve(_hues[i])
		# The halo is drawn here rather than hung off a `Halo` node, which needs a
		# Line2D to echo. Same rings, read from the same constant, so the two cannot
		# drift apart. Additive blending is a sum, so drawing the rings before the core
		# changes nothing.
		if halo_amount > 0.0:
			for ring in Halo.RINGS:
				draw_polyline(curve,
					Color(tint.r, tint.g, tint.b,
						tint.a * clampf(ring[1] * halo_amount, 0.0, 1.0)),
					line_width + ring[0] * halo_amount)
		draw_polyline(curve, tint, line_width)


func use_palette(p: Palette):
	palette = p

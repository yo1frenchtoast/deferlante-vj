class_name Halo
extends Node2D

## Wide, faint copies of a stroke, drawn additively on top of it.
##
## This replaces the post-process glow. Measured on a machine rendering in software
## (llvmpipe, 1080p, a busy show), that pass cost **21 ms per frame** — two thirds of
## the whole frame, and by a wide margin the most expensive control on the desk. The
## Compatibility renderer does not draw 2D glow at all, so on the machines that need
## the speed most the setting was about to become dead weight.
##
## A couple of extra strokes do the same job for a fraction of the price. In additive
## blending the rings and the stroke sum where they overlap, so the core saturates
## towards white and the light steps down towards the edges. It is not a Gaussian
## blur and does not pretend to be — two steps, not a curve. In haze, against a beam,
## nobody can tell.
##
## It lives as a child of the stroke it echoes, so position and rotation come free
## from the parent transform. Only the shape, the width and the colour are copied.

## Each ring as `[extra width in pixels at HALO = 1, alpha at HALO = 1]`.
##
## The spread is in **pixels, not multiples of the stroke**: light bleeds a distance
## into the haze, it does not bleed proportionally to how thick the beam is. Tried
## the multiplicative version first and a 10 px laser grew a 70 px slab with a hard
## edge, which reads as a second, wider line rather than as spill.
##
## Widest ring first: it has to be drawn under the tighter one, and children draw in
## order.
const RINGS := [[30.0, 0.07], [11.0, 0.13]]

## Mirrors the HALO setting. 0 switches the rings off outright — nothing drawn, and
## nothing copied either.
var amount: float = 0.0:
	set(value):
		amount = maxf(0.0, value)
		visible = amount > 0.0
		# An echo nobody draws must not copy anything either: with forty circles on
		# the sphere and forty strokes in the fan, that is over a hundred array
		# copies a frame paid for a setting sitting at zero.
		set_process(visible)

var _source: Line2D
var _rings: Array[Line2D] = []


## Hangs a halo under `line` and hands it back, so the caller can drive `amount`.
static func attach(line: Line2D) -> Halo:
	var halo := Halo.new()
	halo._source = line
	halo.visible = false
	line.add_child(halo)
	return halo


func _ready():
	# The rings copy a shape their stroke has already recomputed this frame. Tree
	# order would give that for free — children run after their parent — but saying
	# it outright is what keeps a future reparenting from silently costing a frame
	# of lag on every stroke.
	process_priority = 1

	# Additive, like the strokes: a ring has to add light where it overlaps, not
	# paint a dim band over the beam it is meant to widen. One material for every
	# ring of every stroke; they all want the same thing.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for _ring in RINGS:
		var line := Line2D.new()
		line.material = mat
		add_child(line)
		_rings.append(line)


func _process(_delta: float):
	if _source == null:
		return
	var tint := _source.default_color
	for i in range(_rings.size()):
		var ring: Line2D = _rings[i]
		# `points` is assigned wholesale rather than rebuilt point by point: the
		# stroke has the array already, and this runs once per ring per frame.
		ring.points = _source.points
		ring.width = _source.width + RINGS[i][0] * amount
		# Multiplied by the stroke's own alpha, never replacing it: the sphere fades
		# its circles out at the horizon, and a halo that stayed lit through the fade
		# would leave a ring hanging where the circle just vanished.
		ring.default_color = Color(tint.r, tint.g, tint.b,
			tint.a * clampf(RINGS[i][1] * amount, 0.0, 1.0))

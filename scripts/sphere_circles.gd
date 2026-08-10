extends Node2D

## Circles spread over a virtual sphere, projected onto the screen.
##
## The centre of the screen is the point of the sphere nearest the eye: the circle
## sitting there is seen head-on, round and wide. The further a circle moves from it,
## the more two effects compound:
##   1. it shrinks, because it recedes in depth (perspective);
##   2. it flattens into an ellipse, because it is seen at an angle — until it is a
##      mere line by the time it reaches the sphere's edge.
## It is chiefly the flattening that makes this read as a sphere rather than as
## circles of assorted sizes.

@export var circle_count: int = 14:
	set(value):
		circle_count = maxi(0, value)
		if is_inside_tree():
			_rebuild()
@export var sphere_radius: float = 400.0
## Angular radius of a circle on the sphere, in radians.
@export var circle_size: float = 0.13
@export var spin: float = 0.6
## Eye distance, in sphere radii. Small means strong perspective, large means a
## near-orthographic projection where circles no longer shrink.
@export var eye_distance: float = 2.0
@export var segments: int = 48
@export var line_width: float = 3.0:
	set(value):
		line_width = value
		for c in _circles:
			c.width = value
## Brightness of circles that have passed behind the sphere's horizon.
## 0 gives an opaque sphere, showing only the cap facing the eye (the most legible).
## Raising it gives a glass sphere where the far side shows through as well.
@export var back_dim: float = 0.0

var speed_scale: float = 1.0
## Shared reference to the colour state: nothing is copied.
var palette: Palette
## 0 keeps the sphere rigid; 1 makes the circles shiver and drift across it.
var chaos: float = 0.0

var _time: float = 0.0
var _dirs: PackedVector3Array = []
var _hues: PackedFloat32Array = []
var _circles: Array[Line2D] = []
var _material: CanvasItemMaterial


func _ready():
	_material = CanvasItemMaterial.new()
	_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_rebuild()


func _rebuild():
	for c in _circles:
		c.queue_free()
	_circles.clear()
	_dirs.clear()
	_hues.clear()

	for i in range(circle_count):
		var line := Line2D.new()
		line.material = _material
		line.width = line_width
		add_child(line)
		_circles.append(line)
		_dirs.append(_fibonacci_point(i, circle_count))
		_hues.append(randf())


## Fibonacci distribution: evenly spaced points over the sphere, without the
## clustering at the poles a latitude/longitude grid would give.
func _fibonacci_point(index: int, total: int) -> Vector3:
	var y := 1.0 - 2.0 * (index + 0.5) / float(total)
	var ring := sqrt(maxf(0.0, 1.0 - y * y))
	var phi := index * PI * (3.0 - sqrt(5.0))
	return Vector3(cos(phi) * ring, y, sin(phi) * ring)


func randomize_look():
	for i in range(_hues.size()):
		_hues[i] = randf()
	_time = randf() * TAU


func _process(delta: float):
	if _circles.is_empty() or palette == null:
		return

	_time += delta * speed_scale * spin

	# Sphere rotation: continuous yaw on a slightly tilted axis, so the same band
	# does not keep sweeping past.
	var rot := Basis(Vector3(1, 0, 0), 0.4) * Basis(Vector3(0, 1, 0), _time)
	var center := get_viewport_rect().size / 2.0
	var tangential := sphere_radius * sin(circle_size)

	for i in range(_circles.size()):
		var dir := _dirs[i]
		if chaos > 0.0:
			# Each circle slides along its longitude at its own pace: the sphere
			# stays legible, but its surface is no longer of one piece.
			var jitter := sin(_time * 5.0 + i * 2.399) * chaos * 0.3
			dir = Basis(Vector3(0, 1, 0), jitter) * dir
		_project(_circles[i], rot * dir, center, tangential, _hues[i])


func _project(line: Line2D, v: Vector3, center: Vector2, tangential: float, hue: float):
	# Horizon: past it the surface tips behind the silhouette. With the eye at
	# distance d the tangent falls at z = 1/d, not at z = 0 as in orthographic.
	var horizon := 1.0 / eye_distance
	var facing := clampf((v.z - horizon) / maxf(0.001, 1.0 - horizon), 0.0, 1.0)
	var alpha := lerpf(back_dim, 1.0, facing)

	# A circle on the hidden face costs nothing: no points, no draw.
	line.visible = alpha > 0.004
	if not line.visible:
		return

	# Perspective: a point near the eye (v.z = 1) is magnified, one at the back
	# (v.z = -1) is shrunk. A large eye_distance all but cancels the effect.
	var persp := eye_distance / (eye_distance - v.z)
	var origin := center + Vector2(v.x, -v.y) * sphere_radius * persp

	# Semi-axis along the tangent: the circle's true width.
	var semi_major := tangential * persp
	if chaos > 0.0:
		semi_major *= 1.0 + sin(_time * 9.0 + hue * TAU) * chaos * 0.35
	# Semi-axis along the radius: squashed by the tilt of the surface. At v.z = 0
	# (the sphere's edge) it drops to 0 and the circle becomes a line.
	var semi_minor := semi_major * absf(v.z)

	# The minor axis points at the sphere's centre, the major one is perpendicular.
	var radial := origin - center
	radial = radial.normalized() if radial.length() > 0.001 else Vector2.RIGHT
	var tangent := Vector2(-radial.y, radial.x)

	line.clear_points()
	for j in range(segments + 1):
		var angle := TAU * float(j) / segments
		line.add_point(
			origin + tangent * (semi_major * cos(angle)) + radial * (semi_minor * sin(angle))
		)

	# Fade towards the edge: a circle reaching the silhouette dims out instead of
	# vanishing at once, which would make the sphere flicker.
	var tint := palette.resolve(hue)
	tint.a = alpha
	line.default_color = tint


func use_palette(p: Palette):
	palette = p

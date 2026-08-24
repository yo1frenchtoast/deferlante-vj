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
		# Only a real change rebuilds. A preset crossfade writes every setting on
		# every frame, and most of those writes land on the number already there:
		# without this every circle was freed and built again sixty times a second,
		# and since a rebuild draws fresh hues the sphere flickered through random
		# colours for the length of the fade.
		var wanted := maxi(0, value)
		if wanted == circle_count:
			return
		circle_count = wanted
		if is_inside_tree():
			_rebuild()
@export var sphere_radius: float = 400.0
## Angular radius of a circle on the sphere, in radians.
@export var circle_size: float = 0.13
## Number of sides of each shape. 0 gives circles; 3 and above give regular
## polygons inscribed in the same ellipse, so a triangle reaches as far from its
## centre as the circle it replaces, while covering less ground. 1 and 2 cannot
## close a shape and are read as circles.
@export var sides: int = 0
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
## Mirrors the HALO setting. Held here rather than read from the controller, so a
## sphere rebuilt on a count change hands it straight to the new circles.
var halo_amount: float = 0.0:
	set(value):
		halo_amount = value
		for h in _halos:
			h.amount = value

var speed_scale: float = 1.0
## Shared reference to the colour state: nothing is copied.
var palette: Palette
## 0 keeps the sphere rigid; 1 makes the circles shiver and drift across it.
var chaos: float = 0.0

var _time: float = 0.0
var _dirs: PackedVector3Array = []
var _hues: PackedFloat32Array = []
var _circles: Array[Line2D] = []
var _halos: Array[Halo] = []
var _material: CanvasItemMaterial


func _ready():
	_material = CanvasItemMaterial.new()
	_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_rebuild()


## Builds or frees the difference, never the whole sphere. A crossfade walks the
## count up one at a time, and rebuilding outright at each step cost a frame and
## drew fresh hues with it, so the sphere jumped to new colours on its way across.
func _rebuild():
	while _circles.size() > circle_count:
		# The echo is a child of its circle, so it goes with it; the list only has
		# to forget it.
		_circles.pop_back().queue_free()
		_halos.pop_back()
		_hues.remove_at(_hues.size() - 1)

	while _circles.size() < circle_count:
		var line := Line2D.new()
		line.material = _material
		line.width = line_width
		add_child(line)
		_circles.append(line)
		var halo := Halo.attach(line)
		halo.amount = halo_amount
		_halos.append(halo)
		_hues.append(randf())

	# Every direction is recomputed even so: a Fibonacci point is placed against
	# the total, so the circles that stay do shift when a new one joins them. That
	# is array arithmetic, not a node being born.
	_dirs.resize(circle_count)
	for i in range(circle_count):
		_dirs[i] = _fibonacci_point(i, circle_count)


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

	# A circle is sampled finely enough to look smooth; a polygon wants exactly its
	# own vertices, and nothing between them. The same loop serves both: `segments`
	# is a resolution in the first case, a side count in the second.
	var steps := segments if sides < 3 else sides
	# A circle looks the same whichever way it is turned, a polygon does not: with a
	# common phase every shape would point at the sphere's centre in step, which
	# reads as a pattern rather than as a surface. The hue already gives each shape
	# a number of its own, so it serves as the angle too.
	var phase := 0.0 if sides < 3 else hue * TAU

	line.clear_points()
	for j in range(steps + 1):
		var angle := phase + TAU * float(j) / steps
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

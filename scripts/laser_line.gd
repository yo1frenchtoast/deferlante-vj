extends Line2D

## A long stroke that spins on itself and bounces off the screen edges.
## Each stroke keeps its own random character (hue, spin rate, heading); the sliders
## apply global multipliers on top.
##
## Its **length is not one of those characters**. A stroke is meant to read as a beam
## crossing the frame, not as a segment lying in it, and a segment is exactly what a
## random length gives you the moment it comes up short — two bright tips sitting in
## mid-air, which is the one thing that says "line" instead of "laser".
##
## `align` blends between two entirely different behaviours rather than tweaking
## one. At 0 the stroke drifts and spins on its own, bouncing off the edges. At 1 it
## takes the shared angle and an evenly spaced place in a fan, and `scroll` walks
## that fan sideways — which is what turns a scatter of lines into scanlines. In
## between, both are simply mixed.

## How far past the frame a stroke runs, as a multiple of the screen's diagonal.
##
## Twice, and the two is arithmetic rather than taste. A stroke is centred on its own
## position, that position wanders anywhere in the frame, and the worst case is one
## sitting in a corner and pointing at the opposite one: half the stroke has to cover
## the whole diagonal for both ends to be outside. So the whole of it is two.
##
## Taken from the viewport rather than fixed, so the resolution chosen on the launcher
## is what it follows, and re-read when that changes.
const SPAN := 2.0

@export var min_speed: float = 50.0
@export var max_speed: float = 150.0

var velocity: Vector2
var _own_rotation: float = 0.0
var _own_position: Vector2 = Vector2.ZERO
var rotation_speed: float
var hue: float

# Global multipliers, driven by the controller.
var speed_scale: float = 1.0
var spin_scale: float = 1.0
## Shared reference to the colour state: nothing is copied.
var palette: Palette
## 0 means every stroke obeys the global direction; 1 gives each one its own heading.
var chaos: float = 0.0
## 0 keeps every stroke on its own heading, 1 puts them all on the shared one.
var align: float = 0.0
## The shared angle and the scrolling phase: the controller owns both so every
## stroke agrees, including one spawned halfway through a set.
var align_angle: float = 0.0
var scroll_phase: float = 0.0
## Where this stroke sits in the fan, 0..1. Reassigned whenever the count changes.
var slot: float = 0.0

# This stroke's own heading, revealed progressively by chaos.
var _own_dir: float = 1.0

var _length_scale: float = 1.0

var _halo: Halo


func _ready():
	_halo = Halo.attach(self)
	randomize_look()
	# The frame is not fixed for the life of a stroke: the launcher chooses a
	# resolution and F11 changes the shape of it again mid-set. A length worked out
	# once at spawn would leave the ends showing on whichever is the larger.
	get_viewport().size_changed.connect(_lay_out)
	set_length_scale(1.0)


func set_halo(value: float):
	_halo.amount = value


## Redraws every random characteristic of the stroke (R key).
func randomize_look():
	hue = randf()
	# Magnitude only, never the sign: the direction comes from the global SPIN
	# setting. Otherwise half the strokes would turn the other way and
	# "leftwards / rightwards" would mean nothing on screen.
	rotation_speed = randf_range(0.4, 1.0)
	_own_dir = randf_range(-1.0, 1.0)
	velocity = Vector2.from_angle(randf() * TAU) * randf_range(min_speed, max_speed)
	_own_rotation = randf() * TAU
	refresh_color()


func use_palette(p: Palette):
	palette = p
	palette.changed.connect(refresh_color)
	refresh_color()


func refresh_color():
	if palette:
		default_color = palette.resolve(hue)


## The slider, and the audio, as a multiple of the crossing length. 1 crosses; below
## that the ends come into frame, which is a thing worth being able to ask for and no
## longer a thing that happens by itself.
func set_length_scale(factor: float):
	_length_scale = factor
	_lay_out()


func _lay_out():
	var half := get_viewport_rect().size.length() * SPAN * _length_scale / 2.0
	clear_points()
	add_point(Vector2(-half, 0))
	add_point(Vector2(half, 0))


func _process(delta: float):
	var scaled_delta = delta * speed_scale
	var screen_size = get_viewport_rect().size

	# --- the stroke's own wandering, unchanged ---

	# Spin. Chaos brings back the disorder the direction setting removed: at 1,
	# every stroke recovers its own heading and rate.
	var dir = lerpf(1.0, _own_dir, chaos)
	_own_rotation += rotation_speed * spin_scale * dir * scaled_delta

	# Random swerves: the path starts to zigzag.
	if chaos > 0.0 and randf() < chaos * 0.02:
		velocity = velocity.rotated(randf_range(-1.0, 1.0) * chaos)

	_own_position += velocity * scaled_delta

	# Bounce off the edges. We push back inside, otherwise a stroke that leaves
	# the frame flips its velocity every frame and gets stuck.
	if _own_position.x < 0 or _own_position.x > screen_size.x:
		velocity.x *= -1
		_own_position.x = clampf(_own_position.x, 0, screen_size.x)
	if _own_position.y < 0 or _own_position.y > screen_size.y:
		velocity.y *= -1
		_own_position.y = clampf(_own_position.y, 0, screen_size.y)

	if align <= 0.0:
		rotation = _own_rotation
		position = _own_position
		return

	# --- the scanline fan ---

	# Perpendicular to the shared angle: the direction the fan is stacked along,
	# and therefore the one it scrolls in.
	var across := Vector2.from_angle(align_angle + PI * 0.5)
	# Far enough that a stroke leaves the frame completely before it wraps, so the
	# wrap never shows. The diagonal covers every angle.
	var span := screen_size.length()
	var offset := fposmod(slot + scroll_phase, 1.0) - 0.5
	var fan: Vector2 = screen_size * 0.5 + across * offset * span

	rotation = lerp_angle(_own_rotation, align_angle, align)
	position = _own_position.lerp(fan, align)

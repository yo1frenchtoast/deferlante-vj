extends Line2D

## A long stroke that spins on itself and bounces off the screen edges.
## Each stroke keeps its own random character (hue, length, spin rate); the sliders
## apply global multipliers on top.

@export var min_length: float = 2000.0
@export var max_length: float = 8000.0
@export var min_speed: float = 50.0
@export var max_speed: float = 150.0

var velocity: Vector2
var rotation_speed: float
var base_length: float
var hue: float

# Global multipliers, driven by the controller.
var speed_scale: float = 1.0
var spin_scale: float = 1.0
## Shared reference to the colour state: nothing is copied.
var palette: Palette
## 0 means every stroke obeys the global direction; 1 gives each one its own heading.
var chaos: float = 0.0

# This stroke's own heading, revealed progressively by chaos.
var _own_dir: float = 1.0


func _ready():
	randomize_look()
	set_length_scale(1.0)


## Redraws every random characteristic of the stroke (R key).
func randomize_look():
	hue = randf()
	# Magnitude only, never the sign: the direction comes from the global SPIN
	# setting. Otherwise half the strokes would turn the other way and
	# "leftwards / rightwards" would mean nothing on screen.
	rotation_speed = randf_range(0.4, 1.0)
	_own_dir = randf_range(-1.0, 1.0)
	base_length = randf_range(min_length, max_length)
	velocity = Vector2.from_angle(randf() * TAU) * randf_range(min_speed, max_speed)
	rotation = randf() * TAU
	refresh_color()


func use_palette(p: Palette):
	palette = p
	palette.changed.connect(refresh_color)
	refresh_color()


func refresh_color():
	if palette:
		default_color = palette.resolve(hue)


func set_length_scale(factor: float):
	var half = (base_length * factor) / 2.0
	clear_points()
	add_point(Vector2(-half, 0))
	add_point(Vector2(half, 0))


func _process(delta: float):
	var scaled_delta = delta * speed_scale

	# 1. Spin. Chaos brings back the disorder the direction setting removed: at 1,
	#    every stroke recovers its own heading and rate.
	var dir = lerpf(1.0, _own_dir, chaos)
	rotation += rotation_speed * spin_scale * dir * scaled_delta

	# Random swerves: the path starts to zigzag.
	if chaos > 0.0 and randf() < chaos * 0.02:
		velocity = velocity.rotated(randf_range(-1.0, 1.0) * chaos)

	# 2. Travel
	position += velocity * scaled_delta

	# 3. Bounce off the edges. We push back inside, otherwise a stroke that leaves
	#    the frame flips its velocity every frame and gets stuck.
	var screen_size = get_viewport_rect().size
	if position.x < 0 or position.x > screen_size.x:
		velocity.x *= -1
		position.x = clampf(position.x, 0, screen_size.x)
	if position.y < 0 or position.y > screen_size.y:
		velocity.y *= -1
		position.y = clampf(position.y, 0, screen_size.y)

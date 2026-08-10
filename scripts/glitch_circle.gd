extends Line2D

## A pulsing circle that moves like a followspot hunting for someone, with random
## glitches.
##
## A followspot does not drift: it sweeps fast to a point, stops there, hesitates
## with a slight tremor, then leaves for somewhere else. And because the head pivots
## on two axes (pan / tilt), the beam traces *arcs* on a flat wall, never straight
## lines. It is that curvature, plus the pauses, that make it read as "a light
## searching" where continuous motion only gives decorative drift.

@export var base_radius: float = 200.0
## How far the radius swells and shrinks around base_radius.
@export var fluctuation_range: float = 25.0
## Segment count for the circle (128 is visually enough; 360 was waste).
@export var segments: int = 128
@export var line_width: float = 3.0
## Chance of firing a glitch on any given frame. Zero by default, like the glow:
## effects that make a statement are switched on when wanted, they do not impose
## themselves. For scale, 0.005 is roughly one glitch every 3 s, 0.05 is continuous.
@export var glitch_chance: float = 0.0

@export_group("Followspot")
## Sweep speed. Higher makes a jumpy head, lower a composed one.
@export var seek_speed: float = 0.5
## Base duration of the pauses on target, in seconds.
@export var hold_time: float = 1.8
## Distance from head to wall, in pixels. Small gives strongly curved arcs and a
## large size difference between centre and edges; large gives an almost flat sweep.
@export var throw_distance: float = 750.0
## Maximum travel of the head, in radians.
@export var pan_range: float = 0.9
@export var tilt_range: float = 0.42
## Roughly one time in three the head makes a small correction instead of a wide
## sweep: it thinks it has found something and checks just beside it.
@export var refine_chance: float = 0.35
## The tremor at rest runs on its own clock, deliberately independent of
## `seek_speed`: a head can sweep fast and peer calmly, or the other way round.
## Only the global speed catches both, so that 0 truly freezes everything.
@export var wobble_speed: float = 6.0
@export var wobble_amount: float = 0.4

var time_passed: float = 0.0
var hue: float
## Shared reference to the colour state: nothing is copied.
var palette: Palette
var is_glitching: bool = false

## Global speed multiplier, driven by the controller.
var speed_scale: float = 1.0
## 0 is a composed followspot; 1 is a panicked head that can no longer settle.
var chaos: float = 0.0

## How much of the physical off-axis growth to apply. 0 keeps the pool the same
## size wherever it points, 1 is the full effect.
@export_range(0.0, 1.0, 0.01) var spread_amount: float = 0.35

@export_group("Manual aim")
## How fast the head travels under the stick, in radians per second at full
## deflection. This is the feel of the handle: too slow and you lose the actor,
## too fast and you cannot hold him.
@export var track_speed: float = 0.9
## Seconds the head stays where the operator left it after the stick goes still.
## Long on purpose: an actor stops moving, the operator stops pushing, and the
## beam must not wander off during the monologue.
@export var manual_hold: float = 30.0
## Seconds the auto sweep takes to reassert itself afterwards.
@export var manual_blend: float = 6.0
## Locked by the operator: the head never returns to hunting on its own.
var manual_lock: bool = false

# The state machine keeps its own `_pan`/`_tilt` throughout — it is never
# suspended. Manual aim is a second pair of angles, and what actually gets drawn
# is a blend of the two. That is what makes the hand-back progressive rather than
# a switch: the sweep fades back in over seconds while the machine is already
# mid-gesture, so there is no moment where control visibly changes hands.
var _manual_pan: float = 0.0
var _manual_tilt: float = 0.0
var _manual_weight: float = 0.0
var _manual_idle: float = 0.0

enum { SEEK_MOVE, SEEK_HOLD }
var _state: int = SEEK_MOVE
var _state_time: float = 0.0
var _move_duration: float = 1.0
var _hold_duration: float = 1.0
var _pan: float = 0.0
var _tilt: float = 0.0
var _pan_from: float = 0.0
var _tilt_from: float = 0.0
var _pan_to: float = 0.0
var _tilt_to: float = 0.0
var _wobble_time: float = 0.0


func _ready():
	randomize_look()
	_pick_target()
	generate_circle_points(base_radius, segments)


func randomize_look():
	hue = randf()
	refresh_color()


func use_palette(p: Palette):
	palette = p
	palette.changed.connect(refresh_color)
	refresh_color()


func refresh_color():
	# During a glitch the stroke is white: we leave it be, the colour is picked up
	# again on the way out.
	if palette and not is_glitching:
		default_color = _target_color()


func set_line_width(value: float):
	line_width = value
	if not is_glitching:
		width = line_width


func _process(delta: float):
	# While glitching we freeze the shape so it is not overwritten frame by frame.
	if is_glitching:
		return

	# 1. Constant motion, always smooth.
	default_behaviour(delta)

	# 2. Random glitch trigger (a very small chance each frame). Deliberately
	#    independent of chaos: chaos unsettles the head's *motion*, the glitch keeps
	#    its own setting. We combine them by hand rather than let one drag the other.
	if randf() < glitch_chance:
		apply_glitch()


func default_behaviour(delta: float):
	time_passed += delta * speed_scale
	# The tremor's clock: it ignores `seek_speed`, which is the whole point.
	_wobble_time += delta * speed_scale * wobble_speed
	_update_head(delta * speed_scale * seek_speed)

	_decay_manual(delta)
	var pan := aimed_pan()
	var tilt := aimed_tilt()

	# Projecting the beam onto the wall. The 1/cos(pan) term is what curves the
	# path: at constant tilt, a horizontal sweep traces an arc.
	var center = get_viewport_rect().size / 2
	position = center + Vector2(
		throw_distance * tan(pan),
		# Minus: tilt grows upwards, screen Y grows downwards.
		-throw_distance * tan(tilt) / cos(pan)
	)

	# The further out to the sides the head aims, the longer the beam travels and
	# the wider the pool grows — a real followspot does this. Taken literally it is
	# a lot, though: +61 % at the edge of the pan range and +76 % in the corner,
	# and since the pool is scaled evenly rather than stretched into an ellipse it
	# reads as the circle resizing rather than as an oblique beam. Hence the dose.
	var spread = lerpf(1.0, 1.0 / (cos(pan) * cos(tilt)), spread_amount)
	var radius = (base_radius + sin(time_passed * 2.0) * fluctuation_range) * spread
	generate_circle_points(radius, segments)


## What is actually drawn: the machine's own aim, pulled towards the operator's.
func aimed_pan() -> float:
	return lerpf(_pan, _manual_pan, _manual_weight)


func aimed_tilt() -> float:
	return lerpf(_tilt, _manual_tilt, _manual_weight)


## Drive the head like a followspot handle: the stick sets a *rate*, not a
## position, and the beam stays where you stopped pushing. That is the only way
## to walk a beam alongside someone crossing a stage.
##
## Deliberately independent of `speed_scale`: freezing the show must not take the
## handle out of the operator's hands.
func aim_by(dx: float, dy: float, delta: float):
	if _manual_weight <= 0.0:
		# Take over from wherever the beam currently is, never from wherever it
		# was left last time — otherwise grabbing the stick would teleport it.
		_manual_pan = aimed_pan()
		_manual_tilt = aimed_tilt()
	_manual_weight = 1.0
	_manual_idle = 0.0
	_manual_pan = clampf(_manual_pan + dx * track_speed * delta, -pan_range, pan_range)
	_manual_tilt = clampf(_manual_tilt + dy * track_speed * delta, -tilt_range, tilt_range)


## Give the head back now, without waiting out the hold. Still progressive: the
## blend runs, it does not cut.
func release_aim():
	_manual_idle = manual_hold


func _decay_manual(delta: float):
	if _manual_weight <= 0.0 or manual_lock:
		return
	_manual_idle += absf(delta)
	if _manual_idle < manual_hold:
		return
	_manual_weight = maxf(0.0, _manual_weight - absf(delta) / maxf(0.01, manual_blend))


func _update_head(delta: float):
	# Absolute value: a negative global speed plays the lasers and the sphere
	# backwards, but a followspot does not "un-search". It keeps sweeping forwards,
	# otherwise its state machine would sit stuck.
	_state_time += absf(delta)

	if _state == SEEK_MOVE:
		var t = clampf(_state_time / _move_duration, 0.0, 1.0)
		var eased = _motor_ease(t)
		_pan = lerpf(_pan_from, _pan_to, eased)
		_tilt = lerpf(_tilt_from, _tilt_to, eased)
		if t >= 1.0:
			_state = SEEK_HOLD
			_state_time = 0.0
			# The more chaos, the less the head stays put.
			_hold_duration = hold_time * randf_range(0.3, 1.6) * lerpf(1.0, 0.12, chaos)
	else:
		# Paused on target: the head is never perfectly still, it trembles
		# slightly. That micro-movement is what makes it look like it is peering
		# rather than merely paused.
		var amp = wobble_amount * lerpf(1.0, 7.0, chaos)
		_pan = _pan_to + sin(_wobble_time) * 0.012 * amp
		_tilt = _tilt_to + sin(_wobble_time * 1.7) * 0.008 * amp
		if _state_time >= _hold_duration:
			_pick_target()


func _pick_target():
	_pan_from = _pan
	_tilt_from = _tilt

	if randf() < refine_chance:
		# Small correction: it thinks it has found something and checks beside it.
		_pan_to = clampf(_pan + randf_range(-0.18, 0.18), -pan_range, pan_range)
		_tilt_to = clampf(_tilt + randf_range(-0.12, 0.12), -tilt_range, tilt_range)
	else:
		# Wide sweep towards some other point in the room.
		_pan_to = randf_range(-pan_range, pan_range)
		_tilt_to = randf_range(-tilt_range, tilt_range)

	# A wider travel takes longer, but not proportionally: the motors run at close
	# to constant speed, only the distance changes.
	var travel = Vector2(_pan_to - _pan_from, _tilt_to - _tilt_from).length()
	_move_duration = (0.22 + travel * 0.55) * lerpf(1.0, 0.3, chaos)
	_state = SEEK_MOVE
	_state_time = 0.0


## A stepper motor's profile: brisk start, long braking, and a slight damped
## overshoot at the end as the head settles onto its target.
func _motor_ease(t: float) -> float:
	var overshoot = 0.6
	var c = overshoot + 1.0
	var u = t - 1.0
	return 1.0 + c * u * u * u + overshoot * u * u


func apply_glitch():
	if is_glitching:
		return
	is_glitching = true

	# 1. Violent teleport anywhere on screen.
	var screen_size = get_viewport_rect().size
	position = Vector2(randf_range(0, screen_size.x), randf_range(0, screen_size.y))

	# 2. Shape distortion: few segments, so the circle becomes an odd polygon.
	generate_circle_points(base_radius * randf_range(0.5, 1.5), randi_range(3, 12))

	# 3. Colour flash (pure white) and a huge stroke width.
	default_color = Color.WHITE
	width = line_width * 6.0

	# Very short glitch (the shorter it is, the more violent it reads).
	await get_tree().create_timer(0.08).timeout

	# 4. Back to normal: _process takes over again on the next frame.
	default_color = _target_color()
	width = line_width
	is_glitching = false


func generate_circle_points(radius: float, points_count: int):
	clear_points()
	for i in range(points_count + 1):
		var angle = TAU * (float(i) / points_count)
		add_point(Vector2(cos(angle), sin(angle)) * radius)


func _target_color() -> Color:
	return palette.resolve(hue) if palette else Color.WHITE

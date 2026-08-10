extends Node

## Gamepad control surface, mapped for an Xbox pad.
##
## Two kinds of control, and they behave differently on purpose:
##
##   * The left stick **drives the spotlight like a followspot handle**: it sets a
##     rate, not a position. Push and the beam travels; stop pushing and it stays
##     exactly where you left it, so a beam can be walked alongside someone
##     crossing a stage.
##   * Everything else drives ordinary settings through `VJParam.set_value()`, the
##     same entry point as the sliders, OSC and the web page, so a value changed
##     from the pad shows up everywhere at once.
##
## Deliberately, the pad does **not** wake the on-screen panel. It is a performance
## surface like OSC: holding a stick for a whole track would otherwise leave the
## sliders projected on the wall.

signal aim(dx: float, dy: float, delta: float)
signal aim_released
signal glitch_requested
signal randomize_requested
signal panel_toggled

@export var enabled: bool = true
## Below this the stick counts as centred. Worn sticks rest off-zero, and a
## followspot that drifts because nobody is touching it looks broken.
@export var deadzone: float = 0.18
## Full range of a trigger, in setting-units per second.
@export var trigger_rate: float = 260.0
## Right stick, in setting-units per second.
@export var stick_rate: float = 1.2

## Held-button overrides on the global speed. Released, the previous value returns.
@export var freeze_speed: float = 0.0
@export var boost_speed: float = 2.5

## Set by the controller: called as (slug) -> VJParam.
var find_param: Callable

var _pad: int = -1
var _aiming: bool = false
var _speed_before_hold: float = 0.0
var _holding_speed: bool = false


func _ready():
	if not enabled:
		set_process(false)
		return
	_refresh_pad()
	Input.joy_connection_changed.connect(_on_connection_changed)


func _on_connection_changed(_device: int, _connected: bool):
	_refresh_pad()


func _refresh_pad():
	var pads := Input.get_connected_joypads()
	_pad = pads[0] if pads.size() > 0 else -1
	if _pad >= 0:
		print("Gamepad: %s connected" % Input.get_joy_name(_pad))


func is_connected_pad() -> bool:
	return _pad >= 0


func _process(delta: float):
	if _pad < 0:
		return
	_read_aim(delta)
	_read_triggers(delta)
	_read_right_stick(delta)
	_read_speed_holds()


# --------------------------------------------------------------------------
# Left stick: aiming the spotlight
# --------------------------------------------------------------------------

func _read_aim(delta: float):
	var stick := Vector2(
		Input.get_joy_axis(_pad, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(_pad, JOY_AXIS_LEFT_Y)
	)

	# Radial deadzone rather than per-axis: a square deadzone lets a diagonal
	# push through on one axis only, and the head twitches sideways.
	if stick.length() < deadzone:
		if _aiming:
			_aiming = false
			aim_released.emit()
		return

	# Rescale past the deadzone so the first millimetre of travel is not a jump.
	var scaled := stick.normalized() * ((stick.length() - deadzone) / (1.0 - deadzone))
	# Squared response: fine tracking near centre, fast repositioning at the edge.
	# A followspot operator needs both from the same stick.
	var shaped := scaled * scaled.length()
	_aiming = true
	# A stick reports -1 upwards; tilt grows upwards too, so the sign flips.
	aim.emit(clampf(shaped.x, -1.0, 1.0), clampf(-shaped.y, -1.0, 1.0), delta)


# --------------------------------------------------------------------------
# Triggers and right stick: rate-based settings
# --------------------------------------------------------------------------

func _read_triggers(delta: float):
	# Analogue, not on/off: a light squeeze creeps, a full pull sweeps.
	var grow := Input.get_joy_axis(_pad, JOY_AXIS_TRIGGER_RIGHT)
	var shrink := Input.get_joy_axis(_pad, JOY_AXIS_TRIGGER_LEFT)
	var amount := (grow - shrink) * trigger_rate * delta
	if absf(amount) > 0.0001:
		_shift("spot/radius", amount)


func _read_right_stick(delta: float):
	var x := Input.get_joy_axis(_pad, JOY_AXIS_RIGHT_X)
	var y := Input.get_joy_axis(_pad, JOY_AXIS_RIGHT_Y)
	if absf(x) > deadzone:
		_shift("lasers/spin", x * stick_rate * delta)
	if absf(y) > deadzone:
		# Up is more chaos, which is the direction that feels like "push".
		_shift("global/chaos", -y * stick_rate * delta)


## Nudges a setting by an amount in its own units, through the one entry point
## everything else uses.
func _shift(slug: String, amount: float):
	if not find_param.is_valid():
		return
	var p: VJParam = find_param.call(slug)
	if p:
		p.set_value(p.value + amount)


## Named `_write` rather than `_set`: Object already declares `_set`, and
## overriding it with another signature is a parse error.
func _write(slug: String, value: float):
	if not find_param.is_valid():
		return
	var p: VJParam = find_param.call(slug)
	if p:
		p.set_value(value)


func _value_of(slug: String) -> float:
	if not find_param.is_valid():
		return 0.0
	var p: VJParam = find_param.call(slug)
	return p.value if p else 0.0


# --------------------------------------------------------------------------
# Shoulders: momentary speed
# --------------------------------------------------------------------------

## Hold to freeze, hold to boost. Momentary rather than latching: in a set you
## want to lean on a button for four bars and have it let go by itself.
func _read_speed_holds():
	var freeze := Input.is_joy_button_pressed(_pad, JOY_BUTTON_LEFT_SHOULDER)
	var boost := Input.is_joy_button_pressed(_pad, JOY_BUTTON_RIGHT_SHOULDER)

	if freeze or boost:
		if not _holding_speed:
			_holding_speed = true
			_speed_before_hold = _value_of("global/speed")
		_write("global/speed", freeze_speed if freeze else boost_speed)
	elif _holding_speed:
		_holding_speed = false
		_write("global/speed", _speed_before_hold)


# --------------------------------------------------------------------------
# Buttons
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent):
	if not (event is InputEventJoypadButton and event.pressed):
		return

	match event.button_index:
		JOY_BUTTON_A:
			glitch_requested.emit()
		JOY_BUTTON_B:
			randomize_requested.emit()
		JOY_BUTTON_X:
			# Full on, like Y does for the glow. A stab button wants one
			# predictable result, not whatever the slider happened to be at.
			_write("mirror/effect", 0.0 if _value_of("mirror/effect") > 0.0 else 1.0)
		JOY_BUTTON_Y:
			# Glow is a room decision, so the pad only flips it on and off rather
			# than sweeping it: 0 or a usable amount, nothing in between.
			_write("global/glow", 0.0 if _value_of("global/glow") > 0.0 else 1.0)
		JOY_BUTTON_DPAD_UP:
			_shift("lasers/count", 1)
		JOY_BUTTON_DPAD_DOWN:
			_shift("lasers/count", -1)
		JOY_BUTTON_DPAD_RIGHT:
			_shift("mirror/segments", 1)
		JOY_BUTTON_DPAD_LEFT:
			_shift("mirror/segments", -1)
		JOY_BUTTON_START:
			panel_toggled.emit()
		JOY_BUTTON_BACK:
			# Hand the spotlight back without waiting to let go of the stick.
			aim_released.emit()

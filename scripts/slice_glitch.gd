extends CanvasLayer

## Full-screen pass that tears the picture into sliding bands.
##
## It sits above the wave and below the aberration: the tear cuts the rippled picture,
## and the fringes are put on what is left. It is below the settings panel for the same
## reason as the mirror: the sliders are not part of the picture.

@onready var rect: ColorRect = $Rect

## 0 is off. The pass is genuinely switched off there rather than left running as an
## identity: it covers the whole screen.
var amount: float = 0.0
## How many bands the picture is cut into.
var bands: float = 12.0
## How many times a second the tear changes into a new one.
var rate: float = 8.0
## Global speed multiplier, driven by the controller. At 0 the tear holds still.
var speed_scale: float = 1.0

## What is on screen: `amount`, plus whatever the sound is adding to it this frame.
var _drawn: float = 0.0
var _clock: float = 0.0


func _ready():
	_apply()


func set_amount(value: float):
	amount = value
	_drawn = clampf(value, 0.0, 1.0)
	_apply()


func set_bands(value: float):
	bands = value
	_apply()


func set_rate(value: float):
	rate = value


## What the sound writes: the strength that is drawn, which is not the setting. Added
## to, not multiplied, for the same reason as the aberration: at rest this is off, and
## a kick that could only scale a zero would never show.
func draw_amount(value: float):
	_drawn = clampf(value, 0.0, 1.0)
	_apply()


func _apply():
	rect.visible = _drawn > 0.0
	if not rect.visible:
		return
	var material: ShaderMaterial = rect.material
	material.set_shader_parameter("strength", _drawn)
	material.set_shader_parameter("bands", bands)


func _process(delta: float):
	if not rect.visible:
		return
	_clock += absf(speed_scale) * rate * delta
	# A new tear each time the clock passes a whole number. Wrapped, so that the value
	# a shader hashes never grows large enough to lose its precision.
	rect.material.set_shader_parameter("seed", fposmod(floorf(_clock), 997.0))

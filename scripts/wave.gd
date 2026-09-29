extends CanvasLayer

## Full-screen pass that makes the picture ripple.
##
## It sits above the mirror, so the fold is already in the image it reads and the
## ripple runs across the whole kaleidoscope, and below the aberration, so the fringes
## follow the waves rather than being waved themselves. It is below the settings panel
## for the same reason as the mirror: the sliders are not part of the picture.

@onready var rect: ColorRect = $Rect

## How strong, 0 to 1. At 0 the pass is genuinely switched off, not left running as an
## identity: it covers the whole screen.
var amount: float = 0.0
## Waves across the height of the screen.
var count: float = 4.0
## Signed: which way the waves travel, and how fast. 0 holds them still.
var speed: float = 0.3
## Global speed multiplier, driven by the controller.
var speed_scale: float = 1.0

## The most a point is pulled, at amount 1, as a fraction of the screen: 77 pixels on a
## 1920 wide one. The top of a slider should be too much.
const MAX_AMPLITUDE := 0.04
## A wave at speed 1 travels this many turns of phase a second.
const TURNS_PER_SECOND := 0.5

var _phase: float = 0.0


func _ready():
	_apply()


func set_amount(value: float):
	amount = value
	_apply()


func set_count(value: float):
	count = value
	_apply()


func set_speed(value: float):
	speed = value


func _apply():
	rect.visible = amount > 0.0
	if not rect.visible:
		return
	var material: ShaderMaterial = rect.material
	material.set_shader_parameter("amplitude", amount * MAX_AMPLITUDE)
	material.set_shader_parameter("count", count)


func _process(delta: float):
	if not rect.visible or speed == 0.0:
		return
	_phase += speed * speed_scale * TURNS_PER_SECOND * TAU * delta
	# Kept small: a phase that grows for an hour loses the precision a sine needs.
	_phase = fposmod(_phase, TAU * 4.0)
	rect.material.set_shader_parameter("phase", _phase)

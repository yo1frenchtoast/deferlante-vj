extends CanvasLayer

## Full-screen pass that splits the colour channels apart at the edges.
##
## It sits above the mirror, so the fold is already in the image it reads: the fringes
## follow the mirrored shapes, where a pass below the mirror would be folded into
## symmetrical fringes that no lens would make. It sits below the settings panel, for
## the same reason as the mirror — the sliders are not part of the picture.

@onready var rect: ColorRect = $Rect

## The strength, 0 to 1. At 0 the pass is genuinely switched off rather than left
## running as an identity: it covers the whole screen, and the machine in the room is
## often the weakest one the show ever runs on.
var amount: float = 0.0
## 0 moves the channels the same way everywhere, 1 spreads them from the centre.
var radial: float = 0.0
## The direction of the uniform part, in turns: 0 to 1 is once round.
var angle: float = 0.0

## The most a channel moves, at amount 1, as a fraction of the screen height: 32 pixels
## on a 1080 p screen. The top of a slider should be too much; the middle is where the
## set lives.
const MAX_SHIFT := 0.03

## What is on screen: `amount`, plus whatever the sound is adding to it this frame.
var _drawn: float = 0.0


func _ready():
	_apply()


func set_amount(value: float):
	amount = value
	_drawn = clampf(value, 0.0, 1.0)
	_apply()


func set_radial(value: float):
	radial = value
	_apply()


func set_angle(value: float):
	angle = value
	_apply()


## What the sound writes: the strength that is *drawn*, which is not the setting. The
## setting stays what the slider says, and `set_amount()` puts the drawing back.
## Unlike the other targets this one is added to, not multiplied: the ordinary state
## of this effect is off, and a kick that could only scale a zero would never show.
func draw_amount(value: float):
	_drawn = clampf(value, 0.0, 1.0)
	_apply()


func _apply():
	rect.visible = _drawn > 0.0
	if not rect.visible:
		return
	var material: ShaderMaterial = rect.material
	material.set_shader_parameter("shift", _drawn * MAX_SHIFT)
	material.set_shader_parameter("radial", radial)
	material.set_shader_parameter("angle", angle * TAU)

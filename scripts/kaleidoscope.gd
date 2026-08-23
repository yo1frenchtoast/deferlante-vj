extends CanvasLayer

## Full-screen pass that folds the image into symmetrical wedges.
##
## It sits on a layer above the visuals and below the settings panel: the strokes
## are folded, the interface is not — otherwise the sliders would end up multiplied
## across the screen as well.

@onready var rect: ColorRect = $Rect

var amount: float = 0.0
var segments: int = 6
var spin: float = 0.0
## Global speed multiplier, driven by the controller.
var speed_scale: float = 1.0

var _rotation: float = 0.0


func _ready():
	_apply()


func set_amount(value: float):
	amount = value
	_apply()


func set_segments(value: float):
	segments = int(value)
	_apply()


func set_spin(value: float):
	spin = value


func _apply():
	# The fold is off or on, so `amount` is the visibility of the pass and nothing
	# else — the shader has no blend left to feed. At 0 the pass is genuinely
	# switched off rather than left running as an identity transform: it covers the
	# whole screen, no reason to pay for nothing.
	rect.visible = amount > 0.0
	if not rect.visible:
		return
	var material: ShaderMaterial = rect.material
	material.set_shader_parameter("segments", segments)


func _process(delta: float):
	if not rect.visible or spin == 0.0:
		return
	_rotation += delta * spin * speed_scale
	rect.material.set_shader_parameter("rotation", _rotation)

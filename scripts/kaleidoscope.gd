extends CanvasLayer

## Passe plein écran qui replie l'image en parts symétriques.
##
## Elle est posée sur un calque au-dessus des visuels et en dessous du panneau de
## réglages : les traits sont repliés, l'interface non — sinon les sliders se
## retrouveraient eux aussi démultipliés à l'écran.

@onready var rect: ColorRect = $Rect

var amount: float = 0.0
var segments: int = 6
var spin: float = 0.0
## Multiplicateur global de vitesse, piloté par le contrôleur.
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
	# À 0 on éteint vraiment la passe plutôt que de la laisser tourner en
	# identité : c'est un plein écran, autant ne pas le payer pour rien.
	rect.visible = amount > 0.0
	if not rect.visible:
		return
	var material: ShaderMaterial = rect.material
	material.set_shader_parameter("amount", amount)
	material.set_shader_parameter("segments", segments)


func _process(delta: float):
	if not rect.visible or spin == 0.0:
		return
	_rotation += delta * spin * speed_scale
	rect.material.set_shader_parameter("rotation", _rotation)

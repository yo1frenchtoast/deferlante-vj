extends Line2D

## Trait long qui tourne sur lui-même et rebondit sur les bords de l'écran.
## Chaque trait garde ses caractéristiques aléatoires (teinte, longueur, sens de
## rotation) ; les sliders appliquent des multiplicateurs globaux par-dessus.

@export var min_length: float = 2000.0
@export var max_length: float = 8000.0
@export var min_speed: float = 50.0
@export var max_speed: float = 150.0

var velocity: Vector2
var rotation_speed: float
var base_length: float
var hue: float

# Multiplicateurs globaux, pilotés par le contrôleur.
var speed_scale: float = 1.0
var spin_scale: float = 1.0
## Référence partagée vers l'état de couleur : on ne recopie rien.
var palette: Palette
## 0 = tous les traits obéissent au sens global ; 1 = chacun reprend son cap.
var chaos: float = 0.0

# Cap propre à ce trait, révélé progressivement par le chaos.
var _own_dir: float = 1.0


func _ready():
	randomize_look()
	set_length_scale(1.0)


## Retire toutes les caractéristiques aléatoires du trait (touche R).
func randomize_look():
	hue = randf()
	# Amplitude seulement, jamais le signe : le sens de rotation vient du réglage
	# global SPIN, sinon la moitié des traits tournerait à contresens et le
	# « vers la gauche / vers la droite » n'aurait plus de sens à l'écran.
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

	# 1. Rotation. Le chaos ramène le désordre que le réglage de sens avait
	#    supprimé : à 1, chaque trait retrouve son cap et sa vitesse propres.
	var dir = lerpf(1.0, _own_dir, chaos)
	rotation += rotation_speed * spin_scale * dir * scaled_delta

	# Coups de barre aléatoires : la trajectoire se met à zigzaguer.
	if chaos > 0.0 and randf() < chaos * 0.02:
		velocity = velocity.rotated(randf_range(-1.0, 1.0) * chaos)

	# 2. Déplacement
	position += velocity * scaled_delta

	# 3. Rebond sur les bords. On repositionne dans l'écran, sinon un trait sorti
	#    du cadre inverse sa vélocité à chaque image et reste coincé.
	var screen_size = get_viewport_rect().size
	if position.x < 0 or position.x > screen_size.x:
		velocity.x *= -1
		position.x = clampf(position.x, 0, screen_size.x)
	if position.y < 0 or position.y > screen_size.y:
		velocity.y *= -1
		position.y = clampf(position.y, 0, screen_size.y)

extends Node2D

## Cercles répartis sur une sphère virtuelle, projetés à l'écran.
##
## Le centre de l'écran est le point de la sphère le plus proche de l'œil : le
## cercle qui s'y trouve est vu de face, rond et large. Plus un cercle s'en
## éloigne, plus deux choses se cumulent :
##   1. il rétrécit, parce qu'il part en profondeur (perspective) ;
##   2. il s'aplatit en ellipse, parce qu'on le voit de biais — jusqu'à devenir
##      un simple trait quand il atteint le bord de la sphère.
## C'est surtout l'aplatissement qui donne la lecture « sphère » plutôt que
## « cercles de tailles différentes ».

@export var circle_count: int = 40:
	set(value):
		circle_count = maxi(0, value)
		if is_inside_tree():
			_rebuild()
@export var sphere_radius: float = 400.0
## Rayon angulaire d'un cercle sur la sphère, en radians.
@export var circle_size: float = 0.13
@export var spin: float = 0.6
## Distance de l'œil, en rayons de sphère. Petit = perspective marquée,
## grand = projection quasi orthographique (les cercles ne rétrécissent plus).
@export var eye_distance: float = 2.0
@export var segments: int = 48
@export var line_width: float = 3.0:
	set(value):
		line_width = value
		for c in _circles:
			c.width = value
## Luminosité des cercles passés derrière l'horizon de la sphère.
## 0 = sphère opaque, on ne voit que la calotte tournée vers l'œil (le plus lisible).
## Monter la valeur donne une sphère de verre : on voit aussi la face arrière.
@export var back_dim: float = 0.0

var speed_scale: float = 1.0
## Référence partagée vers l'état de couleur : on ne recopie rien.
var palette: Palette
## 0 = sphère rigide ; 1 = les cercles vibrent et se décalent sur sa surface.
var chaos: float = 0.0

var _time: float = 0.0
var _dirs: PackedVector3Array = []
var _hues: PackedFloat32Array = []
var _circles: Array[Line2D] = []
var _material: CanvasItemMaterial


func _ready():
	_material = CanvasItemMaterial.new()
	_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_rebuild()


func _rebuild():
	for c in _circles:
		c.queue_free()
	_circles.clear()
	_dirs.clear()
	_hues.clear()

	for i in range(circle_count):
		var line := Line2D.new()
		line.material = _material
		line.width = line_width
		add_child(line)
		_circles.append(line)
		_dirs.append(_fibonacci_point(i, circle_count))
		_hues.append(randf())


## Répartition de Fibonacci : des points régulièrement espacés sur la sphère,
## sans les paquets aux pôles qu'on obtient avec une grille latitude/longitude.
func _fibonacci_point(index: int, total: int) -> Vector3:
	var y := 1.0 - 2.0 * (index + 0.5) / float(total)
	var ring := sqrt(maxf(0.0, 1.0 - y * y))
	var phi := index * PI * (3.0 - sqrt(5.0))
	return Vector3(cos(phi) * ring, y, sin(phi) * ring)


func randomize_look():
	for i in range(_hues.size()):
		_hues[i] = randf()
	_time = randf() * TAU


func _process(delta: float):
	if _circles.is_empty() or palette == null:
		return

	_time += delta * speed_scale * spin

	# Rotation de la sphère : lacet continu, sur un axe légèrement basculé pour
	# qu'on ne voie pas toujours la même bande passer.
	var rot := Basis(Vector3(1, 0, 0), 0.4) * Basis(Vector3(0, 1, 0), _time)
	var center := get_viewport_rect().size / 2.0
	var tangential := sphere_radius * sin(circle_size)

	for i in range(_circles.size()):
		var dir := _dirs[i]
		if chaos > 0.0:
			# Chaque cercle glisse sur sa longitude à son propre rythme : la
			# sphère reste lisible, mais sa surface n'est plus solidaire.
			var jitter := sin(_time * 5.0 + i * 2.399) * chaos * 0.3
			dir = Basis(Vector3(0, 1, 0), jitter) * dir
		_project(_circles[i], rot * dir, center, tangential, _hues[i])


func _project(line: Line2D, v: Vector3, center: Vector2, tangential: float, hue: float):
	# Horizon : au-delà, la surface bascule derrière la silhouette. Avec un œil à
	# distance d, la tangente se fait à z = 1/d, pas à z = 0 comme en orthographique.
	var horizon := 1.0 / eye_distance
	var facing := clampf((v.z - horizon) / maxf(0.001, 1.0 - horizon), 0.0, 1.0)
	var alpha := lerpf(back_dim, 1.0, facing)

	# Un cercle de la face cachée ne coûte rien : ni points, ni rendu.
	line.visible = alpha > 0.004
	if not line.visible:
		return

	# Perspective : un point proche de l'œil (v.z = 1) est grossi, un point au
	# fond (v.z = -1) est réduit. eye_distance élevé = effet quasi nul.
	var persp := eye_distance / (eye_distance - v.z)
	var origin := center + Vector2(v.x, -v.y) * sphere_radius * persp

	# Demi-axe dans le sens tangent : la largeur vraie du cercle.
	var semi_major := tangential * persp
	if chaos > 0.0:
		semi_major *= 1.0 + sin(_time * 9.0 + hue * TAU) * chaos * 0.35
	# Demi-axe dans le sens radial : écrasé par l'inclinaison de la surface.
	# À v.z = 0 (le bord de la sphère) il tombe à 0 : le cercle devient un trait.
	var semi_minor := semi_major * absf(v.z)

	# Le petit axe pointe vers le centre de la sphère, le grand lui est perpendiculaire.
	var radial := origin - center
	radial = radial.normalized() if radial.length() > 0.001 else Vector2.RIGHT
	var tangent := Vector2(-radial.y, radial.x)

	line.clear_points()
	for j in range(segments + 1):
		var angle := TAU * float(j) / segments
		line.add_point(
			origin + tangent * (semi_major * cos(angle)) + radial * (semi_minor * sin(angle))
		)

	# Fondu vers le bord : un cercle qui atteint la silhouette s'éteint au lieu de
	# disparaître d'un coup, ce qui ferait clignoter la sphère.
	var tint := palette.resolve(hue)
	tint.a = alpha
	line.default_color = tint


func use_palette(p: Palette):
	palette = p

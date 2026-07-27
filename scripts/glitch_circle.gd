extends Line2D

## Cercle pulsant qui se déplace comme une poursuite (lyre) cherchant quelqu'un,
## avec des glitchs aléatoires.
##
## Une poursuite ne dérive pas : elle balaye vite vers un point, s'y arrête, hésite
## en tremblant un peu, puis repart ailleurs. Et comme la tête pivote sur deux axes
## (pan / tilt), le faisceau décrit des *arcs* sur un mur plat, jamais des droites.
## C'est cette courbure, plus les arrêts, qui font lire « projecteur qui cherche »
## là où un mouvement continu ne donne qu'une dérive décorative.

@export var base_radius: float = 200.0
## Amplitude de la pulsation du rayon autour de base_radius.
@export var fluctuation_range: float = 50.0
## Nombre de segments du cercle (128 suffit visuellement, 360 était du gâchis).
@export var segments: int = 128
@export var line_width: float = 3.0
## Probabilité de déclencher un glitch à chaque image (0.005 ≈ un toutes les 3 s).
@export var glitch_chance: float = 0.005

@export_group("Poursuite")
## Vitesse des balayages. Monter = tête nerveuse, descendre = tête posée.
@export var seek_speed: float = 1.0
## Durée de base des arrêts sur cible, en secondes.
@export var hold_time: float = 0.9
## Distance de la tête au mur, en pixels. Petit = arcs très courbés et gros
## écarts de taille entre le centre et les bords ; grand = balayage presque plat.
@export var throw_distance: float = 750.0
## Débattements maximum de la tête, en radians.
@export var pan_range: float = 0.9
@export var tilt_range: float = 0.42
## Une fois sur trois environ, la tête fait un petit recalage au lieu d'un grand
## balayage : elle croit avoir trouvé, et vérifie juste à côté.
@export var refine_chance: float = 0.35

var time_passed: float = 0.0
var hue: float
## Référence partagée vers l'état de couleur : on ne recopie rien.
var palette: Palette
var is_glitching: bool = false

## Multiplicateur global de vitesse, piloté par le contrôleur.
var speed_scale: float = 1.0
## 0 = poursuite posée ; 1 = tête paniquée qui n'arrive plus à se fixer.
var chaos: float = 0.0

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
	# Pendant un glitch le trait est blanc : on ne l'écrase pas, la couleur
	# sera reprise à la sortie du glitch.
	if palette and not is_glitching:
		default_color = _target_color()


func set_line_width(value: float):
	line_width = value
	if not is_glitching:
		width = line_width


func _process(delta: float):
	# Pendant un glitch, on gèle la forme pour ne pas l'écraser image par image.
	if is_glitching:
		return

	# 1. Mouvement constant (toujours fluide)
	default_behaviour(delta)

	# 2. Déclenchement aléatoire du glitch (probabilité très faible par frame).
	#    Volontairement indépendant du chaos : le chaos dérègle le *mouvement* de
	#    la tête, le glitch garde son propre réglage. On les combine à la main
	#    plutôt que de laisser l'un entraîner l'autre.
	if randf() < glitch_chance:
		apply_glitch()


func default_behaviour(delta: float):
	time_passed += delta * speed_scale
	_update_head(delta * speed_scale * seek_speed)

	# Projection du faisceau sur le mur. Le terme en 1/cos(pan) est ce qui courbe
	# la trajectoire : à tilt constant, un balayage horizontal décrit un arc.
	var center = get_viewport_rect().size / 2
	position = center + Vector2(
		throw_distance * tan(_pan),
		throw_distance * tan(_tilt) / cos(_pan)
	)

	# Plus la tête vise loin sur les côtés, plus le trajet du faisceau est long
	# et plus la tache s'élargit — comme une vraie poursuite.
	var spread = 1.0 / (cos(_pan) * cos(_tilt))
	var radius = (base_radius + sin(time_passed * 2.0) * fluctuation_range) * spread
	generate_circle_points(radius, segments)


func _update_head(delta: float):
	# Valeur absolue : une vitesse globale négative fait rejouer les lasers et la
	# sphère à l'envers, mais une poursuite ne « dé-cherche » pas. Elle continue
	# de balayer vers l'avant, sinon sa machine à états resterait bloquée.
	_state_time += absf(delta)

	if _state == SEEK_MOVE:
		var t = clampf(_state_time / _move_duration, 0.0, 1.0)
		var eased = _motor_ease(t)
		_pan = lerpf(_pan_from, _pan_to, eased)
		_tilt = lerpf(_tilt_from, _tilt_to, eased)
		if t >= 1.0:
			_state = SEEK_HOLD
			_state_time = 0.0
			# Plus il y a de chaos, moins la tête tient en place.
			_hold_duration = hold_time * randf_range(0.3, 1.6) * lerpf(1.0, 0.12, chaos)
	else:
		# Arrêt sur cible : la tête n'est jamais parfaitement immobile, elle
		# tremble légèrement. C'est ce micro-mouvement qui donne l'impression
		# qu'elle scrute au lieu d'être simplement en pause.
		var wobble = _state_time * 6.0
		var amp = lerpf(1.0, 7.0, chaos)
		_pan = _pan_to + sin(wobble) * 0.012 * amp
		_tilt = _tilt_to + sin(wobble * 1.7) * 0.008 * amp
		if _state_time >= _hold_duration:
			_pick_target()


func _pick_target():
	_pan_from = _pan
	_tilt_from = _tilt

	if randf() < refine_chance:
		# Petit recalage : elle croit avoir trouvé et vérifie juste à côté.
		_pan_to = clampf(_pan + randf_range(-0.18, 0.18), -pan_range, pan_range)
		_tilt_to = clampf(_tilt + randf_range(-0.12, 0.12), -tilt_range, tilt_range)
	else:
		# Grand balayage vers un point quelconque de la salle.
		_pan_to = randf_range(-pan_range, pan_range)
		_tilt_to = randf_range(-tilt_range, tilt_range)

	# Un grand débattement prend plus de temps, mais pas proportionnellement :
	# les moteurs tournent à vitesse quasi constante, seule la course change.
	var travel = Vector2(_pan_to - _pan_from, _tilt_to - _tilt_from).length()
	_move_duration = (0.22 + travel * 0.55) * lerpf(1.0, 0.3, chaos)
	_state = SEEK_MOVE
	_state_time = 0.0


## Profil d'un moteur pas-à-pas : départ franc, freinage long, et un léger
## dépassement amorti en fin de course quand la tête se cale sur sa cible.
func _motor_ease(t: float) -> float:
	var overshoot = 0.6
	var c = overshoot + 1.0
	var u = t - 1.0
	return 1.0 + c * u * u * u + overshoot * u * u


func apply_glitch():
	if is_glitching:
		return
	is_glitching = true

	# 1. Téléportation violente sur tout l'écran
	var screen_size = get_viewport_rect().size
	position = Vector2(randf_range(0, screen_size.x), randf_range(0, screen_size.y))

	# 2. Distorsion de forme : peu de segments, le cercle devient un polygone bizarre
	generate_circle_points(base_radius * randf_range(0.5, 1.5), randi_range(3, 12))

	# 3. Flash de couleur (blanc pur) et épaisseur énorme
	default_color = Color.WHITE
	width = line_width * 6.0

	# Temps de glitch très court (plus c'est court, plus c'est violent)
	await get_tree().create_timer(0.08).timeout

	# 4. Retour à la normale : _process reprend la main à l'image suivante
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

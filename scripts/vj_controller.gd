extends Node2D

## Chef d'orchestre : déclare les réglages, instancie les lasers, route l'OSC.
##
## L'affichage est au panneau (`control_panel.gd`), le protocole au serveur OSC
## (`osc_server.gd`). Ici on ne trouve que la liste des réglages et ce qu'ils
## pilotent — ajouter une ligne à `_build_params()` crée du même coup le slider,
## la navigation clavier et l'adresse OSC.

@export var laser_scene: PackedScene = preload("res://scenes/laser.tscn")
@export var laser_count: int = 5
## Glow coupé par défaut : avec une machine à fumée, la diffusion se fait
## physiquement, et le glow logiciel casse le côté incisif du trait.
@export_range(0.0, 2.0, 0.01) var default_glow: float = 0.0

@onready var world_env: WorldEnvironment = get_parent()
@onready var circle: Line2D = $GlitchCircle
@onready var sphere: Node2D = $SphereCircles
@onready var kaleido: CanvasLayer = $Kaleidoscope
@onready var panel: CanvasLayer = $ControlPanel
@onready var osc: Node = $OscServer

var lasers: Array[Line2D] = []
var params: Array[VJParam] = []
var osc_routes: Dictionary = {}

# Réglages globaux courants, réappliqués aux lasers créés par la suite.
var v_speed: float = 1.0
var v_chaos: float = 0.0
var v_laser_width: float = 5.0
var v_length: float = 1.0
var v_spin: float = 1.0
## L'état de couleur, partagé par référence avec tous les effets.
var palette := Palette.new()
var _mode_param: VJParam
## Vrai pendant l'application des valeurs de départ : sans ce garde-fou, poser la
## valeur initiale de ROUGE ferait basculer le projet en manuel dès le démarrage.
var _initializing: bool = true

# Pilote automatique : 0 = éteint, 1 = un changement par seconde environ.
var _randomizer: float = 0.0
var _next_roll: float = 0.0


func _ready():
	_build_params()
	panel.build(params)

	circle.use_palette(palette)
	sphere.use_palette(palette)
	_spawn_lasers(laser_count)
	for p in params:
		p.apply_current()
	_initializing = false

	for p in params:
		osc_routes["/deferlante/" + p.slug] = p
	osc.message_received.connect(_on_osc_message)


# --------------------------------------------------------------------------
# Réglages
# --------------------------------------------------------------------------

## Premier argument : l'adresse OSC, stable. Deuxième : le libellé à l'écran,
## qu'on peut reformuler sans rien casser côté console.
func _build_params():
	_section("GLOBAL")
	_fn("global/vitesse", "VITESSE", -3, 3, 0.05, 1.0, _set_speed, true)
	_fn("global/chaos", "CHAOS", 0, 1, 0.02, 0.0, _set_chaos)
	_fn("global/randomizer", "RANDOMIZER", 0, 1, 0.02, 0.0, _set_randomizer).randomizable = false
	_fn("global/halo", "HALO", 0, 2, 0.05, default_glow, _set_glow)

	_section("COULEUR")
	_mode_param = _fn("couleur/mode", "MODE", 0, 1, 1, 0.0, _set_color_mode)
	_mode_param.choices = PackedStringArray(["ALÉATOIRE", "MANUEL"])
	_fn("couleur/saturation", "SATURATION", 0, 1, 0.02, 0.7, _set_saturation)
	_fn("couleur/rouge", "ROUGE", 0, 1, 0.02, 1.0, _set_channel.bind(0)).tint = Color(1, 0.45, 0.4)
	_fn("couleur/vert", "VERT", 0, 1, 0.02, 0.25, _set_channel.bind(1)).tint = Color(0.45, 1, 0.5)
	_fn("couleur/bleu", "BLEU", 0, 1, 0.02, 0.1, _set_channel.bind(2)).tint = Color(0.5, 0.65, 1)

	_section("MIROIR")
	_fn("miroir/effet", "EFFET", 0, 1, 0.02, 0.0, kaleido.set_amount)
	_fn("miroir/segments", "SEGMENTS", 2, 16, 1, 6.0, kaleido.set_segments)
	_fn("miroir/rotation", "ROTATION", -1, 1, 0.02, 0.0, kaleido.set_spin, true)

	_section("LASERS")
	_fn("lasers/nombre", "NOMBRE", 0, 40, 1, laser_count, _set_laser_count)
	_fn("lasers/epaisseur", "ÉPAISSEUR", 1, 24, 0.5, 5.0, _set_laser_width)
	_fn("lasers/longueur", "LONGUEUR", 0.1, 2, 0.05, 1.0, _set_length)
	_fn("lasers/rotation", "ROTATION", -1, 1, 0.05, 1.0, _set_spin, true)

	_section("POURSUITE")
	# Réglages qui ne font qu'écrire une propriété : déclarés, pas codés.
	_prop("poursuite/rayon", "RAYON", 20, 600, 5, 200.0, circle, "base_radius")
	_prop("poursuite/pulsation", "PULSATION", 0, 300, 5, 50.0, circle, "fluctuation_range")
	_fn("poursuite/epaisseur", "ÉPAISSEUR", 1, 24, 0.5, 3.0, func(v): circle.set_line_width(v))
	_prop("poursuite/vitesse", "VITESSE", 0, 2, 0.05, 1.0, circle, "seek_speed")
	_prop("poursuite/arrets", "ARRÊTS", 0, 3, 0.05, 0.9, circle, "hold_time")
	_prop("poursuite/tremblement", "TREMBLEMENT", 0, 3, 0.05, 1.0, circle, "wobble_amount")
	_prop("poursuite/frequence", "FRÉQUENCE", 0, 20, 0.5, 6.0, circle, "wobble_speed")
	_prop("poursuite/glitch", "GLITCH", 0, 0.05, 0.001, 0.0, circle, "glitch_chance")

	_section("SPHÈRE")
	_prop("sphere/cercles", "CERCLES", 0, 80, 1, 40.0, sphere, "circle_count")
	_prop("sphere/taille", "TAILLE", 0.03, 0.8, 0.01, 0.13, sphere, "circle_size")
	_prop("sphere/rayon", "RAYON", 100, 800, 10, 400.0, sphere, "sphere_radius")
	_prop("sphere/rotation", "ROTATION", -1, 1, 0.05, 0.6, sphere, "spin", true)
	_prop("sphere/profondeur", "PROFONDEUR", 1.2, 10, 0.1, 2.0, sphere, "eye_distance")
	_prop("sphere/epaisseur", "ÉPAISSEUR", 1, 24, 0.5, 3.0, sphere, "line_width")
	_prop("sphere/verre", "VERRE", 0, 1, 0.02, 0.0, sphere, "back_dim")

	# Hors de portée du pilote automatique : le tempo, le halo et les couleurs
	# relèvent d'une décision (la salle, le morceau), pas d'une variation.
	for slug in ["global/vitesse", "global/halo", "couleur/saturation",
			"couleur/mode", "couleur/rouge", "couleur/vert", "couleur/bleu"]:
		param(slug).randomizable = false


var _current_section: String = ""


func _section(name: String):
	_current_section = name


## Réglage qui demande de la logique. Renvoie le paramètre pour pouvoir
## l'affiner sur place (teinte du libellé, libellés énumérés).
func _fn(slug: String, label: String, mn: float, mx: float, step: float,
		value: float, apply: Callable, signed: bool = false) -> VJParam:
	var p := VJParam.new(slug, label, mn, mx, step, value, apply, signed)
	_append(p)
	return p


## Réglage qui écrit simplement une propriété sur un nœud : la moitié de la
## liste tient en une ligne au lieu d'une fonction de trois.
func _prop(slug: String, label: String, mn: float, mx: float, step: float,
		value: float, target: Object, property: String, signed: bool = false) -> VJParam:
	var p := VJParam.new(slug, label, mn, mx, step, value,
		func(v): target.set(property, v), signed)
	_append(p)
	return p


## Retrouve un réglage par son adresse.
func param(slug: String) -> VJParam:
	for p in params:
		if p.slug == slug:
			return p
	return null


func _append(p: VJParam):
	p.section = _current_section
	params.append(p)


func _set_speed(value: float):
	v_speed = value
	circle.speed_scale = value
	sphere.speed_scale = value
	kaleido.speed_scale = value
	for l in lasers:
		l.speed_scale = value


## Pilote automatique. Il ne remplace pas la main sur les sliders : il pioche un
## ou deux réglages et les repose ailleurs, à un rythme qui dépend de sa valeur.
func _set_randomizer(value: float):
	_randomizer = value
	_next_roll = _interval()


func _interval() -> float:
	return lerpf(12.0, 1.0, _randomizer)


func _process(delta: float):
	if _randomizer <= 0.0:
		return
	_next_roll -= delta
	if _next_roll > 0.0:
		return
	_next_roll = _interval()
	_roll()


func _roll():
	var candidats: Array[VJParam] = []
	for p in params:
		if p.randomizable:
			candidats.append(p)
	if candidats.is_empty():
		return

	# Un ou deux réglages à la fois : au-delà, ça ne se lit plus comme un geste
	# mais comme une panne.
	for i in range(randi_range(1, 2)):
		var p: VJParam = candidats.pick_random()
		# Moyenne de deux tirages : les valeurs se groupent vers le milieu de la
		# plage, donc on évite les extrêmes qui vident l'écran ou le saturent.
		var t := (randf() + randf()) * 0.5
		p.set_value(lerpf(p.min_value, p.max_value, t))

	# De temps en temps, un coup de neuf sur les couleurs — mais seulement si
	# elles sont en aléatoire, sinon on écraserait un choix manuel.
	if palette.mode == Palette.RANDOM and randf() < 0.25:
		_randomize_all()


func _set_chaos(value: float):
	v_chaos = value
	circle.chaos = value
	sphere.chaos = value
	for l in lasers:
		l.chaos = value


func _set_glow(value: float):
	var env: Environment = world_env.environment
	# À 0 on coupe vraiment la passe de glow plutôt que de la laisser tourner
	# à intensité nulle : ça économise ~0.3 ms par image.
	env.glow_enabled = value > 0.0
	env.glow_intensity = value


func _set_laser_count(value: float):
	var target := int(value)
	while lasers.size() > target:
		lasers.pop_back().queue_free()
	if lasers.size() < target:
		_spawn_lasers(target - lasers.size())


func _set_laser_width(value: float):
	v_laser_width = value
	for l in lasers:
		l.width = value


func _set_length(value: float):
	v_length = value
	for l in lasers:
		l.set_length_scale(value)


func _set_spin(value: float):
	v_spin = value
	for l in lasers:
		l.spin_scale = value


func _set_saturation(value: float):
	palette.set_saturation(value)


func _set_color_mode(value: float):
	palette.set_mode(int(value))


## Toucher une couleur bascule en manuel : sans ça, bouger ROUGE ne produirait
## rien de visible tant qu'on est en aléatoire, ce qui donnerait un slider mort.
## Le garde-fou d'initialisation évite que poser les valeurs de départ ne fasse
## démarrer le projet en manuel.
func _set_channel(value: float, index: int):
	palette.set_channel(index, value)
	if not _initializing and palette.mode != Palette.MANUAL and _mode_param:
		_mode_param.set_value(Palette.MANUAL)


func _spawn_lasers(count: int):
	var screen_size := get_viewport_rect().size
	for i in range(count):
		var laser: Line2D = laser_scene.instantiate()
		add_child(laser)
		laser.position = Vector2(
			randf_range(0, screen_size.x),
			randf_range(0, screen_size.y)
		)
		# Un laser créé en cours de route doit hériter des réglages courants.
		laser.speed_scale = v_speed
		laser.spin_scale = v_spin
		laser.chaos = v_chaos
		laser.width = v_laser_width
		laser.use_palette(palette)
		laser.set_length_scale(v_length)
		lasers.append(laser)


# --------------------------------------------------------------------------
# OSC (Chataigne, TouchOSC, ou n'importe quel émetteur)
# --------------------------------------------------------------------------

func _on_osc_message(address: String, args: Array):
	match address:
		"/deferlante/glitch_now":
			circle.apply_glitch()
			return
		"/deferlante/randomize":
			_randomize_all()
			return
		"/deferlante/couleur/rgb":
			# Un sélecteur de couleur envoie ses composantes d'un bloc.
			if args.size() >= 3:
				_set_rgb_from_osc(args)
			return

	if args.is_empty() or not (args[0] is float or args[0] is int):
		return
	var value := float(args[0])

	# Forme normalisée : /deferlante/norm/<nom> attend 0..1 et l'étale sur la
	# plage du réglage. Pour un fader MIDI ou une surface tactile qui ne sait
	# envoyer que du 0..1 sans connaître les bornes de chaque réglage.
	var normalized := address.begins_with("/deferlante/norm/")
	var key := address.replace("/norm/", "/") if normalized else address

	var p: VJParam = osc_routes.get(key)
	if p == null:
		return
	if normalized:
		value = lerpf(p.min_value, p.max_value, clampf(value, 0.0, 1.0))
	p.set_value(value)


## Touche R : revient à l'aléatoire et retire de nouvelles teintes. C'est la
## sortie du mode manuel, celle qu'on trouve sans réfléchir en plein set.
func _set_rgb_from_osc(args: Array):
	var names := ["couleur/rouge", "couleur/vert", "couleur/bleu"]
	for i in range(3):
		var p: VJParam = osc_routes.get("/deferlante/" + names[i])
		if p:
			p.set_value(float(args[i]))


func _randomize_all():
	if _mode_param and palette.mode != Palette.RANDOM:
		_mode_param.set_value(Palette.RANDOM)
	circle.randomize_look()
	sphere.randomize_look()
	for l in lasers:
		l.randomize_look()


# --------------------------------------------------------------------------
# Raccourcis de scène (le panneau gère les siens : flèches, H, F3)
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_SPACE:
			circle.apply_glitch()
		KEY_R:
			_randomize_all()
		KEY_F11:
			var mode := DisplayServer.window_get_mode()
			if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

extends CanvasLayer

## Panneau de réglages : une ligne par paramètre, navigation clavier, effacement
## automatique et compteur de FPS.
##
## Le panneau ne réapparaît que sur une action de l'utilisateur. Une valeur qui
## arrive par OSC met bien le slider à jour, mais sans réveiller l'affichage :
## sinon une automation Chataigne laisserait les sliders visibles — donc projetés
## sur le mur — pendant tout le set.

## Secondes d'inactivité avant que les sliders s'effacent d'eux-mêmes.
@export var hide_delay: float = 4.0
@export var show_fps: bool = false

@onready var rows: VBoxContainer = $Controls
@onready var fps_label: Label = $FpsLabel

var params: Array[VJParam] = []
var selected: int = 0
## Figé : le panneau reste à l'écran pendant les réglages.
var pinned: bool = false

var _sliders: Array[HSlider] = []
var _name_labels: Array[Label] = []
var _value_labels: Array[Label] = []

var _idle: float = 0.0
var _fade: Tween

# Moyennage du compteur de FPS : sur 0.25 s, sinon le chiffre est illisible.
const FPS_REFRESH := 0.25
var _fps_elapsed: float = 0.0
var _fps_frames: int = 0


## Couleur des en-têtes de section : chaude, pour trancher avec le blanc des
## valeurs sans attirer l'œil plus que les réglages eux-mêmes.
const SECTION_COLOR := Color(1.0, 0.72, 0.35)


func build(p_params: Array[VJParam]):
	params = p_params
	var current_section := ""
	for i in range(params.size()):
		if params[i].section != current_section:
			current_section = params[i].section
			_build_section_header(current_section, i > 0)
		_build_row(params[i], i)
	_build_help()
	select(0)
	fps_label.visible = show_fps
	wake()


func _build_section_header(name: String, spaced: bool):
	if spaced:
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 10
		rows.add_child(spacer)

	var header := Label.new()
	header.text = name
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", SECTION_COLOR)
	rows.add_child(header)


func _build_row(p: VJParam, index: int):
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.custom_minimum_size.x = 130
	if p.tint.a > 0.0:
		name_label.add_theme_color_override("font_color", p.tint)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = p.min_value
	slider.max_value = p.max_value
	slider.step = p.step
	slider.value = p.value
	slider.custom_minimum_size.x = 260
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Sans ça les sliders captent les flèches et cassent la navigation clavier.
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_slider_moved.bind(index))
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 100
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	rows.add_child(row)
	_name_labels.append(name_label)
	_sliders.append(slider)
	_value_labels.append(value_label)

	p.changed.connect(_on_param_changed.bind(index))


func _build_help():
	for text in [
		"↑↓ paramètre    ←→ régler (Maj : précis)    ESPACE glitch    R couleurs",
		"H figer l'UI    F3 fps    F11 plein écran    ÉCHAP quitter",
	]:
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 13)
		label.modulate = Color(1, 1, 1, 0.55)
		rows.add_child(label)


# --------------------------------------------------------------------------
# Synchronisation valeurs <-> affichage
# --------------------------------------------------------------------------

func _on_slider_moved(value: float, index: int):
	params[index].set_value(value)
	select(index)
	wake()


## Le paramètre a changé, d'où qu'il vienne. On remet le slider en place sans
## réémettre son signal, sinon un aller-retour OSC ferait boucler l'affectation.
func _on_param_changed(value: float, index: int):
	_sliders[index].set_value_no_signal(value)
	_value_labels[index].text = params[index].format_value()


func select(index: int):
	selected = wrapi(index, 0, params.size())
	for i in range(params.size()):
		var on := i == selected
		_name_labels[i].text = ("  ▸ " if on else "     ") + params[i].label
		_name_labels[i].modulate = Color.WHITE if on else Color(1, 1, 1, 0.5)
		_value_labels[i].modulate = Color.WHITE if on else Color(1, 1, 1, 0.5)
		_value_labels[i].text = params[i].format_value()


# --------------------------------------------------------------------------
# Effacement automatique
# --------------------------------------------------------------------------

func wake():
	_idle = 0.0
	if _fade:
		_fade.kill()
		_fade = null
	rows.visible = true
	rows.modulate.a = 1.0


func _fade_out():
	_fade = create_tween()
	_fade.tween_property(rows, "modulate:a", 0.0, 0.7)
	_fade.tween_callback(func(): rows.visible = false)


func _input(event: InputEvent):
	# Le moindre geste rappelle le panneau ; c'est le silence qui l'efface.
	if event is InputEventKey or event is InputEventMouse:
		if rows.visible and _fade == null:
			_idle = 0.0
		else:
			wake()


func _unhandled_input(event: InputEvent):
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_UP:
			select(selected - 1)
		KEY_DOWN:
			select(selected + 1)
		KEY_LEFT:
			params[selected].nudge(-1, event.shift_pressed)
		KEY_RIGHT:
			params[selected].nudge(1, event.shift_pressed)
		KEY_H:
			pinned = not pinned
			wake()
		KEY_F3:
			fps_label.visible = not fps_label.visible
			_fps_elapsed = 0.0
			_fps_frames = 0


# --------------------------------------------------------------------------
# Boucle
# --------------------------------------------------------------------------

func _process(delta: float):
	if rows.visible and not pinned and _fade == null:
		_idle += delta
		if _idle >= hide_delay:
			_fade_out()

	if fps_label.visible:
		_update_fps(delta)


func _update_fps(delta: float):
	_fps_elapsed += delta
	_fps_frames += 1
	if _fps_elapsed < FPS_REFRESH:
		return

	# Temps par image moyenné : c'est lui qui compte, pas le chiffre de FPS.
	# Un écart de 0.3 ms fait chuter le compteur de plusieurs centaines de FPS
	# quand on tourne déjà très haut, sans que ça pèse sur le budget d'image.
	var avg_ms := (_fps_elapsed / _fps_frames) * 1000.0
	var text := "%.0f FPS   %.2f ms" % [1000.0 / avg_ms, avg_ms]

	# Le taux de l'écran (ou du vidéoprojecteur) : c'est la cible réelle à tenir.
	var refresh := DisplayServer.screen_get_refresh_rate(
		DisplayServer.window_get_current_screen()
	)
	if refresh > 0.0:
		text += "   écran %.0f Hz" % refresh
	fps_label.text = text

	_fps_elapsed = 0.0
	_fps_frames = 0

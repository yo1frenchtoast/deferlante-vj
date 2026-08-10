extends CanvasLayer

## Settings panel: one row per parameter, keyboard navigation, auto-hide and an
## FPS readout.
##
## The panel only comes back on a gesture from the operator. A value arriving over
## OSC does update its slider, but without waking the display: otherwise a
## Chataigne automation would leave the sliders on screen — and therefore
## projected on the wall — for the whole set.

## Seconds of inactivity before the sliders fade out on their own.
@export var hide_delay: float = 4.0
@export var show_fps: bool = false

@onready var rows: VBoxContainer = $Controls
@onready var fps_label: Label = $FpsLabel

var params: Array[VJParam] = []
var selected: int = 0
## Pinned: the panel stays on screen while settings are being dialled in.
var pinned: bool = false

var _lang: Lang
var _sliders: Array[HSlider] = []
var _name_labels: Array[Label] = []
var _value_labels: Array[Label] = []
var _section_labels: Array[Label] = []
var _section_keys: PackedStringArray = []
var _help_labels: Array[Label] = []
## Where to reach the machine, kept apart from the shortcut lines because it is
## looked up rather than remembered — it is what gets typed into a phone.
var _status: Label
var _status_text: String = ""

## Panel brightness. The panel is projected on the wall along with the visuals, so
## turning it down lets the operator keep reading it at arm's length while the room
## barely sees it. 1 is the ordinary look.
var brightness: float = 1.0

var _idle: float = 0.0
var _fade: Tween

# The FPS readout is averaged over 0.25 s, otherwise the number is unreadable.
const FPS_REFRESH := 0.25
var _fps_elapsed: float = 0.0
var _fps_frames: int = 0

const HELP_KEYS := ["help.params", "help.actions", "help.keys", "help.pad"]

## Section header colour: warm, so it stands apart from the white values without
## pulling more attention than the settings themselves.
const SECTION_COLOR := Color(1.0, 0.72, 0.35)

# Rough heights, used only to decide where to break into a new column. They do not
# have to be exact — being a few pixels out costs nothing, and the alternative is
# building the panel, measuring it, then rebuilding it a frame later.
const ROW_HEIGHT := 27
const HEADER_HEIGHT := 30
const HELP_HEIGHT := 90

## Pixels kept clear at the top and bottom of the screen.
@export var vertical_margin: float = 48.0

var _column: VBoxContainer


func build(p_params: Array[VJParam], lang: Lang):
	params = p_params
	_lang = lang
	_lang.changed.connect(_retranslate)

	_build_columns()
	_build_help()

	select(0)
	fps_label.visible = show_fps
	wake()


## Lays the settings out in as many columns as it takes to fit the screen, breaking
## only between sections so a section is never split in two. The panel used to be a
## single column and simply grew past the bottom of the screen every time a setting
## was added; this way it cannot.
func _build_columns():
	var groups := _group_by_section()
	var budget := get_viewport().get_visible_rect().size.y - vertical_margin - HELP_HEIGHT

	var total := 0.0
	for group in groups:
		total += _height_of(group)

	# Work out how many columns are needed, then aim for equal columns rather than
	# filling the first one to the brim. Two lopsided columns read worse than two
	# balanced ones, and the eye has to travel further to find anything.
	var wanted := maxi(1, ceili(total / maxf(1.0, budget)))
	var target := total / wanted

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	# Columns run left to right from the screen edge; each one is bottom-aligned
	# inside itself, so the whole panel sits in the bottom-left corner as before.
	columns.alignment = BoxContainer.ALIGNMENT_BEGIN
	columns.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rows.add_child(columns)

	_column = _new_column(columns)
	var used := 0.0
	var remaining := wanted
	var index := 0

	for group in groups:
		var height := _height_of(group)
		# Break when this section's midpoint would land past the target: the usual
		# balancing rule, and it keeps a section whole either side of the break.
		if used > 0.0 and remaining > 1 and used + height * 0.5 > target:
			_column = _new_column(columns)
			used = 0.0
			remaining -= 1
		_build_section_header(group["key"], used > 0.0)
		for p in group["params"]:
			_build_row(p, index)
			index += 1
		used += height


func _height_of(group: Dictionary) -> float:
	return HEADER_HEIGHT + group["params"].size() * ROW_HEIGHT


func _group_by_section() -> Array:
	var groups: Array = []
	var current := ""
	for p in params:
		if p.section != current:
			current = p.section
			groups.append({"key": current, "params": []})
		groups[-1]["params"].append(p)
	return groups


func _new_column(parent: HBoxContainer) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(column)
	return column


func _build_section_header(key: String, spaced: bool):
	if spaced:
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 10
		_column.add_child(spacer)

	var header := Label.new()
	header.text = _lang.text(key)
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", SECTION_COLOR)
	_column.add_child(header)
	_section_labels.append(header)
	_section_keys.append(key)


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
	slider.custom_minimum_size.x = 200
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Without this the sliders swallow the arrow keys and break navigation.
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_slider_moved.bind(index))
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 100
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	_column.add_child(row)
	_name_labels.append(name_label)
	_sliders.append(slider)
	_value_labels.append(value_label)

	p.changed.connect(_on_param_changed.bind(index))


func _build_help():
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", SECTION_COLOR)
	rows.add_child(_status)

	for key in HELP_KEYS:
		var label := Label.new()
		label.text = _lang.text(key)
		label.add_theme_font_size_override("font_size", 13)
		label.modulate = Color(1, 1, 1, 0.55)
		rows.add_child(label)
		_help_labels.append(label)


## Set by the controller once the servers are up: the address to type into a phone,
## and whether a pad is plugged in.
func set_status(text: String):
	_status_text = text
	if _status:
		_status.text = text


## Rewrites every piece of text in place when the language changes. Cheaper and
## far less disruptive than tearing the panel down and rebuilding it.
func _retranslate():
	for i in range(_section_labels.size()):
		_section_labels[i].text = _lang.text(_section_keys[i])
	for i in range(_help_labels.size()):
		_help_labels[i].text = _lang.text(HELP_KEYS[i])
	select(selected)


# --------------------------------------------------------------------------
# Keeping values and display in step
# --------------------------------------------------------------------------

func _on_slider_moved(value: float, index: int):
	params[index].set_value(value)
	select(index)
	wake()


## The parameter changed, wherever it came from. The slider is put back in place
## without re-emitting, otherwise an OSC round trip would loop on itself.
func _on_param_changed(value: float, index: int):
	_sliders[index].set_value_no_signal(value)
	_value_labels[index].text = params[index].format_value()


func select(index: int):
	selected = wrapi(index, 0, params.size())
	for i in range(params.size()):
		var on := i == selected
		_name_labels[i].text = ("  ▸ " if on else "     ") + params[i].label()
		_name_labels[i].modulate = Color.WHITE if on else Color(1, 1, 1, 0.5)
		_value_labels[i].modulate = Color.WHITE if on else Color(1, 1, 1, 0.5)
		_value_labels[i].text = params[i].format_value()


# --------------------------------------------------------------------------
# Auto-hide
# --------------------------------------------------------------------------

func set_brightness(value: float):
	brightness = clampf(value, 0.0, 1.0)
	fps_label.modulate.a = brightness
	# Only touch the panel if it is actually up: mid-fade or hidden, the alpha
	# belongs to the fade and writing to it would flash the panel back on.
	if rows.visible and _fade == null:
		rows.modulate.a = brightness


func wake():
	_idle = 0.0
	if _fade:
		_fade.kill()
		_fade = null
	rows.visible = true
	rows.modulate.a = brightness


func _fade_out():
	_fade = create_tween()
	_fade.tween_property(rows, "modulate:a", 0.0, 0.7)
	_fade.tween_callback(func(): rows.visible = false)


func _input(event: InputEvent):
	# The slightest gesture calls the panel back; it is silence that hides it.
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
# Loop
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

	# Averaged milliseconds per frame: that is the number that matters, not the
	# FPS count. A 0.3 ms difference costs hundreds of FPS when already running
	# very high, without weighing anything on the frame budget.
	var avg_ms := (_fps_elapsed / _fps_frames) * 1000.0
	var text := "%.0f FPS   %.2f ms" % [1000.0 / avg_ms, avg_ms]

	# The screen (or projector) refresh rate: that is the real target to hold.
	var refresh := DisplayServer.screen_get_refresh_rate(
		DisplayServer.window_get_current_screen()
	)
	if refresh > 0.0:
		text += "   " + _lang.text("fps.screen") % refresh
	fps_label.text = text

	_fps_elapsed = 0.0
	_fps_frames = 0

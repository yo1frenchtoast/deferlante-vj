extends Control

## The screen before the show: what has to be decided while the process is still
## young enough to change it.
##
## Everything here could have been a command-line flag, and for a while that is what
## it was. But the machine in the room is not the machine these were typed on — it
## is a laptop on a table in the dark, ten minutes before doors, and a flag you have
## to remember is a flag nobody sets. The values live in `user://launch.cfg`, so the
## dialogue opens on last night's answers and `LANCER` is usually the only key.
##
## Two of these cannot be applied to a running process. The **renderer** is chosen by
## Godot before any script runs: picking the other one starts the process again, with
## the flag, and the new one skips this screen. The **ports** and the **audio source**
## are merely bound early, so they are read from the config rather than set from here.
##
## It steps aside without being asked in two cases: a `--headless` run, which has
## nobody to click it, and an explicit `-- --skip-launcher`, which is what the
## relaunch uses. Both go straight to the show on the saved settings.

const MAIN_SCENE := "res://scenes/main.tscn"

## Matches the panel's section headers, so the two screens look like one program.
const HEADING := Color(1.0, 0.72, 0.35)
const DIM := Color(0.62, 0.62, 0.62)

const RESOLUTIONS := [
	Vector2i.ZERO,          # the screen's own
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const MSAA_SAMPLES := [0, 2, 4, 8]
## 0 is uncapped; the rest are the refresh rates a projector or a monitor actually
## runs at. A free-typed number would be one more thing to get wrong in the dark.
const MAX_FPS := [0, 30, 60, 75, 120, 144, 240]

var lang := Lang.new()

var _renderer: OptionButton
var _msaa: OptionButton
var _msaa_note: Label
var _resolution: OptionButton
var _fullscreen: CheckBox
var _vsync: CheckBox
var _max_fps: OptionButton
var _audio: OptionButton
var _hide_panel: CheckBox
var _web_port: SpinBox
var _osc_port: SpinBox
var _language: OptionButton
var _restart_note: Label

var _audio_devices: PackedStringArray


func _ready():
	if _should_skip():
		_start_show()
		return
	lang.set_language(Launch.language)
	_build()
	_load_values()


## Nobody to answer: a headless run has no window, and the relaunch has already been
## answered once. Deliberately not a saved "do not ask again" — this screen is meant
## to be seen, and a preference that hides it is a preference nobody remembers
## setting when the ports turn out to be wrong in the room.
func _should_skip() -> bool:
	return (DisplayServer.get_name() == "headless"
		or "--skip-launcher" in OS.get_cmdline_user_args())


# --------------------------------------------------------------------------
# Layout
# --------------------------------------------------------------------------

func _build():
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	centre.add_child(column)

	var title := Label.new()
	title.text = "DÉFERLANTE"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HEADING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = lang.text("launch.subtitle")
	subtitle.add_theme_color_override("font_color", DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	column.add_child(_spacer(8))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 9)
	column.add_child(grid)

	# First, and on purpose: it is the row that decides what every other row says.
	_language = _option(grid, "launch.language", Lang.LANGUAGES)
	_language.item_selected.connect(_on_language_picked)

	_renderer = _option(grid, "launch.renderer",
		[lang.text("launch.renderer.compat"), lang.text("launch.renderer.forward")])
	_renderer.item_selected.connect(func(_i): _refresh_renderer_dependants())

	_msaa = _option(grid, "launch.msaa", _msaa_choices())
	_msaa_note = _note(grid)

	_resolution = _option(grid, "launch.resolution", _resolution_choices())
	_fullscreen = _check(grid, "launch.fullscreen")
	_vsync = _check(grid, "launch.vsync")
	_max_fps = _option(grid, "launch.maxfps", _max_fps_choices())

	_audio = _option(grid, "launch.audio", _audio_choices())
	# On Linux, Godot's PulseAudio backend enumerates nothing at all — the list comes
	# back as `["Default"]` before capture, after capture, and every moment in
	# between (measured). A picker that cannot pick has to say so rather than sit
	# there looking operational; the helper script is the real mechanism, and it
	# works by making the source Godot gets anyway the right one.
	if _audio_devices.size() <= 1:
		_note(grid).text = lang.text("launch.audio.blind")
	_hide_panel = _check(grid, "launch.panel", "launch.panel.hidden")
	_web_port = _spin(grid, "launch.webport", 1024, 65534)
	_osc_port = _spin(grid, "launch.oscport", 1024, 65535)

	column.add_child(_spacer(6))

	_restart_note = Label.new()
	_restart_note.add_theme_color_override("font_color", DIM)
	_restart_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_restart_note)

	var go := Button.new()
	go.text = lang.text("launch.go")
	go.custom_minimum_size = Vector2(0, 44)
	go.pressed.connect(_go)
	column.add_child(go)
	go.grab_focus()


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _heading(grid: GridContainer, key: String):
	var label := Label.new()
	label.text = lang.text(key)
	label.add_theme_color_override("font_color", HEADING)
	grid.add_child(label)


func _option(grid: GridContainer, key: String, choices) -> OptionButton:
	_heading(grid, key)
	var button := OptionButton.new()
	button.custom_minimum_size = Vector2(340, 0)
	for choice in choices:
		button.add_item(choice)
	grid.add_child(button)
	return button


func _check(grid: GridContainer, key: String, label_key: String = "") -> CheckBox:
	_heading(grid, key)
	var box := CheckBox.new()
	if label_key != "":
		box.text = lang.text(label_key)
	grid.add_child(box)
	return box


func _spin(grid: GridContainer, key: String, low: int, high: int) -> SpinBox:
	_heading(grid, key)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = 1
	spin.custom_minimum_size = Vector2(140, 0)
	grid.add_child(spin)
	return spin


## An empty cell in the left column, so a note can sit under the control it explains
## without breaking the two-column rhythm.
func _note(grid: GridContainer) -> Label:
	grid.add_child(Control.new())
	var label := Label.new()
	label.add_theme_color_override("font_color", DIM)
	grid.add_child(label)
	return label


func _msaa_choices() -> PackedStringArray:
	var out := PackedStringArray([lang.text("launch.msaa.off")])
	for samples in MSAA_SAMPLES.slice(1):
		out.append("MSAA %d×" % samples)
	return out


func _resolution_choices() -> PackedStringArray:
	var out := PackedStringArray([lang.text("launch.resolution.native")])
	for size in RESOLUTIONS.slice(1):
		out.append("%d × %d" % [size.x, size.y])
	return out


func _max_fps_choices() -> PackedStringArray:
	var out := PackedStringArray([lang.text("launch.maxfps.free")])
	for fps in MAX_FPS.slice(1):
		out.append("%d fps" % fps)
	return out


func _audio_choices() -> PackedStringArray:
	_audio_devices = AudioServer.get_input_device_list()
	var out := PackedStringArray([lang.text("launch.audio.auto")])
	out.append_array(_audio_devices)
	return out


# --------------------------------------------------------------------------
# Config in, config out
# --------------------------------------------------------------------------

func _load_values():
	_renderer.selected = 1 if Launch.rendering_method == "forward_plus" else 0
	_msaa.selected = maxi(0, MSAA_SAMPLES.find(Launch.msaa))
	_resolution.selected = maxi(0, RESOLUTIONS.find(Launch.resolution))
	_fullscreen.button_pressed = Launch.fullscreen
	_vsync.button_pressed = Launch.vsync
	_max_fps.selected = maxi(0, MAX_FPS.find(Launch.max_fps))
	_audio.selected = maxi(0, _audio_devices.find(Launch.audio_device) + 1)
	_hide_panel.button_pressed = Launch.hide_panel
	_web_port.value = Launch.web_port
	_osc_port.value = Launch.osc_port
	_language.selected = Launch.language
	_refresh_renderer_dependants()


func _collect():
	Launch.rendering_method = "forward_plus" if _renderer.selected == 1 else "gl_compatibility"
	Launch.msaa = MSAA_SAMPLES[_msaa.selected] if Launch.msaa_available() else 0
	Launch.resolution = RESOLUTIONS[_resolution.selected]
	Launch.fullscreen = _fullscreen.button_pressed
	Launch.vsync = _vsync.button_pressed
	Launch.max_fps = MAX_FPS[_max_fps.selected]
	Launch.audio_device = "" if _audio.selected == 0 else _audio_devices[_audio.selected - 1]
	Launch.hide_panel = _hide_panel.button_pressed
	Launch.web_port = int(_web_port.value)
	Launch.osc_port = int(_osc_port.value)
	Launch.language = _language.selected


## Two things follow from the renderer, and both are the kind of surprise that costs
## a set: an antialiasing setting that silently does nothing, and a relaunch nobody
## was expecting. Say so on screen rather than let either be discovered.
func _refresh_renderer_dependants():
	var forward := _renderer.selected == 1
	_msaa.disabled = not forward
	_msaa_note.text = "" if forward else lang.text("launch.msaa.unavailable")

	var chosen := "forward_plus" if forward else "gl_compatibility"
	_restart_note.text = ("" if chosen == RenderingServer.get_current_rendering_method()
		else lang.text("launch.restart"))


func _on_language_picked(index: int):
	lang.set_language(index)
	# Relabelling every control in place would mean holding a reference to each
	# label; there are twelve rows and the screen is not yet doing anything, so it
	# is cheaper — in code and in reading — to build it again.
	_collect()
	Launch.language = index
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build()
	_load_values()


# --------------------------------------------------------------------------
# Go
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent):
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_go()
		KEY_ESCAPE:
			get_tree().quit()


func _go():
	_collect()
	Launch.save()
	if Launch.rendering_method != RenderingServer.get_current_rendering_method():
		_relaunch()
		return
	_start_show()


func _start_show():
	Launch.apply_runtime()
	# Deferred: on the skip path this runs from `_ready`, where the tree is still
	# adding children and refuses to have the scene swapped out from under it.
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)


## Start over with the other renderer. The new process skips this screen — the
## question has just been answered — and reads everything else from the file that
## was saved a moment ago.
func _relaunch():
	var args := PackedStringArray()
	if OS.has_feature("editor"):
		# From the editor the executable is Godot itself, which needs telling which
		# project to run.
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--rendering-method", Launch.rendering_method])
	# After a bare `--`, Godot stops interpreting and hands the rest to the project.
	# Anything it does not recognise before that point is a fatal argument error.
	args.append_array(["--", "--skip-launcher"])

	if OS.create_process(OS.get_executable_path(), args) == -1:
		# Stranding the operator on a black screen ten minutes before doors is worse
		# than the wrong renderer. Carry on in the one already running, and say why.
		push_warning("Launcher: cannot restart for %s, staying on %s"
			% [Launch.rendering_method, RenderingServer.get_current_rendering_method()])
		_start_show()
		return
	get_tree().quit()

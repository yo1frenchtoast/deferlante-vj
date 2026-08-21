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
var _web_access: OptionButton
var _web_port: SpinBox
var _osc_access: OptionButton
var _osc_port: SpinBox
var _language: OptionButton
var _restart_note: Label

## Whether the sound can be routed from here, probed once and remembered: every
## answer costs a subprocess, and the row is rebuilt from scratch on each change of
## language. -1 is "not asked yet".
var _routable: int = -1
## The outputs behind the audio row when the machine lets us route the sound
## ourselves, as `{name, label}`. Empty on a machine where it does not, and the row
## then falls back to offering Godot's own input list.
var _audio_outputs: Array[Dictionary]
## Every line of that row, in the order it is shown, so a selection index maps
## straight back to what it means. The separators keep their place in here precisely
## so that mapping stays a plain lookup rather than an arithmetic apology.
var _audio_entries: Array[Dictionary]
var _audio_devices: PackedStringArray
## The live meter under the audio row, and the line beneath it. Only built where the
## sound can be routed from here, which is also the only place the meter could follow
## a change of choice.
var _audio_meter: ProgressBar
var _audio_hint: Label
var _probe: AudioProbe
## The addresses behind both access rows, in the order they list them after their
## shared first entry. The two rows offer the same list and answer it separately.
var _access_addresses: PackedStringArray
## Guards against handing over twice. See `_go()`.
var _going: bool = false
## The launch button, kept so Enter can tell whether it is aimed here. See the guard
## in `_unhandled_input()`.
var _go_button: Button


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

	# Two different questions wearing one row. Where the sound can be routed from
	# here, the useful choice is *which output to listen to* — the show taps its
	# monitor at launch. Where it cannot, all that is left is Godot's own input list,
	# which is the old row, and which on this backend cannot pick either.
	var routed := _can_route()
	_audio = _audio_row(grid)
	if routed:
		_build_meter(grid)
		_audio.item_selected.connect(_on_audio_picked)
	elif not _input_honoured():
		# A picker that cannot pick has to say so rather than sit there looking
		# operational. Whether it can is probed, not assumed — see `_input_honoured()`.
		_audio.disabled = true
		_note(grid).text = lang.text("launch.audio.blind")
	_hide_panel = _check(grid, "launch.panel", "launch.panel.hidden")
	_web_access = _option(grid, "launch.access", _access_choices())
	# A saved address the network has taken back would fail to bind and leave the
	# surface silently off. It falls back to this machine; the row says so rather
	# than reopening on a choice that is no longer the one that will be honoured.
	if Launch.web_bind != Launch.LOCAL and not _access_addresses.has(Launch.web_bind):
		_note(grid).text = lang.text("launch.access.gone")
	_web_port = _spin(grid, "launch.webport", 1024, 65534)
	_osc_access = _option(grid, "launch.oscaccess", _access_choices())
	if Launch.osc_bind != Launch.LOCAL and not _access_addresses.has(Launch.osc_bind):
		_note(grid).text = lang.text("launch.access.gone")
	_osc_port = _spin(grid, "launch.oscport", 1024, 65535)

	column.add_child(_spacer(6))

	_restart_note = Label.new()
	_restart_note.add_theme_color_override("font_color", DIM)
	_restart_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_restart_note)

	_go_button = Button.new()
	_go_button.text = lang.text("launch.go")
	_go_button.custom_minimum_size = Vector2(0, 44)
	_go_button.pressed.connect(_go)
	column.add_child(_go_button)
	_go_button.grab_focus()


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


## The meter, and the line under it.
##
## A launcher that lets you choose where the sound comes from and then says nothing
## about it has moved the guesswork rather than removed it: every wrong answer looks
## exactly like every right one until the show is running. This is the difference,
## and it is worth the twenty lines.
func _build_meter(grid: GridContainer):
	grid.add_child(Control.new())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	grid.add_child(column)

	_audio_meter = ProgressBar.new()
	_audio_meter.show_percentage = false
	_audio_meter.min_value = 0.0
	_audio_meter.max_value = 1.0
	_audio_meter.step = 0.001
	_audio_meter.custom_minimum_size = Vector2(340, 8)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.14, 0.14, 0.14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = HEADING
	_audio_meter.add_theme_stylebox_override("background", back)
	_audio_meter.add_theme_stylebox_override("fill", fill)
	column.add_child(_audio_meter)

	_audio_hint = Label.new()
	_audio_hint.add_theme_color_override("font_color", DIM)
	_audio_hint.text = lang.text("launch.listen.hint")
	column.add_child(_audio_hint)

	_probe = AudioProbe.new()
	add_child(_probe)
	_probe.level_changed.connect(_on_level)
	_probe.listen(_metered_source())


## Which line the meter should be reading: the one just chosen, or the tap when the
## choice was an output to listen to.
func _metered_source() -> String:
	return Launch.audio_device if Launch.audio_device != "" else AudioRouting.SOURCE


func _on_level(value: float):
	if _audio_meter == null:
		return
	_audio_meter.value = value
	_audio_hint.text = lang.text(
		"launch.listen.nothing" if _probe.silent else "launch.listen.hint")


## Re-point the capture the moment the choice changes, so the meter answers about the
## line just picked rather than about the one before it. This is the same routing the
## GO button applies — doing it now only means the operator sees the result of their
## own choice before committing to it.
func _on_audio_picked(_index: int):
	_collect()
	_route_audio()
	if _probe != null:
		_probe.listen(_metered_source())


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
	for samples in Launch.MSAA_SAMPLES.slice(1):
		out.append("MSAA %d×" % samples)
	return out


func _resolution_choices() -> PackedStringArray:
	var out := PackedStringArray([lang.text("launch.resolution.native")])
	for size in Launch.RESOLUTIONS.slice(1):
		out.append("%d × %d" % [size.x, size.y])
	return out


func _max_fps_choices() -> PackedStringArray:
	var out := PackedStringArray([lang.text("launch.maxfps.free")])
	for fps in Launch.MAX_FPS.slice(1):
		out.append("%d fps" % fps)
	return out


## Loopback first, then the addresses a phone could actually reach. Offered as a
## list rather than a free field: the useful answers are few and the machine already
## knows them, and a typo here is a surface that never comes up.
func _access_choices() -> PackedStringArray:
	_access_addresses = Launch.local_addresses()
	var out := PackedStringArray([lang.text("launch.access.local")])
	out.append_array(_access_addresses)
	return out


func _can_route() -> bool:
	if _routable == -1:
		_routable = 1 if AudioRouting.available() else 0
	return _routable == 1


## One row, two questions, because they are the same question asked at two depths.
##
## **Listen to an output** and the show taps its monitor: the ordinary answer, and the
## one that needs nothing arranged beforehand. **Capture an input** and it taps
## nothing at all, it simply listens where it is told — which is what you want the
## moment something else on the machine insists on standing in the middle. EasyEffects
## hands every recording to its own source; naming that source here makes it a link in
## the chain rather than a thing to be fought.
func _audio_row(grid: GridContainer) -> OptionButton:
	_audio_entries = []
	var button := _option(grid, "launch.listen" if _can_route() else "launch.audio",
		PackedStringArray() if _can_route() else _audio_choices())
	if not _can_route():
		return button

	button.add_item(lang.text("launch.listen.auto"))
	_audio_entries.append({"kind": "auto"})

	button.add_separator(lang.text("launch.listen.outputs"))
	_audio_entries.append({"kind": "separator"})
	_audio_outputs = AudioRouting.outputs()
	for output in _audio_outputs:
		button.add_item(output["label"])
		_audio_entries.append({"kind": "sink", "name": output["name"]})

	button.add_separator(lang.text("launch.listen.sources"))
	_audio_entries.append({"kind": "separator"})
	for source in AudioRouting.sources():
		button.add_item(source["label"])
		_audio_entries.append({"kind": "source", "name": source["name"]})
	return button


## The inputs Godot is willing to name, for the platforms where naming one is what
## works. Unused where the sound can be routed from here.
func _audio_choices() -> PackedStringArray:
	_audio_devices = PackedStringArray()
	for device in AudioServer.get_input_device_list():
		# Godot's own "Default" is what the first entry already means, spelled in the
		# operator's language. Listing both would offer the same thing twice.
		if device != "Default":
			_audio_devices.append(device)
	var out := PackedStringArray([lang.text("launch.audio.auto")])
	out.append_array(_audio_devices)
	return out


## Does this build actually follow a chosen input?
##
## Godot's PulseAudio backend does not. Assigning `AudioServer.input_device` reads
## back empty, and the capture keeps following the system default — measured by
## pointing it at a source known to hold nothing but silence and still reading the
## music. Other backends do honour it, so this assigns a real device and checks
## whether it stuck, rather than hardcoding a platform.
##
## Safe here and nowhere else: the launcher has no capture open, so the assignment
## and its undo cost nothing. Once `audio_reactor.gd` has started, touching this
## kills the capture outright.
func _input_honoured() -> bool:
	if _audio_devices.is_empty():
		return false
	var before := AudioServer.input_device
	AudioServer.input_device = _audio_devices[0]
	var held := AudioServer.input_device == _audio_devices[0]
	AudioServer.input_device = before
	return held


# --------------------------------------------------------------------------
# Config in, config out
# --------------------------------------------------------------------------

func _load_values():
	_renderer.selected = 1 if Launch.rendering_method == "forward_plus" else 0
	_msaa.selected = maxi(0, Launch.MSAA_SAMPLES.find(Launch.msaa))
	_resolution.selected = maxi(0, Launch.RESOLUTIONS.find(Launch.resolution))
	_fullscreen.button_pressed = Launch.fullscreen
	_vsync.button_pressed = Launch.vsync
	_max_fps.selected = maxi(0, Launch.MAX_FPS.find(Launch.max_fps))
	_audio.selected = _audio_selection()
	_hide_panel.button_pressed = Launch.hide_panel
	_web_access.selected = maxi(0, _access_addresses.find(Launch.web_bind) + 1)
	_web_port.value = Launch.web_port
	_osc_access.selected = maxi(0, _access_addresses.find(Launch.osc_bind) + 1)
	_osc_port.value = Launch.osc_port
	_language.selected = Launch.language
	_refresh_renderer_dependants()


## The saved answer's place in the row, or the first entry — "whatever is playing" —
## when it names something this machine no longer has. An output that went away with
## the interface it belonged to is the ordinary case, not an error.
func _audio_selection() -> int:
	if not _can_route():
		return maxi(0, _audio_devices.find(Launch.audio_device) + 1)
	for i in _audio_entries.size():
		var entry := _audio_entries[i]
		# A named source wins outright: it is the more specific of the two answers,
		# and it is only ever set by having been chosen here.
		if entry["kind"] == "source" and entry["name"] == Launch.audio_device:
			return i
		if (entry["kind"] == "sink" and Launch.audio_device == ""
				and entry["name"] == Launch.audio_sink):
			return i
	return 0


func _collect():
	Launch.rendering_method = "forward_plus" if _renderer.selected == 1 else "gl_compatibility"
	Launch.msaa = Launch.MSAA_SAMPLES[_msaa.selected] if Launch.msaa_available() else 0
	Launch.resolution = Launch.RESOLUTIONS[_resolution.selected]
	Launch.fullscreen = _fullscreen.button_pressed
	Launch.vsync = _vsync.button_pressed
	Launch.max_fps = Launch.MAX_FPS[_max_fps.selected]
	if _can_route():
		var entry: Dictionary = ({"kind": "auto"} if _audio.selected >= _audio_entries.size()
			else _audio_entries[_audio.selected])
		match entry["kind"]:
			"sink":
				Launch.audio_sink = entry["name"]
				Launch.audio_device = ""
			"source":
				Launch.audio_device = entry["name"]
			_:
				Launch.audio_sink = ""
				Launch.audio_device = ""
	else:
		# A disabled picker means this build ignores the choice; saving one would
		# leave a setting in the file that quietly does nothing on the next launch.
		Launch.audio_device = ("" if _audio.disabled or _audio.selected == 0
			else _audio_devices[_audio.selected - 1])
	Launch.hide_panel = _hide_panel.button_pressed
	Launch.web_bind = (Launch.LOCAL if _web_access.selected == 0
		else _access_addresses[_web_access.selected - 1])
	Launch.web_port = int(_web_port.value)
	Launch.osc_bind = (Launch.LOCAL if _osc_access.selected == 0
		else _access_addresses[_osc_access.selected - 1])
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
			# A remote control has no mouse: OK arrives as Enter, and the row it
			# lands on is far more often a droplist than the launch button. Controls
			# act on the key *release* (see `_go()`), so the press falls through to
			# here first — which made one press of OK unfold a list and start the
			# show in the same breath, with no way left to change a setting from the
			# sofa. Enter is a launch only when nothing else is waiting to answer it.
			var focused := get_viewport().gui_get_focus_owner()
			if focused != null and focused != _go_button:
				return
			_go()
		KEY_ESCAPE:
			get_tree().quit()


func _go():
	# Enter arrives here twice: the focused button emits `pressed` on the key
	# *release*, so the press itself goes unhandled and reaches `_unhandled_input`
	# first. `get_tree().quit()` only takes effect at the end of the frame, which
	# left the second call time to start a second process — measured on an exported
	# build: two shows racing for the same ports, one losing and warning about it.
	# Handing over is a one-way door, so it is latched like one.
	if _going:
		return
	_going = true
	_collect()
	Launch.save()
	if Launch.rendering_method != RenderingServer.get_current_rendering_method():
		_relaunch()
		return
	_start_show()


func _start_show():
	_route_audio()
	Launch.apply_runtime()
	# Deferred: on the skip path this runs from `_ready`, where the tree is still
	# adding children and refuses to have the scene swapped out from under it.
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)


## Put the tap on the chosen output, before anything opens a capture.
##
## Done on every launch, including the ones that walk straight past this screen. The
## tap survives a reboot; the machine's output does not necessarily stay the same,
## and a tap left on last night's interface reads as perfect silence — the failure
## with no symptom that `audio_reactor.gd` counts the seconds of. Redoing it costs
## nothing when it is already right, and is the whole fix when it is not.
##
## Never fatal. A show with no reactivity is a disappointment; a show that refuses to
## start ten minutes before doors is an incident.
func _route_audio():
	if not _can_route():
		return
	# A named source is an instruction not to route anything: the operator has said
	# where to listen, and the chain that gets the sound there is theirs to arrange.
	if Launch.audio_device != "":
		if not AudioRouting.capture_from(Launch.audio_device):
			push_warning("Launcher: cannot capture from %s — the show will start "
				% Launch.audio_device + "on whatever the machine offers instead")
		return
	if not AudioRouting.listen(Launch.audio_sink):
		push_warning("Launcher: cannot listen to %s — the show will start without it"
			% (Launch.audio_sink if Launch.audio_sink != "" else "the current output"))


## Start over with the other renderer. The new process skips this screen — the
## question has just been answered — and reads everything else from the file that
## was saved a moment ago.
func _relaunch():
	if not Launch.relaunch():
		# Stranding the operator on a black screen ten minutes before doors is worse
		# than the wrong renderer. Carry on in the one already running, and say why.
		push_warning("Launcher: cannot restart for %s, staying on %s"
			% [Launch.rendering_method, RenderingServer.get_current_rendering_method()])
		_start_show()
		return
	get_tree().quit()

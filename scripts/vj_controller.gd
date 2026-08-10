extends Node2D

## Conductor: declares the settings, spawns the lasers, routes OSC.
##
## Display belongs to the panel (`control_panel.gd`), the protocol to the OSC
## server (`osc_server.gd`). All that lives here is the list of settings and what
## they drive — adding a line to `_build_params()` creates the slider, the keyboard
## navigation and the OSC address in one go.

@export var laser_scene: PackedScene = preload("res://scenes/laser.tscn")
@export var laser_count: int = 3
## Where the D key ducks the panel to: readable up close, all but gone on a wall.
@export_range(0.05, 1.0, 0.05) var discreet_brightness: float = 0.15
## Glow off by default: with a haze machine the beam is diffused physically, and
## the software glow only softens the edges.
@export_range(0.0, 2.0, 0.01) var default_glow: float = 0.0

@onready var world_env: WorldEnvironment = get_parent()
@onready var circle: Line2D = $GlitchCircle
@onready var sphere: Node2D = $SphereCircles
@onready var kaleido: CanvasLayer = $Kaleidoscope
@onready var panel: CanvasLayer = $ControlPanel
@onready var osc: Node = $OscServer
@onready var web: Node = $WebServer
@onready var pad: Node = $Gamepad
@onready var presets: Node = $Presets
@onready var audio: Node = $Audio

var lang := Lang.new()
## Shared colour state, held by reference by every effect.
var palette := Palette.new()

var lasers: Array[Line2D] = []
var params: Array[VJParam] = []
var osc_routes: Dictionary = {}

# Current global settings, re-applied to lasers spawned later on.
var v_speed: float = 1.0
var v_chaos: float = 0.0
var v_laser_width: float = 5.0
var v_spot_width: float = 3.0
var v_sphere_width: float = 3.0
var _audio_was_active: bool = false
var _status_tick: float = 0.0
var v_length: float = 1.0
var v_spin: float = 1.0
var v_align: float = 0.0
## The fan's shared angle and its scrolling phase. Kept here rather than in each
## stroke so they agree even when a stroke is spawned mid-set.
var _align_angle: float = 0.0
var _scroll: float = 0.0
var _scroll_phase: float = 0.0

# Audio reactivity. The master is zero by default, so nothing moves until asked.
var _react: float = 0.0
var _react_lasers: float = 1.0
var _react_spot: float = 1.0
var _react_sphere: float = 1.0

var _mode_param: VJParam
## True while start-up values are being applied: without this guard, setting the
## initial RED would flip the project into manual colour mode on launch.
var _initializing: bool = true
var _autodim: bool = true

# Auto-pilot: 0 is off, 1 is roughly one change per second.
var _randomizer: float = 0.0
var _next_roll: float = 0.0

var _current_section: String = ""


func _ready():
	_build_params()
	for p in params:
		p.use_language(lang)
	panel.build(params, lang)

	circle.use_palette(palette)
	sphere.use_palette(palette)
	_spawn_lasers(laser_count)
	for p in params:
		p.apply_current()
	_initializing = false

	for p in params:
		osc_routes["/deferlante/" + p.slug] = p
	osc.message_received.connect(_on_osc_message)

	web.api_handler = _handle_api
	web.client_connected.connect(_send_schema)
	web.set_requested.connect(_on_web_set)
	web.action_requested.connect(_on_web_action)
	# A phone must see what the keyboard, OSC or the auto-pilot just did.
	for p in params:
		p.changed.connect(func(v): web.broadcast({"type": "value", "slug": p.slug, "value": v}))
	# Switching language relabels the page too, so it is rebuilt from scratch.
	lang.changed.connect(_send_schema)

	_refresh_status()
	lang.changed.connect(_refresh_status)

	# A deliberate click hands the panel back, exactly like a keypress does.
	panel.mouse_reclaimed.connect(func(): panel.set_external_control(false, discreet_brightness))

	presets.all_params = func(): return params
	presets.slots_changed.connect(_send_schema)

	pad.connection_changed.connect(_refresh_status)
	# Wrapping the lookup catches every pad interaction in one place.
	pad.find_param = func(slug): _external_touch(); return param(slug)
	pad.aim.connect(circle.aim_by)
	pad.aim.connect(func(_a, _b, _c): _external_touch())
	pad.aim_released.connect(circle.release_aim)
	pad.glitch_requested.connect(circle.apply_glitch)
	pad.randomize_requested.connect(_randomize_all)
	pad.panel_toggled.connect(func():
		panel.pinned = not panel.pinned
		panel.wake())


# --------------------------------------------------------------------------
# Settings
# --------------------------------------------------------------------------

## First argument is the OSC address, which never changes. What appears on screen
## comes from `Lang`, keyed by that same address.
func _build_params():
	_section("section.global")
	_fn("global/speed", -3, 3, 0.05, 1.0, _set_speed, true)
	_fn("global/chaos", 0, 1, 0.02, 0.0, _set_chaos)
	_fn("global/randomizer", 0, 1, 0.02, 0.0, _set_randomizer).randomizable = false
	_fn("global/glow", 0, 2, 0.05, default_glow, _set_glow)
	_prop("global/recall", 0, 10, 0.1, 2.0, presets, "recall_time")
	_fn("global/panel", 0.05, 1, 0.05, 1.0, panel.set_brightness)
	var autodim := _fn("global/autodim", 0, 1, 1, 1.0, _set_autodim)
	autodim.choices = PackedStringArray(["mode.off", "mode.on"])
	autodim.randomizable = false
	var language := _fn("global/language", 0, 1, 1, 0.0, _set_language)
	language.choices = PackedStringArray(Lang.LANGUAGES)
	# Language names stay in their own tongue, so they are not Lang keys.
	language.translate_choices = false
	language.randomizable = false

	_section("section.color")
	_mode_param = _fn("color/mode", 0, 1, 1, 0.0, _set_color_mode)
	_mode_param.choices = PackedStringArray(["mode.random", "mode.manual"])
	_fn("color/saturation", 0, 1, 0.02, 0.7, _set_saturation)
	_fn("color/red", 0, 1, 0.02, 1.0, _set_channel.bind(0)).tint = Color(1, 0.45, 0.4)
	_fn("color/green", 0, 1, 0.02, 0.25, _set_channel.bind(1)).tint = Color(0.45, 1, 0.5)
	_fn("color/blue", 0, 1, 0.02, 0.1, _set_channel.bind(2)).tint = Color(0.5, 0.65, 1)

	_section("section.mirror")
	_fn("mirror/effect", 0, 1, 0.02, 0.0, kaleido.set_amount)
	_fn("mirror/segments", 2, 16, 1, 6.0, kaleido.set_segments)
	_fn("mirror/rotation", -1, 1, 0.02, 0.0, kaleido.set_spin, true)

	_section("section.lasers")
	_fn("lasers/count", 0, 40, 1, laser_count, _set_laser_count)
	_fn("lasers/width", 1, 24, 0.5, 5.0, _set_laser_width)
	_fn("lasers/length", 0.1, 2, 0.05, 1.0, _set_length)
	_fn("lasers/spin", -1, 1, 0.05, 1.0, _set_spin, true)
	_fn("lasers/parallel", 0, 1, 0.02, 0.0, _set_align)
	_fn("lasers/scroll", -1, 1, 0.02, 0.0, func(v): _scroll = v, true)

	_section("section.spot")
	# Settings that only write a property are declared, not coded.
	_prop("spot/radius", 20, 600, 5, 200.0, circle, "base_radius")
	_prop("spot/pulse", 0, 300, 5, 25.0, circle, "fluctuation_range")
	_fn("spot/width", 1, 24, 0.5, 3.0, func(v): v_spot_width = v; circle.set_line_width(v))
	_prop("spot/speed", 0, 2, 0.05, 0.5, circle, "seek_speed")
	_prop("spot/hold", 0, 3, 0.05, 1.8, circle, "hold_time")
	_prop("spot/shake", 0, 3, 0.05, 0.4, circle, "wobble_amount")
	_prop("spot/frequency", 0, 20, 0.5, 6.0, circle, "wobble_speed")
	_prop("spot/spread", 0, 1, 0.02, 0.35, circle, "spread_amount")
	_prop("spot/glitch", 0, 0.05, 0.001, 0.0, circle, "glitch_chance")
	var manual := _fn("spot/manual", 0, 1, 1, 0.0, _set_manual_lock)
	manual.choices = PackedStringArray(["mode.auto", "mode.manual_lock"])
	manual.randomizable = false
	_prop("spot/track", 0.2, 3, 0.05, 0.9, circle, "track_speed")
	_prop("spot/handback", 2, 120, 1, 30.0, circle, "manual_hold")

	_section("section.audio")
	_fn("audio/reactivity", 0, 1, 0.02, 0.0, _set_reactivity)
	_prop("audio/punch", 0, 1, 0.02, 0.35, audio, "punch")
	_fn("audio/lasers", 0, 3, 0.05, 1.0, func(v): _react_lasers = v)
	_fn("audio/spot", 0, 3, 0.05, 1.0, func(v): _react_spot = v)
	_fn("audio/sphere", 0, 3, 0.05, 1.0, func(v): _react_sphere = v)

	_section("section.sphere")
	_prop("sphere/count", 0, 80, 1, 14.0, sphere, "circle_count")
	_prop("sphere/size", 0.03, 0.8, 0.01, 0.13, sphere, "circle_size")
	_prop("sphere/radius", 100, 800, 10, 400.0, sphere, "sphere_radius")
	_prop("sphere/spin", -1, 1, 0.05, 0.6, sphere, "spin", true)
	_prop("sphere/depth", 1.2, 10, 0.1, 2.0, sphere, "eye_distance")
	_fn("sphere/width", 1, 24, 0.5, 3.0, func(v): v_sphere_width = v; sphere.line_width = v)
	_prop("sphere/glass", 0, 1, 0.02, 0.0, sphere, "back_dim")

	# Out of the auto-pilot's reach: tempo, glow and colour are decisions — the
	# room, the track — rather than variations to be subjected to.
	for slug in ["global/speed", "global/glow", "global/recall", "global/panel",
			"global/autodim", "audio/reactivity", "color/saturation",
			"color/mode", "color/red", "color/green", "color/blue"]:
		param(slug).randomizable = false


func _section(key: String):
	_current_section = key


## A setting that needs logic. Returns the parameter so it can be refined on the
## spot (label tint, enumerated choices).
func _fn(slug: String, mn: float, mx: float, step: float, value: float,
		apply: Callable, signed: bool = false) -> VJParam:
	var p := VJParam.new(slug, mn, mx, step, value, apply, signed)
	_append(p)
	return p


## A setting that only writes a property on a node: half the list fits on one
## line instead of a three-line function.
func _prop(slug: String, mn: float, mx: float, step: float, value: float,
		target: Object, property: String, signed: bool = false) -> VJParam:
	var p := VJParam.new(slug, mn, mx, step, value,
		func(v): target.set(property, v), signed)
	_append(p)
	return p


## Finds a setting by its address.
func param(slug: String) -> VJParam:
	for p in params:
		if p.slug == slug:
			return p
	return null


func _append(p: VJParam):
	p.section = _current_section
	params.append(p)


## The cursor the operator can set: locked to the stick, or free to go hunting
## again after the hand-back delay.
## The line under the panel: where to reach this machine, and what is plugged in.
## It is looked up rather than remembered, so it belongs on screen and not only in
## the console, where it scrolls away before anyone needs it.
func _refresh_status():
	var bits: Array = []
	var url: String = web.address()
	if url != "":
		bits.append("%s  %s" % [lang.text("status.web"), url])
	if osc.is_listening():
		bits.append("OSC %d" % osc.port)
	var meter: String = _audio_meter()
	if meter != "":
		bits.append(meter)
	if pad.is_connected_pad():
		bits.append("%s  %s" % [lang.text("status.pad"), pad.pad_name()])
	else:
		bits.append(lang.text("status.nopad"))
	panel.set_status("   ·   ".join(bits))


func _set_autodim(value: float):
	_autodim = value >= 0.5
	if not _autodim:
		panel.set_external_control(false, discreet_brightness)


## Something other than this keyboard just moved a setting: get the panel out of
## the way, and out of the mouse's reach.
func _external_touch():
	if _autodim and not _initializing:
		panel.set_external_control(true, discreet_brightness)


func _set_manual_lock(value: float):
	circle.manual_lock = value >= 0.5


func _set_language(value: float):
	lang.set_language(int(value))


func _set_speed(value: float):
	v_speed = value
	circle.speed_scale = value
	sphere.speed_scale = value
	kaleido.speed_scale = value
	for l in lasers:
		l.speed_scale = value


func _set_chaos(value: float):
	v_chaos = value
	circle.chaos = value
	sphere.chaos = value
	for l in lasers:
		l.chaos = value


func _set_glow(value: float):
	var env: Environment = world_env.environment
	# At 0 the glow pass is genuinely switched off rather than left running at
	# zero intensity: that saves about 0.3 ms per frame.
	env.glow_enabled = value > 0.0
	env.glow_intensity = value


func _set_laser_count(value: float):
	var target := int(value)
	while lasers.size() > target:
		lasers.pop_back().queue_free()
	if lasers.size() < target:
		_spawn_lasers(target - lasers.size())
	_reslot()


## Spreads the strokes evenly across the fan. Without this the scanlines would
## inherit the random spacing they had as a scatter, which is most of what makes
## them read as scanlines rather than as parallel lines that happen to coincide.
func _reslot():
	for i in range(lasers.size()):
		lasers[i].slot = float(i) / maxf(1.0, float(lasers.size()))


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


func _set_align(value: float):
	v_align = value
	for l in lasers:
		l.align = value


func _set_saturation(value: float):
	palette.set_saturation(value)


func _set_color_mode(value: float):
	palette.set_mode(int(value))


## Touching a colour switches to manual: without that, moving RED while in random
## mode would do nothing visible and the slider would look broken.
##
## It has to stay quiet for anything that sets several values at once, though. On
## launch and on a preset recall the colour channels land alongside the mode, and
## they would drag a preset saved in random mode straight back into manual.
func _set_channel(value: float, index: int):
	palette.set_channel(index, value)
	if _initializing or presets.applying:
		return
	if palette.mode != Palette.MANUAL and _mode_param:
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
		# A laser spawned mid-set must inherit the current settings.
		laser.speed_scale = v_speed
		laser.spin_scale = v_spin
		laser.chaos = v_chaos
		laser.width = v_laser_width
		laser.use_palette(palette)
		laser.set_length_scale(v_length)
		laser.align = v_align
		lasers.append(laser)


# --------------------------------------------------------------------------
# Audio reactivity
# --------------------------------------------------------------------------

## The sound *adds* to the widths rather than setting them: the sliders keep
## meaning what they say, and turning REACTIVITY back to 0 restores exactly the
## look that was there. Nothing here writes to a VJParam, so nothing the sound does
## gets saved into a preset or fights the operator for a slider.
##
## Each effect follows a different band on purpose. Three effects all breathing on
## the same envelope reads as one thing pumping; on bass, mid and treble they pick
## out different parts of the track and the picture comes apart into layers.
func _set_reactivity(value: float):
	_react = value


## A live bar in the status line. Without it, "the visuals are not moving" could be
## silence, wrong routing, a stale process or a slider at zero, and nothing on
## screen told them apart.
func _audio_meter() -> String:
	var label: String = lang.text("status.audio")
	if not audio.capturing:
		return "%s %s" % [label, lang.text("status.deaf")]
	var glyphs := ["▁", "▂", "▃", "▄", "▅", "█"]
	var bars := ""
	for value in [audio.bass, audio.mid, audio.treble]:
		bars += glyphs[clampi(int(round(value * 5.0)), 0, 5)]
	# The amount is shown next to the bars: bars moving while this reads 0 % is
	# the difference between "it cannot hear you" and "you have not turned it up".
	return "%s %s %.0f%%" % [label, bars, _react * 100.0]


func _apply_audio():
	if _react <= 0.0 or not audio.capturing:
		if _audio_was_active:
			_audio_was_active = false
			_restore_widths()
		return
	_audio_was_active = true

	var lasers_w: float = v_laser_width * (1.0 + _react * _react_lasers * audio.bass)
	for l in lasers:
		l.width = lasers_w
	circle.set_line_width(v_spot_width * (1.0 + _react * _react_spot * audio.mid))
	sphere.line_width = v_sphere_width * (1.0 + _react * _react_sphere * audio.treble)


func _restore_widths():
	for l in lasers:
		l.width = v_laser_width
	circle.set_line_width(v_spot_width)
	sphere.line_width = v_sphere_width


# --------------------------------------------------------------------------
# Auto-pilot
# --------------------------------------------------------------------------

## It does not replace a hand on the sliders: it picks one or two settings and
## puts them down somewhere else, at a pace set by its own value.
func _set_randomizer(value: float):
	_randomizer = value
	_next_roll = _interval()


func _interval() -> float:
	return lerpf(12.0, 1.0, _randomizer)


func _process(delta: float):
	_apply_audio()

	# The meter has to be refreshed on a clock: the status line is otherwise only
	# rebuilt on events, and levels are not events.
	_status_tick += delta
	if _status_tick > 0.2:
		_status_tick = 0.0
		if audio.capturing:
			_refresh_status()

	# The fan turns and scrolls once per frame, and every stroke reads the same
	# two numbers — that is what keeps them parallel and evenly spaced.
	if v_align > 0.0:
		var step := delta * v_speed
		_align_angle += v_spin * step * 0.4
		_scroll_phase += _scroll * step * 0.25
		for l in lasers:
			l.align_angle = _align_angle
			l.scroll_phase = _scroll_phase

	if _randomizer <= 0.0:
		return
	_next_roll -= delta
	if _next_roll > 0.0:
		return
	_next_roll = _interval()
	_roll()


func _roll():
	var candidates: Array[VJParam] = []
	for p in params:
		if p.randomizable:
			candidates.append(p)
	if candidates.is_empty():
		return

	# One or two at a time: beyond that it stops reading as a gesture and starts
	# reading as a malfunction.
	for i in range(randi_range(1, 2)):
		var p: VJParam = candidates.pick_random()
		# Averaging two draws clusters values towards the middle of the range, so
		# we avoid the extremes that either empty or saturate the screen.
		var t := (randf() + randf()) * 0.5
		p.set_value(lerpf(p.min_value, p.max_value, t))

	# Every so often, fresh colours too — but only if they are in random mode,
	# otherwise we would trample a manual choice.
	if palette.mode == Palette.RANDOM and randf() < 0.25:
		_randomize_all()


# --------------------------------------------------------------------------
# OSC (Chataigne, TouchOSC, or any other sender)
# --------------------------------------------------------------------------

func _on_osc_message(address: String, args: Array):
	match address:
		"/deferlante/glitch_now":
			circle.apply_glitch()
			return
		"/deferlante/randomize":
			_randomize_all()
			return
		"/deferlante/preset/recall":
			if not args.is_empty():
				presets.recall(int(args[0]))
			return
		"/deferlante/preset/save":
			if not args.is_empty():
				presets.save_slot(int(args[0]))
			return
		"/deferlante/color/rgb":
			# A colour picker sends its components in one go.
			if args.size() >= 3:
				_set_rgb_from_osc(args)
			return

	if args.is_empty() or not (args[0] is float or args[0] is int):
		return
	var value := float(args[0])

	# Normalised form: /deferlante/norm/<address> takes 0..1 and spreads it over
	# the setting's range. For a MIDI fader or a touch surface that can only send
	# 0..1 without knowing each setting's bounds.
	var normalized := address.begins_with("/deferlante/norm/")
	var key := address.replace("/norm/", "/") if normalized else address

	var p: VJParam = osc_routes.get(key)
	if p == null:
		return
	_external_touch()
	if normalized:
		value = lerpf(p.min_value, p.max_value, clampf(value, 0.0, 1.0))
	p.set_value(value)


func _set_rgb_from_osc(args: Array):
	var names := ["color/red", "color/green", "color/blue"]
	for i in range(3):
		var p: VJParam = osc_routes.get("/deferlante/" + names[i])
		if p:
			p.set_value(float(args[i]))


## R key: back to random colours, with a fresh draw. This is the way out of manual
## mode, the one you find without thinking mid-set.
func _randomize_all():
	if _mode_param and palette.mode != Palette.RANDOM:
		_mode_param.set_value(Palette.RANDOM)
	circle.randomize_look()
	sphere.randomize_look()
	for l in lasers:
		l.randomize_look()


# --------------------------------------------------------------------------
# Web control surface
# --------------------------------------------------------------------------

## The page builds itself entirely from this, so it cannot drift from the settings
## Godot actually has: a setting added in _build_params() simply shows up there.
func _send_schema():
	var described: Array = []
	for p in params:
		var choices: Array = []
		for c in p.choices:
			choices.append(lang.text(c) if p.translate_choices else c)
		described.append({
			"slug": p.slug,
			"label": p.label(),
			"section": lang.text(p.section),
			"min": p.min_value,
			"max": p.max_value,
			"step": p.step,
			"value": p.value,
			"choices": choices,
			"bidirectional": p.bidirectional,
		})
	web.broadcast({
		"type": "schema",
		"params": described,
		"presets": {"used": presets.used_slots(), "count": presets.SLOTS},
	})


func _on_web_set(slug: String, value: float):
	_external_touch()
	var p := param(slug)
	if p:
		p.set_value(value)


func _on_web_action(name: String):
	_external_touch()
	if name.begins_with("preset:"):
		var bits := name.split(":")
		if bits[1] == "save":
			presets.save_slot(int(bits[2]))
		else:
			presets.recall(int(bits[2]))
		return
	match name:
		"glitch":
			circle.apply_glitch()
		"randomize":
			_randomize_all()


# --------------------------------------------------------------------------
# REST API
# --------------------------------------------------------------------------

## Same entry point as everything else: a PUT ends up in `VJParam.set_value()`,
## so a value set over HTTP is clamped, snapped and mirrored to the panel and to
## every connected phone exactly like one set over OSC.
## Which preset slot a key means, if any.
##
## Read from the *physical* key rather than the character it produces. On AZERTY
## the top row is & é " ' ( - è _ ç, and only é, è and ç fell through to a digit —
## Godot maps the ASCII ones to their punctuation keycodes, so six slots out of
## nine were unreachable. The physical code is the same key wherever the layout
## puts it, which is also what any game means by "the 1 key".
func _preset_slot(event: InputEventKey) -> int:
	if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
		return event.physical_keycode - KEY_0
	# The numeric keypad is laid out the same everywhere, so it can use its own
	# keycodes — and it is the obvious surface for stabbing presets anyway.
	if event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_9:
		return event.keycode - KEY_KP_0
	return 0


func _handle_api(method: String, path: String, body: String) -> Dictionary:
	if path == "/openapi.json":
		return {"code": 200, "body": _openapi()}

	if path == "/api/params":
		var listed: Array = []
		for p in params:
			listed.append(_describe(p))
		return {"code": 200, "body": {"params": listed}}

	if path.begins_with("/api/params/"):
		var slug := path.substr("/api/params/".length())
		var p := param(slug)
		if p == null:
			return {"code": 404, "body": {"error": "unknown setting", "setting": slug}}
		if method == "GET":
			return {"code": 200, "body": _describe(p)}
		if method == "PUT" or method == "POST":
			var payload = JSON.parse_string(body)
			if typeof(payload) != TYPE_DICTIONARY or not payload.has("value"):
				return {"code": 400, "body": {"error": "expected {\"value\": number}"}}
			p.set_value(float(payload["value"]))
			return {"code": 200, "body": _describe(p)}
		return {"code": 405, "body": {"error": "use GET or PUT"}}

	if path == "/api/presets":
		return {"code": 200, "body": {"slots": presets.used_slots(), "count": presets.SLOTS}}

	if path.begins_with("/api/presets/"):
		var rest := path.substr("/api/presets/".length()).split("/")
		var slot: int = int(rest[0])
		var verb: String = rest[1] if rest.size() > 1 else ""
		if method != "POST":
			return {"code": 405, "body": {"error": "use POST"}}
		match verb:
			"recall":
				if not presets.recall(slot):
					return {"code": 404, "body": {"error": "empty slot", "slot": slot}}
				return {"code": 200, "body": {"recalled": slot}}
			"save", "":
				if not presets.save_slot(slot):
					return {"code": 400, "body": {"error": "slot out of range", "slot": slot}}
				return {"code": 200, "body": {"saved": slot}}
			_:
				return {"code": 404, "body": {"error": "use /save or /recall"}}

	if path.begins_with("/api/actions/"):
		if method != "POST":
			return {"code": 405, "body": {"error": "use POST"}}
		var action := path.substr("/api/actions/".length())
		match action:
			"glitch":
				circle.apply_glitch()
			"randomize":
				_randomize_all()
			_:
				return {"code": 404, "body": {"error": "unknown action", "action": action}}
		return {"code": 200, "body": {"triggered": action}}

	return {"code": 404, "body": {"error": "no such endpoint", "path": path}}


func _describe(p: VJParam) -> Dictionary:
	var choices: Array = []
	for c in p.choices:
		choices.append(lang.text(c) if p.translate_choices else c)
	return {
		"slug": p.slug,
		"label": p.label(),
		"section": lang.text(p.section),
		"min": p.min_value,
		"max": p.max_value,
		"step": p.step,
		"value": p.value,
		"choices": choices,
		"bidirectional": p.bidirectional,
	}


## The spec is generated from the settings rather than written alongside them, for
## the same reason the Chataigne module is: a hand-kept copy drifts silently.
func _openapi() -> Dictionary:
	var slugs: Array = []
	for p in params:
		slugs.append(p.slug)

	var setting_param := {
		"name": "setting",
		"in": "path",
		"required": true,
		"description": "Section and name, e.g. spot/hold",
		"schema": {"type": "string", "enum": slugs},
	}

	return {
		"openapi": "3.0.3",
		"info": {
			"title": "Deferlante",
			"version": "1.0.0",
			"description": "VJ visuals control. Every setting here is the same object the "
				+ "on-screen sliders and OSC drive, so changes made through this API show "
				+ "up everywhere at once.",
		},
		"servers": [{"url": "/"}],
		"paths": {
			"/api/params": {"get": {
				"summary": "List every setting",
				"tags": ["Settings"],
				"responses": {"200": {"description": "All settings with their bounds and current values"}},
			}},
			"/api/params/{setting}": {
				"get": {
					"summary": "Read one setting",
					"tags": ["Settings"],
					"parameters": [setting_param],
					"responses": {"200": {"description": "The setting"}, "404": {"description": "No such setting"}},
				},
				"put": {
					"summary": "Set one setting",
					"description": "The value is clamped to the setting's bounds and snapped to its step.",
					"tags": ["Settings"],
					"parameters": [setting_param],
					"requestBody": {"required": true, "content": {"application/json": {
						"schema": {"type": "object", "required": ["value"],
							"properties": {"value": {"type": "number"}}},
					}}},
					"responses": {"200": {"description": "The setting, after clamping"},
						"400": {"description": "Body was not {\"value\": number}"},
						"404": {"description": "No such setting"}},
				},
			},
			"/api/actions/{action}": {"post": {
				"summary": "Fire a one-shot action",
				"tags": ["Actions"],
				"parameters": [{
					"name": "action", "in": "path", "required": true,
					"schema": {"type": "string", "enum": ["glitch", "randomize"]},
				}],
				"responses": {"200": {"description": "Fired"}, "404": {"description": "No such action"}},
			}},
		},
	}


# --------------------------------------------------------------------------
# Show shortcuts (the panel handles its own: arrows, H, F3)
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if not (event is InputEventKey and event.pressed):
		return
	# Any key takes the wheel back from whatever external surface had it.
	panel.set_external_control(false, discreet_brightness)

	# Number keys: recall a preset, or save into it with Ctrl held. Ctrl rather
	# than Shift because Shift is already the fine-adjust modifier on the arrows.
	var slot := _preset_slot(event)
	if slot > 0:
		if event.ctrl_pressed:
			presets.save_slot(slot)
		else:
			presets.recall(slot)
		return

	match event.keycode:
		KEY_F2:
			# One key to duck the panel out of sight and back. A slider is fine for
			# choosing how discreet, but not for getting there quickly. F2 sits
			# beside F3, the other key that changes what is on screen rather than
			# what the visuals do.
			#
			# Comparing against the midpoint rather than against the dim level
			# itself: the setting is snapped to its step, so the value never comes
			# back bit-identical and `value > dim` stayed true forever.
			var p := param("global/panel")
			var midpoint := (discreet_brightness + 1.0) * 0.5
			p.set_value(discreet_brightness if p.value > midpoint else 1.0)
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

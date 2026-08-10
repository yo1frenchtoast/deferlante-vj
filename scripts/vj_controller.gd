extends Node2D

## Conductor: declares the settings, spawns the lasers, routes OSC.
##
## Display belongs to the panel (`control_panel.gd`), the protocol to the OSC
## server (`osc_server.gd`). All that lives here is the list of settings and what
## they drive — adding a line to `_build_params()` creates the slider, the keyboard
## navigation and the OSC address in one go.

@export var laser_scene: PackedScene = preload("res://scenes/laser.tscn")
@export var laser_count: int = 5
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
var v_length: float = 1.0
var v_spin: float = 1.0

var _mode_param: VJParam
## True while start-up values are being applied: without this guard, setting the
## initial RED would flip the project into manual colour mode on launch.
var _initializing: bool = true

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

	pad.find_param = param
	pad.aim.connect(circle.aim_at)
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

	_section("section.spot")
	# Settings that only write a property are declared, not coded.
	_prop("spot/radius", 20, 600, 5, 200.0, circle, "base_radius")
	_prop("spot/pulse", 0, 300, 5, 50.0, circle, "fluctuation_range")
	_fn("spot/width", 1, 24, 0.5, 3.0, func(v): circle.set_line_width(v))
	_prop("spot/speed", 0, 2, 0.05, 1.0, circle, "seek_speed")
	_prop("spot/hold", 0, 3, 0.05, 0.9, circle, "hold_time")
	_prop("spot/shake", 0, 3, 0.05, 1.0, circle, "wobble_amount")
	_prop("spot/frequency", 0, 20, 0.5, 6.0, circle, "wobble_speed")
	_prop("spot/glitch", 0, 0.05, 0.001, 0.0, circle, "glitch_chance")

	_section("section.sphere")
	_prop("sphere/count", 0, 80, 1, 40.0, sphere, "circle_count")
	_prop("sphere/size", 0.03, 0.8, 0.01, 0.13, sphere, "circle_size")
	_prop("sphere/radius", 100, 800, 10, 400.0, sphere, "sphere_radius")
	_prop("sphere/spin", -1, 1, 0.05, 0.6, sphere, "spin", true)
	_prop("sphere/depth", 1.2, 10, 0.1, 2.0, sphere, "eye_distance")
	_prop("sphere/width", 1, 24, 0.5, 3.0, sphere, "line_width")
	_prop("sphere/glass", 0, 1, 0.02, 0.0, sphere, "back_dim")

	# Out of the auto-pilot's reach: tempo, glow and colour are decisions — the
	# room, the track — rather than variations to be subjected to.
	for slug in ["global/speed", "global/glow", "color/saturation",
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


## Touching a colour switches to manual: without that, moving RED while in random
## mode would do nothing visible and the slider would look broken. The start-up
## guard keeps the initial values from flipping the mode on launch.
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
		# A laser spawned mid-set must inherit the current settings.
		laser.speed_scale = v_speed
		laser.spin_scale = v_spin
		laser.chaos = v_chaos
		laser.width = v_laser_width
		laser.use_palette(palette)
		laser.set_length_scale(v_length)
		lasers.append(laser)


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
	web.broadcast({"type": "schema", "params": described})


func _on_web_set(slug: String, value: float):
	var p := param(slug)
	if p:
		p.set_value(value)


func _on_web_action(name: String):
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

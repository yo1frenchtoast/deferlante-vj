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
## Halo off by default: with a haze machine the beam is diffused physically, and
## adding a software halo on top only softens the edges.
@export_range(0.0, 2.0, 0.01) var default_glow: float = 0.0

@onready var circle: Line2D = $GlitchCircle
@onready var sphere: Node2D = $SphereCircles
@onready var kaleido: CanvasLayer = $Kaleidoscope
@onready var panel: CanvasLayer = $ControlPanel
@onready var osc: Node = $OscServer
@onready var web: Node = $WebServer
@onready var pad: Node = $Gamepad
@onready var presets: Node = $Presets
@onready var audio: Node = $Audio
@onready var api: Node = $RestApi
@onready var autopilot: Node = $Autopilot

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
var v_halo: float = 0.0
var _audio_was_active: bool = false
var _status_tick: float = 0.0
var _meter_tick: float = 0.0
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
var _amounts := {"lasers": 2.5, "spot": 2.5, "sphere": 2.5}
var _modulations: Array = []

enum { BASS, MID, TREBLE }

var _mode_param: VJParam
## True while start-up values are being applied: without this guard, setting the
## initial RED would flip the project into manual colour mode on launch.
var _initializing: bool = true
var _autodim: bool = true


var _current_section: String = ""


func _ready():
	# Settled at the launcher and fixed for the run. It was a setting on the panel
	# once; it is a decision about who is standing in front of the machine, made
	# before the show rather than during it.
	lang.set_language(Launch.language)
	_build_params()
	for p in params:
		p.use_language(lang)
	panel.build(params, lang)

	autopilot.all_params = func(): return params
	autopilot.randomize_colours = _randomize_all
	autopilot.palette = palette

	_build_modulations()
	circle.use_palette(palette)
	sphere.use_palette(palette)
	_spawn_lasers(laser_count)
	for p in params:
		p.apply_current()
	_initializing = false

	for p in params:
		osc_routes["/deferlante/" + p.slug] = p
	osc.message_received.connect(_on_osc_message)

	api.find_param = param
	api.all_params = func(): return params
	api.describe = _describe
	api.presets = presets
	api.glitch = circle.apply_glitch
	api.randomize = _randomize_all
	web.api_handler = api.handle
	web.client_connected.connect(_send_schema)
	web.set_requested.connect(_on_web_set)
	web.action_requested.connect(_on_web_action)
	# A phone must see what the keyboard, OSC or the auto-pilot just did.
	for p in params:
		p.changed.connect(func(v): web.broadcast({"type": "value", "slug": p.slug, "value": v}))

	_refresh_status()

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
	_fn("global/randomizer", 0, 1, 0.02, 0.0, autopilot.set_amount).randomizable = false
	_fn("global/glow", 0, 2, 0.05, default_glow, _set_glow)
	_prop("global/recall", 0, 10, 0.1, 2.0, presets, "recall_time")
	_fn("global/panel", 0.05, 1, 0.05, 1.0, panel.set_brightness)
	var autodim := _fn("global/autodim", 0, 1, 1, 1.0, _set_autodim)
	autodim.choices = PackedStringArray(["mode.off", "mode.on"])
	autodim.randomizable = false

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
	_fn("spot/width", 1, 24, 0.5, 3.0, circle.set_line_width)
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
	# Written out one by one rather than looped over: this list is read back by
	# `tools/build_chataigne_module.py`, which parses the declarations as text, and
	# a slug built at runtime is a slug the tooling cannot see.
	# Ranges deliberately past the point of good taste. The envelope now pulses
	# rather than swells, which makes each hit shorter as well as sharper, and a
	# ceiling that stopped at something reasonable meant the top of the slider was
	# merely brisk. The top of a slider should be too much; the middle is where the
	# set lives.
	_fn("audio/lasers", 0, 12, 0.05, 2.5, func(v): _amounts["lasers"] = v)
	_fn("audio/spot", 0, 12, 0.05, 2.5, func(v): _amounts["spot"] = v)
	_fn("audio/sphere", 0, 12, 0.05, 2.5, func(v): _amounts["sphere"] = v)

	_section("section.sphere")
	_prop("sphere/count", 0, 80, 1, 14.0, sphere, "circle_count")
	_prop("sphere/size", 0.03, 0.8, 0.01, 0.13, sphere, "circle_size")
	_prop("sphere/radius", 100, 800, 10, 400.0, sphere, "sphere_radius")
	_prop("sphere/spin", -1, 1, 0.05, 0.6, sphere, "spin", true)
	_prop("sphere/depth", 1.2, 10, 0.1, 2.0, sphere, "eye_distance")
	_prop("sphere/width", 1, 24, 0.5, 3.0, sphere, "line_width")
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
	var osc_at: String = osc.address()
	if osc_at != "":
		bits.append("osc  %s" % osc_at)
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


## HALO. No longer the post-process glow: each stroke draws its own wide, faint
## echo (see `halo.gd`). The setting keeps its name, its range and its OSC address —
## what changed is who does the work, not what the operator reaches for.
func _set_glow(value: float):
	v_halo = value
	circle.set_halo(value)
	sphere.halo_amount = value
	for l in lasers:
		l.set_halo(value)


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
		laser.set_halo(v_halo)
		lasers.append(laser)


# --------------------------------------------------------------------------
# Audio reactivity
# --------------------------------------------------------------------------

func _set_reactivity(value: float):
	_react = value


## A live bar in the status line. Without it, "the visuals are not moving" could be
## silence, wrong routing, a stale process or a slider at zero, and nothing on
## screen told them apart.
func _audio_meter() -> String:
	var label: String = lang.text("status.audio")
	if not audio.capturing:
		return "%s %s" % [label, lang.text("status.deaf")]
	# Told apart from a quiet passage on purpose: this one means the capture is open
	# on something that carries nothing, which is almost always the wrong source.
	if audio.is_silent():
		return "%s %s" % [label, lang.text("status.silent")]
	var glyphs := ["▁", "▂", "▃", "▄", "▅", "█"]
	var bars := ""
	for value in [audio.bass, audio.mid, audio.treble]:
		bars += glyphs[clampi(int(round(value * 5.0)), 0, 5)]
	# The amount is shown next to the bars: bars moving while this reads 0 % is
	# the difference between "it cannot hear you" and "you have not turned it up".
	return "%s %s %.0f%%" % [label, bars, _react * 100.0]


## The same three levels the status line draws, sent to the browsers.
##
## On a clock rather than from the `levels` signal: that one fires every frame, and
## sixty packets a second per phone is a lot of radio for a bar nobody can read
## faster than about twenty. The reactivity rides along so the page can make the
## same distinction the status line does — hearing nothing and not being turned up
## look identical otherwise.
func _broadcast_levels():
	if not web.has_clients():
		return
	web.broadcast({
		"type": "audio",
		"capturing": audio.capturing,
		"bass": audio.bass,
		"mid": audio.mid,
		"treble": audio.treble,
		"silent": audio.is_silent(),
		"reactivity": _react,
	})


## What the sound moves, one line per target.
##
## Each entry names the setting that holds the *base* value, the band that drives
## it, the amount slider that scales it, and how strongly. Reading the base from the
## setting rather than from a copy in this file is the point: adding a target used
## to mean a shadow variable, a modified setter, and a line in each of two
## hand-written loops, and the four could drift apart.
##
## Size moves at a third of the weight of thickness — a radius reads far more
## strongly than a width, and matching them made every hit look like a blowout.
func _build_modulations():
	_modulations = [
		{"slug": "lasers/width", "band": MID, "amount": "lasers", "weight": 1.0,
			"set": func(v: float): _write_lasers("width", v)},
		{"slug": "lasers/length", "band": MID, "amount": "lasers", "weight": 0.33,
			"set": func(v: float): for l in lasers: l.set_length_scale(v)},
		{"slug": "spot/width", "band": BASS, "amount": "spot", "weight": 1.0,
			"set": circle.set_line_width},
		{"slug": "spot/radius", "band": BASS, "amount": "spot", "weight": 0.33,
			"set": func(v: float): circle.base_radius = v},
		{"slug": "sphere/width", "band": TREBLE, "amount": "sphere", "weight": 1.0,
			"set": func(v: float): sphere.line_width = v},
		{"slug": "sphere/size", "band": TREBLE, "amount": "sphere", "weight": 0.33,
			"set": func(v: float): sphere.circle_size = v},
	]


func _write_lasers(property: String, value: float):
	for l in lasers:
		l.set(property, value)


## The sound *adds* to each target rather than setting it, and nothing here writes
## to a VJParam — so the sliders keep meaning what they say, REACTIVITY back to 0
## restores exactly the look that was there, and the sound never lands in a preset
## or fights the operator for a slider.
##
## Each effect follows a different band. Three effects breathing on one envelope
## read as a single thing pumping; on separate bands the picture comes apart into
## layers. The kick drives the spotlight, the biggest shape on screen.
func _apply_audio():
	if _react <= 0.0 or not audio.capturing:
		if _audio_was_active:
			_audio_was_active = false
			_reset_modulations()
		return
	_audio_was_active = true

	var bands := [audio.bass, audio.mid, audio.treble]
	for m in _modulations:
		var base: float = param(m["slug"]).value
		var drive: float = _react * _amounts[m["amount"]] * bands[m["band"]]
		m["set"].call(base * (1.0 + drive * m["weight"]))


func _reset_modulations():
	for m in _modulations:
		m["set"].call(param(m["slug"]).value)


# --------------------------------------------------------------------------
# Per-frame work
# --------------------------------------------------------------------------

func _process(delta: float):
	_apply_audio()

	# The meter has to be refreshed on a clock: the status line is otherwise only
	# rebuilt on events, and levels are not events.
	_status_tick += delta
	if _status_tick > 0.2:
		_status_tick = 0.0
		if audio.capturing:
			_refresh_status()

	# Same reasoning for the phones, on their own clock: twenty a second while there
	# is something to watch, one a second when there is not — a page that just
	# connected still has to be told the machine is deaf.
	_meter_tick += delta
	if _meter_tick > (0.05 if audio.capturing else 1.0):
		_meter_tick = 0.0
		_broadcast_levels()

	# The fan turns and scrolls once per frame, and every stroke reads the same
	# two numbers — that is what keeps them parallel and evenly spaced.
	if v_align > 0.0:
		var step := delta * v_speed
		_align_angle += v_spin * step * 0.4
		_scroll_phase += _scroll * step * 0.25
		for l in lasers:
			l.align_angle = _align_angle
			l.scroll_phase = _scroll_phase


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

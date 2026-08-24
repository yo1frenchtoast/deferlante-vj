extends Node2D

## Conductor: declares the settings, spawns the lasers, routes OSC.
##
## Display belongs to the panel (`control_panel.gd`), the protocol to the OSC
## server (`osc_server.gd`). All that lives here is the list of settings and what
## they drive — adding a line to `_build_params()` creates the slider, the keyboard
## navigation and the OSC address in one go.

## The one-shot actions every surface offers. Named once: the REST spec advertises
## these, the Chataigne module is built from them, and `_on_web_action()` wires them.
const ACTIONS := ["glitch", "randomize", "shuffle"]

## Where OSC addresses and Chataigne callbacks are rooted.
const OSC_PREFIX := "/deferlante/"

@export var laser_scene: PackedScene = preload("res://scenes/laser.tscn")
@export var laser_count: int = 3
## Where the D key ducks the panel to: readable up close, all but gone on a wall.
@export_range(0.05, 1.0, 0.05) var discreet_brightness: float = 0.15
## Halo off by default: with a haze machine the beam is diffused physically, and
## adding a software halo on top only softens the edges.
@export_range(0.0, 2.0, 0.01) var default_glow: float = 0.0

@onready var circle: Line2D = $GlitchCircle
@onready var sphere: Node2D = $SphereCircles
@onready var warp: Node2D = $Hyperspace
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
var _amounts := {"lasers": 2.5, "spot": 2.5, "sphere": 2.5, "warp": 2.5}
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
	warp.use_palette(palette)
	_spawn_lasers(laser_count)
	for p in params:
		p.apply_current()
	_initializing = false

	for p in params:
		osc_routes[OSC_PREFIX + p.slug] = p
	osc.message_received.connect(_on_osc_message)

	api.find_param = param
	api.all_params = func(): return params
	api.describe = func(p): return _describe(p, Lang.EN)
	api.presets = presets
	api.actions = ACTIONS
	api.fire = fire_action
	web.api_handler = api.handle
	web.client_connected.connect(_send_schema)
	web.set_requested.connect(_on_web_set)
	web.action_requested.connect(_on_web_action)
	web.launch_set_requested.connect(_on_web_launch_set)
	# A phone must see what the keyboard, OSC or the auto-pilot just did.
	for p in params:
		p.changed.connect(func(v): web.broadcast({"type": "value", "slug": p.slug, "value": v}))

	_refresh_status()

	# Asked for by a generator rather than by an operator: describe the show and
	# stand down without ever putting anything on screen.
	var wanted := _dump_path()
	if wanted != "":
		_dump(wanted)
		return

	# A deliberate click hands the panel back, exactly like a keypress does.
	panel.mouse_reclaimed.connect(func(): panel.set_external_control(false, discreet_brightness))

	presets.all_params = func(): return params
	presets.slots_changed.connect(_send_schema)

	# The state the show comes up in, settled at the launcher. This is the one
	# decision no surface can make for us: at this moment nothing is connected, no
	# console has sent anything, and there is nobody at the keyboard — which is the
	# whole situation the row exists for. Instant rather than a crossfade: a fade
	# from the defaults is a fade from a look nobody chose, and there is no audience
	# yet to fade for. A slot that was never saved simply leaves the defaults
	# standing, the same way an empty slot does everywhere else.
	if Launch.auto_start > 0:
		presets.recall(Launch.auto_start, true)

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
	_prop("global/recall", 0, 10, 0.1, 0.0, presets, "recall_time")
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
	# Off or on, with nothing in between. The cross-fade that used to live here was
	# `mix(image, folded, amount)`, and on additive neon over black that is the wrong
	# operator: at 0.5 it gives the whole image at half brightness plus the whole
	# fold at half brightness. On a monitor that reads as a mirror opening. Through a
	# projector into haze, which has no contrast to spare, it reads as a washed-out
	# ghost. The pad has written 0 or 1 here since the day it got a mirror button.
	var mirror := _fn("mirror/effect", 0, 1, 1, 0.0, kaleido.set_amount)
	mirror.choices = PackedStringArray(["mode.off", "mode.on"])
	_fn("mirror/segments", 2, 16, 1, 5.0, kaleido.set_segments)
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
	# In the order the ear takes them, low to high, which is also the order the
	# vu-metre draws them. They used to run mids, bass, treble — the order they were
	# written in — and reading the panel meant translating every time.
	_fn("audio/spot", 0, 12, 0.05, 2.5, func(v): _amounts["spot"] = v)
	# The one band shared by two effects. Four effects and three bands leave no
	# choice, and the kick is where a jump to light speed belongs. What the doc
	# below warns against is two effects breathing on the same *property*: the
	# spotlight takes the bass as a size, the star field takes it as a speed, and
	# the two read as separate layers rather than as one pump.
	_fn("audio/warp", 0, 12, 0.05, 2.5, func(v): _amounts["warp"] = v)
	_fn("audio/lasers", 0, 12, 0.05, 2.5, func(v): _amounts["lasers"] = v)
	_fn("audio/sphere", 0, 12, 0.05, 2.5, func(v): _amounts["sphere"] = v)

	_section("section.sphere")
	_prop("sphere/count", 0, 80, 1, 14.0, sphere, "circle_count")
	_prop("sphere/size", 0.03, 0.8, 0.01, 0.13, sphere, "circle_size")
	_prop("sphere/radius", 100, 800, 10, 400.0, sphere, "sphere_radius")
	_prop("sphere/spin", -1, 1, 0.05, 0.6, sphere, "spin", true)
	_prop("sphere/depth", 1.2, 10, 0.1, 2.0, sphere, "eye_distance")
	_prop("sphere/width", 1, 24, 0.5, 3.0, sphere, "line_width")
	_prop("sphere/glass", 0, 1, 0.02, 0.0, sphere, "back_dim")

	_section("section.warp")
	# Off by default, unlike the sphere. This effect arrived after nine preset slots
	# had been filled on machines already in use, and a preset saved before it
	# existed carries no value for it. One that lit itself up on launch would appear
	# in every one of those shows, uninvited, until each was saved again.
	_prop("warp/count", 0, 400, 5, 0.0, warp, "star_count")
	_prop("warp/speed", 0, 4, 0.05, 1.0, warp, "approach")
	_prop("warp/streak", 0, 0.4, 0.01, 0.12, warp, "shutter")
	_prop("warp/width", 0.5, 12, 0.5, 2.0, warp, "line_width")
	_prop("warp/spread", 0.1, 2, 0.05, 0.7, warp, "field")

	# Out of the auto-pilot's reach: tempo, glow and colour are decisions — the
	# room, the track — rather than variations to be subjected to.
	#
	# `spot/track` and `spot/handback` are here for a second reason: they are the
	# feel of the operator's handle, not a look. Rolling the tracking speed while a
	# hand is on the stick changes how the beam answers mid-follow, and rolling the
	# hand-back delay decides how long the beam sits still afterwards. `spot/manual`
	# was already out for the same reason; these two were left behind.
	for slug in ["global/speed", "global/glow", "global/recall", "global/panel",
			"global/autodim", "audio/reactivity", "color/saturation",
			"color/mode", "color/red", "color/green", "color/blue",
			"spot/track", "spot/handback"]:
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


## The cursor the operator can set: locked to the stick, or free to go hunting
## again after the hand-back delay.
func _set_manual_lock(value: float):
	circle.manual_lock = value >= 0.5


func _set_speed(value: float):
	v_speed = value
	circle.speed_scale = value
	sphere.speed_scale = value
	warp.speed_scale = value
	kaleido.speed_scale = value
	for l in lasers:
		l.speed_scale = value


func _set_chaos(value: float):
	v_chaos = value
	circle.chaos = value
	sphere.chaos = value
	warp.chaos = value
	for l in lasers:
		l.chaos = value


## HALO. No longer the post-process glow: each stroke draws its own wide, faint
## echo (see `halo.gd`). The setting keeps its name, its range and its OSC address —
## what changed is who does the work, not what the operator reaches for.
func _set_glow(value: float):
	v_halo = value
	circle.set_halo(value)
	sphere.halo_amount = value
	warp.halo_amount = value
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
		{"slug": "warp/speed", "band": BASS, "amount": "warp", "weight": 1.0,
			"set": func(v: float): warp.approach = v},
		{"slug": "warp/width", "band": BASS, "amount": "warp", "weight": 0.33,
			"set": func(v: float): warp.line_width = v},
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
		"/deferlante/shuffle":
			autopilot.roll_now()
			return
	if address.begins_with("/deferlante/shuffle/"):
		_external_touch()
		autopilot.roll_now(address.substr("/deferlante/shuffle/".length()))
		return
	match address:
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
	warp.randomize_look()
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
		# In the room's own tongue: this one is read by a person, not a program.
		described.append(_describe(p, lang.current))
	web.broadcast({
		"type": "schema",
		"params": described,
		"presets": {"used": presets.used_slots(), "count": presets.SLOTS},
		# Named rather than spelled out in the page: the buttons are built from this,
		# so an action added to `ACTIONS` appears on every phone without touching
		# the HTML — the same way a setting does.
		"actions": ACTIONS.map(func(a): return {
			"name": a, "label": lang.text("action." + a)}),
		"launch": _describe_launch(),
	})


## The start-up settings, described the same way the live ones are, so the page can
## build its tab from this and never drift from what Godot holds.
##
## These are the launcher's rows minus the audio ones. Which output the show listens
## to is bound when capture opens and cannot be moved afterwards — the very reason
## it lives in the launcher — and answering it honestly needs a live meter and a
## subprocess per candidate. A phone across the room is the wrong place to ask.
##
## Every one of these takes effect on the next process, not this one, which is what
## the restart button is for. `apply_runtime()` could reach some of them live, but a
## tab where three rows bite immediately and six wait would be worse than one where
## none do.
func _describe_launch() -> Dictionary:
	var resolutions: Array = [lang.text("launch.resolution.native")]
	for i in range(1, Launch.RESOLUTIONS.size()):
		var r: Vector2i = Launch.RESOLUTIONS[i]
		resolutions.append("%d × %d" % [r.x, r.y])

	var rates: Array = [lang.text("launch.maxfps.free")]
	for i in range(1, Launch.MAX_FPS.size()):
		rates.append(str(Launch.MAX_FPS[i]))

	var samples: Array = [lang.text("launch.msaa.off")]
	for i in range(1, Launch.MSAA_SAMPLES.size()):
		samples.append("%d×" % Launch.MSAA_SAMPLES[i])

	# The same list the launcher offers, and the same re-check: an address saved
	# last night may not be one this machine still holds.
	var addresses: Array = [lang.text("launch.access.local")]
	for a in Launch.local_addresses():
		addresses.append(a)

	return {
		"tab": lang.text("launch.tab"),
		"restart": lang.text("launch.restart.now"),
		"applies": lang.text("launch.restart.applies"),
		"web_warning": lang.text("launch.restart.web"),
		"failed": lang.text("launch.restart.failed"),
		# Asked before the button is drawn, not after it is pressed: a control that
		# can never work is worse than a sentence saying so.
		"can_restart": Launch.can_relaunch(),
		"settings": [
			_launch_choice("language", "launch.language", Lang.LANGUAGES, Lang.choice_of(Launch.language)),
			_launch_choice("renderer", "launch.renderer", [
				lang.text("launch.renderer.compat"), lang.text("launch.renderer.forward"),
			], 1 if Launch.rendering_method == "forward_plus" else 0),
			# Offered against the renderer *chosen*, not the one running: the next
			# process is the one that will honour it, and it is the one being
			# configured here.
			_launch_choice("msaa", "launch.msaa", samples,
				maxi(0, Launch.MSAA_SAMPLES.find(Launch.msaa)),
				"" if Launch.msaa_available() else lang.text("launch.msaa.unavailable")),
			_launch_choice("resolution", "launch.resolution", resolutions,
				maxi(0, Launch.RESOLUTIONS.find(Launch.resolution))),
			_launch_toggle("fullscreen", "launch.fullscreen", Launch.fullscreen),
			_launch_toggle("vsync", "launch.vsync", Launch.vsync),
			_launch_choice("max_fps", "launch.maxfps", rates,
				maxi(0, Launch.MAX_FPS.find(Launch.max_fps))),
			_launch_toggle("hide_panel", "launch.panel", Launch.hide_panel,
				lang.text("launch.panel.hidden")),
			_launch_choice("auto_start", "launch.autostart", _auto_start_choices(),
				clampi(Launch.auto_start, 0, presets.SLOTS),
				lang.text("launch.autostart.hint")),
			_launch_choice("web_bind", "launch.access", addresses,
				maxi(0, addresses.find(Launch.web_bind))),
			_launch_port("web_port", "launch.webport", Launch.web_port),
			_launch_choice("osc_bind", "launch.oscaccess", addresses,
				maxi(0, addresses.find(Launch.osc_bind))),
			_launch_port("osc_port", "launch.oscport", Launch.osc_port),
		],
	}


## The same nine rows the launcher offers, each saying whether it holds anything.
## Read live rather than from disk: this show has the slots in memory, and a slot
## saved from a phone a moment ago must appear here without a restart.
func _auto_start_choices() -> Array:
	var used: Array = presets.used_slots()
	var choices: Array = [lang.text("launch.autostart.none")]
	for i in range(1, presets.SLOTS + 1):
		var key := "launch.autostart.slot" if used.has(i) else "launch.autostart.empty"
		choices.append(lang.text(key) % i)
	return choices


func _launch_choice(key: String, label_key: String, choices: Array, index: int,
		note: String = "") -> Dictionary:
	return {"key": key, "label": lang.text(label_key), "type": "choice",
		"choices": choices, "value": index, "note": note}


## `caption` is the words beside the box rather than a warning under the row: the
## launcher writes PANNEAU ☐ masqué pour tout le set, and a bare switch labelled
## only PANNEAU would not say which way is which.
func _launch_toggle(key: String, label_key: String, on: bool,
		caption: String = "") -> Dictionary:
	return {"key": key, "label": lang.text(label_key), "type": "bool",
		"value": on, "caption": caption, "note": ""}


func _launch_port(key: String, label_key: String, port: int) -> Dictionary:
	return {"key": key, "label": lang.text(label_key), "type": "int",
		"value": port, "min": 1024, "max": 65535, "note": ""}


func _on_web_set(slug: String, value: float):
	_external_touch()
	var p := param(slug)
	if p:
		p.set_value(value)


func _on_web_action(name: String):
	_external_touch()
	# Restarting is not a show action: it is not in `ACTIONS`, it is not offered
	# over OSC, and it ends this process. It stays on the surface that has a button
	# for it, behind a confirmation.
	if name == "restart":
		_restart()
		return
	fire_action(name)


## Fire a one-shot action by name, or answer false if there is no such thing.
##
## Every surface routes through here, which is the point: the REST spec advertises
## `ACTIONS`, and for a while the API itself matched on a hand-written list beside
## it. They came apart the moment an action was added — the spec offered `shuffle`
## and the endpoint answered "unknown action". One door now, and it is the same
## list that describes it.
func fire_action(name: String) -> bool:
	if name.begins_with("preset:"):
		var bits := name.split(":")
		if bits.size() < 3:
			return false
		if bits[1] == "save":
			presets.save_slot(int(bits[2]))
		else:
			presets.recall(int(bits[2]))
		return true

	# "shuffle:lasers" rolls one section; bare "shuffle" rolls the whole show.
	if name.begins_with("shuffle:"):
		autopilot.roll_now(name.substr("shuffle:".length()))
		return true

	if not ACTIONS.has(name):
		return false
	match name:
		"glitch":
			circle.apply_glitch()
		"randomize":
			_randomize_all()
		"shuffle":
			autopilot.roll_now()
	return true


## Start the show again on the start-up settings as they now stand.
##
## The saving is done on every keystroke of that tab rather than here, so a restart
## by any other route — the panel, a power cut — still comes up on what was asked
## for. Standing the old show down belongs to `Launch.relaunch()`, which is the only
## place that knows whether this platform wants it.
##
## A machine that will not fork is told so on the surface that asked, rather than
## by appearing to ignore the button: nothing has changed, and the operator needs
## to know that before reaching for it again.
func _restart():
	if not Launch.relaunch():
		push_warning("Web: this platform will not start a second process")
		web.broadcast({"type": "restart_failed"})


## A start-up setting, changed from the web surface.
##
## Written straight to disk. The tab is a way to set up the next start from across
## the room — often from the sofa, minutes before the room fills — and a value that
## only lived until the process ended would be exactly the wrong promise.
##
## Nothing here touches the running show. Every one of these is a setting Godot
## fixes before a script runs, or binds before anything can listen; that is the
## reason they are start-up settings at all.
func _on_web_launch_set(key: String, value: Variant):
	_external_touch()
	var index := int(value) if typeof(value) != TYPE_BOOL else 0
	match key:
		"language":
			Launch.language = Lang.value_of(index)
		"renderer":
			Launch.rendering_method = "forward_plus" if index == 1 else "gl_compatibility"
			# Antialiasing only exists under Forward+, and a value left behind by
			# the other renderer would be applied the moment one switched back.
			if not Launch.msaa_available():
				Launch.msaa = 0
		"msaa":
			Launch.msaa = Launch.MSAA_SAMPLES[clampi(index, 0, Launch.MSAA_SAMPLES.size() - 1)]
		"resolution":
			Launch.resolution = Launch.RESOLUTIONS[clampi(index, 0, Launch.RESOLUTIONS.size() - 1)]
		"fullscreen":
			Launch.fullscreen = bool(value)
		"vsync":
			Launch.vsync = bool(value)
		"max_fps":
			Launch.max_fps = Launch.MAX_FPS[clampi(index, 0, Launch.MAX_FPS.size() - 1)]
		"hide_panel":
			Launch.hide_panel = bool(value)
		"auto_start":
			Launch.auto_start = clampi(index, 0, presets.SLOTS)
		"web_bind":
			Launch.web_bind = _launch_address(index)
		"osc_bind":
			Launch.osc_bind = _launch_address(index)
		"web_port":
			Launch.web_port = clampi(index, 1024, 65535)
		"osc_port":
			Launch.osc_port = clampi(index, 1024, 65535)
		_:
			return
	Launch.save()
	# Two phones on the same show must not disagree about what the next start will
	# be, and one row can move another: picking Compatibility empties the
	# antialiasing beside it.
	_send_schema()


## The address behind an index in the list `_describe_launch()` offered. Out of
## range reads as loopback rather than as the nearest guess: a stale index should
## narrow what can reach the show, never widen it.
func _launch_address(index: int) -> String:
	if index <= 0:
		return Launch.LOCAL
	var addresses := Launch.local_addresses()
	return addresses[index - 1] if index - 1 < addresses.size() else Launch.LOCAL


# --------------------------------------------------------------------------
# Describing the show to whatever builds against it
# --------------------------------------------------------------------------

## The path a generator asked us to write to, or "" for an ordinary run.
##
## After a bare `--`, Godot hands the rest to the project, so this reads the user
## arguments rather than the engine's.
func _dump_path() -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--dump-params")
	if at == -1 or at + 1 >= args.size():
		return ""
	return args[at + 1]


## Write everything a generator needs, then quit.
##
## The Chataigne module used to be built by running regular expressions over this
## very file and over `lang.gd`, which made the *shape* of a declaration part of the
## contract — a setting wrapped onto two lines would have been missed — and left the
## tool keeping lists of its own beside it. One of those lists had already drifted in
## both directions unnoticed.
##
## So the show describes itself instead. English throughout, like the API and for the
## same reason: what reads this is a program, not a person in a room.
func _dump(path: String):
	var described: Array = []
	for p in params:
		described.append(_describe(p, Lang.EN))
	var payload := {
		"osc_prefix": OSC_PREFIX,
		"params": described,
		"actions": ACTIONS,
		"presets": {"count": presets.SLOTS},
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write the description to %s: %s"
			% [path, error_string(FileAccess.get_open_error())])
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	print("Described %d settings into %s" % [described.size(), path])
	get_tree().quit()


## The surfaces on screen speak whichever tongue the launcher was set to. The API
## does not: its slugs, its actions and its OSC addresses are English, and a spec
## whose labels changed with the room would be one nobody could write against.
## So the tongue is named by the caller rather than read from the room.
func _describe(p: VJParam, tongue: int) -> Dictionary:
	var choices: Array = []
	for c in p.choices:
		choices.append(lang.text_in(c, tongue) if p.translate_choices else c)
	return {
		"slug": p.slug,
		"label": p.label_in(tongue),
		# One line saying what the setting does, shown when the web surface's
		# operator hovers or holds its name. Empty when none is written yet.
		"hint": lang.hint_in(p.slug, tongue),
		"section": lang.text_in(p.section, tongue),
		"min": p.min_value,
		"max": p.max_value,
		"step": p.step,
		"value": p.value,
		"choices": choices,
		"bidirectional": p.bidirectional,
		# Whether the auto-pilot may move it, which is also whether a shuffle can.
		# The surfaces need it to avoid offering a button that cannot do anything:
		# every setting under COLOUR is a decision about the room, so that section
		# has nothing to roll.
		"randomizable": p.randomizable,
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

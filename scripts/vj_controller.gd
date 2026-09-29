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

## Every purely-visual node lives inside this SubViewport, kept separate from
## the control panel so the two can be captured independently (see SpoutSender).
@onready var show_viewport: SubViewport = $ShowLayer/ShowViewportContainer/ShowViewport
@onready var circle: Line2D = $ShowLayer/ShowViewportContainer/ShowViewport/GlitchCircle
@onready var sphere: Node2D = $ShowLayer/ShowViewportContainer/ShowViewport/SphereCircles
@onready var warp: Node2D = $ShowLayer/ShowViewportContainer/ShowViewport/Hyperspace
@onready var kaleido: CanvasLayer = $ShowLayer/ShowViewportContainer/ShowViewport/Kaleidoscope
@onready var blur: CanvasLayer = $ShowLayer/ShowViewportContainer/ShowViewport/MotionBlur
@onready var panel: CanvasLayer = $ControlPanel
@onready var osc: Node = $OscServer
@onready var web: Node = $WebServer
@onready var pad: Node = $Gamepad
@onready var midi: Node = $MidiInput
@onready var presets: Node = $Presets
@onready var audio: Node = $Audio
@onready var api: Node = $RestApi
@onready var autopilot: Node = $Autopilot
@onready var spout: Node = $SpoutSender
@onready var console: Node = $Console

var lang := Lang.new()
var launch_surface: LaunchSurface
## Shared colour state, held by reference by every effect.
var palette := Palette.new()

var rig: LaserRig
var registry := ParamRegistry.new()
var actions: ShowActions
var osc_router: OscRouter

var _audio_was_active: bool = false
var _status_tick: float = 0.0
## What moved since the last frame, slug -> value, waiting to go out in one message.
var _pending_values: Dictionary = {}
var _meter_tick: float = 0.0
# Audio reactivity. The master is zero by default, so nothing moves until asked.
var _react: float = 0.0
var _amounts := {"lasers": 2.5, "spot": 2.5, "sphere": 2.5, "warp": 2.5,
	"randomizer": 0.0}
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
	launch_surface = LaunchSurface.new(lang, presets, console)
	rig = LaserRig.new(laser_scene, show_viewport, palette,
		func(): return get_viewport_rect().size)
	_build_params()
	for p in registry.all():
		p.use_language(lang)
	panel.build(registry.all(), lang)

	autopilot.registry = registry
	autopilot.randomize_colours = _randomize_all
	autopilot.palette = palette

	_build_modulations()
	circle.use_palette(palette)
	sphere.use_palette(palette)
	warp.use_palette(palette)
	rig.spawn(laser_count)
	for p in registry.all():
		p.apply_current()
	_initializing = false

	actions = ShowActions.new(circle, autopilot, presets, _randomize_all)
	osc_router = OscRouter.new(registry, actions, presets, _external_touch)
	osc.message_received.connect(osc_router.handle)

	api.registry = registry
	api.describe = func(p): return _describe(p, Lang.EN)
	api.presets = presets
	api.actions = ShowActions.LIST
	api.fire = actions.fire
	web.api_handler = api.handle
	web.client_connected.connect(_send_schema)
	web.set_requested.connect(_on_web_set)
	web.action_requested.connect(_on_web_action)
	web.launch_set_requested.connect(_on_web_launch_set)
	# A phone must see what the keyboard, OSC or the auto-pilot just did. The value
	# is noted here and sent once a frame rather than the moment it moves: a preset
	# crossfade and the auto-pilot both write every setting on every frame, and one
	# message per setting per frame is a few thousand a second down a wifi link to
	# a phone — which the phone then has to parse before it can draw anything.
	for p in registry.all():
		p.changed.connect(func(v): _pending_values[p.slug] = v)
		# A fader holding this setting is now lying about where it is: a preset
		# recall, the auto-pilot or a phone just moved it under the operator's hand.
		p.changed.connect(func(_v): midi.on_param_changed(p.slug))

	# The kick, offered to the auto-pilot. Connected rather than polled: a rising
	# edge read once a frame from here would be a beat missed on any frame the
	# envelope crossed and came back within.
	audio.beat.connect(_on_beat)

	console.setup(panel, show_viewport, lang, route_key)

	if Launch.spout_enabled:
		spout.start(show_viewport.get_texture())

	_refresh_status()

	# Asked for by a generator rather than by an operator: describe the show and
	# stand down without ever putting anything on screen.
	var wanted := _dump_path()
	if wanted != "":
		_dump(wanted)
		return

	# The operator's own window, where there are two screens to put one on. After the
	# dump path above, which must never put anything on screen at all; and deferred,
	# because a second window cannot join the tree while the first is still building
	# it, which is what `_ready()` is.
	if Launch.console_window:
		console.open.call_deferred()

	# A deliberate click hands the panel back, exactly like a keypress does.
	panel.mouse_reclaimed.connect(func(): panel.set_external_control(false, discreet_brightness))

	presets.registry = registry
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

	# Every door the MIDI surface can open is one another surface already had: the
	# settings by slug, and `ShowActions.fire()` for the one-shots. Nothing new to reach
	# means the Chataigne module still covers everything a profile can.
	midi.registry = registry
	midi.fire = actions.fire
	midi.touched = _external_touch
	midi.actions = ShowActions.LIST
	midi.preset_count = presets.SLOTS
	midi.surface_changed.connect(_refresh_status)
	midi.start()

	pad.connection_changed.connect(_refresh_status)
	# Wrapping the lookup catches every pad interaction in one place.
	pad.registry = registry
	pad.touched = _external_touch
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

	_section("section.blur")
	# One setting, and it is the exposure time. What a longer trail does to the look
	# is not a second decision to be made here: the strokes on screen already carry
	# their own speed, and the blur only says how long the eye is allowed to keep
	# them. A second slider for the strength of the ghost would be a second way of
	# saying the same thing, out of step with the first.
	_fn("blur/amount", 0, 1, 0.02, 0.0, blur.set_amount)

	_section("section.lasers")
	_fn("lasers/count", 0, 40, 1, laser_count, _set_laser_count)
	_fn("lasers/width", 1, 24, 0.5, 5.0, rig.set_width)
	_fn("lasers/length", 0.1, 2, 0.05, 1.0, rig.set_length)
	_fn("lasers/spin", -1, 1, 0.05, 1.0, rig.set_spin, true)
	_fn("lasers/parallel", 0, 1, 0.02, 0.0, rig.set_align)
	_fn("lasers/scroll", -1, 1, 0.02, 0.0, func(v): rig.scroll = v, true)

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
	# The shutter. Both default to the full circle, so no show that exists changes.
	_prop("spot/arcs", 1, 12, 1, 1.0, circle, "arcs")
	_prop("spot/length", 0.05, 1, 0.01, 1.0, circle, "arc_length")
	_prop("spot/spin", -1, 1, 0.05, 0.0, circle, "spin", true)
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
	# Not a multiplier like the four above: the sound does not scale a setting here,
	# it hits SHUFFLE. So this one is the chance that a kick rolls the show, and it
	# starts at 0 — a show saved before this existed comes up with the auto-pilot on
	# its own clock, the way it was left.
	_fn("audio/randomizer", 0, 1, 0.02, 0.0, func(v): _amounts["randomizer"] = v)

	_section("section.sphere")
	_prop("sphere/count", 0, 80, 1, 14.0, sphere, "circle_count")
	_prop("sphere/size", 0.03, 0.8, 0.01, 0.13, sphere, "circle_size")
	_prop("sphere/sides", 0, 12, 1, 0.0, sphere, "sides")
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
			"global/autodim", "audio/reactivity", "audio/randomizer",
			"color/saturation",
			"color/mode", "color/red", "color/green", "color/blue",
			"spot/track", "spot/handback"]:
		registry.find(slug).randomizable = false


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


func _append(p: VJParam):
	p.section = _current_section
	registry.add(p)


## One message a frame, carrying whatever moved in it. A fade that touches fifty
## settings therefore costs one message rather than fifty. The buffer is emptied
## even with nobody listening, so that a phone connecting later is not handed a
## backlog of values from a fade that finished minutes ago — it asks for the whole
## schema on connect anyway.
func _flush_values():
	if _pending_values.is_empty():
		return
	if web.has_clients():
		web.broadcast({"type": "values", "values": _pending_values})
	_pending_values = {}


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
	var surface: String = midi.surface()
	if surface != "":
		bits.append("midi  %s" % surface)
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
	circle.speed_scale = value
	sphere.speed_scale = value
	warp.speed_scale = value
	kaleido.speed_scale = value
	rig.set_speed(value)


func _set_chaos(value: float):
	circle.chaos = value
	sphere.chaos = value
	warp.chaos = value
	kaleido.chaos = value
	rig.set_chaos(value)


## HALO. No longer the post-process glow: each stroke draws its own wide, faint
## echo (see `halo.gd`). The setting keeps its name, its range and its OSC address —
## what changed is who does the work, not what the operator reaches for.
func _set_glow(value: float):
	circle.set_halo(value)
	sphere.halo_amount = value
	warp.halo_amount = value
	rig.set_halo(value)


func _set_laser_count(value: float):
	rig.set_count(int(value))


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


# --------------------------------------------------------------------------
# Audio reactivity
# --------------------------------------------------------------------------

func _set_reactivity(value: float):
	_react = value


## Scaled by REACTIVITY like every other amount, so the master still switches the
## whole of the sound response off in one move.
func _on_beat():
	autopilot.on_beat(_react * _amounts["randomizer"])


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
			"set": rig.draw_width},
		{"slug": "lasers/length", "band": MID, "amount": "lasers", "weight": 0.33,
			"set": rig.draw_length},
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
		var base: float = registry.find(m["slug"]).value
		var drive: float = _react * _amounts[m["amount"]] * bands[m["band"]]
		m["set"].call(base * (1.0 + drive * m["weight"]))


func _reset_modulations():
	for m in _modulations:
		m["set"].call(registry.find(m["slug"]).value)


# --------------------------------------------------------------------------
# Per-frame work
# --------------------------------------------------------------------------

func _process(delta: float):
	_apply_audio()
	_flush_values()

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

	rig.process(delta)


# --------------------------------------------------------------------------
# OSC (Chataigne, TouchOSC, or any other sender)
# --------------------------------------------------------------------------

## R key: back to random colours, with a fresh draw. This is the way out of manual
## mode, the one you find without thinking mid-set.
func _randomize_all():
	if _mode_param and palette.mode != Palette.RANDOM:
		_mode_param.set_value(Palette.RANDOM)
	circle.randomize_look()
	sphere.randomize_look()
	warp.randomize_look()
	rig.randomize_look()


# --------------------------------------------------------------------------
# Web control surface
# --------------------------------------------------------------------------

## The page builds itself entirely from this, so it cannot drift from the settings
## Godot actually has: a setting added in _build_params() simply shows up there.
func _send_schema():
	var described: Array = []
	for p in registry.all():
		# In the room's own tongue: this one is read by a person, not a program.
		described.append(_describe(p, lang.current))
	web.broadcast({
		"type": "schema",
		"params": described,
		"presets": {"used": presets.used_slots(), "count": presets.SLOTS},
		# Named rather than spelled out in the page: the buttons are built from this,
		# so an action added to `ShowActions.LIST` appears on every phone without touching
		# the HTML — the same way a setting does.
		"actions": ShowActions.LIST.map(func(a): return {
			"name": a, "label": lang.text("action." + a)}),
		"launch": launch_surface.describe(),
	})


func _on_web_launch_set(key: String, value: Variant):
	_external_touch()
	# A row can move another — Compatibility empties the antialiasing beside it — and
	# two phones on one show must not disagree about what the next start will be.
	if launch_surface.apply(key, value):
		_send_schema()


func _on_web_set(slug: String, value: float):
	_external_touch()
	var p := registry.find(slug)
	if p:
		p.set_value(value)


func _on_web_action(name: String):
	_external_touch()
	# Restarting is not a show action: it is not in `ShowActions.LIST`, it is not offered
	# over OSC, and it ends this process. It stays on the surface that has a button
	# for it, behind a confirmation.
	if name == "restart":
		_restart()
		return
	actions.fire(name)


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
	for p in registry.all():
		described.append(_describe(p, Lang.EN))
	var payload := {
		"osc_prefix": OscRouter.PREFIX,
		"params": described,
		"actions": ShowActions.LIST,
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
	route_key(event)


## Every key the show answers to, wherever it was typed.
##
## The keyboard goes to the window that has the focus, and with the console open
## there are two of them: the panel is in one, the show's nodes are in the other,
## and whichever the operator clicked last is the one the keys reach. Thus neither
## window handles keys of its own — both hand them here, and here decides. The panel
## gets first refusal, because its keys are the ones held down repeatedly.
func route_key(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if not (event is InputEventKey and event.pressed):
		return
	# Any key takes the wheel back from whatever external surface had it.
	panel.set_external_control(false, discreet_brightness)
	if panel.handle_key(event):
		return

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
			var p := registry.find("global/panel")
			var midpoint := (discreet_brightness + 1.0) * 0.5
			p.set_value(discreet_brightness if p.value > midpoint else 1.0)
		KEY_SPACE:
			circle.apply_glitch()
		KEY_R:
			_randomize_all()
		KEY_F4:
			# The projector that gets plugged in after the show has started, which
			# is most of them. Beside F2 and F3: the keys that change what the
			# operator sees rather than what the room sees.
			console.toggle()
		KEY_F11:
			var mode := DisplayServer.window_get_mode()
			if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

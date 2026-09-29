class_name WebBridge
extends RefCounted

## What the phones are told, and what they are allowed to ask for.
##
## `web_server.gd` speaks HTTP and WebSocket and knows nothing of the show. This is
## the other half: the schema the page builds itself from, the values that moved, the
## sound's levels, and the four things a phone can send back — a setting, an action,
## a start-up row and a restart.
##
## The controller supplies the two things it alone can do: getting the panel out of
## the way when somebody touches a surface, and rebuilding the description of the
## start-up rows when one moves another.

var _web: Node
var _registry: ParamRegistry
var _lang: Lang
var _presets: Node
var _launch: LaunchSurface
var _actions: ShowActions
var _modulation: AudioModulation
var _audio: Node
var _touched: Callable

## What moved since the last frame, slug -> value, waiting to go out in one message.
var _pending: Dictionary = {}
var _meter_tick: float = 0.0


func _init(web: Node, registry: ParamRegistry, lang: Lang, presets: Node,
		launch: LaunchSurface, actions: ShowActions, modulation: AudioModulation,
		audio: Node, touched: Callable):
	_web = web
	_registry = registry
	_lang = lang
	_presets = presets
	_launch = launch
	_actions = actions
	_modulation = modulation
	_audio = audio
	_touched = touched


func connect_surface():
	_web.client_connected.connect(send_schema)
	_web.set_requested.connect(_on_set)
	_web.action_requested.connect(_on_action)
	_web.launch_set_requested.connect(_on_launch_set)
	# A phone must see what the keyboard, OSC or the auto-pilot just did. The value
	# is noted here and sent once a frame rather than the moment it moves: a preset
	# crossfade and the auto-pilot both write every setting on every frame, and one
	# message per setting per frame is a few thousand a second down a wifi link to
	# a phone — which the phone then has to parse before it can draw anything.
	for p in _registry.all():
		p.changed.connect(func(v): _pending[p.slug] = v)


## Once a frame.
func process(delta: float):
	_flush_values()

	# The sound's levels go out on their own clock, not the frame's: twenty a second
	# while there is something to watch, one a second when there is not — a page that
	# just connected still has to be told the machine is deaf.
	_meter_tick += delta
	if _meter_tick > (0.05 if _audio.capturing else 1.0):
		_meter_tick = 0.0
		_broadcast_levels()


## The page builds itself entirely from this, so it cannot drift from the settings
## Godot actually has: a setting added in `_build_params()` simply shows up there.
func schema() -> Dictionary:
	var described: Array = []
	for p in _registry.all():
		# In the room's own tongue: this one is read by a person, not a program.
		described.append(p.describe(_lang.current))
	return {
		"type": "schema",
		"params": described,
		"presets": {"used": _presets.used_slots(), "count": _presets.SLOTS},
		# Named rather than spelled out in the page: the buttons are built from this,
		# so an action added to `ShowActions.LIST` appears on every phone without
		# touching the HTML — the same way a setting does.
		"actions": ShowActions.LIST.map(func(a): return {
			"name": a, "label": _lang.text("action." + a)}),
		"launch": _launch.describe(),
	}


func send_schema():
	_web.broadcast(schema())


## One message a frame, carrying whatever moved in it. A fade that touches fifty
## settings therefore costs one message rather than fifty. The buffer is emptied
## even with nobody listening, so that a phone connecting later is not handed a
## backlog of values from a fade that finished minutes ago — it asks for the whole
## schema on connect anyway.
func _flush_values():
	if _pending.is_empty():
		return
	if _web.has_clients():
		_web.broadcast({"type": "values", "values": _pending})
	_pending = {}


## The same three levels the status line draws, sent to the browsers.
##
## On a clock rather than from the `levels` signal: that one fires every frame, and
## sixty packets a second per phone is a lot of radio for a bar nobody can read
## faster than about twenty. The reactivity rides along so the page can make the
## same distinction the status line does — hearing nothing and not being turned up
## look identical otherwise.
func levels() -> Dictionary:
	return {
		"type": "audio",
		"capturing": _audio.capturing,
		"bass": _audio.bass,
		"mid": _audio.mid,
		"treble": _audio.treble,
		"silent": _audio.is_silent(),
		"reactivity": _modulation.react,
	}


func _broadcast_levels():
	if not _web.has_clients():
		return
	_web.broadcast(levels())


func _on_set(slug: String, value: float):
	_touched.call()
	var p := _registry.find(slug)
	if p:
		p.set_value(value)


func _on_action(name: String):
	_touched.call()
	# Restarting is not a show action: it is not in `ShowActions.LIST`, it is not
	# offered over OSC, and it ends this process. It stays on the surface that has a
	# button for it, behind a confirmation.
	if name == "restart":
		_restart()
		return
	_actions.fire(name)


func _on_launch_set(key: String, value: Variant):
	_touched.call()
	# A row can move another — Compatibility empties the antialiasing beside it — and
	# two phones on one show must not disagree about what the next start will be.
	if _launch.apply(key, value):
		send_schema()


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
		_web.broadcast({"type": "restart_failed"})

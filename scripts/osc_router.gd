class_name OscRouter
extends RefCounted

## What an OSC message means to the show: Chataigne, TouchOSC, or any other sender.
##
## `osc_server.gd` reads the bytes and knows nothing of the show. This is the other
## half: an address in, and a setting moved or an action fired out. Every setting is
## reachable at `/deferlante/<slug>`, and at `/deferlante/norm/<slug>` with 0..1
## spread over its range.

## Where OSC addresses and Chataigne callbacks are rooted.
const PREFIX := "/deferlante/"

var _registry: ParamRegistry
var _actions: ShowActions
var _presets: Node
## Told when a message moved something, so the panel can get out of the way.
var _touched: Callable
var _routes := {}


func _init(registry: ParamRegistry, actions: ShowActions, presets: Node, touched: Callable):
	_registry = registry
	_actions = actions
	_presets = presets
	_touched = touched
	for p in registry.all():
		_routes[PREFIX + p.slug] = p


func handle(address: String, args: Array):
	match address:
		PREFIX + "glitch_now":
			_actions.fire("glitch")
			return
		PREFIX + "randomize":
			_actions.fire("randomize")
			return
		PREFIX + "shuffle":
			_actions.fire("shuffle")
			return
	if address.begins_with(PREFIX + "shuffle/"):
		_touched.call()
		_actions.fire("shuffle:" + address.substr((PREFIX + "shuffle/").length()))
		return

	match address:
		PREFIX + "preset/recall":
			if not args.is_empty():
				_presets.recall(int(args[0]))
			return
		PREFIX + "preset/save":
			if not args.is_empty():
				_presets.save_slot(int(args[0]))
			return
		PREFIX + "color/rgb":
			# A colour picker sends its components in one go.
			if args.size() >= 3:
				_set_rgb(args)
			return

	if args.is_empty() or not (args[0] is float or args[0] is int):
		return
	var value := float(args[0])

	# Normalised form: /deferlante/norm/<address> takes 0..1 and spreads it over
	# the setting's range. For a MIDI fader or a touch surface that can only send
	# 0..1 without knowing each setting's bounds.
	var normalized := address.begins_with(PREFIX + "norm/")
	var key := address.replace("/norm/", "/") if normalized else address

	var p: VJParam = _routes.get(key)
	if p == null:
		return
	_touched.call()
	if normalized:
		value = lerpf(p.min_value, p.max_value, clampf(value, 0.0, 1.0))
	p.set_value(value)


func _set_rgb(args: Array):
	var names := ["color/red", "color/green", "color/blue"]
	for i in range(3):
		var p: VJParam = _routes.get(PREFIX + names[i])
		if p:
			p.set_value(float(args[i]))

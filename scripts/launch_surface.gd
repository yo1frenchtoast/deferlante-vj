class_name LaunchSurface
extends RefCounted

## The start-up settings as a phone sees them: described for the page, and changed
## from it.
##
## Kept out of the controller because none of it is about running a show. It reads
## and writes `Launch`, the file the launcher writes, and answers in the room's
## tongue. What the controller keeps is the two calls that need the show — touching
## the panel, and sending the schema again once a row has moved another.

var _lang: Lang
var _presets: Node
var _console: Node


func _init(lang: Lang, presets: Node, console: Node):
	_lang = lang
	_presets = presets
	_console = console


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
func describe() -> Dictionary:
	var resolutions: Array = [_lang.text("launch.resolution.native")]
	for i in range(1, Launch.RESOLUTIONS.size()):
		var r: Vector2i = Launch.RESOLUTIONS[i]
		resolutions.append("%d × %d" % [r.x, r.y])

	var rates: Array = [_lang.text("launch.maxfps.free")]
	for i in range(1, Launch.MAX_FPS.size()):
		rates.append(str(Launch.MAX_FPS[i]))

	var samples: Array = [_lang.text("launch.msaa.off")]
	for i in range(1, Launch.MSAA_SAMPLES.size()):
		samples.append("%d×" % Launch.MSAA_SAMPLES[i])

	# The same list the launcher offers, and the same re-check: an address saved
	# last night may not be one this machine still holds.
	var addresses: Array = [_lang.text("launch.access.local")]
	for a in Launch.local_addresses():
		addresses.append(a)

	return {
		"tab": _lang.text("launch.tab"),
		"restart": _lang.text("launch.restart.now"),
		"applies": _lang.text("launch.restart.applies"),
		"web_warning": _lang.text("launch.restart.web"),
		"failed": _lang.text("launch.restart.failed"),
		# Asked before the button is drawn, not after it is pressed: a control that
		# can never work is worse than a sentence saying so.
		"can_restart": Launch.can_relaunch(),
		"settings": [
			_choice("language", "launch.language", Lang.LANGUAGES, Lang.choice_of(Launch.language)),
			_choice("renderer", "launch.renderer", [
				_lang.text("launch.renderer.compat"), _lang.text("launch.renderer.forward"),
			], 1 if Launch.rendering_method == "forward_plus" else 0),
			# Offered against the renderer *chosen*, not the one running: the next
			# process is the one that will honour it, and it is the one being
			# configured here.
			_choice("msaa", "launch.msaa", samples,
				maxi(0, Launch.MSAA_SAMPLES.find(Launch.msaa)),
				"" if Launch.msaa_available() else _lang.text("launch.msaa.unavailable")),
			_choice("resolution", "launch.resolution", resolutions,
				maxi(0, Launch.RESOLUTIONS.find(Launch.resolution))),
			_toggle("fullscreen", "launch.fullscreen", Launch.fullscreen),
			_toggle("vsync", "launch.vsync", Launch.vsync),
			_choice("max_fps", "launch.maxfps", rates,
				maxi(0, Launch.MAX_FPS.find(Launch.max_fps))),
			_toggle("spout_enabled", "launch.spout", Launch.spout_enabled,
				_lang.text("launch.spout.on")),
			_toggle("hide_panel", "launch.panel", Launch.hide_panel,
				_lang.text("launch.panel.hidden")),
			# Offered with a note rather than left out where the platform has one
			# window only: a row that quietly vanishes on the phone is a row nobody
			# can find out about. The note is the page's way of saying "this one
			# cannot bite", which is why the hint the launcher prints is not passed
			# on here — a working row would come out looking like a dead one.
			_toggle("console_window", "launch.console", Launch.console_window,
				_lang.text("launch.console.on"),
				"" if _console.available() else _lang.text("launch.console.unavailable")),
			_choice("auto_start", "launch.autostart", _auto_start_choices(),
				clampi(Launch.auto_start, 0, _presets.SLOTS),
				_lang.text("launch.autostart.hint")),
			_choice("web_bind", "launch.access", addresses,
				maxi(0, addresses.find(Launch.web_bind))),
			_port("web_port", "launch.webport", Launch.web_port),
			_choice("osc_bind", "launch.oscaccess", addresses,
				maxi(0, addresses.find(Launch.osc_bind))),
			_port("osc_port", "launch.oscport", Launch.osc_port),
		],
	}


## The same nine rows the launcher offers, each saying whether it holds anything.
## Read live rather than from disk: this show has the slots in memory, and a slot
## saved from a phone a moment ago must appear here without a restart.
func _auto_start_choices() -> Array:
	var used: Array = _presets.used_slots()
	var choices: Array = [_lang.text("launch.autostart.none")]
	for i in range(1, _presets.SLOTS + 1):
		var key := "launch.autostart.slot" if used.has(i) else "launch.autostart.empty"
		choices.append(_lang.text(key) % i)
	return choices


func _choice(key: String, label_key: String, choices: Array, index: int,
		note: String = "") -> Dictionary:
	return {"key": key, "label": _lang.text(label_key), "type": "choice",
		"choices": choices, "value": index, "note": note}


## `caption` is the words beside the box rather than a warning under the row: the
## launcher writes PANNEAU ☐ masqué pour tout le set, and a bare switch labelled
## only PANNEAU would not say which way is which.
func _toggle(key: String, label_key: String, on: bool,
		caption: String = "", note: String = "") -> Dictionary:
	return {"key": key, "label": _lang.text(label_key), "type": "bool",
		"value": on, "caption": caption, "note": note}


func _port(key: String, label_key: String, port: int) -> Dictionary:
	return {"key": key, "label": _lang.text(label_key), "type": "int",
		"value": port, "min": 1024, "max": 65535, "note": ""}


## A start-up setting, changed from the web surface.
##
## Written straight to disk. The tab is a way to set up the next start from across
## the room — often from the sofa, minutes before the room fills — and a value that
## only lived until the process ended would be exactly the wrong promise.
##
## Nothing here touches the running show. Every one of these is a setting Godot
## fixes before a script runs, or binds before anything can listen; that is the
## reason they are start-up settings at all.
func apply(key: String, value: Variant) -> bool:
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
		"spout_enabled":
			Launch.spout_enabled = bool(value)
		"hide_panel":
			Launch.hide_panel = bool(value)
		"console_window":
			Launch.console_window = bool(value)
		"auto_start":
			Launch.auto_start = clampi(index, 0, _presets.SLOTS)
		"web_bind":
			Launch.web_bind = _address(index)
		"osc_bind":
			Launch.osc_bind = _address(index)
		"web_port":
			Launch.web_port = clampi(index, 1024, 65535)
		"osc_port":
			Launch.osc_port = clampi(index, 1024, 65535)
		_:
			return false
	Launch.save()
	return true


## The address behind an index in the list `describe()` offered. Out of range reads
## as loopback rather than as the nearest guess: a stale index should narrow what
## can reach the show, never widen it.
func _address(index: int) -> String:
	if index <= 0:
		return Launch.LOCAL
	var addresses := Launch.local_addresses()
	return addresses[index - 1] if index - 1 < addresses.size() else Launch.LOCAL

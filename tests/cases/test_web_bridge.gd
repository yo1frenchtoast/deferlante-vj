extends TestCase

const NEEDS_SHOW := false


class Web extends Node:
	signal client_connected
	signal set_requested(slug: String, value: float)
	signal action_requested(name: String)
	signal launch_set_requested(key: String, value: Variant)
	var sent: Array = []
	var clients := true

	func broadcast(payload: Dictionary):
		sent.append(payload)

	func has_clients() -> bool:
		return clients


class FakePresets extends Node:
	const SLOTS := 9

	func used_slots() -> Array:
		return [1, 3]


class Console extends Node:
	func available() -> bool:
		return true


class Ear extends Node:
	var capturing := true
	var bass := 0.5
	var mid := 0.25
	var treble := 0.125

	func is_silent() -> bool:
		return false


class Spy extends Node:
	var calls: Array = []

	func apply_glitch():
		calls.append("glitch")

	func set_line_width(_v: float):
		pass

	func roll_now(section: String = ""):
		calls.append("roll:" + section)


var web: Web
var registry: ParamRegistry
var bridge: WebBridge
var touches := 0
var applied := []
var spy: Spy


func _setup():
	web = Web.new()
	registry = ParamRegistry.new()
	var lang := Lang.new()
	lang.set_language(Lang.EN)
	var p := VJParam.new("global/speed", -3, 3, 0.05, 1.0, func(v): applied.append(v))
	p.section = "section.global"
	p.use_language(lang)
	registry.add(p)
	var presets := FakePresets.new()
	spy = Spy.new()
	var actions := ShowActions.new(spy, spy, presets, func(): pass)
	var modulation := AudioModulation.new(registry, Ear.new(),
		LaserRig.new(null, null, null, func(): return Vector2.ZERO), spy, spy, spy)
	touches = 0
	var launch := LaunchSurface.new(lang, presets, Console.new())
	bridge = WebBridge.new(web, registry, lang, presets, launch, actions, modulation,
		Ear.new(), func(): touches += 1)
	bridge.connect_surface()
	# Held by the case: a Callable does not keep a RefCounted alive.
	_keep = [launch, actions, modulation]


var _keep: Array


func test_the_schema_is_what_the_page_builds_from():
	_setup()
	var schema := bridge.schema()
	same(schema["type"], "schema", "typed")
	same(schema["params"].size(), 1, "one entry per setting")
	same(schema["params"][0]["slug"], "global/speed", "by slug")
	same(schema["presets"], {"used": [1, 3], "count": 9}, "with the slots")
	same(schema["actions"].map(func(a): return a["name"]), Array(ShowActions.LIST), "and the actions")
	check(schema["launch"]["settings"].size() > 0, "and the start-up tab")


func test_a_connecting_phone_is_sent_the_schema():
	_setup()
	web.client_connected.emit()
	same(web.sent.size(), 1, "one message")
	same(web.sent[0]["type"], "schema", "which is the schema")


func test_values_go_out_once_a_frame():
	_setup()
	var p := registry.find("global/speed")
	p.set_value(1.5)
	p.set_value(2.0)
	bridge.process(0.016)
	var values := web.sent.filter(func(m): return m["type"] == "values")
	same(values.size(), 1, "two moves, one message")
	same(values[0]["values"], {"global/speed": 2.0}, "carrying the latest")
	web.sent.clear()
	bridge.process(0.016)
	same(web.sent.filter(func(m): return m["type"] == "values").size(), 0, "and nothing when nothing moved")


func test_nothing_is_kept_for_a_phone_that_is_not_there():
	_setup()
	web.clients = false
	registry.find("global/speed").set_value(2.0)
	bridge.process(0.016)
	web.clients = true
	bridge.process(0.016)
	same(web.sent.filter(func(m): return m["type"] == "values").size(), 0, "no backlog")


func test_a_phone_moves_a_setting_and_an_action():
	_setup()
	web.set_requested.emit("global/speed", 2.5)
	same(registry.find("global/speed").value, 2.5, "the setting moved")
	web.set_requested.emit("no/such", 1.0)
	web.action_requested.emit("glitch")
	same(spy.calls, ["glitch"], "the action fired")
	same(touches, 3, "and each request got the panel out of the way")


func test_levels_carry_the_meter_and_the_master():
	_setup()
	var levels := bridge.levels()
	same([levels["bass"], levels["mid"], levels["treble"]], [0.5, 0.25, 0.125], "the bands")
	same(levels["reactivity"], 0.0, "the master, so the page can tell deaf from turned down")

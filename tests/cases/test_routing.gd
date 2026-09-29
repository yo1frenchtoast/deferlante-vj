extends TestCase

const NEEDS_SHOW := false


## Stands in for the circle, the auto-pilot and the presets, and writes down what it
## was asked.
class Spy extends Node:
	var calls: Array = []

	func apply_glitch():
		calls.append("glitch")

	func roll_now(section: String = ""):
		calls.append("roll:" + section)

	func recall(slot: int, _instant: bool = false):
		calls.append("recall:%d" % slot)

	func save_slot(slot: int):
		calls.append("save:%d" % slot)


var spy: Spy
var touches: Array
var registry: ParamRegistry
var value_seen := []
var actions: ShowActions
var router: OscRouter


func _setup():
	spy = Spy.new()
	touches = []
	value_seen = []
	registry = ParamRegistry.new()
	var p := VJParam.new("global/speed", -3, 3, 0.05, 1.0, func(v): value_seen.append(v))
	registry.add(p)
	for slug in ["color/red", "color/green", "color/blue"]:
		registry.add(VJParam.new(slug, 0, 1, 0.02, 0.0, func(_v): pass))
	actions = ShowActions.new(spy, spy, spy, func(): spy.calls.append("randomize"))
	router = OscRouter.new(registry, actions, spy, func(): touches.append(1))


func test_actions_reach_their_targets():
	_setup()
	check(actions.fire("glitch"), "glitch")
	check(actions.fire("randomize"), "randomize")
	check(actions.fire("shuffle"), "shuffle")
	check(actions.fire("shuffle:lasers"), "shuffle a section")
	check(actions.fire("preset:recall:3"), "recall")
	check(actions.fire("preset:save:4"), "save")
	same(spy.calls, ["glitch", "randomize", "roll:", "roll:lasers", "recall:3", "save:4"], "in order")


func test_actions_refuse_what_they_do_not_know():
	_setup()
	check(not actions.fire("nonsense"), "unknown")
	check(not actions.fire("preset:recall"), "a preset with no slot")
	check(not actions.fire("glitch:now"), "a suffix on a plain action")
	same(spy.calls, [], "nothing was fired")


func test_osc_addresses_fire_actions():
	_setup()
	router.handle("/deferlante/glitch_now", [])
	router.handle("/deferlante/randomize", [])
	router.handle("/deferlante/shuffle", [])
	router.handle("/deferlante/shuffle/spot", [])
	same(spy.calls, ["glitch", "randomize", "roll:", "roll:spot"], "one action per address")
	same(touches.size(), 1, "only the sectioned shuffle touches the panel")


func test_osc_presets():
	_setup()
	router.handle("/deferlante/preset/recall", [2])
	router.handle("/deferlante/preset/save", [5.0])
	router.handle("/deferlante/preset/recall", [])
	same(spy.calls, ["recall:2", "save:5"], "the argument is the slot, and none means nothing")


func test_osc_moves_a_setting_and_touches_the_panel():
	_setup()
	router.handle("/deferlante/global/speed", [2.5])
	same(registry.find("global/speed").value, 2.5, "the value")
	same(touches.size(), 1, "and the panel is told")
	router.handle("/deferlante/norm/global/speed", [1.0])
	same(registry.find("global/speed").value, 3.0, "normalised, at the top")
	router.handle("/deferlante/nowhere", [1.0])
	router.handle("/deferlante/global/speed", ["x"])
	same(touches.size(), 2, "a message that moved nothing touches nothing")


func test_osc_rgb():
	_setup()
	router.handle("/deferlante/color/rgb", [0.2, 0.4, 0.6])
	same([registry.find("color/red").value, registry.find("color/blue").value], [0.2, 0.6], "three at once")

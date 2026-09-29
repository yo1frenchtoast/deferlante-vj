extends TestCase

const NEEDS_SHOW := false

var registry: ParamRegistry
var map: MidiMap
var fired: Array
var touches: int


func _setup(controls: Array):
	registry = ParamRegistry.new()
	for slug in ["global/speed", "global/chaos"]:
		registry.add(VJParam.new(slug, 0, 100, 1, 50.0, func(_v): pass))
	for slug in ["color/red", "color/green", "color/blue"]:
		registry.add(VJParam.new(slug, 0, 1, 0.01, 0.0, func(_v): pass))
	fired = []
	touches = 0
	map = MidiMap.new()
	map.registry = registry
	map.fire = func(name): fired.append(name)
	map.touched = func(): touches += 1
	map.actions = ShowActions.LIST
	map.preset_count = 9
	map.index(controls)


func _speed() -> float:
	return registry.find("global/speed").value


func _fader() -> Array:
	return [{"cc": 1, "target": "global/speed", "mode": "norm", "label": "F1"}]


func test_a_fader_writes_only_once_it_has_met_the_setting():
	_setup(_fader())
	map.on_cc(1, 0)
	same(_speed(), 50.0, "far away: read, not obeyed")
	map.on_cc(1, 20)
	same(_speed(), 50.0, "still short")
	map.on_cc(1, 80)
	check(_speed() != 50.0, "it crossed the value, and now has it")
	map.on_cc(1, 127)
	same(_speed(), 100.0, "from then on it follows")


func test_a_fader_already_there_takes_over_at_once():
	_setup(_fader())
	map.on_cc(1, 64)
	check(absf(_speed() - 50.4) < 0.6, "within a step of the setting, it writes")


func test_something_else_moving_the_setting_disarms_the_fader():
	_setup(_fader())
	map.on_cc(1, 64)
	map.on_cc(1, 127)
	same(_speed(), 100.0, "armed and following")
	registry.find("global/speed").set_value(10.0)
	map.on_param_changed("global/speed")
	map.on_cc(1, 127)
	same(_speed(), 10.0, "a preset recall must not be undone by a fader that is lying")


func test_our_own_writes_do_not_disarm():
	_setup(_fader())
	map.on_cc(1, 64)
	registry.find("global/speed").changed.connect(func(_v): map.on_param_changed("global/speed"))
	map.on_cc(1, 100)
	map.on_cc(1, 120)
	check(_speed() > 90.0, "still armed after its own writes")


func test_relative_encoder_ticks():
	_setup([{"cc": 2, "target": "global/speed", "mode": "relative", "label": "E"}])
	map.on_cc(2, 3)
	same(_speed(), 53.0, "clockwise")
	map.on_cc(2, 125)
	same(_speed(), 50.0, "two's complement, back three")


func test_an_action_fires_and_touches_the_panel():
	_setup([{"note": 60, "target": "glitch", "mode": "action", "label": "G"}])
	map.on_note_on(60)
	same(fired, ["glitch"], "fired")
	same(touches, 1, "and the panel is told")
	map.on_note_off(60)
	same(fired.size(), 1, "release does nothing")


func test_a_toggle_alternates_between_its_value_and_the_minimum():
	_setup([{"note": 61, "target": "global/chaos", "mode": "toggle", "value": 80, "label": "T"}])
	map.on_note_on(61)
	same(registry.find("global/chaos").value, 80.0, "on")
	map.on_note_on(61)
	same(registry.find("global/chaos").value, 0.0, "off is the bottom of the range")


func test_a_set_writes_its_value():
	_setup([{"note": 62, "target": "global/chaos", "mode": "set", "value": 30, "label": "S"}])
	map.on_note_on(62)
	same(registry.find("global/chaos").value, 30.0, "set")


func test_momentary_puts_back_what_was_there_when_the_last_finger_lifts():
	_setup([
		{"note": 63, "target": "global/speed", "mode": "momentary", "value": 0, "label": "FREEZE"},
		{"note": 64, "target": "global/speed", "mode": "momentary", "value": 100, "label": "BOOST"},
	])
	map.on_note_on(63)
	same(_speed(), 0.0, "frozen")
	map.on_note_on(64)
	same(_speed(), 100.0, "boosted over it")
	map.on_note_off(63)
	same(_speed(), 100.0, "one finger still down")
	map.on_note_off(64)
	same(_speed(), 50.0, "back to what it was before the first")


func test_rgb_writes_three_channels():
	_setup([{"note": 65, "target": "color/rgb", "mode": "rgb", "value": [0.1, 0.2, 0.3], "label": "C"}])
	map.on_note_on(65)
	same([registry.find("color/red").value, registry.find("color/blue").value], [0.1, 0.3], "one pad, three values")


func test_a_hold_fires_only_if_still_down():
	_setup([{"note": 66, "target": "shuffle", "mode": "hold", "hold_ms": 20, "label": "H"}])
	map.on_note_on(66)
	map.on_note_off(66)
	await Engine.get_main_loop().create_timer(0.08).timeout
	same(fired, [], "let go early: a brush past the pad does nothing")
	map.on_note_on(66)
	await Engine.get_main_loop().create_timer(0.08).timeout
	same(fired, ["shuffle"], "held long enough")


func test_latching_buttons_act_on_every_press_and_follow_their_state():
	_setup([
		{"cc": 10, "target": "glitch", "mode": "action", "latching": true, "label": "A"},
		{"cc": 11, "target": "global/chaos", "mode": "toggle", "value": 60, "latching": true, "label": "T"},
	])
	map.on_cc(10, 127)
	map.on_cc(10, 0)
	same(fired, ["glitch", "glitch"], "a one-shot on a latching button fires on every message")
	map.on_cc(11, 127)
	same(registry.find("global/chaos").value, 60.0, "on with the lamp")
	map.on_cc(11, 0)
	same(registry.find("global/chaos").value, 0.0, "off with the lamp")


func test_a_button_on_a_cc_springs():
	_setup([{"cc": 12, "target": "glitch", "mode": "action", "label": "A"}])
	map.on_cc(12, 127)
	map.on_cc(12, 0)
	same(fired, ["glitch"], "pressed once, let go once")


func test_the_profile_is_refused_line_by_line():
	_setup([
		{"cc": 1, "target": "global/speed", "mode": "norm", "label": "ok"},
		{"cc": 1, "target": "global/chaos", "mode": "norm", "label": "dup"},
		{"cc": 2, "target": "nowhere/none", "mode": "norm", "label": "typo"},
		{"note": 5, "target": "global/speed", "mode": "norm", "label": "fader on a note"},
		{"note": 6, "target": "global/speed", "mode": "set", "label": "no value"},
		{"note": 7, "target": "global/speed", "mode": "wobble", "label": "no such mode"},
		{"target": "glitch", "mode": "action", "label": "nowhere"},
		{"note": 8, "target": "shuffle:global", "mode": "action", "label": "section"},
		{"note": 9, "target": "preset:recall:9", "mode": "action", "label": "slot"},
		{"note": 10, "target": "preset:recall:10", "mode": "action", "label": "past the slots"},
	])
	same(map.size(), 3, "only the three good lines stand")


func test_the_checker_and_the_map_agree_on_the_modes():
	# tools/build_midi_map.py keeps its own copy of the two lists, because it runs
	# without Godot. Two copies drift; this is what says so.
	var source := FileAccess.get_file_as_string("res://tools/build_midi_map.py")
	for name in ["MODES", "NEEDS_VALUE"]:
		var found := RegEx.create_from_string("(?m)^%s = \\[(.*)\\]" % name).search(source)
		check(found != null, "%s is in the checker" % name)
		if found == null:
			continue
		var theirs := found.get_string(1).replace('"', "").replace(" ", "").split(",")
		var ours: Array = MidiControl.MODES if name == "MODES" else MidiControl.NEEDS_VALUE
		same(Array(theirs), ours, "%s" % name)

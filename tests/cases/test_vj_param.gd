extends TestCase

const NEEDS_SHOW := false


func _param(mn := 0.0, mx := 10.0, step := 0.5, signed := false) -> VJParam:
	return VJParam.new("test/x", mn, mx, step, mn, func(_v): pass, signed)


func test_clamps_to_the_bounds():
	var p := _param()
	p.set_value(99.0)
	same(p.value, 10.0, "above the range")
	p.set_value(-5.0)
	same(p.value, 0.0, "below the range")


func test_snaps_to_the_step():
	var p := _param(0.0, 10.0, 0.5)
	p.set_value(3.3)
	same(p.value, 3.5, "3.3 snaps to the nearest half")


func test_applies_and_announces():
	var seen := []
	var heard := []
	var p := VJParam.new("test/x", 0, 1, 0.1, 0.0, func(v): seen.append(v))
	p.changed.connect(func(v): heard.append(v))
	p.set_value(0.5)
	same(seen, [0.5], "the effect was written once")
	same(heard, [0.5], "the change was announced once")


func test_apply_current_does_not_announce():
	var heard := []
	var seen := []
	var p := VJParam.new("test/x", 0, 1, 0.1, 0.4, func(v): seen.append(v))
	p.changed.connect(func(v): heard.append(v))
	p.apply_current()
	same(seen, [0.4], "the default reaches the effect")
	same(heard, [], "and nobody is told it moved")


func test_nudge():
	var p := _param(0.0, 40.0, 0.5)
	p.set_value(20.0)
	p.nudge(1, false)
	same(p.value, 21.0, "a coarse nudge is a fortieth of the range")
	p.nudge(-1, true)
	same(p.value, 20.5, "a fine nudge is one step")


func test_formatting():
	same(_param(0, 10, 1).format_value(), "0", "whole steps show no decimals")
	same(_param(0, 1, 0.02).format_value(), "0.00", "hundredths")
	same(_param(0, 1, 0.001).format_value(), "0.000", "thousandths")
	var s := _param(-1, 1, 0.05, true)
	s.set_value(0.5)
	same(s.format_value(), "→ 0.50", "signed, forward")
	s.set_value(-0.5)
	same(s.format_value(), "← 0.50", "signed, backward")
	s.set_value(0.0)
	same(s.format_value(), "·  0.00", "signed, still")


func test_choices_show_names():
	var p := _param(0, 1, 1)
	p.choices = PackedStringArray(["off", "on"])
	p.translate_choices = false
	p.set_value(1.0)
	same(p.format_value(), "on", "the name, not the number")

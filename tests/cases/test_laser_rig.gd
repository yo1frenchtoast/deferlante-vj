extends TestCase

const NEEDS_SHOW := false


func _rig() -> Array:
	var parent := Node2D.new()
	Engine.get_main_loop().root.add_child(parent)
	var rig := LaserRig.new(load("res://scenes/laser.tscn"), parent, Palette.new(),
		func(): return Vector2(1000, 500))
	return [rig, parent]


func test_count_grows_and_shrinks_and_spaces_the_fan():
	var made := _rig()
	var rig: LaserRig = made[0]
	rig.set_count(4)
	same(rig.lasers.size(), 4, "grown")
	same(rig.lasers[2].slot, 0.5, "spread evenly across the fan")
	rig.set_count(1)
	same(rig.lasers.size(), 1, "shrunk")
	same(rig.lasers[0].slot, 0.0, "one stroke sits at the start")
	made[1].free()


func test_a_late_stroke_looks_like_the_others():
	var made := _rig()
	var rig: LaserRig = made[0]
	rig.set_count(1)
	rig.set_width(12.0)
	rig.set_speed(2.0)
	rig.set_count(2)
	same(rig.lasers[1].width, 12.0, "width")
	same(rig.lasers[1].speed_scale, 2.0, "speed")
	made[1].free()


func test_sound_leans_on_the_drawing_not_the_setting():
	var made := _rig()
	var rig: LaserRig = made[0]
	rig.set_count(1)
	rig.set_width(5.0)
	rig.draw_width(9.0)
	same(rig.lasers[0].width, 9.0, "what is drawn")
	same(rig.width, 5.0, "what the setting says")
	rig.set_count(2)
	same(rig.lasers[1].width, 5.0, "and a new stroke starts from the setting")
	made[1].free()


func test_the_fan_only_turns_when_parallel():
	var made := _rig()
	var rig: LaserRig = made[0]
	rig.set_count(1)
	rig.process(1.0)
	same(rig.lasers[0].align_angle, 0.0, "not parallel, not turning")
	rig.set_align(1.0)
	rig.process(1.0)
	check(rig.lasers[0].align_angle != 0.0, "parallel, turning")
	made[1].free()

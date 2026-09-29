extends TestCase

const NEEDS_SHOW := false


class Ear extends Node:
	var capturing := true
	var bass := 0.0
	var mid := 0.0
	var treble := 0.0


class Circle extends Node:
	var base_radius := 0.0
	var width := 0.0

	func set_line_width(v: float):
		width = v


class Sphere extends Node:
	var line_width := 0.0
	var circle_size := 0.0


class Warp extends Node:
	var approach := 0.0
	var line_width := 0.0


var registry: ParamRegistry
var ear: Ear
var circle: Circle
var sphere: Sphere
var warp: Warp
var mod: AudioModulation


func _setup():
	registry = ParamRegistry.new()
	for slug in ["lasers/width", "lasers/length", "spot/width", "spot/radius",
			"sphere/width", "sphere/size", "warp/speed", "warp/width"]:
		registry.add(VJParam.new(slug, 0, 100, 1, 10.0, func(_v): pass))
	ear = Ear.new()
	circle = Circle.new()
	sphere = Sphere.new()
	warp = Warp.new()
	var rig := LaserRig.new(null, null, null, func(): return Vector2.ZERO)
	mod = AudioModulation.new(registry, ear, rig, circle, sphere, warp)


func test_silent_master_moves_nothing():
	_setup()
	ear.bass = 1.0
	mod.apply()
	same(circle.base_radius, 0.0, "reactivity 0 leaves the effect alone")


func test_each_effect_follows_its_own_band():
	_setup()
	mod.react = 1.0
	ear.bass = 1.0
	mod.apply()
	same(circle.width, 10.0 * (1.0 + 2.5), "the spotlight takes the bass")
	same(sphere.line_width, 10.0, "the sphere, on the treble, stays put")
	ear.bass = 0.0
	ear.treble = 1.0
	mod.apply()
	same(sphere.line_width, 10.0 * (1.0 + 2.5), "the sphere takes the treble")


func test_a_third_of_the_weight_for_size():
	_setup()
	mod.react = 1.0
	ear.bass = 1.0
	mod.apply()
	same(snappedf(circle.base_radius, 0.001), snappedf(10.0 * (1.0 + 2.5 * 0.33), 0.001), "radius")


func test_letting_go_restores_the_base():
	_setup()
	mod.react = 1.0
	ear.bass = 1.0
	mod.apply()
	mod.react = 0.0
	mod.apply()
	same(circle.width, 10.0, "back to what the setting says")
	same(warp.approach, 10.0, "for every target")


func test_the_beat_chance_is_scaled_by_the_master():
	_setup()
	mod.amounts["randomizer"] = 0.5
	same(mod.beat_chance(), 0.0, "master at zero")
	mod.react = 0.5
	same(mod.beat_chance(), 0.25, "half of half")


class Aberration extends Node:
	var drawn := -1.0

	func draw_amount(v: float):
		drawn = v


## The same show with the aberration wired in: it needs a setting to read its base from.
func _setup_with_aberration() -> Aberration:
	_setup()
	registry.add(VJParam.new("fx/aberration", 0, 1, 0.02, 0.0, func(_v): pass))
	var aberration := Aberration.new()
	var rig := LaserRig.new(null, null, null, func(): return Vector2.ZERO)
	mod = AudioModulation.new(registry, ear, rig, circle, sphere, warp, aberration)
	return aberration


func test_the_kick_lifts_the_aberration_from_zero():
	var aberration := _setup_with_aberration()
	mod.react = 1.0
	mod.amounts["aberration"] = 2.5
	ear.bass = 1.0
	mod.apply()
	check(is_equal_approx(aberration.drawn, 0.5), "added to a setting at 0: a full hit is half strength")
	ear.bass = 0.0
	mod.apply()
	same(aberration.drawn, 0.0, "and it closes again when the hit is gone")


func test_the_aberration_adds_to_the_setting_where_the_others_multiply():
	var aberration := _setup_with_aberration()
	registry.find("fx/aberration").set_value(0.2)
	mod.react = 1.0
	mod.amounts["aberration"] = 2.5
	ear.bass = 1.0
	mod.apply()
	check(is_equal_approx(aberration.drawn, 0.7), "0.2 and a full hit make 0.7, not 0.2 times something")


func test_the_aberration_is_off_until_its_amount_is_turned_up():
	var aberration := _setup_with_aberration()
	mod.react = 1.0
	ear.bass = 1.0
	same(mod.amounts["aberration"], 0.0, "a show that already had REACTIVITY up sees no new fringes")
	mod.apply()
	same(aberration.drawn, 0.0, "nothing is drawn")


func test_letting_go_puts_the_aberration_back_to_its_setting():
	var aberration := _setup_with_aberration()
	registry.find("fx/aberration").set_value(0.3)
	mod.react = 1.0
	mod.amounts["aberration"] = 2.5
	ear.bass = 1.0
	mod.apply()
	mod.react = 0.0
	mod.apply()
	check(is_equal_approx(aberration.drawn, 0.3), "the slider says 0.3, and that is what is drawn again")


class Slices extends Node:
	var drawn := -1.0

	func draw_amount(v: float):
		drawn = v


func _setup_with_slices() -> Slices:
	_setup()
	registry.add(VJParam.new("fx/slice", 0, 1, 0.02, 0.0, func(_v): pass))
	var slices := Slices.new()
	var rig := LaserRig.new(null, null, null, func(): return Vector2.ZERO)
	mod = AudioModulation.new(registry, ear, rig, circle, sphere, warp, null, slices)
	return slices


func test_the_kick_tears_the_picture_from_zero():
	var slices := _setup_with_slices()
	mod.react = 1.0
	mod.amounts["slice"] = 2.0
	ear.bass = 1.0
	mod.apply()
	check(is_equal_approx(slices.drawn, 0.5), "added to a setting at 0: a full hit at 2 is half strength")
	ear.bass = 0.0
	mod.apply()
	same(slices.drawn, 0.0, "and it settles when the hit is gone")


func test_the_slices_are_off_until_their_amount_is_turned_up():
	var slices := _setup_with_slices()
	mod.react = 1.0
	ear.bass = 1.0
	same(mod.amounts["slice"], 0.0, "a show that already had REACTIVITY up sees no tearing")
	mod.apply()
	same(slices.drawn, 0.0, "nothing is drawn")


func test_letting_go_puts_the_slices_back_to_their_setting():
	var slices := _setup_with_slices()
	registry.find("fx/slice").set_value(0.3)
	mod.react = 1.0
	mod.amounts["slice"] = 2.0
	ear.bass = 1.0
	mod.apply()
	mod.react = 0.0
	mod.apply()
	check(is_equal_approx(slices.drawn, 0.3), "back to what the slider says")

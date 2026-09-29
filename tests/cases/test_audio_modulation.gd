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

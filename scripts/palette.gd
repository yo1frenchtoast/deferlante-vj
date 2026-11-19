class_name Palette
extends RefCounted

## The show's colour state, shared by the lasers, the spotlight and the sphere.
##
## It is a single object everyone references, not a value copied into each effect:
## changing the saturation here changes it everywhere, and a laser spawned mid-set is
## already up to date because it points at the same object.
##
## Three modes coexist without treading on each other: in random mode every element
## keeps the hue it drew for itself, which the R key redraws; in manual mode they all
## take the chosen colour; in cycle mode, which sits between the two, they all take
## one colour that travels round the hue wheel. Switching between them destroys nothing — the random hues are kept
## and reappear on the way back, and the cycle picks up where it left off.

signal changed

## In the order of the MODE setting: cycle in the middle, between drawing a hue for
## each element and choosing one by hand.
enum { RANDOM, CYCLE, MANUAL }

## Turns of the hue wheel per second at CYCLE SPEED 1: one every four seconds.
const CYCLE_TURNS := 0.25

var saturation: float = 0.7
var mode: int = RANDOM
var manual: Color = Color(1.0, 0.25, 0.1)
## Speed of the cycle, 0..1. 0 holds the colour where it is.
var cycle_speed: float = 0.2
## Where the cycle is on the hue wheel, 0..1.
var cycle_hue: float = 0.0


## `hue` is only read in random mode; in manual mode `manual` decides, in cycle mode
## the hue the cycle has reached.
## In both cases saturation pulls towards white, which keeps the setting useful when
## projecting: a beam close to white cuts through haze better than a saturated one.
func resolve(hue: float) -> Color:
	if mode == MANUAL:
		return manual.lerp(Color.WHITE, 1.0 - saturation)
	if mode == CYCLE:
		return Color.from_hsv(cycle_hue, saturation, 1.0)
	# Value forced to 1: under additive blending a dark colour simply does not show.
	return Color.from_hsv(hue, saturation, 1.0)


## Moves the cycle on. Only in cycle mode, and only then does it tell the effects
## that hold their colour until told (lasers, spotlight) to pick it up again.
func advance(delta: float):
	if mode != CYCLE or cycle_speed <= 0.0:
		return
	cycle_hue = fposmod(cycle_hue + delta * cycle_speed * CYCLE_TURNS, 1.0)
	changed.emit()


func set_saturation(value: float):
	saturation = value
	changed.emit()


func set_mode(value: int):
	mode = value
	changed.emit()


func set_channel(index: int, value: float):
	match index:
		0: manual.r = value
		1: manual.g = value
		2: manual.b = value
	changed.emit()

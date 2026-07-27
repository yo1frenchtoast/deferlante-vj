class_name Palette
extends RefCounted

## The show's colour state, shared by the lasers, the spotlight and the sphere.
##
## It is a single object everyone references, not a value copied into each effect:
## changing the saturation here changes it everywhere, and a laser spawned mid-set is
## already up to date because it points at the same object.
##
## Two modes coexist without treading on each other: in random mode every element
## keeps the hue it drew for itself, which the R key redraws; in manual mode they all
## take the chosen colour. Switching between them destroys nothing — the random hues
## are kept and reappear on the way back.

signal changed

enum { RANDOM, MANUAL }

var saturation: float = 0.7
var mode: int = RANDOM
var manual: Color = Color(1.0, 0.25, 0.1)


## `hue` is only read in random mode; in manual mode `manual` decides.
## In both cases saturation pulls towards white, which keeps the setting useful when
## projecting: a beam close to white cuts through haze better than a saturated one.
func resolve(hue: float) -> Color:
	if mode == MANUAL:
		return manual.lerp(Color.WHITE, 1.0 - saturation)
	# Value forced to 1: under additive blending a dark colour simply does not show.
	return Color.from_hsv(hue, saturation, 1.0)


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

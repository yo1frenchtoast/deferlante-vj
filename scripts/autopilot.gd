extends Node

## Moves the settings on its own, so a scene evolves without a hand on it.
##
## It does not replace an operator: it picks one or two settings and puts them down
## somewhere else, at a pace set by its own value. Kept out of the controller for
## the same reason as the REST API — none of it is about what the visuals *are*,
## only about nudging them, and the controller reads better without it.

## Set by the controller.
var all_params: Callable
var randomize_colours: Callable
var palette: Palette

var amount: float = 0.0

var _next_roll: float = 0.0


func set_amount(value: float):
	amount = value
	_next_roll = _interval()


## One change every twelve seconds at the bottom of the range, one a second at the
## top. Below 12 s apart the scene never settles enough to be looked at.
func _interval() -> float:
	return lerpf(12.0, 1.0, amount)


func _process(delta: float):
	if amount <= 0.0:
		return
	_next_roll -= delta
	if _next_roll > 0.0:
		return
	_next_roll = _interval()
	_roll()


func _roll():
	if not all_params.is_valid():
		return
	var candidates: Array = []
	for p in all_params.call():
		if p.randomizable:
			candidates.append(p)
	if candidates.is_empty():
		return

	# One or two at a time: beyond that it stops reading as a gesture and starts
	# reading as a malfunction.
	for i in range(randi_range(1, 2)):
		var p: VJParam = candidates.pick_random()
		# Averaging two draws clusters values towards the middle of the range, so
		# we avoid the extremes that either empty or saturate the screen.
		var t := (randf() + randf()) * 0.5
		p.set_value(lerpf(p.min_value, p.max_value, t))

	# Every so often, fresh colours too — but only if they are in random mode,
	# otherwise we would trample a manual choice.
	if palette and palette.mode == Palette.RANDOM and randf() < 0.25:
		randomize_colours.call()

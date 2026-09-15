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

## Fastest the sound is allowed to move the show, in seconds. The same floor the
## clock has at the top of its range: a roll per sixteenth stops reading as a
## gesture and starts reading as a strobe of settings.
const BEAT_FLOOR := 1.0

var _next_roll: float = 0.0
## Since the last roll the sound asked for. Starts armed, so the first kick of the
## night lands rather than being swallowed by a floor nothing has used yet.
var _since_beat_roll: float = BEAT_FLOOR


func set_amount(value: float):
	amount = value
	_next_roll = _interval()


## One change every twelve seconds at the bottom of the range, one a second at the
## top. Below 12 s apart the scene never settles enough to be looked at.
func _interval() -> float:
	return lerpf(12.0, 1.0, amount)


func _process(delta: float):
	# Counted whatever the pace is set to, including nought: the sound reaches for
	# this clock at RANDOMIZER 0 too, and a floor that only advanced while the
	# auto-pilot ran would never release.
	_since_beat_roll += delta
	if amount <= 0.0:
		return
	_next_roll -= delta
	if _next_roll > 0.0:
		return
	_next_roll = _interval()
	_roll()


## One move, now, whatever the pace is set to — including nought, which is the
## point: it makes the randomiser something you can hit rather than something you
## leave running. The clock is rearmed so a hit does not land moments before an
## automatic one and read as a double.
func roll_now(section: String = ""):
	_roll(section)
	if amount > 0.0:
		_next_roll = _interval()


## The sound reaching for the same handle SHUFFLE reaches for, once per kick.
##
## `chance` is read on the beat rather than held here, so nothing in this file has
## to be kept in step with a slider: a chance, not a switch. Measured at 128 bpm,
## with the floor below doing its share: 1 is a move every three kicks, half way up
## is one a bar, and 0.1 is one every three bars.
##
## Deliberately unaffected by RANDOMIZER: at 0 the auto-pilot's own clock is off
## and the sound is the only thing moving the show, which is the setting this was
## asked for. The two run together happily as well.
func on_beat(chance: float):
	if chance <= 0.0 or _since_beat_roll < BEAT_FLOOR:
		return
	if randf() > chance:
		return
	_since_beat_roll = 0.0
	roll_now()


## `section` is a slug prefix — "lasers", "spot" — and empty means the whole show.
## Narrowing it is what makes this usable during a set: re-rolling the lasers while
## the spotlight keeps doing what it was asked is a musical decision, where rolling
## everything at once is a scene change.
func _roll(section: String = ""):
	if not all_params.is_valid():
		return
	var candidates: Array = []
	for p in all_params.call():
		if not p.randomizable:
			continue
		if section != "" and not p.slug.begins_with(section + "/"):
			continue
		candidates.append(p)
	if candidates.is_empty():
		return

	# One or two at a time: beyond that it stops reading as a gesture and starts
	# reading as a malfunction.
	for i in range(randi_range(1, maxi(1, mini(2, candidates.size() - 1)))):
		var p: VJParam = candidates.pick_random()
		# Averaging two draws clusters values towards the middle of the range, so
		# we avoid the extremes that either empty or saturate the screen.
		var t := (randf() + randf()) * 0.5
		p.set_value(lerpf(p.min_value, p.max_value, t))

	# Every so often, fresh colours too — but only if they are in random mode,
	# otherwise we would trample a manual choice.
	if palette and palette.mode == Palette.RANDOM and randf() < 0.25:
		randomize_colours.call()

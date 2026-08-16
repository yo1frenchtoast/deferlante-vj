class_name VJParam
extends RefCounted

## One controllable setting: its bounds, its step, and what to do with its value.
##
## The `slug` is the stable identity — it becomes the OSC address. What the
## operator reads comes from `Lang`, keyed by that same slug, so rewording a label
## (or switching language) can never break a console already wired to an address.
##
## The setting knows nothing about its widgets. The panel subscribes to `changed`,
## which lets the slider, the keyboard and OSC all funnel through one entry point
## without any of them needing to know the others exist.

signal changed(value: float)

## Stable identifier, used as the OSC address: "sphere/spin" -> /deferlante/sphere/spin
var slug: String
## Panel section this setting belongs to, as a Lang key.
var section: String

var min_value: float
var max_value: float
var step: float
var value: float
## Two-way setting: the sign is a direction of rotation, shown as an arrow rather
## than a minus sign — in the dark an arrow reads at a glance.
var bidirectional: bool
## Enumerated display: shows names instead of 0 / 1. Holds Lang keys, or raw
## strings for anything that reads the same in every language.
var choices: PackedStringArray = []
## Whether the choices above are Lang keys needing translation.
var translate_choices: bool = true
## Label tint on screen. Transparent means the theme's default colour.
var tint: Color = Color(0, 0, 0, 0)
## May the auto-pilot touch this setting? We exclude anything that is a decision
## about the room or the track (glow, saturation, tempo) rather than a variation.
var randomizable: bool = true

var _lang: Lang
var _apply: Callable


func _init(p_slug: String, p_min: float, p_max: float, p_step: float,
		p_value: float, p_apply: Callable, p_bidirectional: bool = false):
	slug = p_slug
	min_value = p_min
	max_value = p_max
	step = p_step
	value = p_value
	_apply = p_apply
	bidirectional = p_bidirectional


func use_language(lang: Lang):
	_lang = lang


func label() -> String:
	return _lang.label(slug) if _lang else slug


## The single entry point: slider, keyboard and OSC all end up here.
func set_value(new_value: float):
	value = clampf(snappedf(new_value, step), min_value, max_value)
	_apply.call(value)
	changed.emit(value)


func apply_current():
	_apply.call(value)


## Nudge by one notch: fine is a single step, otherwise a fortieth of the range so
## the setting can be crossed in a few presses.
func nudge(direction: int, fine: bool):
	var amount = step if fine else maxf(step, (max_value - min_value) / 40.0)
	set_value(value + direction * amount)


## Decimal count follows the step: a step of 1 has no business showing ".00".
func format_value() -> String:
	if not choices.is_empty():
		var choice := choices[clampi(int(value), 0, choices.size() - 1)]
		return _lang.text(choice) if translate_choices and _lang else choice
	if bidirectional:
		if value > 0.0005:
			return "→ %.2f" % value
		elif value < -0.0005:
			return "← %.2f" % absf(value)
		return "·  0.00"
	if step >= 1.0:
		return "%d" % value
	elif step < 0.01:
		return "%.3f" % value
	return "%.2f" % value

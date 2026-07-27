class_name VJParam
extends RefCounted

## Un réglage pilotable : ses bornes, son pas, et quoi faire de sa valeur.
##
## `slug` (l'adresse OSC) et `label` (ce qui s'affiche) sont séparés à dessein :
## on peut reformuler un libellé à l'écran sans casser les mappings d'une console
## déjà câblée sur l'ancienne adresse.
##
## Le paramètre ne connaît pas son affichage. Le panneau s'abonne à `changed`, ce
## qui permet au slider, au clavier et à l'OSC de passer tous par le même point
## d'entrée sans que l'un ait à savoir que les autres existent.

signal changed(value: float)

## Identifiant stable, utilisé pour l'adresse OSC : "sph_r" -> /deferlante/sph_r
var slug: String
## Ce que lit l'utilisateur à l'écran.
var label: String
## Section du panneau où ranger le réglage.
var section: String

var min_value: float
var max_value: float
var step: float
var value: float
## Réglage à double sens : le signe est un sens de rotation, affiché par une flèche
## plutôt que par un signe moins — dans le noir, une flèche se lit d'un coup d'œil.
var bidirectional: bool
## Affichage énuméré : "ALÉATOIRE" / "MANUEL" au lieu de 0 / 1.
var choices: PackedStringArray = []
## Teinte du libellé à l'écran. Transparent = couleur par défaut du thème.
var tint: Color = Color(0, 0, 0, 0)
## Le pilote automatique a-t-il le droit de toucher à ce réglage ? On exclut ce
## qui relève d'un choix de salle (halo, saturation) ou du tempo (vitesse) :
## ce sont des décisions, pas des variations.
var randomizable: bool = true

var _apply: Callable


func _init(p_slug: String, p_label: String, p_min: float, p_max: float,
		p_step: float, p_value: float, p_apply: Callable,
		p_bidirectional: bool = false):
	slug = p_slug
	label = p_label
	min_value = p_min
	max_value = p_max
	step = p_step
	value = p_value
	_apply = p_apply
	bidirectional = p_bidirectional


## Seul point d'entrée : slider, clavier et OSC y aboutissent tous.
func set_value(new_value: float):
	value = clampf(snappedf(new_value, step), min_value, max_value)
	_apply.call(value)
	changed.emit(value)


func apply_current():
	_apply.call(value)


## Décalage d'un cran : fin = un pas, sinon 1/40e de la plage pour traverser
## le réglage en quelques appuis.
func nudge(direction: int, fine: bool):
	var amount = step if fine else maxf(step, (max_value - min_value) / 40.0)
	set_value(value + direction * amount)


## Nombre de décimales déduit du pas : un pas de 1 n'a pas à afficher ".00".
func format_value() -> String:
	if not choices.is_empty():
		return choices[clampi(int(value), 0, choices.size() - 1)]
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

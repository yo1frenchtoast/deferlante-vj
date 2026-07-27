class_name Palette
extends RefCounted

## L'état de couleur du spectacle, partagé par les lasers, la poursuite et la sphère.
##
## C'est un objet unique que tout le monde référence, pas une valeur recopiée dans
## chaque effet : changer la saturation ici la change partout, et un laser créé en
## cours de route est déjà à jour puisqu'il pointe sur le même objet.
##
## Deux modes coexistent sans se marcher dessus : en aléatoire, chaque élément garde
## la teinte qu'il s'est tirée et que la touche R renouvelle ; en manuel, tous
## prennent la couleur choisie. Passer de l'un à l'autre ne détruit rien — les
## teintes aléatoires sont conservées et réapparaissent au retour.

signal changed

enum { RANDOM, MANUAL }

var saturation: float = 0.7
var mode: int = RANDOM
var manual: Color = Color(1.0, 0.25, 0.1)


## `hue` n'est lu qu'en mode aléatoire ; en manuel c'est `manual` qui décide.
## Dans les deux cas la saturation ramène vers le blanc, ce qui garde le réglage
## utile en projection : un faisceau proche du blanc traverse mieux la fumée.
func resolve(hue: float) -> Color:
	if mode == MANUAL:
		return manual.lerp(Color.WHITE, 1.0 - saturation)
	# Valeur forcée à 1 : en blend additif, une couleur sombre ne se voit pas.
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

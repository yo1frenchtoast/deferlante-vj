class_name Lang
extends RefCounted

## On-screen language. Everything the operator reads goes through here; the code
## itself, the OSC addresses and the docs stay in English so the project remains
## readable by anyone.
##
## Labels are keyed by OSC slug rather than by their own text: renaming what is
## displayed can never break a console already wired to an address.

signal changed

enum { FR, EN }

var current: int = FR


## slug -> [french, english]
const LABELS := {
	"global/speed": ["VITESSE", "SPEED"],
	"global/chaos": ["CHAOS", "CHAOS"],
	"global/randomizer": ["RANDOMIZER", "RANDOMIZER"],
	"global/glow": ["HALO", "GLOW"],
	"global/language": ["LANGUE", "LANGUAGE"],

	"color/mode": ["MODE", "MODE"],
	"color/saturation": ["SATURATION", "SATURATION"],
	"color/red": ["ROUGE", "RED"],
	"color/green": ["VERT", "GREEN"],
	"color/blue": ["BLEU", "BLUE"],

	"mirror/effect": ["EFFET", "EFFECT"],
	"mirror/segments": ["SEGMENTS", "SEGMENTS"],
	"mirror/rotation": ["ROTATION", "ROTATION"],

	"lasers/count": ["NOMBRE", "COUNT"],
	"lasers/width": ["ÉPAISSEUR", "WIDTH"],
	"lasers/length": ["LONGUEUR", "LENGTH"],
	"lasers/spin": ["ROTATION", "SPIN"],

	"spot/radius": ["RAYON", "RADIUS"],
	"spot/pulse": ["PULSATION", "PULSE"],
	"spot/width": ["ÉPAISSEUR", "WIDTH"],
	"spot/speed": ["VITESSE", "SPEED"],
	"spot/hold": ["ARRÊTS", "HOLD"],
	"spot/shake": ["TREMBLEMENT", "SHAKE"],
	"spot/frequency": ["FRÉQUENCE", "FREQUENCY"],
	"spot/glitch": ["GLITCH", "GLITCH"],

	"sphere/count": ["CERCLES", "CIRCLES"],
	"sphere/size": ["TAILLE", "SIZE"],
	"sphere/radius": ["RAYON", "RADIUS"],
	"sphere/spin": ["ROTATION", "SPIN"],
	"sphere/depth": ["PROFONDEUR", "DEPTH"],
	"sphere/width": ["ÉPAISSEUR", "WIDTH"],
	"sphere/glass": ["VERRE", "GLASS"],
}

const TEXTS := {
	"section.global": ["GLOBAL", "GLOBAL"],
	"section.color": ["COULEUR", "COLOR"],
	"section.mirror": ["MIROIR", "MIRROR"],
	"section.lasers": ["LASERS", "LASERS"],
	"section.spot": ["POURSUITE", "SPOTLIGHT"],
	"section.sphere": ["SPHÈRE", "SPHERE"],

	"mode.random": ["ALÉATOIRE", "RANDOM"],
	"mode.manual": ["MANUEL", "MANUAL"],

	"help.params": [
		"↑↓ paramètre    ←→ régler (Maj : précis)    ESPACE glitch    R couleurs",
		"↑↓ parameter    ←→ adjust (Shift: fine)    SPACE glitch    R colors",
	],
	"help.keys": [
		"H figer l'UI    F3 fps    F11 plein écran    ÉCHAP quitter",
		"H pin UI    F3 fps    F11 fullscreen    ESC quit",
	],
	"fps.screen": ["écran %.0f Hz", "screen %.0f Hz"],
}

## The language names stay in their own tongue, as is customary.
const LANGUAGES := ["FRANÇAIS", "ENGLISH"]


func set_language(value: int):
	current = clampi(value, 0, 1)
	changed.emit()


func label(slug: String) -> String:
	return LABELS[slug][current] if LABELS.has(slug) else slug


func text(key: String) -> String:
	return TEXTS[key][current] if TEXTS.has(key) else key

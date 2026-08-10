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
	"global/recall": ["FONDU PRESET", "RECALL FADE"],
	"global/panel": ["PANNEAU", "PANEL"],
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
	"spot/spread": ["ÉTALEMENT", "SPREAD"],
	"spot/glitch": ["GLITCH", "GLITCH"],
	"spot/manual": ["PILOTAGE", "AIMING"],
	"spot/track": ["SUIVI", "TRACKING"],
	"spot/handback": ["RETOUR AUTO", "HAND BACK"],

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
	"mode.auto": ["AUTO", "AUTO"],
	"mode.manual_lock": ["MANETTE", "STICK"],

	"help.params": [
		"↑↓ paramètre    ←→ régler    Maj+←→ précis",
		"↑↓ parameter    ←→ adjust    Shift+←→ fine",
	],
	"help.actions": [
		"ESPACE glitch    R couleurs    1-9 preset    Ctrl+1-9 enregistrer",
		"SPACE glitch    R colours    1-9 preset    Ctrl+1-9 store",
	],
	"help.keys": [
		"H figer l'UI    D discrétion    F3 fps    F11 plein écran    ÉCHAP quitter",
		"H pin UI    D dim    F3 fps    F11 fullscreen    ESC quit",
	],
	"help.pad": [
		"manette : stick gauche vise    gâchettes taille    A glitch    LB/RB gel/boost",
		"pad: left stick aims    triggers size    A glitch    LB/RB freeze/boost",
	],
	"status.web": ["surface web", "web surface"],
	"status.pad": ["manette", "pad"],
	"status.nopad": ["aucune manette", "no pad"],
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

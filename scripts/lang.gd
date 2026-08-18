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
	"global/autodim": ["AUTO DISCRET", "AUTO DIM"],

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
	"lasers/parallel": ["PARALLÈLES", "PARALLEL"],
	"lasers/scroll": ["DÉFILEMENT", "SCROLL"],

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

	"audio/reactivity": ["RÉACTIVITÉ", "REACTIVITY"],
	"audio/punch": ["NERVOSITÉ", "PUNCH"],
	"audio/lasers": ["LASERS ← MÉDIUMS", "LASERS ← MID"],
	"audio/spot": ["POURSUITE ← GRAVES", "SPOT ← BASS"],
	"audio/sphere": ["SPHÈRE ← AIGUS", "SPHERE ← TREBLE"],

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
	"section.audio": ["SON", "AUDIO"],
	"section.sphere": ["SPHÈRE", "SPHERE"],

	"mode.random": ["ALÉATOIRE", "RANDOM"],
	"mode.manual": ["MANUEL", "MANUAL"],
	"mode.auto": ["AUTO", "AUTO"],
	"mode.off": ["NON", "OFF"],
	"mode.on": ["OUI", "ON"],
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
		"H figer l'UI    F2 discrétion    F3 fps    F11 plein écran    ÉCHAP quitter",
		"H pin UI    F2 dim    F3 fps    F11 fullscreen    ESC quit",
	],
	"help.pad": [
		"manette : stick gauche vise    gâchettes taille    A glitch    LB/RB gel/boost",
		"pad: left stick aims    triggers size    A glitch    LB/RB freeze/boost",
	],
	"status.web": ["surface web", "web surface"],
	"status.pad": ["manette", "pad"],
	"status.audio": ["son", "audio"],
	"status.listening": ["à l'écoute", "listening"],
	"status.deaf": ["pas de capture", "no capture"],
	"status.silent": ["silence — rien n'entre", "silence — nothing coming in"],
	"status.nopad": ["aucune manette", "no pad"],
	"fps.screen": ["écran %.0f Hz", "screen %.0f Hz"],

	"launch.subtitle": ["réglages de démarrage", "start-up settings"],
	"launch.renderer": ["RENDU", "RENDERER"],
	"launch.renderer.compat": [
		"Compatibility — rapide, sans carte graphique",
		"Compatibility — fast, no graphics card",
	],
	"launch.renderer.forward": [
		"Forward+ — antialiasing, mais deux fois plus lourd",
		"Forward+ — antialiasing, but twice the cost",
	],
	"launch.msaa": ["ANTIALIASING", "ANTIALIASING"],
	"launch.msaa.off": ["aucun", "none"],
	"launch.msaa.unavailable": [
		"sans effet en Compatibility",
		"has no effect in Compatibility",
	],
	"launch.resolution": ["RÉSOLUTION", "RESOLUTION"],
	"launch.resolution.native": ["celle de l'écran", "the screen's own"],
	"launch.fullscreen": ["PLEIN ÉCRAN", "FULLSCREEN"],
	"launch.vsync": ["VSYNC", "VSYNC"],
	"launch.maxfps": ["FPS MAX", "MAX FPS"],
	"launch.maxfps.free": ["illimité", "uncapped"],
	"launch.audio": ["ENTRÉE AUDIO", "AUDIO INPUT"],
	"launch.audio.auto": ["choix automatique", "picked automatically"],
	"launch.audio.blind": [
		"ce Godot ignore ce choix — voir tools/listen-to-output.sh",
		"this Godot build ignores the choice — see tools/listen-to-output.sh",
	],
	"launch.panel": ["PANNEAU", "PANEL"],
	"launch.panel.hidden": ["masqué pour tout le set", "hidden for the whole set"],
	"launch.access": ["ACCÈS WEB", "WEB ACCESS"],
	"launch.access.local": ["cette machine seulement", "this machine only"],
	"launch.access.gone": [
		"l'adresse enregistrée a disparu du réseau",
		"the saved address is no longer on the network",
	],
	"launch.webport": ["PORT WEB", "WEB PORT"],
	"launch.oscaccess": ["ACCÈS OSC", "OSC ACCESS"],
	"launch.oscport": ["PORT OSC", "OSC PORT"],
	"launch.language": ["LANGUE", "LANGUAGE"],
	"launch.go": ["LANCER", "START"],
	"launch.restart": [
		"changer de rendu relance l'application",
		"changing the renderer restarts the app",
	],
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

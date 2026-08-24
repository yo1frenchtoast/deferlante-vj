class_name Lang
extends RefCounted

## On-screen language. Everything the operator reads goes through here; the code
## itself, the OSC addresses and the docs stay in English so the project remains
## readable by anyone.
##
## Labels are keyed by OSC slug rather than by their own text: renaming what is
## displayed can never break a console already wired to an address.
##
## English comes first in every table, and is the first member of the enum. The
## source is English throughout — identifiers, addresses, comments, documentation
## — so the tongue the reader of the code already has is the one they meet first,
## and the French is plainly the translation of it. What the operator sees is a
## separate question, answered by ORDER and by the launcher.

signal changed

enum { EN, FR }

var current: int = FR


## The order the two are offered in, which is not the order they are stored in.
## The room this is built for is French-speaking, so FRANÇAIS stays the first row
## at the launcher and the first entry on the web tab. Nothing may assume that a
## position in this list is the enum value: go through choice_of() and value_of().
const ORDER := [FR, EN]

## Named in ORDER.
const LANGUAGES := ["FRANÇAIS", "ENGLISH"]

## What goes into launch.cfg. A code rather than the enum value, so that adding a
## language, or reordering the enum as this project just did, cannot silently
## reinterpret a file already on disk and open the show in the wrong tongue.
const CODES := {EN: "en", FR: "fr"}


## slug -> [english, french]
const LABELS := {
	"global/speed": ["SPEED", "VITESSE"],
	"global/chaos": ["CHAOS", "CHAOS"],
	"global/randomizer": ["RANDOMIZER", "RANDOMIZER"],
	"global/glow": ["GLOW", "HALO"],
	"global/recall": ["RECALL FADE", "FONDU PRESET"],
	"global/panel": ["PANEL", "PANNEAU"],
	"global/autodim": ["AUTO DIM", "AUTO DISCRET"],

	"color/mode": ["MODE", "MODE"],
	"color/saturation": ["SATURATION", "SATURATION"],
	"color/red": ["RED", "ROUGE"],
	"color/green": ["GREEN", "VERT"],
	"color/blue": ["BLUE", "BLEU"],

	"mirror/effect": ["EFFECT", "EFFET"],
	"mirror/segments": ["SEGMENTS", "SEGMENTS"],
	"mirror/rotation": ["ROTATION", "ROTATION"],

	"lasers/count": ["COUNT", "NOMBRE"],
	"lasers/width": ["WIDTH", "ÉPAISSEUR"],
	"lasers/length": ["LENGTH", "LONGUEUR"],
	"lasers/spin": ["SPIN", "ROTATION"],
	"lasers/parallel": ["PARALLEL", "PARALLÈLES"],
	"lasers/scroll": ["SCROLL", "DÉFILEMENT"],

	"spot/radius": ["RADIUS", "RAYON"],
	"spot/pulse": ["PULSE", "PULSATION"],
	"spot/width": ["WIDTH", "ÉPAISSEUR"],
	"spot/speed": ["SPEED", "VITESSE"],
	"spot/hold": ["HOLD", "ARRÊTS"],
	"spot/shake": ["SHAKE", "TREMBLEMENT"],
	"spot/frequency": ["FREQUENCY", "FRÉQUENCE"],
	"spot/spread": ["SPREAD", "ÉTALEMENT"],
	"spot/glitch": ["GLITCH", "GLITCH"],
	"spot/manual": ["AIMING", "PILOTAGE"],
	"spot/track": ["TRACKING", "SUIVI"],
	"spot/handback": ["HAND BACK", "RETOUR AUTO"],

	"audio/reactivity": ["REACTIVITY", "RÉACTIVITÉ"],
	"audio/punch": ["PUNCH", "NERVOSITÉ"],
	"audio/spot": ["SPOT ← BASS", "POURSUITE ← GRAVES"],
	"audio/warp": ["HYPERSPACE ← BASS", "HYPERESPACE ← GRAVES"],
	"audio/lasers": ["LASERS ← MID", "LASERS ← MÉDIUMS"],
	"audio/sphere": ["SPHERE ← TREBLE", "SPHÈRE ← AIGUS"],

	"sphere/count": ["CIRCLES", "CERCLES"],
	"sphere/size": ["SIZE", "TAILLE"],
	"sphere/radius": ["RADIUS", "RAYON"],
	"sphere/spin": ["SPIN", "ROTATION"],
	"sphere/depth": ["DEPTH", "PROFONDEUR"],
	"sphere/width": ["WIDTH", "ÉPAISSEUR"],
	"sphere/glass": ["GLASS", "VERRE"],

	"warp/count": ["STARS", "ÉTOILES"],
	"warp/speed": ["SPEED", "VITESSE"],
	"warp/streak": ["STREAK", "TRAÎNÉE"],
	"warp/width": ["WIDTH", "ÉPAISSEUR"],
	"warp/spread": ["SPREAD", "ÉTALEMENT"],
}

const TEXTS := {
	"section.global": ["GLOBAL", "GLOBAL"],
	"section.color": ["COLOR", "COULEUR"],
	"section.mirror": ["MIRROR", "MIROIR"],
	"section.lasers": ["LASERS", "LASERS"],
	"section.spot": ["SPOTLIGHT", "POURSUITE"],
	"section.audio": ["AUDIO", "SON"],
	"section.sphere": ["SPHERE", "SPHÈRE"],
	"section.warp": ["HYPERSPACE", "HYPERESPACE"],

	"mode.random": ["RANDOM", "ALÉATOIRE"],
	"mode.manual": ["MANUAL", "MANUEL"],
	"mode.auto": ["AUTO", "AUTO"],
	"mode.off": ["OFF", "NON"],
	"mode.on": ["ON", "OUI"],
	"mode.manual_lock": ["STICK", "MANETTE"],

	"help.params": [
		"↑↓ parameter    ←→ adjust    Shift+←→ fine",
		"↑↓ paramètre    ←→ régler    Maj+←→ précis",
	],
	"help.actions": [
		"SPACE glitch    R colours    1-9 preset    Ctrl+1-9 store",
		"ESPACE glitch    R couleurs    1-9 preset    Ctrl+1-9 enregistrer",
	],
	"help.keys": [
		"H pin UI    F2 dim    F3 fps    F11 fullscreen    ESC quit",
		"H figer l'UI    F2 discrétion    F3 fps    F11 plein écran    ÉCHAP quitter",
	],
	"help.pad": [
		"pad: left stick aims    triggers size    A glitch    LB/RB freeze/boost",
		"manette : stick gauche vise    gâchettes taille    A glitch    LB/RB gel/boost",
	],
	"status.web": ["web surface", "surface web"],
	"status.pad": ["pad", "manette"],
	"status.audio": ["audio", "son"],
	"status.listening": ["listening", "à l'écoute"],
	"status.deaf": ["no capture", "pas de capture"],
	"status.silent": ["silence — nothing coming in", "silence — rien n'entre"],
	"status.nopad": ["no pad", "aucune manette"],
	"fps.screen": ["screen %.0f Hz", "écran %.0f Hz"],

	"launch.subtitle": ["start-up settings", "réglages de démarrage"],
	"launch.renderer": ["RENDERER", "RENDU"],
	"launch.renderer.compat": [
		"Compatibility — fast, no graphics card",
		"Compatibility — rapide, sans carte graphique",
	],
	"launch.renderer.forward": [
		"Forward+ — antialiasing, but twice the cost",
		"Forward+ — antialiasing, mais deux fois plus lourd",
	],
	"launch.msaa": ["ANTIALIASING", "ANTIALIASING"],
	"launch.msaa.off": ["none", "aucun"],
	"launch.msaa.unavailable": [
		"has no effect in Compatibility",
		"sans effet en Compatibility",
	],
	"launch.resolution": ["RESOLUTION", "RÉSOLUTION"],
	"launch.resolution.native": ["the screen's own", "celle de l'écran"],
	"launch.fullscreen": ["FULLSCREEN", "PLEIN ÉCRAN"],
	"launch.vsync": ["VSYNC", "VSYNC"],
	"launch.maxfps": ["MAX FPS", "FPS MAX"],
	"launch.maxfps.free": ["uncapped", "illimité"],
	"launch.listen": ["SOUND LISTENED TO", "SON ÉCOUTÉ"],
	"launch.listen.auto": [
		"whichever output is playing at launch",
		"la sortie active au lancement",
	],
	"launch.listen.outputs": ["— listen to an output —", "— écouter une sortie —"],
	"launch.listen.sources": ["— capture an input —", "— capter une entrée —"],
	"launch.listen.nothing": [
		"nothing coming in — this one is silent",
		"rien n'entre — ce choix est muet",
	],
	"launch.listen.hint": [
		"the sound is tapped on its way out, not rerouted",
		"le son est écouté au passage, pas dérouté",
	],
	"launch.audio": ["AUDIO INPUT", "ENTRÉE AUDIO"],
	"launch.audio.auto": ["picked automatically", "choix automatique"],
	"launch.audio.blind": [
		"this Godot build ignores the choice — see tools/listen-to-output.sh",
		"ce Godot ignore ce choix — voir tools/listen-to-output.sh",
	],
	"launch.panel": ["PANEL", "PANNEAU"],
	"launch.autostart": ["START ON", "DÉMARRER SUR"],
	"launch.autostart.none": ["the defaults", "les valeurs par défaut"],
	"launch.autostart.slot": ["preset %d", "preset %d"],
	"launch.autostart.empty": ["preset %d — empty", "preset %d — vide"],
	"launch.autostart.hint": [
		"a slot saved with RANDOMIZER up starts a show that runs itself",
		"un preset enregistré avec RANDOMIZER en haut lance un show qui tourne seul",
	],
	"launch.panel.hidden": ["hidden for the whole set", "masqué pour tout le set"],
	"launch.access": ["WEB ACCESS", "ACCÈS WEB"],
	"launch.access.local": ["this machine only", "cette machine seulement"],
	"launch.access.gone": [
		"the saved address is no longer on the network",
		"l'adresse enregistrée a disparu du réseau",
	],
	"launch.webport": ["WEB PORT", "PORT WEB"],
	"launch.oscaccess": ["OSC ACCESS", "ACCÈS OSC"],
	"launch.oscport": ["OSC PORT", "PORT OSC"],
	"launch.language": ["LANGUAGE", "LANGUE"],
	"launch.go": ["START", "LANCER"],
	"launch.restart": [
		"changing the renderer restarts the app",
		"changer de rendu relance l'application",
	],
	# The web surface offers the same settings from across the room, and needs a few
	# words the launcher never had to say: it can restart the show itself, and it is
	# reached through the very port one of these rows can move.
	# The one-shot actions, as the web surface labels its buttons. The panel says the
	# same words in its help line; these are keyed by action name so a new one in
	# `ACTIONS` only needs a line here to read properly.
	"action.glitch": ["GLITCH", "GLITCH"],
	"action.randomize": ["COLORS", "COULEURS"],
	"action.shuffle": ["SHUFFLE", "BRASSER"],

	"launch.tab": ["START-UP", "DÉMARRAGE"],
	"launch.restart.now": ["RESTART", "REDÉMARRER"],
	"launch.restart.applies": [
		"these settings take effect on restart",
		"ces réglages prennent effet au redémarrage",
	],
	"launch.restart.web": [
		"changing the web access or port will cut this page off",
		"changer l'accès ou le port web coupera cette page",
	],
	"launch.restart.failed": [
		"this device cannot restart itself · the settings are saved, relaunch the "
			+ "app to apply them",
		"cet appareil ne sait pas se relancer seul · les réglages sont enregistrés, "
			+ "relancez l'application pour les appliquer",
	],
}

## One line per setting, shown when the operator hovers or holds its name on
## the web surface. Keyed by slug like LABELS, for the same reason: rewording
## one can never move an address. Say what the setting does and what its ends
## mean — the page has room for a line, not for a paragraph.
const HINTS := {
	"global/speed": ["Global speed. 1 is normal, 0 freezes, negative runs backwards.", "Vitesse de tout. 1 normal, 0 fige, négatif rembobine."],
	"global/chaos": ["Motion disorder, layered on top of the others. It does not touch GLITCH.", "Désordre du mouvement, par-dessus les autres réglages. Ne touche pas au GLITCH."],
	"global/randomizer": ["Auto-pilot. 0 is off, 1 is about one change per second.", "Pilote automatique. 0 coupé, 1 environ un changement par seconde."],
	"global/glow": ["Halo, drawn by the strokes themselves. Of no use in haze, which already spreads the beam.", "Halo, dessiné par les traits eux-mêmes. Inutile dans la fumée : le halo y est déjà."],
	"global/recall": ["Crossfade time when you recall a preset. 0 snaps.", "Durée du fondu quand on rappelle un preset. 0 coupe net."],
	"global/panel": ["Panel brightness. The projector puts the panel on the wall with the rest.", "Luminosité du panneau. Il est projeté au mur avec le reste."],
	"global/autodim": ["Dims the panel as soon as another surface takes control.", "Assombrit le panneau dès qu'une autre surface prend la main."],

	"color/mode": ["Each element takes its own hue, or all take the chosen color.", "Chaque élément sa teinte, ou la couleur choisie pour tous."],
	"color/saturation": ["0 is pure white, 1 is a full color. Near 0.4 the beam cuts through haze better.", "0 blanc pur, 1 couleur pleine. Vers 0.4 le faisceau perce mieux la fumée."],
	"color/red": ["Red of the manual color. A touch here switches to manual.", "Rouge de la couleur manuelle. Y toucher bascule en manuel."],
	"color/green": ["Green of the manual color. A touch here switches to manual.", "Vert de la couleur manuelle. Y toucher bascule en manuel."],
	"color/blue": ["Blue of the manual color. A touch here switches to manual.", "Bleu de la couleur manuelle. Y toucher bascule en manuel."],

	"mirror/effect": ["Kaleidoscope fold, off or on. At OFF the show does not pay for the pass.", "Pliage kaléidoscope, tout ou rien. À NON la passe n'est pas payée."],
	"mirror/segments": ["Number of mirror wedges. 6 gives the classic star.", "Nombre de quartiers du miroir. 6 donne l'étoile classique."],
	"mirror/rotation": ["Turns the mirrors. ← left, → right.", "Fait tourner les miroirs. ← gauche, → droite."],

	"lasers/count": ["Number of strokes. The show adds and removes them live.", "Nombre de traits. Ajoutés et retirés en direct."],
	"lasers/width": ["Stroke width.", "Épaisseur des traits."],
	"lasers/length": ["1 crosses the frame at every resolution. Below 1 the tips come into view.", "1 traverse le cadre quelle que soit la résolution. En dessous, les pointes entrent dans l'image."],
	"lasers/spin": ["Direction and speed of rotation. ← leftwards, → rightwards.", "Sens et vitesse de rotation des traits. ← gauche, → droite."],
	"lasers/parallel": ["0 is a scatter, 1 is an even fan. With SCROLL it makes scanlines.", "0 une dispersion, 1 un éventail régulier. Avec SCROLL, cela fait des scanlines."],
	"lasers/scroll": ["Walks the fan sideways. ← one way, → the other.", "Fait défiler l'éventail de côté. ← un sens, → l'autre."],

	"spot/radius": ["Radius of the pool.", "Rayon de la tache."],
	"spot/pulse": ["How far the radius swells. 0 holds it steady.", "Amplitude du battement du rayon. 0 le tient fixe."],
	"spot/width": ["Circle stroke width.", "Épaisseur du cercle."],
	"spot/speed": ["Sweep speed. It has no direction: a followspot does not un-search.", "Vitesse de balayage. Elle n'a pas de sens : une poursuite ne cherche pas à l'envers."],
	"spot/hold": ["Time spent on a target. 0 sweeps without any stop.", "Temps passé sur une cible. 0 balaie sans jamais s'arrêter."],
	"spot/shake": ["Tremor amplitude at rest. 0 holds it perfectly still.", "Amplitude du tremblement à l'arrêt. 0 tient parfaitement immobile."],
	"spot/frequency": ["Tremor rate, independent of the sweep speed.", "Vitesse du tremblement, indépendante de la vitesse de balayage."],
	"spot/spread": ["How much the pool grows when it aims away from center, like a real followspot.", "Grossissement de la tache quand elle vise loin du centre, comme une vraie poursuite."],
	"spot/glitch": ["Glitch chance per frame. 0.005 gives about one every 3 s.", "Probabilité de glitch par image. 0.005 fait environ un toutes les 3 s."],
	"spot/manual": ["AUTO hands back on its own. STICK keeps the beam on the gamepad.", "AUTO rend la main toute seule, STICK garde le faisceau à la manette."],
	"spot/track": ["Beam speed at full stick. Too slow and you lose your actor, too fast and you cannot hold them.", "Vitesse du faisceau à fond de manche. Trop lent on perd l'acteur, trop vite on ne le tient pas."],
	"spot/handback": ["Delay before the automatic sweep takes the beam back.", "Délai avant que le balayage automatique ne reprenne le faisceau."],

	"audio/reactivity": ["Master amount of the sound response. At 0 nothing moves.", "Dose générale de la réaction au son. À 0 rien ne bouge."],
	"audio/punch": ["Response curve. Higher, and only the hits show.", "Courbe de réponse. Plus haut, seuls les coups ressortent."],
	"audio/spot": ["The kick drives the spotlight: its radius and its stroke width.", "Le kick pilote la poursuite : son rayon et son épaisseur."],
	"audio/warp": ["The kick drives the star field: how fast it flies and how thick the streaks are.", "Le kick pilote le champ d'étoiles : sa vitesse et l'épaisseur des traînées."],
	"audio/lasers": ["Mids drive the lasers: their length and their stroke width.", "Les médiums pilotent les lasers : leur longueur et leur épaisseur."],
	"audio/sphere": ["Treble drives the sphere: the circle size and the stroke width.", "Les aigus pilotent la sphère : la taille des cercles et leur épaisseur."],

	"sphere/count": ["Number of circles. 0 switches the effect off.", "Nombre de cercles. 0 éteint l'effet."],
	"sphere/size": ["Size of one circle, in radians on the sphere.", "Taille d'un cercle, en radians sur la sphère."],
	"sphere/radius": ["Sphere radius on screen.", "Rayon de la sphère à l'écran."],
	"sphere/spin": ["Direction and speed of the sphere. ← leftwards, → rightwards.", "Sens et vitesse de rotation de la sphère. ← gauche, → droite."],
	"sphere/depth": ["Eye distance. A small value gives strong perspective.", "Distance de l'œil. Petit donne une perspective forte."],
	"sphere/width": ["Circle stroke width.", "Épaisseur des cercles."],
	"sphere/glass": ["0 is an opaque sphere, 1 shows the far side through it.", "0 sphère opaque, 1 laisse voir la face arrière au travers."],

	"warp/count": ["Number of stars. 0 switches the effect off.", "Nombre d'étoiles. 0 éteint l'effet."],
	"warp/speed": ["How fast the field flies past. The global SPEED still catches it, and reverses it.", "Vitesse de défilement du champ. La VITESSE générale l'attrape aussi, et l'inverse."],
	"warp/streak": ["Length of the trail, in seconds of travel. It is a shutter speed: faster stars streak further on their own.", "Longueur de la traînée, en secondes de trajet. C'est un temps de pose : une étoile rapide file plus loin d'elle-même."],
	"warp/width": ["Streak thickness at the far plane. Near stars are drawn thicker.", "Épaisseur des traînées au fond. Les étoiles proches sont tracées plus épaisses."],
	"warp/spread": ["Width of the tube. Small comes straight at you, large throws the stars past the corners.", "Largeur du tube. Petit arrive droit sur vous, grand jette les étoiles hors des coins."],
}




## The enum value behind a position in LANGUAGES, and back again. Every surface
## that offers the choice as a list goes through these two.
static func value_of(choice: int) -> int:
	return ORDER[clampi(choice, 0, ORDER.size() - 1)]


static func choice_of(value: int) -> int:
	return maxi(0, ORDER.find(value))


## The code stored on disk, and the value behind one. An unknown code, or a file
## written before codes were used, falls back to the default rather than fails.
static func code_of(value: int) -> String:
	return CODES.get(value, CODES[FR])


static func value_of_code(code: String, fallback: int = FR) -> int:
	for value in CODES:
		if CODES[value] == code:
			return value
	return fallback


func set_language(value: int):
	current = clampi(value, 0, 1)
	changed.emit()


func label(slug: String) -> String:
	return label_in(slug, current)


func text(key: String) -> String:
	return text_in(key, current)


## The same words, in a tongue named rather than the one the room is set to. The
## API answers in English whatever the launcher was told, so that a spec written
## against it does not change meaning when somebody switches the screen to French.
func label_in(slug: String, tongue: int) -> String:
	return LABELS[slug][tongue] if LABELS.has(slug) else slug


func text_in(key: String, tongue: int) -> String:
	return TEXTS[key][tongue] if TEXTS.has(key) else key


## The one-line explanation of a setting. Empty when none is written, so a new
## setting can be tried out before it is described and the surfaces simply show
## nothing rather than its slug.
func hint_in(slug: String, tongue: int) -> String:
	return HINTS[slug][tongue] if HINTS.has(slug) else ""


func hint(slug: String) -> String:
	return hint_in(slug, current)

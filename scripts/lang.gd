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
	"audio/spot": ["POURSUITE ← GRAVES", "SPOT ← BASS"],
	"audio/lasers": ["LASERS ← MÉDIUMS", "LASERS ← MID"],
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
	"launch.listen": ["SON ÉCOUTÉ", "SOUND LISTENED TO"],
	"launch.listen.auto": [
		"la sortie active au lancement",
		"whichever output is playing at launch",
	],
	"launch.listen.outputs": ["— écouter une sortie —", "— listen to an output —"],
	"launch.listen.sources": ["— capter une entrée —", "— capture an input —"],
	"launch.listen.nothing": [
		"rien n'entre — ce choix est muet",
		"nothing coming in — this one is silent",
	],
	"launch.listen.hint": [
		"le son est écouté au passage, pas dérouté",
		"the sound is tapped on its way out, not rerouted",
	],
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
	# The web surface offers the same settings from across the room, and needs a few
	# words the launcher never had to say: it can restart the show itself, and it is
	# reached through the very port one of these rows can move.
	# The one-shot actions, as the web surface labels its buttons. The panel says the
	# same words in its help line; these are keyed by action name so a new one in
	# `ACTIONS` only needs a line here to read properly.
	"action.glitch": ["GLITCH", "GLITCH"],
	"action.randomize": ["COULEURS", "COLORS"],
	"action.shuffle": ["BRASSER", "SHUFFLE"],

	"launch.tab": ["DÉMARRAGE", "START-UP"],
	"launch.restart.now": ["REDÉMARRER", "RESTART"],
	"launch.restart.applies": [
		"ces réglages prennent effet au redémarrage",
		"these settings take effect on restart",
	],
	"launch.restart.web": [
		"changer l'accès ou le port web coupera cette page",
		"changing the web access or port will cut this page off",
	],
	"launch.restart.failed": [
		"cet appareil ne sait pas se relancer seul · les réglages sont enregistrés, "
			+ "relancez l'application pour les appliquer",
		"this device cannot restart itself · the settings are saved, relaunch the "
			+ "app to apply them",
	],
}

## One line per setting, shown when the operator hovers or holds its name on
## the web surface. Keyed by slug like LABELS, for the same reason: rewording
## one can never move an address. Say what the setting does and what its ends
## mean — the page has room for a line, not for a paragraph.
const HINTS := {
	"global/speed": ["Vitesse de tout. 1 normal, 0 fige, négatif rembobine.", "Global speed. 1 is normal, 0 freezes, negative runs backwards."],
	"global/chaos": ["Désordre du mouvement, par-dessus les autres réglages. Ne touche pas au GLITCH.", "Motion disorder, layered on top of the others. It does not touch GLITCH."],
	"global/randomizer": ["Pilote automatique. 0 coupé, 1 environ un changement par seconde.", "Auto-pilot. 0 is off, 1 is about one change per second."],
	"global/glow": ["Halo, dessiné par les traits eux-mêmes. Inutile dans la fumée : le halo y est déjà.", "Halo, drawn by the strokes themselves. Of no use in haze, which already spreads the beam."],
	"global/recall": ["Durée du fondu quand on rappelle un preset. 0 coupe net.", "Crossfade time when you recall a preset. 0 snaps."],
	"global/panel": ["Luminosité du panneau. Il est projeté au mur avec le reste.", "Panel brightness. The projector puts the panel on the wall with the rest."],
	"global/autodim": ["Assombrit le panneau dès qu'une autre surface prend la main.", "Dims the panel as soon as another surface takes control."],

	"color/mode": ["Chaque élément sa teinte, ou la couleur choisie pour tous.", "Each element takes its own hue, or all take the chosen color."],
	"color/saturation": ["0 blanc pur, 1 couleur pleine. Vers 0.4 le faisceau perce mieux la fumée.", "0 is pure white, 1 is a full color. Near 0.4 the beam cuts through haze better."],
	"color/red": ["Rouge de la couleur manuelle. Y toucher bascule en manuel.", "Red of the manual color. A touch here switches to manual."],
	"color/green": ["Vert de la couleur manuelle. Y toucher bascule en manuel.", "Green of the manual color. A touch here switches to manual."],
	"color/blue": ["Bleu de la couleur manuelle. Y toucher bascule en manuel.", "Blue of the manual color. A touch here switches to manual."],

	"mirror/effect": ["Pliage kaléidoscope. À 0 la passe n'est pas payée.", "Kaleidoscope fold. At 0 the show does not pay for the pass."],
	"mirror/segments": ["Nombre de quartiers du miroir. 6 donne l'étoile classique.", "Number of mirror wedges. 6 gives the classic star."],
	"mirror/rotation": ["Fait tourner les miroirs. ← gauche, → droite.", "Turns the mirrors. ← left, → right."],

	"lasers/count": ["Nombre de traits. Ajoutés et retirés en direct.", "Number of strokes. The show adds and removes them live."],
	"lasers/width": ["Épaisseur des traits.", "Stroke width."],
	"lasers/length": ["1 traverse le cadre quelle que soit la résolution. En dessous, les pointes entrent dans l'image.", "1 crosses the frame at every resolution. Below 1 the tips come into view."],
	"lasers/spin": ["Sens et vitesse de rotation des traits. ← gauche, → droite.", "Direction and speed of rotation. ← leftwards, → rightwards."],
	"lasers/parallel": ["0 une dispersion, 1 un éventail régulier. Avec SCROLL, cela fait des scanlines.", "0 is a scatter, 1 is an even fan. With SCROLL it makes scanlines."],
	"lasers/scroll": ["Fait défiler l'éventail de côté. ← un sens, → l'autre.", "Walks the fan sideways. ← one way, → the other."],

	"spot/radius": ["Rayon de la tache.", "Radius of the pool."],
	"spot/pulse": ["Amplitude du battement du rayon. 0 le tient fixe.", "How far the radius swells. 0 holds it steady."],
	"spot/width": ["Épaisseur du cercle.", "Circle stroke width."],
	"spot/speed": ["Vitesse de balayage. Elle n'a pas de sens : une poursuite ne cherche pas à l'envers.", "Sweep speed. It has no direction: a followspot does not un-search."],
	"spot/hold": ["Temps passé sur une cible. 0 balaie sans jamais s'arrêter.", "Time spent on a target. 0 sweeps without any stop."],
	"spot/shake": ["Amplitude du tremblement à l'arrêt. 0 tient parfaitement immobile.", "Tremor amplitude at rest. 0 holds it perfectly still."],
	"spot/frequency": ["Vitesse du tremblement, indépendante de la vitesse de balayage.", "Tremor rate, independent of the sweep speed."],
	"spot/spread": ["Grossissement de la tache quand elle vise loin du centre, comme une vraie poursuite.", "How much the pool grows when it aims away from center, like a real followspot."],
	"spot/glitch": ["Probabilité de glitch par image. 0.005 fait environ un toutes les 3 s.", "Glitch chance per frame. 0.005 gives about one every 3 s."],
	"spot/manual": ["AUTO rend la main toute seule, STICK garde le faisceau à la manette.", "AUTO hands back on its own. STICK keeps the beam on the gamepad."],
	"spot/track": ["Vitesse du faisceau à fond de manche. Trop lent on perd l'acteur, trop vite on ne le tient pas.", "Beam speed at full stick. Too slow and you lose your actor, too fast and you cannot hold them."],
	"spot/handback": ["Délai avant que le balayage automatique ne reprenne le faisceau.", "Delay before the automatic sweep takes the beam back."],

	"audio/reactivity": ["Dose générale de la réaction au son. À 0 rien ne bouge.", "Master amount of the sound response. At 0 nothing moves."],
	"audio/punch": ["Courbe de réponse. Plus haut, seuls les coups ressortent.", "Response curve. Higher, and only the hits show."],
	"audio/spot": ["Le kick pilote la poursuite : son rayon et son épaisseur.", "The kick drives the spotlight: its radius and its stroke width."],
	"audio/lasers": ["Les médiums pilotent les lasers : leur longueur et leur épaisseur.", "Mids drive the lasers: their length and their stroke width."],
	"audio/sphere": ["Les aigus pilotent la sphère : la taille des cercles et leur épaisseur.", "Treble drives the sphere: the circle size and the stroke width."],

	"sphere/count": ["Nombre de cercles. 0 éteint l'effet.", "Number of circles. 0 switches the effect off."],
	"sphere/size": ["Taille d'un cercle, en radians sur la sphère.", "Size of one circle, in radians on the sphere."],
	"sphere/radius": ["Rayon de la sphère à l'écran.", "Sphere radius on screen."],
	"sphere/spin": ["Sens et vitesse de rotation de la sphère. ← gauche, → droite.", "Direction and speed of the sphere. ← leftwards, → rightwards."],
	"sphere/depth": ["Distance de l'œil. Petit donne une perspective forte.", "Eye distance. A small value gives strong perspective."],
	"sphere/width": ["Épaisseur des cercles.", "Circle stroke width."],
	"sphere/glass": ["0 sphère opaque, 1 laisse voir la face arrière au travers.", "0 is an opaque sphere, 1 shows the far side through it."],
}


## The language names stay in their own tongue, as is customary.
const LANGUAGES := ["FRANÇAIS", "ENGLISH"]


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

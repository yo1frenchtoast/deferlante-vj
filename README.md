# Déferlante

Visuels VJ en Godot 4 : traits néon animés sur fond noir, en blend additif.
Pensé pour une projection vidéo avec machine à fumée.

## Lancer

Ouvrir le projet dans Godot 4.6+ et lancer (F5). La scène principale est `scenes/main.tscn`.

## Piloter

Les sliders **s'effacent tout seuls après 4 s d'inactivité** (fondu de 0,7 s) et
reviennent au moindre appui clavier ou geste de souris. `H` les fige à l'écran
pendant les réglages.

| Touche | Action |
| --- | --- |
| `↑` `↓` | Changer de paramètre (le sélectionné est en surbrillance) |
| `←` `→` | Régler le paramètre — 1/40e de la plage par appui |
| `Maj` + `←` `→` | Réglage précis, un cran à la fois |
| `Espace` | Déclencher un glitch immédiatement |
| `R` | Retirer au sort toutes les couleurs et trajectoires |
| `H` | Figer / libérer l'UI (l'empêche de s'effacer) |
| `F3` | Compteur de FPS |
| `F11` | Plein écran |
| `Échap` | Quitter |

La souris fonctionne aussi sur les sliders, mais le clavier est plus sûr en live :
pas besoin de viser dans le noir.

## Paramètres

Le panneau est rangé en quatre sections, les mêmes que les menus du module Chataigne.

### Global
| Réglage | Plage | Effet |
| --- | --- | --- |
| `VITESSE` | -3 – 3 | Vitesse globale. 1 = normale, 0 = figé, négatif = tout repart à l'envers. |
| `CHAOS` | 0 – 1 | Désordre du mouvement. N'affecte pas `GLITCH`. Voir plus bas. |
| `RANDOMIZER` | 0 – 1 | Pilote automatique. 0 = éteint, 1 = un changement par seconde. |
| `HALO` | 0 – 2 | Glow. **0 par défaut**, voir plus bas. |

### Couleur
| Réglage | Plage | Effet |
| --- | --- | --- |
| `MODE` | ALÉATOIRE / MANUEL | Chaque élément sa teinte, ou la couleur choisie pour tous. |
| `SATURATION` | 0 – 1 | 0 = blanc pur, 1 = couleur franche. Agit dans les deux modes. |
| `ROUGE` `VERT` `BLEU` | 0 – 1 | La couleur du mode manuel. Y toucher bascule en manuel. |

### Miroir
| Réglage | Plage | Effet |
| --- | --- | --- |
| `EFFET` | 0 – 1 | Repli kaléidoscope. 0 = éteint (la passe n'est pas payée). |
| `SEGMENTS` | 2 – 16 | Nombre de parts. 6 donne l'étoile classique. |
| `ROTATION` | -1 – 1 | Fait tourner les miroirs. ← gauche, → droite. |

### Lasers
| Réglage | Plage | Effet |
| --- | --- | --- |
| `NOMBRE` | 0 – 40 | Nombre de traits. Ajout et retrait à chaud. |
| `ÉPAISSEUR` | 1 – 24 | Épaisseur des traits. |
| `LONGUEUR` | 0.1 – 2 | Multiplie la longueur (chaque trait garde la sienne). |
| `ROTATION` | -1 – 1 | ← vers la gauche, → vers la droite. |

### Poursuite
| Réglage | Plage | Effet |
| --- | --- | --- |
| `RAYON` | 20 – 600 | Rayon de la tache. |
| `PULSATION` | 0 – 300 | Amplitude de la pulsation du rayon. 0 = fixe. |
| `ÉPAISSEUR` | 1 – 24 | Épaisseur du cercle. |
| `VITESSE` | 0 – 2 | Vitesse des balayages (sans notion de sens). |
| `ARRÊTS` | 0 – 3 | Durée des arrêts sur cible. 0 = balaye sans s'arrêter. |
| `GLITCH` | 0 – 0.05 | Probabilité de glitch par image. **0 par défaut.** Indépendant de `CHAOS`. 0.005 ≈ un toutes les 3 s. |

### Sphère
| Réglage | Plage | Effet |
| --- | --- | --- |
| `CERCLES` | 0 – 80 | Nombre de cercles. 0 = effet éteint. |
| `TAILLE` | 0.03 – 0.8 | Taille d'un cercle, en radians sur la sphère. |
| `RAYON` | 100 – 800 | Rayon de la sphère à l'écran. |
| `ROTATION` | -1 – 1 | ← vers la gauche, → vers la droite. |
| `PROFONDEUR` | 1.2 – 10 | Distance de l'œil. Petit = perspective marquée. |
| `ÉPAISSEUR` | 1 – 24 | Épaisseur du trait des cercles. |
| `VERRE` | 0 – 1 | 0 = sphère opaque, 1 = face arrière visible. |

Pour ajouter un réglage, une ligne suffit dans `_build_params()` de
`vj_controller.gd` : la section, la ligne d'UI, le slider, le formatage du nombre,
le pilotage clavier et l'adresse OSC en découlent automatiquement.

## Contrôle externe en OSC

Godot écoute l'OSC sur le port **9000** (UDP). Tous les réglages sont pilotables
à distance, depuis Chataigne, TouchOSC, un séquenceur, ou n'importe quel script.

| Adresse | Argument |
| --- | --- |
| `/deferlante/<section>/<réglage>` | la valeur, dans les bornes du slider (écrêtée si elle déborde) |
| `/deferlante/norm/<section>/<réglage>` | 0 → 1, étalé sur la plage du réglage |
| `/deferlante/couleur/rgb` | trois flottants 0 → 1 : la couleur complète d'un bloc |
| `/deferlante/glitch_now` | déclenche un glitch (sans argument) |
| `/deferlante/randomize` | retire au sort couleurs et trajectoires |

Les adresses sont hiérarchiques et suivent les sections du panneau :
`/deferlante/sphere/rotation`, `/deferlante/poursuite/arrets`,
`/deferlante/global/chaos`. La section fait partie du chemin parce que trois
sections ont un réglage `ÉPAISSEUR` — sans elle, les adresses entreraient en
collision.

L'adresse et le libellé sont **découplés** dans le code : `slug` porte l'adresse,
`label` ce qui s'affiche. On peut donc reformuler un libellé à l'écran sans casser
les mappings d'une console déjà câblée.

La forme `norm` sert aux surfaces qui n'envoient que du 0 → 1 (faders MIDI,
TouchOSC) et qui n'ont pas à connaître les bornes de chaque réglage.

Une valeur reçue en OSC **ne réveille pas l'UI**. C'est délibéré : une automation
qui envoie en continu ferait sinon rester les sliders affichés — donc projetés sur
le mur — pendant tout le set.

Un module Chataigne prêt à l'emploi est fourni dans `chataigne/Vjing/`, avec ses
instructions d'installation. Il n'est qu'un confort : le module OSC générique de
Chataigne suffit pour piloter les mêmes adresses.

## Les deux modes de couleur

**ALÉATOIRE** (par défaut) — chaque laser, chaque cercle de la sphère et la poursuite
tirent leur propre teinte. C'est le comportement d'origine, et `R` en renouvelle le
tirage.

**MANUEL** — tout le monde prend la couleur définie par `ROUGE` / `VERT` / `BLEU`.

Trois choses rendent l'aller-retour indolore :

- **Toucher une couleur bascule en manuel** automatiquement. Sans ça, bouger `ROUGE`
  ne produirait rien tant qu'on est en aléatoire, et le slider aurait l'air cassé.
- **Les teintes aléatoires survivent au passage en manuel.** Revenir à `ALÉATOIRE`
  les retrouve à l'identique — le mode manuel les masque, il ne les détruit pas.
- **`R` ramène à l'aléatoire** *et* retire de nouvelles teintes. C'est la sortie de
  secours qu'on trouve sans réfléchir en plein set.

`SATURATION` reste utile dans les deux modes : elle ramène la couleur vers le blanc.
En projection avec fumée, un faisceau proche du blanc traverse mieux qu'une couleur
saturée — descendre vers 0.4–0.5 si le rendu manque de tranchant.

## Le pilote automatique

`RANDOMIZER` fait évoluer les visuels tout seul : toutes les 1 à 12 secondes selon
sa valeur, il pioche un ou deux réglages et les repose ailleurs. Une fois sur quatre
il renouvelle aussi les couleurs, mais seulement si elles sont en mode aléatoire —
sinon il écraserait un choix manuel.

Trois précautions le rendent utilisable en vrai :

- **Un ou deux réglages à la fois.** Au-delà, ça ne se lit plus comme un geste mais
  comme une panne.
- **Les valeurs se groupent vers le milieu** de chaque plage (moyenne de deux
  tirages), ce qui évite les extrêmes qui vident l'écran ou le saturent.
- **Quatre réglages lui échappent** : `VITESSE`, `HALO`, `SATURATION` et les
  couleurs. Ce sont des décisions — le tempo du morceau, le contraste de la salle —
  pas des variations à subir.

## Le kaléidoscope

`EFFET` replie l'image en parts symétriques autour du centre, comme les miroirs d'un
kaléidoscope. Le repli se fait sur le **rendu déjà dessiné**, pas en dupliquant la
géométrie : le coût est celui d'une passe plein écran, que tu aies 5 traits ou 40.

Le calque est posé au-dessus des visuels mais **sous le panneau de réglages** —
sinon les sliders se retrouveraient eux aussi démultipliés à l'écran.

Comme le glow, à 0 la passe est réellement éteinte plutôt que laissée tourner en
identité.

## Le chaos

`CHAOS` est un macro-réglage qui **se superpose** aux autres sans les écraser : à 0 le
rendu est exactement celui que tu as réglé à la main, à 1 tout se dérègle. Sa
progression est volontairement inégale — discret au début, emballé sur la fin.

Ce qu'il fait, effet par effet :

- **Lasers** — chaque trait retrouve peu à peu son cap propre. C'est le désordre que
  le réglage de sens `SPIN` avait supprimé, rendu ici par la porte de derrière : à 1,
  les traits se croisent à contresens comme avant. S'y ajoutent des coups de barre
  aléatoires qui font zigzaguer les trajectoires.
- **Poursuite** — la tête ne tient plus en place (arrêts huit fois plus courts),
  balaye trois fois plus vite et tremble sept fois plus fort. En revanche il ne
  touche **pas** aux glitchs : le chaos dérègle le *mouvement*, `GLITCH` garde son
  propre réglage. Les deux se combinent à la main — une tête paniquée sans glitch,
  ou une tête posée qui explose par intermittence, sont deux images différentes.
- **Sphère** — chaque cercle glisse sur sa longitude à son propre rythme et sa taille
  se met à palpiter. La sphère reste lisible, mais sa surface n'est plus solidaire.

## Vitesses à double sens

`VITESSE` va de **-3 à 3**, les deux `ROTATION` de **-1 à 1**. Dans les trois cas le
curseur au centre est l'arrêt, et 1 la vitesse normale — `VITESSE` garde donc de la
marge au-delà pour les passages qui doivent décoller.
Le signe donne le sens de rotation, l'amplitude la vitesse. L'écran affiche une
flèche plutôt qu'un signe moins (`← 0.60`, `→ 0.60`, `·  0.00`) : dans le noir,
une flèche se lit d'un coup d'œil.

Pour que « vers la gauche / vers la droite » veuille dire quelque chose, chaque
laser tire désormais au sort **l'amplitude** de sa rotation, mais plus son sens :
celui-ci vient du réglage global. Avant, la moitié des traits tournait à contresens
et aucun réglage d'ensemble n'aurait pu les faire converger.

Les signes se combinent : `SPEED` à -1 avec `SPIN` à +1 fait tourner les traits vers
la gauche — inverser le temps global inverse aussi les rotations. En revanche
`SEEK SPD` reste une cadence positive : une poursuite ne « dé-cherche » pas, elle
continue de balayer vers l'avant même quand le reste tourne à l'envers.

## La poursuite (cercle principal)

Le cercle principal ne dérive plus : il se déplace comme une lyre qui cherche
quelqu'un dans la salle. Trois éléments produisent cette lecture :

1. **Il alterne balayages et arrêts** — environ 40 % du temps en mouvement, 60 % à
   l'arrêt sur une cible. C'est le rapport qui compte : un mouvement continu, même
   irrégulier, ne donne jamais l'impression de *chercher*.
2. **Il trace des arcs, pas des droites** — la tête pivote sur deux axes, donc son
   faisceau décrit une courbe sur un mur plat. C'est la signature la plus
   reconnaissable d'un projecteur motorisé, et elle est gratuite : elle tombe toute
   seule de la projection `tan(pan)`, `tan(tilt) / cos(pan)`.
3. **Il hésite** — à l'arrêt la tête tremble légèrement, et une fois sur trois elle
   fait un petit recalage juste à côté au lieu d'un grand balayage, comme si elle
   croyait avoir trouvé.

S'y ajoutent le profil de moteur (départ franc, freinage long, léger dépassement en
fin de course) et l'élargissement de la tache quand la tête vise loin sur les côtés :
le trajet du faisceau est plus long, donc la tache est plus large.

`SEEK SPD` et `SEEK HOLD` pilotent tout ça en live. `SEEK HOLD` à 0 donne un balayage
continu sans arrêt ; monté à 3, une tête qui s'attarde longuement sur chaque cible.
Le débattement, la distance au mur (donc la courbure des arcs) et la fréquence des
recalages sont réglables en `@export` dans l'inspecteur.

## L'effet sphère

Des cercles sont posés sur une sphère virtuelle (répartition de Fibonacci, pas de
paquets aux pôles) et projetés à l'écran. Le centre de l'écran est le point le plus
proche de l'œil. Deux effets se cumulent quand un cercle s'en éloigne :

1. **Il rétrécit** — c'est la perspective, pilotée par `SPH DEPTH`. À 1.2 l'écart de
   taille entre le cercle du centre et ceux du bord est spectaculaire ; à 10 la
   projection devient quasi orthographique et ils font tous la même taille.
2. **Il s'aplatit en ellipse** — on voit la surface de biais. Le petit axe pointe vers
   le centre et s'écrase progressivement, jusqu'au trait sur le bord.

C'est le **point 2 qui fait lire « sphère »** plutôt que « cercles de tailles
différentes ». Sans l'aplatissement, l'œil voit un tas de ronds ; avec, il reconstruit
le volume immédiatement.

Par défaut la face arrière est masquée (`SPH GLASS` = 0) : on ne voit que la calotte
tournée vers l'œil. C'est volontaire — quand les deux faces sont visibles, les cercles
du fond se projettent eux aussi près du centre et on ne distingue plus l'avant de
l'arrière. Monter `SPH GLASS` donne une sphère de verre, plus chargée mais plus étrange.

Coût mesuré : **+0,32 ms** à 40 cercles (le défaut), **+0,77 ms** à 80. Les cercles
passés derrière l'horizon ne sont ni calculés ni rendus.

## Ce qui est coupé par défaut

`HALO` et `GLITCH` démarrent à 0, et l'un comme l'autre est réellement éteint plutôt
que réglé à intensité nulle. Même principe pour `EFFET` du miroir et `RANDOMIZER`.

C'est un parti pris : les effets qui marquent s'allument à la demande, au moment
choisi, plutôt que de tourner en fond. Une scène qui démarre sobre laisse de la place
pour monter ; une scène qui démarre saturée n'a nulle part où aller.

## Le halo (glow)

Avec une machine à fumée, la diffusion du faisceau se fait **physiquement** dans l'air.
Le glow logiciel fait alors double emploi : il adoucit les bords et enlève au trait son
côté incisif. Il est donc à 0 par défaut, et à 0 la passe post-process est réellement
éteinte (`glow_enabled = false`) — pas juste réglée à intensité nulle.

Coût mesuré (RTX 3060, vsync off) : **~0,30 ms par image en 1080p**, ~0,68 ms en 4K.
En FPS bruts ça paraît énorme (1884 → 1203 fps) mais ça ne représente que 1,8 % du budget
d'une image à 60 Hz. Ce n'est pas un problème de performance, c'est un choix esthétique.

## Note projection

Un vidéoprojecteur a un contraste bien plus faible qu'un écran. Si les faisceaux manquent
de tranchant dans la fumée, baisser `SATURATION` vers 0.4–0.5 : un faisceau proche du blanc
traverse mieux la fumée qu'une couleur très saturée.

Penser à `H` puis à laisser l'UI s'effacer avant que le public arrive — les sliders sont
dans un `CanvasLayer`, donc ils sont projetés sur le mur avec le reste.

## Mesurer les perfs (F3)

Le compteur affiche `FPS`, le **temps par image en ms**, et le taux de rafraîchissement
de l'écran détecté. C'est le temps en ms qu'il faut regarder, pas les FPS : à 1200 fps,
0,3 ms de plus fait perdre 400 fps au compteur sans que ça pèse quoi que ce soit.
La seule question qui compte en projection est : *est-ce que je reste sous le budget
d'une image de mon vidéoprojecteur ?* (16,7 ms à 60 Hz, 13,3 ms à 75 Hz).

⚠️ Ne jamais juger le comportement du projet depuis un enregistrement `--write-movie` :
ce mode écrit un PNG par image sur le disque et bloque le rendu pendant l'encodage
(jusqu'à 110 ms par image quand le glow est actif, car les dégradés compressent très mal).
La fenêtre semble alors ramer, et les animations pilotées par `Tween` — comme l'effacement
de l'UI — paraissent saccader, alors que tout est parfaitement régulier en lancement normal.

## Structure

```
tools/
  build_chataigne_module.py   Régénère le module Chataigne depuis les réglages
scenes/
  main.tscn      Scène principale : WorldEnvironment + contrôleur + UI
  laser.tscn     Un trait, instancié N fois par le contrôleur
chataigne/
  Deferlante/    Module Chataigne prêt à installer
shaders/
  kaleidoscope.gdshader   Repli polaire en parts symétriques
scripts/
  kaleidoscope.gd   Pilote la passe plein écran du miroir
  palette.gd        État de couleur, partagé par référence avec les trois effets
  vj_controller.gd  Déclaration des réglages, lasers, routage OSC
  vj_param.gd       Un réglage : bornes, pas, application, formatage
  control_panel.gd  Panneau : lignes, clavier, effacement auto, compteur FPS
  glitch_circle.gd  Cercle de poursuite (lyre qui cherche) + glitchs aléatoires
  laser_line.gd     Trait qui tourne et rebondit sur les bords
  osc_server.gd     Récepteur OSC (UDP), messages et bundles
  sphere_circles.gd Cercles projetés sur une sphère virtuelle
```

L'UI est construite à l'exécution depuis la liste des paramètres : la scène ne contient
qu'un `VBoxContainer` vide, pas 22 paires de nœuds à maintenir à la main.

Un réglage qui ne fait qu'écrire une propriété se déclare en une ligne
(`_prop("PULSE", 0, 300, 5, 50.0, circle, "fluctuation_range")`) ; seuls ceux qui
demandent de la logique ont leur fonction. `VJParam` est le point de passage unique du
slider, du clavier et de l'OSC, ce qui évite d'avoir à savoir d'où vient un changement.

## Note sur le renderer

Le projet utilise **Forward+**. Le glow 2D n'est pas rendu par le renderer Compatibility :
en y rebasculant, le slider `GLOW` n'aurait plus aucun effet.

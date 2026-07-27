# Module Chataigne — Déferlante

Pilote les visuels [Déferlante](../../README.md) depuis
[Chataigne](https://github.com/benkuper/Chataigne) en OSC.

## Installation

Copier le dossier `Deferlante/` (celui qui contient `module.json`) dans le dossier
des modules de Chataigne :

| Système | Chemin |
| --- | --- |
| Linux | `~/Documents/Chataigne/modules/` |
| Windows | `C:\Users\<nom>\Documents\Chataigne\modules\` |
| macOS | `~/Documents/Chataigne/modules/` |

Vérifier en regardant où sont déjà les modules installés : c'est ce dossier-là, et
pas un autre.

Redémarrer Chataigne, puis **Add Module → Software → Deferlante**.

> **Si Chataigne fige à la création d'un nouveau projet**, supprimer le dossier
> `Deferlante/` et relancer. Le crash observé sur cette machine venait en réalité
> d'un autre module dont un thread refusait de s'arrêter, mais autant écarter
> celui-ci en premier pour trancher.

## Configuration

Le module part sur `127.0.0.1:9000`, ce qui marche tel quel si Chataigne et Godot
tournent sur la même machine. Sinon, régler `remoteHost` sur l'IP de la machine qui
affiche les visuels, et vérifier que le port 9000 UDP n'est pas bloqué.

Côté Godot, le port se change sur le nœud `OscServer` de `scenes/main.tscn`.

## Utilisation

Chaque réglage est une commande, rangée par menu (Global, Lasers, Poursuite,
Sphere), avec les **mêmes bornes que les sliders à l'écran** : un mapping Chataigne
balaye exactement la même plage, sans conversion.

Toutes les commandes ont un `mappingIndex: 0`, donc utilisables directement comme
cible d'un Mapping, d'un LFO, d'un fader MIDI ou d'un suivi audio.

Deux commandes dans le menu **Actions** : `Trigger Glitch` et `Randomize Colors`.

Le réglage le plus intéressant à automatiser est **Chaos** : un seul fader qui fait
passer l'ensemble de la scène du rangé au débordement.

## Sans ce module

Le module n'est qu'un confort. Godot écoute de l'OSC brut, donc n'importe quel
émetteur fait l'affaire — le module OSC générique de Chataigne, TouchOSC, un script.
Les adresses sont documentées dans le README principal.

## Ce module est généré

Ne pas l'éditer à la main : il est produit par `tools/build_chataigne_module.py` à
partir de la liste des réglages de Godot. Après avoir ajouté un réglage :

```
python3 tools/build_chataigne_module.py
```

Deux règles de format y sont encodées, apprises en cassant des choses : toute commande
doit avoir un bloc `parameters` **non vide**, et un module OSC déclare `hasInput: true`
avec une section `OSC Input` même désactivée. Aucun module qui fonctionne ne s'en écarte.

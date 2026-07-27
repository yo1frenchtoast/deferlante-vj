#!/usr/bin/env python3
"""Génère le module Chataigne à partir de la liste des réglages de Godot.

    python3 tools/build_chataigne_module.py

Le module est un miroir de `_build_params()` dans `scripts/vj_controller.gd` :
mêmes réglages, mêmes bornes, mêmes défauts. Le générer plutôt que le maintenir à
la main évite la seule panne qui ne se voit pas — un réglage ajouté côté Godot et
oublié côté console, ou pire, des bornes qui divergent en silence.

Le script s'arrête net s'il n'arrive pas à lire tous les réglages : mieux vaut une
erreur bruyante qu'un module amputé de deux commandes sans que personne ne le voie.
"""

import collections
import json
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
CONTROLEUR = RACINE / "scripts" / "vj_controller.gd"
SORTIE = RACINE / "chataigne" / "Deferlante"

VERSION = "5.0.0"
OSC_PORT = 9000

# Les sections du panneau Godot deviennent les menus de Chataigne. Le nom est
# déduit du préfixe de l'adresse : ajouter une section côté Godot suffit, il n'y
# a pas de liste à tenir à jour ici.
def menu_de(slug: str) -> str:
    return slug.split("/")[0].capitalize()

# Réglages qui comptent des entiers plutôt que des flottants.
ENTIERS = {"lasers/nombre", "sphere/cercles", "couleur/mode", "miroir/segments"}

DECLARATION = re.compile(
    r'_(?:fn|prop)\("([^"]+)", "([^"]+)", ([-\d.]+), ([-\d.]+), ([\d.]+), ([-\w.]+)'
)


def lire_reglages(source: str):
    """Extrait (slug, libellé, min, max, pas, défaut) de chaque réglage déclaré."""
    # Un défaut peut être un littéral ou une variable exportée : on résout les deux.
    constantes = {
        nom: float(val)
        for nom, val in re.findall(r"var (\w+):\s*\w+\s*=\s*([-\d.]+)", source)
    }

    reglages = []
    for slug, libelle, mini, maxi, pas, defaut in DECLARATION.findall(source):
        try:
            valeur = float(defaut)
        except ValueError:
            if defaut not in constantes:
                sys.exit(f"Défaut introuvable pour {slug} : {defaut}")
            valeur = constantes[defaut]
        reglages.append((slug, libelle, float(mini), float(maxi), float(pas), valeur))

    # Le garde-fou : autant de réglages lus que déclarés, sinon la regex a raté
    # une forme qu'on n'avait pas prévue et le module sortirait incomplet.
    attendus = len(re.findall(r'_(?:fn|prop)\("', source))
    if len(reglages) != attendus:
        sys.exit(f"Regex incomplète : {len(reglages)} réglages lus sur {attendus}")
    return reglages


def rappel(slug: str) -> str:
    """"sphere/rotation" -> "sphereRotation" : le nom de la fonction JS."""
    section, nom = slug.split("/")
    return section + nom.capitalize()


def sans_accent(texte: str) -> str:
    for accentue, plat in (("É", "E"), ("Ê", "E"), ("À", "A"), ("Ô", "O")):
        texte = texte.replace(accentue, plat)
    return texte


def construire(reglages):
    commandes = collections.OrderedDict()

    for slug, libelle, mini, maxi, _pas, defaut in reglages:
        menu = menu_de(slug)
        commandes[f"{menu} {sans_accent(libelle).title()}"] = collections.OrderedDict(
            [
                ("menu", menu),
                ("callback", rappel(slug)),
                (
                    "parameters",
                    {
                        "Value": collections.OrderedDict(
                            [
                                ("type", "Integer" if slug in ENTIERS else "Float"),
                                ("ui", "slider"),
                                ("min", mini),
                                ("max", maxi),
                                ("default", defaut),
                                ("mappingIndex", 0),
                            ]
                        )
                    },
                ),
            ]
        )

    # Un vrai sélecteur de couleur, qui envoie ses composantes d'un bloc.
    commandes["Couleur Choisie"] = collections.OrderedDict(
        [
            ("menu", "Couleur"),
            ("callback", "couleurRgb"),
            (
                "parameters",
                {
                    "Color": collections.OrderedDict(
                        [("type", "Color"), ("default", [1, 0.25, 0.1, 1]), ("mappingIndex", 0)]
                    )
                },
            ),
        ]
    )

    for nom, fonction in (("Trigger Glitch", "triggerGlitch"), ("Randomize Colors", "randomizeColors")):
        commandes[nom] = collections.OrderedDict(
            [
                ("menu", "Actions"),
                ("callback", fonction),
                # Toute commande doit avoir un bloc `parameters` non vide : une
                # commande sans paramètre a déjà fait planter Chataigne au scan.
                (
                    "parameters",
                    {
                        "Trigger": collections.OrderedDict(
                            [("type", "Boolean"), ("default", True), ("mappingIndex", 0)]
                        )
                    },
                ),
            ]
        )

    module = collections.OrderedDict(
        [
            ("name", "Deferlante"),
            ("type", "OSC"),
            ("path", "Software"),
            ("version", VERSION),
            ("description", "Controle les visuels VJ Deferlante (Godot) via OSC."),
            ("hasInput", True),
            ("hasOutput", True),
            ("hideDefaultCommands", True),
            (
                "defaults",
                collections.OrderedDict(
                    [
                        ("autoAdd", False),
                        (
                            "OSC Outputs",
                            {
                                "OSC Output": {
                                    "local": True,
                                    "remoteHost": "127.0.0.1",
                                    "remotePort": OSC_PORT,
                                }
                            },
                        ),
                        # Entrée déclarée mais désactivée : un module OSC sans
                        # section `OSC Input` s'écarte de tous ceux qui marchent.
                        ("OSC Input", {"enabled": False, "localPort": OSC_PORT + 1}),
                    ]
                ),
            ),
            ("scripts", ["deferlante.js"]),
            ("commands", commandes),
        ]
    )

    lignes = [
        "// Module Chataigne -> visuels Deferlante (Godot).",
        "// Genere par tools/build_chataigne_module.py, ne pas editer a la main.",
        "",
        "function init() {",
        '\tscript.log("Module Deferlante pret");',
        "}",
        "",
    ]
    for slug, *_ in reglages:
        lignes += [
            f"function {rappel(slug)}(value) {{",
            f'\tlocal.send("/deferlante/{slug}", value);',
            "}",
            "",
        ]
    lignes += [
        "// Le selecteur de couleur arrive en tableau [r, v, b, a].",
        "function couleurRgb(color) {",
        '\tlocal.send("/deferlante/couleur/rgb", color[0], color[1], color[2]);',
        "}",
        "",
        "function triggerGlitch(value) {",
        '\tlocal.send("/deferlante/glitch_now");',
        "}",
        "",
        "function randomizeColors(value) {",
        '\tlocal.send("/deferlante/randomize");',
        "}",
        "",
    ]
    return module, "\n".join(lignes)


def main():
    reglages = lire_reglages(CONTROLEUR.read_text(encoding="utf-8"))

    adresses = [slug for slug, *_ in reglages]
    if len(adresses) != len(set(adresses)):
        doublons = [a for a in adresses if adresses.count(a) > 1]
        sys.exit(f"Adresses OSC en collision : {sorted(set(doublons))}")

    module, javascript = construire(reglages)

    SORTIE.mkdir(parents=True, exist_ok=True)
    (SORTIE / "module.json").write_text(
        json.dumps(module, indent=2, ensure_ascii=True) + "\n", encoding="utf-8"
    )
    (SORTIE / "deferlante.js").write_text(javascript, encoding="utf-8")

    # Dernier filet : chaque callback déclaré doit avoir sa fonction JS.
    fonctions = set(re.findall(r"function (\w+)\(", javascript))
    orphelins = [c["callback"] for c in module["commands"].values() if c["callback"] not in fonctions]
    if orphelins:
        sys.exit(f"Callbacks sans fonction JS : {orphelins}")

    print(f"{len(reglages)} réglages -> {len(module['commands'])} commandes")
    print(f"écrit dans {SORTIE.relative_to(RACINE)}/")


if __name__ == "__main__":
    main()

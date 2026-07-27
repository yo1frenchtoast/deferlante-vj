// Module Chataigne -> visuels Deferlante (Godot).
// Genere par tools/build_chataigne_module.py, ne pas editer a la main.

function init() {
	script.log("Module Deferlante pret");
}

function globalVitesse(value) {
	local.send("/deferlante/global/vitesse", value);
}

function globalChaos(value) {
	local.send("/deferlante/global/chaos", value);
}

function globalHalo(value) {
	local.send("/deferlante/global/halo", value);
}

function couleurMode(value) {
	local.send("/deferlante/couleur/mode", value);
}

function couleurSaturation(value) {
	local.send("/deferlante/couleur/saturation", value);
}

function couleurRouge(value) {
	local.send("/deferlante/couleur/rouge", value);
}

function couleurVert(value) {
	local.send("/deferlante/couleur/vert", value);
}

function couleurBleu(value) {
	local.send("/deferlante/couleur/bleu", value);
}

function lasersNombre(value) {
	local.send("/deferlante/lasers/nombre", value);
}

function lasersEpaisseur(value) {
	local.send("/deferlante/lasers/epaisseur", value);
}

function lasersLongueur(value) {
	local.send("/deferlante/lasers/longueur", value);
}

function lasersRotation(value) {
	local.send("/deferlante/lasers/rotation", value);
}

function poursuiteRayon(value) {
	local.send("/deferlante/poursuite/rayon", value);
}

function poursuitePulsation(value) {
	local.send("/deferlante/poursuite/pulsation", value);
}

function poursuiteEpaisseur(value) {
	local.send("/deferlante/poursuite/epaisseur", value);
}

function poursuiteVitesse(value) {
	local.send("/deferlante/poursuite/vitesse", value);
}

function poursuiteArrets(value) {
	local.send("/deferlante/poursuite/arrets", value);
}

function poursuiteGlitch(value) {
	local.send("/deferlante/poursuite/glitch", value);
}

function sphereCercles(value) {
	local.send("/deferlante/sphere/cercles", value);
}

function sphereTaille(value) {
	local.send("/deferlante/sphere/taille", value);
}

function sphereRayon(value) {
	local.send("/deferlante/sphere/rayon", value);
}

function sphereRotation(value) {
	local.send("/deferlante/sphere/rotation", value);
}

function sphereProfondeur(value) {
	local.send("/deferlante/sphere/profondeur", value);
}

function sphereEpaisseur(value) {
	local.send("/deferlante/sphere/epaisseur", value);
}

function sphereVerre(value) {
	local.send("/deferlante/sphere/verre", value);
}

// Le selecteur de couleur arrive en tableau [r, v, b, a].
function couleurRgb(color) {
	local.send("/deferlante/couleur/rgb", color[0], color[1], color[2]);
}

function triggerGlitch(value) {
	local.send("/deferlante/glitch_now");
}

function randomizeColors(value) {
	local.send("/deferlante/randomize");
}

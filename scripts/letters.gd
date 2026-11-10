extends Node2D

## Plain letters, turning as they drift across the picture.
##
## Each letter is a character, a place on the screen, a colour and a rate of its own.
## SPIN is shared the way the lasers' is: one signed setting, whose sign turns every
## letter the same way and whose size sets how fast. What stays a letter's own is its
## share of that speed, so a field of them never turns in lockstep.
##
## Like `bezier.gd` it draws in a single canvas item and keeps no history: the ghost
## is the TRAIL setting's job.

## The faces, in the order of the FONT setting. Bundled with the show: a system font
## would make the same set look different on every machine it plays on.
const FONTS := [
	"res://fonts/Lato-Black.ttf",
	"res://fonts/Lato-Hairline.ttf",
	"res://fonts/LiberationSerif-Bold.ttf",
	"res://fonts/LiberationSerif-Italic.ttf",
	"res://fonts/LiberationMono-Bold.ttf",
]
## Names shown for the faces. The same in every language, so not translated.
const FONT_NAMES := ["BLACK", "HAIRLINE", "SERIF", "ITALIC", "MONO"]
const LOWER := "abcdefghijklmnopqrstuvwxyz"
const UPPER := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
## A letter's share of the shared speed, at the slowest and the fastest.
const RATE_MIN := 0.35
const RATE_MAX := 1.0
## Slowest and fastest a letter drifts, in screens per second at MOVE = 1.
const DRIFT_MIN := 0.04
const DRIFT_MAX := 0.12
## Turns per second at SPIN = 1 and a share of 1.
const TURNS := 0.25
const MAX_STEP := 0.1

## Number of letters. 0 switches the effect off outright — no work, no draw.
@export var count: int = 0:
	set(value):
		var wanted := maxi(0, value)
		if wanted == count:
			return
		count = wanted
		if is_inside_tree():
			_rebuild()
## Height of a letter, as a fraction of the picture's height.
@export var letter_size: float = 0.2
## Signed, like the lasers': the sign is the direction of every letter.
@export var spin: float = 0.6
## 0 lower case, 1 capitals, 2 either, drawn at random for each letter.
## How fast the letters travel, as a multiple of their own pace. 0 leaves them where
## they were put, turning on the spot. The global SPEED scales it too.
@export var travel: float = 0.5
@export var letter_case: int = 1:
	set(value):
		if value == letter_case:
			return
		letter_case = value
		if is_inside_tree():
			_reroll_chars()
@export var font_index: int = 0:
	set(value):
		font_index = clampi(value, 0, FONTS.size() - 1)
		queue_redraw()
@export var hue_drift: float = 0.2

var halo_amount: float = 0.0
var speed_scale: float = 1.0
var chaos: float = 0.0
var palette: Palette

## Place of each letter in screens (0..1 both ways).
var _pos: PackedVector2Array = []
var _vel: PackedVector2Array = []
var _angle: PackedFloat32Array = []
var _rate: PackedFloat32Array = []
var _hues: PackedFloat32Array = []
## Per letter: a draw in [0, 1) that picks its character and its case.
var _pick: PackedFloat32Array = []
var _chars: PackedStringArray = []
var _fonts: Array = []


func _ready():
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	for path in FONTS:
		_fonts.append(load(path))
	_rebuild()


func _rebuild():
	var had := _hues.size()
	_pos.resize(count)
	_vel.resize(count)
	_angle.resize(count)
	_rate.resize(count)
	_hues.resize(count)
	_pick.resize(count)
	_chars.resize(count)
	for i in range(had, count):
		_spawn(i)
	set_process(count > 0)
	queue_redraw()


func _spawn(index: int):
	_pos[index] = Vector2(randf_range(0.05, 0.95), randf_range(0.08, 0.92))
	_vel[index] = Vector2.from_angle(randf() * TAU) * randf_range(DRIFT_MIN, DRIFT_MAX)
	_angle[index] = randf() * TAU
	_rate[index] = randf_range(RATE_MIN, RATE_MAX)
	_hues[index] = randf()
	_pick[index] = randf()
	_chars[index] = _char_for(index)


func _char_for(index: int) -> String:
	var letters := LOWER
	if letter_case == 1:
		letters = UPPER
	elif letter_case == 2 and fmod(_pick[index] * 7.0, 1.0) < 0.5:
		letters = UPPER
	return letters[int(_pick[index] * 26.0) % 26]


func _reroll_chars():
	for i in range(count):
		_chars[i] = _char_for(i)
	queue_redraw()


func randomize_look():
	for i in range(count):
		_hues[i] = randf()
		_pick[i] = randf()
		_pos[i] = Vector2(randf_range(0.05, 0.95), randf_range(0.08, 0.92))
	_reroll_chars()


func _process(delta: float):
	var step := minf(delta, MAX_STEP) * speed_scale * spin * TAU * TURNS
	for i in range(count):
		_angle[i] = fposmod(_angle[i] + step * _rate[i] * (1.0 + chaos * sin(_angle[i] * 3.0)),
			TAU)
	var run := minf(delta, MAX_STEP) * speed_scale * travel
	if run != 0.0:
		for i in range(count):
			var moved := _pos[i] + _vel[i] * run
			var v := _vel[i]
			# Reflect inside the margins the letters are placed in, so a letter turns
			# back before it leaves the picture rather than after.
			if moved.x < 0.05 or moved.x > 0.95:
				moved.x = clampf(moved.x, 0.05, 0.95)
				v.x = -v.x
			if moved.y < 0.08 or moved.y > 0.92:
				moved.y = clampf(moved.y, 0.08, 0.92)
				v.y = -v.y
			_pos[i] = moved
			_vel[i] = v
	if hue_drift > 0.0:
		var slide := delta * hue_drift * 0.1
		for i in range(count):
			_hues[i] = fposmod(_hues[i] + slide, 1.0)
	queue_redraw()


func _draw():
	if count == 0 or palette == null or _fonts.is_empty():
		return
	var font: Font = _fonts[font_index]
	var view := get_viewport_rect().size
	var px := maxi(8, int(view.y * letter_size))
	var up := font.get_ascent(px)
	var down := font.get_descent(px)
	for i in range(count):
		var ch := _chars[i]
		var half := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / 2.0
		# Turn about the middle of the line box, so the letter stays where it was put.
		draw_set_transform(_pos[i] * view, _angle[i], Vector2.ONE)
		var at := Vector2(-half, (up - down) / 2.0)
		var tint := palette.resolve(_hues[i])
		if halo_amount > 0.0:
			for ring in Halo.RINGS:
				font.draw_string_outline(get_canvas_item(), at, ch, HORIZONTAL_ALIGNMENT_LEFT,
					-1, px, int(ring[0] * halo_amount * 0.5),
					Color(tint.r, tint.g, tint.b,
						tint.a * clampf(ring[1] * halo_amount, 0.0, 1.0)))
		font.draw_string(get_canvas_item(), at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func use_palette(p: Palette):
	palette = p

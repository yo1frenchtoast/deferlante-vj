extends CanvasLayer

## Motion blur: the previous frame, dimmed, under the new one.
##
## It sits on a negative layer, so it is drawn before any effect rather than over
## them — it is the floor the frame is painted on, not a filter laid on top.
##
## Where the previous frame comes from is the whole design. The short way is to
## tell the SubViewport never to clear itself, leave last frame's pixels sitting in
## the render target and dim them in place. Under the Compatibility renderer, which
## is the one this show ships on, `CLEAR_MODE_NEVER` makes the viewport render
## nothing whatsoever: not the trail, not the effects, not even a flat rectangle
## drawn on top of it — the wall goes an even grey. So the frame is kept by hand
## instead. `Echo` is a viewport whose only job is to hold a copy of the show, one
## frame behind, and this pass reads that copy. It costs a full-screen blit and one
## more 1080p texture, which is why `Echo` stops updating outright at 0 rather than
## quietly copying a frame nobody reads.
##
## The mirror lives at a positive layer, so a fold is already in the image the copy
## holds. The trail is therefore folded too, and a turning mirror walks it round the
## wedges — which looks like a spiral, and is worth knowing before it surprises
## somebody. It cannot run away: this pass only ever samples and dims, so no light
## is created, and `bias` guarantees each frame's leftovers reach black.

@onready var rect: ColorRect = $Rect
@onready var echo: SubViewport = $Echo
@onready var frame: TextureRect = $Echo/Frame

## 0 is off. The pass is genuinely switched off there, not left running as an
## identity: it covers the whole screen, and a projector rarely has the frame to
## spare — the machine in the room is often the weakest one the show ever runs on.
var amount: float = 0.0

## Seconds for the trail to fade out, at the two ends of the setting. The floor is
## a couple of frames, which reads as a softened edge rather than an echo; the
## ceiling is half a second, by which point a laser sweep writes a solid ribbon.
const SHORTEST := 0.05
const LONGEST := 0.5

## Taken off every channel each frame, as a fraction of full scale. Just over one
## 8-bit step, so the dimmest survivor of the multiply still reaches black.
const FLOOR_PER_FRAME := 1.5 / 255.0


func _ready():
	var show := get_viewport()
	echo.size = show.size
	# Both ends of the loop are wired here rather than in the scene: a
	# `ViewportTexture` saved in a scene file is a node path, and this one would
	# have to point back out of the viewport it is drawn in — which is exactly the
	# arrangement the editor refuses to reopen. Held as plain references there is
	# no path to resolve and nothing to break when a node is moved.
	frame.texture = show.get_texture()
	rect.material.set_shader_parameter("echo_tex", echo.get_texture())
	_apply()


func set_amount(value: float):
	amount = value
	_apply()


func _apply():
	rect.visible = amount > 0.0
	echo.render_target_update_mode = (SubViewport.UPDATE_ALWAYS if rect.visible
		else SubViewport.UPDATE_DISABLED)


func _process(delta: float):
	if not rect.visible:
		return
	# Decay in seconds rather than per frame: the same setting has to mean the same
	# trail on a laptop at 60 and on the projector when it drops to 30. `keep` is
	# what survives one frame of that decay, so a slow frame eats proportionally
	# more of the ghost.
	var seconds: float = lerpf(SHORTEST, LONGEST, clampf(amount, 0.0, 1.0))
	var material: ShaderMaterial = rect.material
	material.set_shader_parameter("keep", exp(-delta / seconds))
	material.set_shader_parameter("bias", FLOOR_PER_FRAME * delta * 60.0)

extends Node

## Sends the show out as a Spout source, for Resolume/TouchDesigner/OBS downstream.
##
## Spout is Windows-only, and the `SpoutOutput` class it needs only exists where the
## godot-spout extension's DLLs shipped with the export — the Linux and Android
## builds never see it. `ClassDB.class_exists` is checked before anything else
## touches that name, the same way `AudioRouting.available()` guards this project's
## other Windows/Linux-only surface (see `audio_routing.gd`), so those builds load
## this scene with nothing missing rather than failing to parse a class that is not
## there.
##
## The sender is built from code rather than as a scene node for exactly that
## reason: a `SpoutOutput` node saved into `main.tscn` would fail to instantiate on
## a platform that never got the extension.
##
## Measured on this project's own two supported renderers: the D3D12 backend (under
## Forward+, which is also the only renderer this addon's own demo ships configured
## for) sends cleanly. The OpenGL backend — meant to cover Compatibility, this
## project's *default* renderer — instead fails `SpoutOpenGLBackend: Could not get
## OpenGL texture handle` on every single frame in the prebuilt release. Rather than
## start a sender that spends the whole show failing silently loud, this only starts
## where Godot is actually running on a RenderingDevice backend (Forward+ or
## Mobile) — `RenderingServer.get_rendering_device()` is null under Compatibility,
## which is the one call that tells the two apart without guessing at a renderer
## name. Turning SPOUT on while still on Compatibility is a switch to Forward+ away,
## the same trade the renderer row in the launcher already asks for.

const CHANNEL_NAME := "Déferlante"

var _output: Node = null


## Point the sender at `texture` and start it, or do nothing where Spout cannot run.
## Idempotent: called once, from `vj_controller.gd`, only when the launch setting
## asks for it.
func start(texture: Texture2D):
	if _output != null:
		return
	if not ClassDB.class_exists("SpoutOutput"):
		push_warning("Spout: extension not available on this platform, staying off")
		return
	if RenderingServer.get_rendering_device() == null:
		push_warning("Spout: needs the Forward+ renderer, staying off under Compatibility")
		return
	_output = ClassDB.instantiate("SpoutOutput")
	add_child(_output)
	_output.set("channel_name", CHANNEL_NAME)
	_output.set("texture", texture)

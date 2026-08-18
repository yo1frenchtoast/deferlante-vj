extends Node

## Everything that has to be decided *before* the show starts, in one place.
##
## Most of this project is adjustable live, on purpose — a setting you cannot reach
## mid-set may as well not exist. These are the exceptions, and they are exceptions
## for reasons the engine imposes rather than reasons of taste:
##
## - the **renderer** is fixed by Godot before a single script runs, so changing it
##   means starting the process again (`launcher.gd` does exactly that);
## - the **ports** have to be bound before anything can listen on them;
## - the **audio source** is bound when capture opens and, measured, cannot be
##   re-opened afterwards — see the note in `audio_reactor.gd`;
## - the **panel** being absent is a decision about the room, not a look.
##
## Registered as the `Launch` autoload, so it is loaded and ready before any node of
## the scene asks it anything. Written by `launcher.gd`, read by whoever needs it.

const PATH := "user://launch.cfg"

## Reachable from this machine and nowhere else.
const LOCAL := "127.0.0.1"

## `forward_plus` or `gl_compatibility`. The project ships Compatibility: it is
## twice as fast in software rendering, and this draws nothing but lines. Forward+
## exists here for one reason — it is the only one that antialiases.
var rendering_method: String = "gl_compatibility"
## Antialiasing, in samples: 0, 2, 4 or 8. Only Forward+ honours it; the
## Compatibility renderer ignores 2D MSAA entirely (verified — two captures of the
## same seeded frame came back identical to the pixel).
var msaa: int = 0
## Empty means "whatever the screen is". Anything else is forced.
var resolution := Vector2i.ZERO
var fullscreen: bool = false
var vsync: bool = true
## 0 is uncapped. Worth setting on a projector: frames past its refresh rate cost
## exactly as much to draw and nobody ever sees them.
var max_fps: int = 0
## Empty leaves `audio_reactor.gd` to its own automatic pick.
var audio_device: String = ""
## The settings panel never appears at all. For a machine that only projects, where
## the panel would be on the wall and the driving happens from a phone.
var hide_panel: bool = false
## The address the web surface binds to. Loopback by default: the control surface
## has no password, so being reachable from the whole room is something one turns
## on, knowing the room. The launcher offers the machine's own addresses.
var web_bind: String = LOCAL
var web_port: int = 7331
## The same decision for OSC, kept separate because the answers differ: the phone
## driving the surface and the console sending OSC are rarely the same machine, and
## letting one in is no reason to let the other.
var osc_bind: String = LOCAL
var osc_port: int = 9000
## `Lang.FR` / `Lang.EN`. Held here so the launcher speaks the same tongue as the
## show it is about to start.
var language: int = 0


func _ready():
	load_from_disk()


func load_from_disk():
	var cfg := ConfigFile.new()
	# A missing file is the ordinary first run, not an error: the defaults above are
	# already the shipping configuration.
	if cfg.load(PATH) != OK:
		return
	rendering_method = cfg.get_value("render", "method", rendering_method)
	msaa = cfg.get_value("render", "msaa", msaa)
	resolution = cfg.get_value("render", "resolution", resolution)
	fullscreen = cfg.get_value("render", "fullscreen", fullscreen)
	vsync = cfg.get_value("render", "vsync", vsync)
	max_fps = cfg.get_value("render", "max_fps", max_fps)
	audio_device = cfg.get_value("io", "audio_device", audio_device)
	web_bind = cfg.get_value("io", "web_bind", web_bind)
	web_port = cfg.get_value("io", "web_port", web_port)
	osc_bind = cfg.get_value("io", "osc_bind", osc_bind)
	osc_port = cfg.get_value("io", "osc_port", osc_port)
	hide_panel = cfg.get_value("ui", "hide_panel", hide_panel)
	language = cfg.get_value("ui", "language", language)


## The private addresses this machine answers on. The same test the web surface has
## always used to decide what to print, in one place now that the launcher offers the
## list rather than the code picking the first match.
static func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.begins_with("192.") or a.begins_with("10.") or a.begins_with("172."):
			out.append(a)
	return out


## What to hand `listen()` or `bind()`. A saved address is re-checked rather than
## trusted: DHCP hands out a different one often enough, and binding to an address
## the machine no longer holds fails outright — a server silently off is worse than
## one that came back narrower than it was left.
static func bind_address(saved: String) -> String:
	if saved == LOCAL or local_addresses().has(saved):
		return saved
	return LOCAL


func save():
	var cfg := ConfigFile.new()
	cfg.set_value("render", "method", rendering_method)
	cfg.set_value("render", "msaa", msaa)
	cfg.set_value("render", "resolution", resolution)
	cfg.set_value("render", "fullscreen", fullscreen)
	cfg.set_value("render", "vsync", vsync)
	cfg.set_value("render", "max_fps", max_fps)
	cfg.set_value("io", "audio_device", audio_device)
	cfg.set_value("io", "web_bind", web_bind)
	cfg.set_value("io", "web_port", web_port)
	cfg.set_value("io", "osc_bind", osc_bind)
	cfg.set_value("io", "osc_port", osc_port)
	cfg.set_value("ui", "hide_panel", hide_panel)
	cfg.set_value("ui", "language", language)
	cfg.save(PATH)


## The half of the configuration that can be applied to a running process. The
## renderer is the other half, and it is why `launcher.gd` sometimes has to start
## the process over.
func apply_runtime():
	if resolution != Vector2i.ZERO:
		DisplayServer.window_set_size(resolution)
		# Re-centre by hand: growing a window from its top-left corner walks it off
		# the bottom of the screen on the second launch.
		var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
		DisplayServer.window_set_position((screen - resolution) / 2)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = maxi(0, max_fps)
	# Ignored outright by the Compatibility renderer, so it is only ever set to
	# something other than off when Forward+ is running.
	get_viewport().msaa_2d = msaa_mode()


## Samples to the viewport enum. Anything unexpected reads as off rather than as
## the nearest guess: a saved file from a future version should degrade quietly.
func msaa_mode() -> Viewport.MSAA:
	match msaa:
		2: return Viewport.MSAA_2X
		4: return Viewport.MSAA_4X
		8: return Viewport.MSAA_8X
		_: return Viewport.MSAA_DISABLED


## True when antialiasing is actually available. Forward+ only — see `msaa`.
func msaa_available() -> bool:
	return rendering_method == "forward_plus"

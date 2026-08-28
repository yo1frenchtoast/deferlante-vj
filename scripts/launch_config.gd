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
##   re-opened afterwards — see the note in `audio_reactor.gd` — so which output the
##   show listens to is routed by the launcher, before the show exists;
## - the **panel** being absent is a decision about the room, not a look.
##
## Registered as the `Launch` autoload, so it is loaded and ready before any node of
## the scene asks it anything. Written by `launcher.gd`, read by whoever needs it.

const PATH := "user://launch.cfg"

## What each of the choices above may be set to. They live with the settings rather
## than with the screen that shows them, because the launcher is no longer the only
## thing offering them: the web surface builds the same rows from the same lists.
const RESOLUTIONS := [
	Vector2i.ZERO,          # the screen's own
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1600, 900),
	Vector2i(1680, 1050),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
	Vector2i(2560, 1440),
	Vector2i(2560, 1600),
	Vector2i(3840, 2160),
]
const MSAA_SAMPLES := [0, 2, 4, 8]
## 0 is uncapped; the rest are the refresh rates a projector or a monitor actually
## runs at. A free-typed number would be one more thing to get wrong in the dark.
const MAX_FPS := [0, 30, 60, 75, 120, 144, 240]

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
## The output whose sound the show listens to, as PipeWire names it. Empty means
## whichever output is playing when the show starts. Applied by `launcher.gd`
## through `AudioRouting`, which is the only way the choice actually holds — see
## the note there. Linux only; ignored where there is no `pactl`.
var audio_sink: String = ""
## The capture Godot itself is pointed at. Only used where `AudioServer.input_device`
## is honoured, which the PulseAudio backend does not — there `audio_sink` is the
## row the launcher shows instead. Empty leaves `audio_reactor.gd` its automatic pick.
var audio_device: String = ""
## The settings panel never appears at all. For a machine that only projects, where
## the panel would be on the wall and the driving happens from a phone.
var hide_panel: bool = false
## The preset slot to start the show on, or 0 for none. Not a duplicate of the
## RANDOMIZER slider or of any other setting: it is the *state* the show comes up
## in, and the one thing no surface can reach, because none of them is connected
## yet. A machine on a shelf with nobody at it starts on the look it was left with,
## and a slot saved with RANDOMIZER up starts a show that runs itself.
var auto_start: int = 0
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
## `Lang.EN` / `Lang.FR`. Held here so the launcher speaks the same tongue as the
## show it is about to start. Written to disk as a code rather than as the enum
## value: the value is a position, and a position means nothing to a file that
## outlives the order it was written in.
var language: int = Lang.FR


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
	audio_sink = cfg.get_value("io", "audio_sink", audio_sink)
	audio_device = cfg.get_value("io", "audio_device", audio_device)
	web_bind = cfg.get_value("io", "web_bind", web_bind)
	web_port = cfg.get_value("io", "web_port", web_port)
	osc_bind = cfg.get_value("io", "osc_bind", osc_bind)
	osc_port = cfg.get_value("io", "osc_port", osc_port)
	hide_panel = cfg.get_value("ui", "hide_panel", hide_panel)
	auto_start = clampi(int(cfg.get_value("ui", "auto_start", auto_start)), 0, 9)
	# Files written before this was a code hold the old enum value, where 0 meant
	# French and 1 meant English. Reading them as the enum stands now would open
	# the show in the other tongue, so an int is migrated rather than trusted.
	var stored = cfg.get_value("ui", "language", Lang.code_of(language))
	if stored is String:
		language = Lang.value_of_code(stored, language)
	else:
		language = Lang.EN if int(stored) == 1 else Lang.FR


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
	cfg.set_value("io", "audio_sink", audio_sink)
	cfg.set_value("io", "audio_device", audio_device)
	cfg.set_value("io", "web_bind", web_bind)
	cfg.set_value("io", "web_port", web_port)
	cfg.set_value("io", "osc_bind", osc_bind)
	cfg.set_value("io", "osc_port", osc_port)
	cfg.set_value("ui", "hide_panel", hide_panel)
	cfg.set_value("ui", "auto_start", auto_start)
	cfg.set_value("ui", "language", Lang.code_of(language))
	cfg.save(PATH)


## Whether starting over is something this platform can actually be asked to do.
##
## Android cannot, and the way it fails is the worst of all of them: `OS.create_process`
## there is not a second process at all, it is this activity being told to restart
## itself. The engine tears the fragment down while the GL thread is still stepping
## it, and the SIGSEGV that follows kills the app before Android can bring it back.
## The show does not restart — it disappears, and somebody has to walk to the
## projector and start it by hand.
##
## Measured on the projector across repeated presses: quitting afterwards or not,
## and with the render loop stopped first, the crash lands in `GodotLib_step` every
## time and a successful restart is a coin toss at best. The bug is below this
## project, so this refuses rather than gambles, and the surfaces ask first so they
## can offer an honest instruction instead of a button that empties the room.
func can_relaunch() -> bool:
	return not OS.has_feature("android")


## Start this show again on the settings as they now stand, and skip the screen
## that would ask for them a second time.
##
## The renderer is passed as a flag rather than left to the file: Godot fixes it
## before a single script runs, so the new process has to be told on the way in.
## Everything else is read from disk, which is why the caller saves first.
##
## Standing the old one down is part of the job, because whether that is even
## wanted depends on the platform — see below.
##
## Returns false when the platform will not start a second process at all, and
## then nothing has happened: the show is still running and still on the old
## settings. Never fatal on its own — what to do with a machine that cannot
## restart is the caller's to decide, and being stranded on a black screen ten
## minutes before doors is worse than any one setting being wrong.
func relaunch() -> bool:
	if not can_relaunch():
		return false

	var args := PackedStringArray()
	if OS.has_feature("editor"):
		# From the editor the executable is Godot itself, which needs telling which
		# project to run.
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--rendering-method", rendering_method])
	# After a bare `--`, Godot stops interpreting and hands the rest to the project.
	# Anything it does not recognise before that point is a fatal argument error.
	args.append_array(["--", "--skip-launcher"])
	if OS.create_process(OS.get_executable_path(), args) == -1:
		return false

	# A second show is now running. Two of them fighting over one set of ports is
	# exactly the mess the launcher's latch exists to avoid, so standing this one
	# down is the last thing left to do.
	get_tree().quit()
	return true


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
	# Measured against the renderer that is *running*, not the one the file asks for.
	# The two come apart on the `--skip-launcher` path, which applies the saved answer
	# without passing the screen that would have relaunched the process for it: the
	# file says Forward+, the engine came up in Compatibility, and setting 2D MSAA
	# there earns a warning on every single start and changes not one pixel.
	get_viewport().msaa_2d = (msaa_mode() if renderer_honours_msaa()
		else Viewport.MSAA_DISABLED)


## Samples to the viewport enum. Anything unexpected reads as off rather than as
## the nearest guess: a saved file from a future version should degrade quietly.
func msaa_mode() -> Viewport.MSAA:
	match msaa:
		2: return Viewport.MSAA_2X
		4: return Viewport.MSAA_4X
		8: return Viewport.MSAA_8X
		_: return Viewport.MSAA_DISABLED


## True when the antialiasing setting is worth offering: it describes the renderer
## the operator has *chosen*, which is what the launcher's row is about. The next
## process is the one that will honour it.
func msaa_available() -> bool:
	return rendering_method == "forward_plus"


## True when the renderer *already running* honours it, which is a different question
## and the one that matters at the moment of applying.
func renderer_honours_msaa() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"

extends Node

## The operator's window: a live picture of the projection, with the settings panel
## over it.
##
## Two screens, two jobs. The main window keeps the show and nothing else — it is
## what the projector puts on the wall, and the panel leaves it entirely. This
## window is what the operator reads: the same image, small, with the sliders on top
## of it exactly as they have always been. Nothing about the panel changes but the
## screen it is on, so the hand goes where it went last night.
##
## The preview costs no second render. `ShowViewport` is already a texture — the
## Spout sender has been sending it out for versions — and this hangs the same
## texture in another window. What it does cost is one more window to present each
## frame, which is why it is opened on purpose rather than always.
##
## On a platform with a single window (Android) none of this exists: `open()` says
## so and stands down.

## Hands the console window's keys to the show. A window is a viewport of its own,
## and input stops there; without this the arrows would work in one window and the
## presets in the other.
class KeyRelay extends Node:
	var route: Callable

	func _unhandled_input(event: InputEvent):
		route.call(event)


## Where the panel lives when the console is closed. Held rather than looked up: by
## the time the console is shut, the panel is somewhere else entirely.
var _home: Node
var _panel: CanvasLayer
var _show: SubViewport
var _lang: Lang
## The show's key router, so both windows answer to the same keys.
var route_key: Callable

var window: Window

signal changed(open: bool)


func setup(panel: CanvasLayer, show_viewport: SubViewport, lang: Lang, router: Callable):
	_panel = panel
	_home = panel.get_parent()
	_show = show_viewport
	_lang = lang
	route_key = router


func is_open() -> bool:
	return window != null


func available() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS)


func toggle():
	if is_open():
		close()
	else:
		open()


func open() -> bool:
	if is_open():
		return true
	if not available():
		push_warning("Console: " + _lang.text_in("console.none", Lang.EN))
		return false

	# Godot draws extra windows inside the main one unless told otherwise, which
	# would put the console on the wall — the one place it must not be.
	get_tree().root.gui_embed_subwindows = false

	window = Window.new()
	window.title = _lang.text("console.title")
	window.min_size = Vector2i(960, 540)
	window.size = _console_size()
	# Closing the console is closing a window, not leaving the show. The projection
	# carries on with nobody reading the panel, which is what a set looks like once
	# it is running anyway.
	window.close_requested.connect(close)
	get_tree().root.add_child(window)
	_place_on_operator_screen()
	# Maximised rather than merely large: the panel is drawn for a 1080p screen, and
	# every pixel short of that is one the settings have to be shrunk into. The
	# window keeps its bar, so the console can still be moved, resized or put behind
	# something — which a full-screen window cannot.
	window.mode = Window.MODE_MAXIMIZED

	window.add_child(_build_preview())

	_panel.reparent(window)
	# Laid out for the projector a moment ago; this window is a different shape.
	_panel.set_on_console(true)

	# The keyboard reaches the window that has the focus, and from now on that is
	# usually this one. Everything typed here is handed to the show's own router, so
	# that both windows answer to the same keys.
	var relay := KeyRelay.new()
	relay.route = route_key
	window.add_child(relay)

	changed.emit(true)
	return true


func close():
	if not is_open():
		return
	_panel.reparent(_home)
	# Back over the projection, the panel takes its own habits up again — including
	# the launcher's answer about whether it should be on the wall at all.
	_panel.set_on_console(false)
	var going := window
	window = null
	going.queue_free()
	changed.emit(false)


## The picture of the projection, kept to the projector's shape and framed.
##
## The frame is not decoration. The show is neon on black and the console window is
## black around it, so without a line there is no telling where the projection ends
## — and where the edge is happens to be the one thing the preview exists to answer:
## a stroke drifting out of frame looks identical to a stroke on a wider screen.
func _build_preview() -> Control:
	var shape := AspectRatioContainer.new()
	shape.set_anchors_preset(Control.PRESET_FULL_RECT)
	shape.ratio = float(_show.size.x) / float(_show.size.y)
	shape.stretch_mode = AspectRatioContainer.STRETCH_FIT
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var edge := StyleBoxFlat.new()
	edge.bg_color = Color(0, 0, 0, 0)
	edge.set_border_width_all(1)
	# Just enough to find in a dark room, not enough to read as part of the show.
	edge.border_color = Color(1, 1, 1, 0.2)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", edge)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape.add_child(frame)

	var preview := TextureRect.new()
	preview.texture = _show.get_texture()
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# A click belongs to the panel over it, never to this.
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(preview)
	return shape


## Two thirds of the screen it opens on, which leaves the window manager's
## decorations and a taskbar room to exist without the operator having to move it.
func _console_size() -> Vector2i:
	var screen := DisplayServer.screen_get_size(_operator_screen())
	if screen.x <= 0 or screen.y <= 0:
		return Vector2i(1280, 720)
	return Vector2i(screen * 2 / 3)


## The screen the projection is not on, where there is one. The show is usually
## already full-screen on the projector by the time this opens, so "somewhere else"
## is the whole requirement — and on a single-screen machine the console simply
## opens over the show, which is what somebody testing at a desk wants anyway.
func _operator_screen() -> int:
	var projecting := DisplayServer.window_get_current_screen(DisplayServer.MAIN_WINDOW_ID)
	if DisplayServer.get_screen_count() < 2:
		return projecting
	return 0 if projecting != 0 else 1


func _place_on_operator_screen():
	var screen := _operator_screen()
	window.current_screen = screen
	var origin := DisplayServer.screen_get_position(screen)
	var room := DisplayServer.screen_get_size(screen)
	window.position = origin + (room - window.size) / 2

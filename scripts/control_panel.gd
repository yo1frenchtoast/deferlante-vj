extends CanvasLayer

## Settings panel: one row per parameter, keyboard navigation, auto-hide and an
## FPS readout.
##
## The panel only comes back on a gesture from the operator. A value arriving over
## OSC does update its slider, but without waking the display: otherwise a
## Chataigne automation would leave the sliders on screen — and therefore
## projected on the wall — for the whole set.

## Seconds of inactivity before the sliders fade out on their own.
@export var hide_delay: float = 4.0
@export var show_fps: bool = false

@onready var rows: VBoxContainer = $Controls
## The shortcut list and the machine's address, kept at the top of the screen so
## the bottom belongs entirely to the settings — that is where the eye goes when
## reaching for a slider, and where the columns want to grow.
@onready var help_box: VBoxContainer = $Help
@onready var fps_label: Label = $FpsLabel

var params: Array[VJParam] = []
var selected: int = 0
## Pinned: the panel stays on screen while settings are being dialled in.
var pinned: bool = false

var _lang: Lang
var _sliders: Array[HSlider] = []
## Setting indices in the order the panel puts them on screen, which is no longer
## the order they were declared in. `↑` and `↓` walk this rather than `params`: the
## arrows have to move to the row under the one you are looking at, and a section
## that reads third down the first column may well be declared sixth.
var _reading_order: PackedInt32Array = []
var _name_labels: Array[Label] = []
var _value_labels: Array[Label] = []
var _section_labels: Array[Label] = []
var _section_keys: PackedStringArray = []
var _help_labels: Array[Label] = []
## Where to reach the machine, kept apart from the shortcut lines because it is
## looked up rather than remembered — it is what gets typed into a phone.
var _status: Label
var _status_text: String = ""

## Panel brightness. The panel is projected on the wall along with the visuals, so
## turning it down lets the operator keep reading it at arm's length while the room
## barely sees it. 1 is the ordinary look.
var brightness: float = 1.0
## An external surface — phone, pad, console — is driving. The panel ducks out of
## the way *and* stops taking the mouse: dimming alone would hide the sliders
## without making them any harder to nudge by accident, which is the actual risk.
##
## Moving the mouse does not end it, but clicking does. A brush of the trackpad is
## not a decision; a click is. The click that ends it is swallowed rather than
## passed on, so the gesture that takes the panel back cannot also move a slider —
## the same way clicking an unfocused window activates it without pressing what
## happens to be under the pointer.
var external_control: bool = false
var _restore_brightness: float = 1.0

var _idle: float = 0.0
var _fade: Tween

# The FPS readout is averaged over 0.25 s, otherwise the number is unreadable.
const FPS_REFRESH := 0.25
var _fps_elapsed: float = 0.0
var _fps_frames: int = 0

const HELP_KEYS := ["help.params", "help.actions", "help.keys", "help.pad"]

## Section header colour: warm, so it stands apart from the white values without
## pulling more attention than the settings themselves.
const SECTION_COLOR := Color(1.0, 0.72, 0.35)

## The panel's reading order, which is deliberately not the order the settings are
## declared in. `_build_params()` is grouped by what drives what; the panel is
## grouped by when you touch it.
##
## SETUP is what you settle before a set and then leave alone — the room, the track,
## the colour. It gets the first column to itself, so the hand goes to the same place
## every night whatever effects the show has gained since.
##
## PLAY is the instruments, and it spreads over the columns after it.
const SETUP_SECTIONS := ["section.global", "section.color", "section.mirror", "section.blur",
	"section.audio"]
const PLAY_SECTIONS := ["section.spot", "section.lasers", "section.sphere", "section.warp"]

# Rough heights, used only to decide where to break into a new column. They do not
# have to be exact — being a few pixels out costs nothing, and the alternative is
# building the panel, measuring it, then rebuilding it a frame later.
const ROW_HEIGHT := 27
const HEADER_HEIGHT := 30
const HELP_HEIGHT := 0

## Narrowest a column may be, so a panel of short labels does not look cramped. The
## grid widens past these on its own when the text asks for it.
const MIN_NAME_WIDTH := 130.0
const MIN_VALUE_WIDTH := 100.0

## Pixels kept clear at the top and bottom of the screen.
@export var vertical_margin: float = 48.0

var _column: GridContainer
## The run of columns, kept so the panel can be measured against the window it is
## in. See `_fit_window()`.
var _columns: HBoxContainer
## What `_build_row()` connected to each setting, so `relayout()` can take it back
## off again. Rebuilding without this leaves every old row still listening, and the
## count grows by one panel every time the window changes size.
var _row_listeners: Array[Callable] = []
## The viewport the layout is currently measured against. The panel moves between
## two of them — the projection and the console — and each has its own size to
## follow, so the connection moves with it.
var _watched: Viewport

## True while the panel lives in the console window rather than over the projection.
## Three of its habits exist only because it is normally projected on the wall, and
## all three are wrong on a screen the audience cannot see: it fades out when left
## alone, it ducks when another surface takes over, and it can be told to stay away
## for the whole set. On the console it simply stays up.
var on_console: bool = false

## Chosen at the launcher: the panel is never shown at all, whatever anyone presses.
## For a machine that only projects, where the sliders would be on the wall and the
## driving happens from a phone. `F3` still works — a readout you have to ask for is
## a diagnostic, not an interface.
var hidden_for_good: bool = false


func build(p_params: Array[VJParam], lang: Lang):
	params = p_params
	_lang = lang
	_lang.changed.connect(_retranslate)
	hidden_for_good = Launch.hide_panel

	_build_columns()
	_build_help()

	_watch_viewport()

	select(0)
	fps_label.visible = show_fps
	if hidden_for_good:
		rows.visible = false
		help_box.visible = false
		return
	wake()


## Lays the settings out in as many columns as it takes to fit the screen, breaking
## only between sections so a section is never split in two. The panel used to be a
## single column and simply grew past the bottom of the screen every time a setting
## was added; this way it cannot.
func _build_columns():
	var groups := _group_by_section()
	var budget := get_viewport().get_visible_rect().size.y - vertical_margin - HELP_HEIGHT

	# A widget per setting, put in place by the setting's own index rather than
	# appended. The panel no longer builds the settings in the order they were
	# declared, and `select()` reads these arrays alongside `params`.
	_name_labels.resize(params.size())
	_sliders.resize(params.size())
	_value_labels.resize(params.size())
	_reading_order.clear()

	var columns := HBoxContainer.new()
	_columns = columns
	columns.add_theme_constant_override("separation", 28)
	# Columns run left to right from the screen edge; each one is bottom-aligned
	# inside itself, so the whole panel sits in the bottom-left corner as before.
	columns.alignment = BoxContainer.ALIGNMENT_BEGIN
	columns.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rows.add_child(columns)

	# The width the columns end up needing is not known here: a column is as wide as
	# its widest label, and a label coming from the fallback font measures short
	# until it has been drawn (see `_new_column()`). Thus the fit is not computed
	# once but followed — every time the run of columns settles on a new size.
	columns.resized.connect(_fit_window)

	var play := _ordered(groups, PLAY_SECTIONS, true)
	var setup_height := _lay_out(_ordered(groups, SETUP_SECTIONS), columns, budget)

	# The setup column sets the height of the panel, and the instruments spread
	# sideways rather than tower over it. Without this cap they make one column as
	# tall as the screen allows: legal, and it puts the top of the panel level with
	# the help text while the width beside it stays empty. The panel belongs in the
	# bottom band of the screen, which is where the hand and the eye both go.
	#
	# Floored at the tallest single section, because a column shorter than that
	# could hold nothing, and a setup list that ever shrank would otherwise drive
	# the count of columns up without limit.
	var tallest := 0.0
	for group in play:
		tallest = maxf(tallest, _height_of(group))
	# Anything the two lists do not name goes in with the instruments, at the end. A
	# section added to the show and forgotten here then reads oddly, which is a bug
	# somebody reports — where a section quietly dropped from the panel is not.
	_lay_out(play, columns, clampf(setup_height, tallest, budget))


## Moves the panel to the console window, or brings it back over the projection.
## Called by `console_window.gd` once the reparenting is done, because everything
## here has to be measured against the window the panel is in *now*.
func set_on_console(value: bool):
	on_console = value
	_watch_viewport()
	relayout()
	if on_console:
		# Whatever the launcher decided about the panel, it decided it about a panel
		# projected on a wall. On the console there is no wall.
		wake()
		return
	if hidden_for_good:
		rows.visible = false
		help_box.visible = false
	else:
		wake()


## The layout is measured against the window the panel is in, thus it has to be
## redone when that window changes — a resize, or the move to and from the console.
func _watch_viewport():
	var current := get_viewport()
	if _watched == current:
		return
	if _watched != null and _watched.size_changed.is_connected(_on_viewport_resized):
		_watched.size_changed.disconnect(_on_viewport_resized)
	_watched = current
	_watched.size_changed.connect(_on_viewport_resized)


## Lays the panel out again for the window it is in now. Called when that window is
## resized, and when the panel moves between the projection and the console: the
## column count comes from the height on offer, and neither answer survives the trip.
##
## The settings themselves are untouched — this rebuilds the widgets that show them,
## and puts the selection back where the operator left it.
func relayout():
	# Nothing to measure against while the panel is between two windows: the console
	# closing frees its window, and the size it reports on the way out belongs to a
	# viewport this panel has already left.
	if params.is_empty() or get_viewport() == null:
		return
	for i in range(_row_listeners.size()):
		params[i].changed.disconnect(_row_listeners[i])
	_row_listeners.clear()
	for child in rows.get_children():
		child.queue_free()
		rows.remove_child(child)
	_section_labels.clear()
	_section_keys.clear()

	var was_selected := selected
	_build_columns()
	select(was_selected)


func _on_viewport_resized():
	# Only the window the panel is in now. A window being torn down resizes as it
	# goes, and that is not a layout this panel has any business following.
	if get_viewport() != _watched:
		return
	relayout()
	# A window that has just appeared, or grown, is a gesture as much as a keypress.
	wake()


## Scales the settings down when the window cannot hold them at full size.
##
## The column count comes from the height on offer, and on a short window that
## answer is "many" — which then runs off the right-hand edge, where nobody can read
## it and nothing says so. The console window makes this ordinary: it is whatever
## size the operator's screen and window manager leave it, not the 1080p the panel
## was drawn for.
##
## Only ever shrinks. A panel blown up to fill a large window would be a different
## instrument from the one the same operator used last night on the projector.
func _fit_window():
	if _columns == null or get_viewport() == null:
		return
	var room := get_viewport().get_visible_rect().size
	var needed := _columns.get_combined_minimum_size()
	if needed.x <= 0.0 or needed.y <= 0.0:
		return
	# The panel sits 24 px in from the left edge and keeps the same margin on the
	# right; the help text at the top is not ours to scale.
	var across := (room.x - 48.0) / needed.x
	var down := (room.y - vertical_margin - HELP_HEIGHT) / needed.y
	var factor := clampf(minf(across, down), 0.35, 1.0)
	# Grown from the bottom-left corner, which is where the panel has always been
	# anchored and where the hand looks for it.
	_columns.pivot_offset = Vector2(0.0, _columns.size.y)
	_columns.scale = Vector2(factor, factor)


## The groups this list names, in the order it names them. With `rest`, everything
## it does not name follows, in the order the show declared it.
func _ordered(groups: Array, wanted: Array, rest: bool = false) -> Array:
	var out: Array = []
	for key in wanted:
		for group in groups:
			if group["key"] == key:
				out.append(group)
	for group in groups:
		if rest and not SETUP_SECTIONS.has(group["key"]) and not wanted.has(group["key"]):
			out.append(group)
	return out


## Fills as many columns as this run of sections needs, breaking only between them so
## a section is never split in two. Called once per run, so the setup sections keep a
## column of their own however tall the instruments grow.
## Hands back the height of its tallest column, which is what the next run is
## measured against.
func _lay_out(groups: Array, columns: HBoxContainer, budget: float) -> float:
	if groups.is_empty():
		return 0.0

	var total := 0.0
	for group in groups:
		total += _height_of(group)

	# Work out how many columns are needed, then aim for equal columns rather than
	# filling the first one to the brim. Two lopsided columns read worse than two
	# balanced ones, and the eye has to travel further to find anything.
	var wanted := maxi(1, ceili(total / maxf(1.0, budget)))
	var target := total / wanted

	_column = _new_column(columns)
	var used := 0.0
	var remaining := wanted
	var tallest := 0.0

	for group in groups:
		var height := _height_of(group)
		# Break when this section's midpoint would land past the target: the usual
		# balancing rule, and it keeps a section whole either side of the break.
		if used > 0.0 and remaining > 1 and used + height * 0.5 > target:
			_column = _new_column(columns)
			used = 0.0
			remaining -= 1
		_build_section_header(group["key"], used > 0.0)
		for p in group["params"]:
			var index := params.find(p)
			_reading_order.append(index)
			_build_row(p, index)
		used += height
		tallest = maxf(tallest, used)
	return tallest


func _height_of(group: Dictionary) -> float:
	return HEADER_HEIGHT + group["params"].size() * ROW_HEIGHT


func _group_by_section() -> Array:
	var groups: Array = []
	var current := ""
	for p in params:
		if p.section != current:
			current = p.section
			groups.append({"key": current, "params": []})
		groups[-1]["params"].append(p)
	return groups


## One screen column: a three-column grid, so the name, the slider and the value line
## up across every row in it by construction — section headers included, since they
## simply take a row of their own.
##
## Column alignment is the engine's job here, and it was this file's first. That did
## not hold. A glyph coming from the **fallback** font — every arrow in this panel:
## the `←` in "SPHERE ← TREBLE", the `→` on two-way values — measures about twenty
## pixels narrower than it is drawn, until it has been drawn once. Asked from
## `build()`, "LASERS ← MID" answered 111 px against a real 131; asked a frame later,
## still short; right only after some tens of frames. Any number of frames to wait
## would have been a guess that happened to work here. A container has no such
## problem: when the metric settles, the minimum size changes and the layout follows
## it, that frame and every frame after.
##
## The bottom alignment lives on a box wrapped around the grid: a GridContainer has
## no alignment of its own, and the panel has always grown upwards from the bottom
## edge of the screen.
func _new_column(parent: HBoxContainer) -> GridContainer:
	var wrapper := VBoxContainer.new()
	wrapper.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(wrapper)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	wrapper.add_child(grid)
	return grid


func _build_section_header(key: String, spaced: bool):
	if spaced:
		for i in 3:
			var spacer := Control.new()
			spacer.custom_minimum_size.y = 10
			_column.add_child(spacer)

	var header := Label.new()
	header.text = _lang.text(key)
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", SECTION_COLOR)
	_column.add_child(header)
	# The two cells the header does not use. A grid row is three cells wide whether
	# or not anything is in them.
	_column.add_child(Control.new())
	_column.add_child(Control.new())
	_section_labels.append(header)
	_section_keys.append(key)


func _build_row(p: VJParam, index: int):
	var name_label := Label.new()
	name_label.custom_minimum_size.x = MIN_NAME_WIDTH
	if p.tint.a > 0.0:
		name_label.add_theme_color_override("font_color", p.tint)
	_column.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = p.min_value
	slider.max_value = p.max_value
	slider.step = p.step
	slider.value = p.value
	slider.custom_minimum_size.x = 200
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Without this the sliders swallow the arrow keys and break navigation.
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_slider_moved.bind(index))
	_column.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = MIN_VALUE_WIDTH
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_column.add_child(value_label)

	_name_labels[index] = name_label
	_sliders[index] = slider
	_value_labels[index] = value_label

	var listener := _on_param_changed.bind(index)
	p.changed.connect(listener)
	_row_listeners.append(listener)


func _build_help():
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", SECTION_COLOR)
	help_box.add_child(_status)

	for key in HELP_KEYS:
		var label := Label.new()
		label.text = _lang.text(key)
		label.add_theme_font_size_override("font_size", 13)
		label.modulate = Color(1, 1, 1, 0.55)
		help_box.add_child(label)
		_help_labels.append(label)


## Set by the controller once the servers are up: the address to type into a phone,
## and whether a pad is plugged in.
func set_status(text: String):
	_status_text = text
	if _status:
		_status.text = text


## Rewrites every piece of text in place when the language changes. Cheaper and
## far less disruptive than tearing the panel down and rebuilding it.
func _retranslate():
	for i in range(_section_labels.size()):
		_section_labels[i].text = _lang.text(_section_keys[i])
	for i in range(_help_labels.size()):
		_help_labels[i].text = _lang.text(HELP_KEYS[i])
	select(selected)


# --------------------------------------------------------------------------
# Keeping values and display in step
# --------------------------------------------------------------------------

func _on_slider_moved(value: float, index: int):
	params[index].set_value(value)
	select(index)
	wake()


## The parameter changed, wherever it came from. The slider is put back in place
## without re-emitting, otherwise an OSC round trip would loop on itself.
func _on_param_changed(value: float, index: int):
	_sliders[index].set_value_no_signal(value)
	_value_labels[index].text = params[index].format_value()


## The setting one row up or down the panel from the selected one, wrapping at the
## end of the last column.
func _step(direction: int) -> int:
	var at := _reading_order.find(selected)
	if at < 0:
		return selected
	return _reading_order[wrapi(at + direction, 0, _reading_order.size())]


func select(index: int):
	selected = wrapi(index, 0, params.size())
	for i in range(params.size()):
		var on := i == selected
		_name_labels[i].text = ("  ▸ " if on else "     ") + params[i].label()
		_name_labels[i].modulate = Color.WHITE if on else Color(1, 1, 1, 0.5)
		_value_labels[i].modulate = Color.WHITE if on else Color(1, 1, 1, 0.5)
		_value_labels[i].text = params[i].format_value()


# --------------------------------------------------------------------------
# Auto-hide
# --------------------------------------------------------------------------

func set_brightness(value: float):
	brightness = clampf(value, 0.0, 1.0)
	fps_label.modulate.a = brightness
	help_box.modulate.a = brightness
	# Only touch the panel if it is actually up: mid-fade or hidden, the alpha
	# belongs to the fade and writing to it would flash the panel back on.
	if rows.visible and _fade == null:
		rows.modulate.a = brightness


## Called when something other than this keyboard moves a setting. Any keypress
## hands control back, so the way out is the thing you were about to do anyway.
func set_external_control(active: bool, dim_to: float):
	# On the console there is nothing to duck out of the way of: the wall does not
	# show this panel, and a console that dimmed itself every time Chataigne moved a
	# fader would be unreadable for exactly as long as the set lasts.
	if on_console:
		return
	if active == external_control:
		return
	external_control = active
	for slider in _sliders:
		slider.mouse_filter = Control.MOUSE_FILTER_IGNORE if active else Control.MOUSE_FILTER_STOP
	if active:
		_restore_brightness = brightness
		set_brightness(dim_to)
	else:
		set_brightness(_restore_brightness)


func wake():
	# Every route back on screen goes through here — a keypress, a click, the pad,
	# a language change — so one guard covers all of them.
	if hidden_for_good and not on_console:
		return
	_idle = 0.0
	if _fade:
		_fade.kill()
		_fade = null
	rows.visible = true
	rows.modulate.a = brightness
	help_box.visible = true
	help_box.modulate.a = brightness


func _fade_out():
	_fade = create_tween()
	_fade.tween_property(rows, "modulate:a", 0.0, 0.7)
	_fade.parallel().tween_property(help_box, "modulate:a", 0.0, 0.7)
	_fade.tween_callback(func():
		rows.visible = false
		help_box.visible = false)


signal mouse_reclaimed


func _input(event: InputEvent):
	if external_control and event is InputEventMouse:
		# A click asks for the panel back; motion does not.
		if event is InputEventMouseButton and event.pressed:
			mouse_reclaimed.emit()
			wake()
			get_viewport().set_input_as_handled()
		return

	# The slightest gesture calls the panel back; it is silence that hides it.
	if event is InputEventKey or event is InputEventMouse:
		if rows.visible and _fade == null:
			_idle = 0.0
		else:
			wake()


## The panel's own shortcuts. Public and called by the controller rather than taken
## from `_unhandled_input`, because the keyboard reaches whichever window has the
## focus and the panel is only ever in one of them: with the console open, the
## arrows have to work from the projection window too, where this node is not.
func handle_key(event: InputEventKey) -> bool:
	if not event.pressed:
		return false
	match event.keycode:
		KEY_UP:
			select(_step(-1))
		KEY_DOWN:
			select(_step(1))
		KEY_LEFT:
			params[selected].nudge(-1, event.shift_pressed)
		KEY_RIGHT:
			params[selected].nudge(1, event.shift_pressed)
		KEY_H:
			pinned = not pinned
			wake()
		KEY_F3:
			fps_label.visible = not fps_label.visible
			_fps_elapsed = 0.0
			_fps_frames = 0
		_:
			return false
	return true


# --------------------------------------------------------------------------
# Loop
# --------------------------------------------------------------------------

func _process(delta: float):
	if rows.visible and not pinned and not on_console and _fade == null:
		_idle += delta
		if _idle >= hide_delay:
			_fade_out()

	if fps_label.visible:
		_update_fps(delta)


func _update_fps(delta: float):
	_fps_elapsed += delta
	_fps_frames += 1
	if _fps_elapsed < FPS_REFRESH:
		return

	# Averaged milliseconds per frame: that is the number that matters, not the
	# FPS count. A 0.3 ms difference costs hundreds of FPS when already running
	# very high, without weighing anything on the frame budget.
	var avg_ms := (_fps_elapsed / _fps_frames) * 1000.0
	var text := "%.0f FPS   %.2f ms" % [1000.0 / avg_ms, avg_ms]

	# The screen (or projector) refresh rate: that is the real target to hold.
	var refresh := DisplayServer.screen_get_refresh_rate(
		DisplayServer.window_get_current_screen()
	)
	if refresh > 0.0:
		text += "   " + _lang.text("fps.screen") % refresh
	fps_label.text = text

	_fps_elapsed = 0.0
	_fps_frames = 0

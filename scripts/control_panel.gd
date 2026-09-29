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

# Rough heights used for the automatic layout live in `PanelLayout`.
const HELP_HEIGHT := 0

## Narrowest a column may be, so a panel of short labels does not look cramped. The
## grid widens past these on its own when the text asks for it.
const MIN_NAME_WIDTH := 130.0
const MIN_VALUE_WIDTH := 100.0

## Pixels kept clear at the top and bottom of the screen.
@export var vertical_margin: float = 48.0

var _column: GridContainer

## Which section goes where, and which are put away. See `PanelLayout`.
var layout := PanelLayout.new()
## Where it is kept. A variable so that a test can point it somewhere it may write.
var layout_path: String = PanelLayout.PATH
## True while the operator is arranging the panel. See `set_editing()`.
var editing: bool = false
## The section the edit keys act on.
var _edit_key: String = ""
## Settings whose section is hidden but shown anyway, dimmed, because the panel is
## being edited: they are on screen, and they are not to be selected or read.
var _dimmed: Dictionary = {}
var _edit_banner: Label

## The mouse's half of the edit mode. A press on a section name chooses it; moved past
## a few pixels it becomes a drag, and the section lands where it is let go.
const DRAG_THRESHOLD := 6.0
## How far right of the last column a drop still means "beside it" rather than in it.
const NEW_COLUMN_MARGIN := 30.0
var _pressed_key: String = ""
## The release that ends a double click, which has nothing left to do.
var _swallow_release: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _ghost: Label
var _marker: ColorRect
## The run of columns, kept so the panel can be measured against the window it is
## in. See `_fit_window()`.
var _columns: HBoxContainer
## What `_build_row()` connected to each setting, so `relayout()` can take it back
## off again. Rebuilding without this leaves every old row still listening, and the
## count grows by one panel every time the window changes size.
var _row_listeners: Array = []
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
	layout = PanelLayout.load_from(layout_path)

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

	# A widget per setting, put in place by the setting's own index rather than
	# appended. The panel no longer builds the settings in the order they were
	# declared, and `select()` reads these arrays alongside `params`. A setting in a
	# hidden section has no widgets at all, and its slot stays null.
	_name_labels.clear()
	_sliders.clear()
	_value_labels.clear()
	_name_labels.resize(params.size())
	_sliders.resize(params.size())
	_value_labels.resize(params.size())
	_reading_order.clear()
	_dimmed.clear()

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
	# The scale has to be put back after every sort. A container fits each child into its
	# rectangle and, doing so, resets that child's scale to 1 — so a scale set once was
	# undone by the next sort, and how long it lived was a matter of timing. Measured
	# with four columns: the panel came up 2062 px wide in a 1920 window and stayed that
	# wide, with its last column off the right edge. `resized` alone cannot catch this,
	# because the run of columns does not change size when its scale is taken away.
	if not rows.sort_children.is_connected(_fit_window):
		rows.sort_children.connect(_fit_window)

	var plan := _plan(groups, editing)
	if editing and not _section_in(plan, _edit_key):
		_edit_key = plan[0][0] if not plan.is_empty() else ""

	for keys in plan:
		_column = _new_column(columns)
		for at in range(keys.size()):
			_build_section(_group_of(groups, keys[at]), at > 0)


## What the layout says goes where, for the window the panel is in now.
func _plan(groups: Array, with_hidden: bool) -> Array:
	var infos: Array = []
	for group in groups:
		infos.append({"key": group["key"], "rows": group["params"].size()})
	var budget := get_viewport().get_visible_rect().size.y - vertical_margin - HELP_HEIGHT
	return layout.plan(infos, budget, with_hidden)


## One section: its header, then a row per setting. In edit mode a hidden section is
## drawn too, dimmed, and its settings stay out of the reading order.
func _build_section(group: Dictionary, spaced: bool):
	var key: String = group["key"]
	var away := layout.hidden.has(key)
	_build_section_header(key, spaced)
	for p in group["params"]:
		var index := params.find(p)
		_build_row(p, index)
		if away:
			_dimmed[index] = true
			# On screen so that it can be brought back, and out of reach until then.
			_sliders[index].mouse_filter = Control.MOUSE_FILTER_IGNORE
			_name_labels[index].mouse_filter = Control.MOUSE_FILTER_IGNORE
			_value_labels[index].mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			_reading_order.append(index)


static func _group_of(groups: Array, key: String) -> Dictionary:
	for group in groups:
		if group["key"] == key:
			return group
	return {}


static func _section_in(plan: Array, key: String) -> bool:
	for column in plan:
		if column.has(key):
			return true
	return false


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
	# The widgets a drag is holding are about to be replaced.
	_end_drag()
	for pair in _row_listeners:
		pair[0].changed.disconnect(pair[1])
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
	header.text = _header_text(key)
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", SECTION_COLOR)
	if editing:
		# The mouse takes a section by its name; `_edit_mouse()` does the rest. The
		# label only has to be there to hit, and to say so with the cursor.
		header.mouse_filter = Control.MOUSE_FILTER_STOP
		header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_column.add_child(header)
	# The two cells the header does not use. A grid row is three cells wide whether
	# or not anything is in them.
	_column.add_child(Control.new())
	_column.add_child(Control.new())
	_section_labels.append(header)
	_section_keys.append(key)
	_style_header(header, key)


func _header_text(key: String) -> String:
	var text := _lang.text(key)
	if not editing:
		return text
	if layout.hidden.has(key):
		text += "  " + _lang.text("layout.hidden")
	return ("▸ " if key == _edit_key else "  ") + text


## In edit mode the section being moved is the bright one, and a hidden one is faint.
func _style_header(header: Label, key: String):
	var color := SECTION_COLOR
	if editing and key == _edit_key:
		color = Color.WHITE
	header.add_theme_color_override("font_color", color)
	header.modulate.a = 0.35 if (editing and layout.hidden.has(key)) else 1.0


func _build_row(p: VJParam, index: int):
	var name_label := Label.new()
	name_label.custom_minimum_size.x = MIN_NAME_WIDTH
	if p.tint.a > 0.0:
		name_label.add_theme_color_override("font_color", p.tint)
	# The name is a place to double click as much as the slider is: a label ignores the
	# mouse by default, so it has to be told not to.
	name_label.mouse_filter = _row_mouse_filter()
	name_label.gui_input.connect(_on_slider_input.bind(index))
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
	slider.gui_input.connect(_on_slider_input.bind(index))
	slider.mouse_filter = _row_mouse_filter()
	_column.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = MIN_VALUE_WIDTH
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.mouse_filter = _row_mouse_filter()
	value_label.gui_input.connect(_on_slider_input.bind(index))
	_column.add_child(value_label)

	_name_labels[index] = name_label
	_sliders[index] = slider
	_value_labels[index] = value_label

	var listener := _on_param_changed.bind(index)
	p.changed.connect(listener)
	_row_listeners.append([p, listener])


## Whether a row takes the mouse. Not while an external surface has the wheel: the panel
## refuses the mouse then, so a stray touch on a projected panel cannot move anything, and
## that has to hold for the names and the numbers as much as for the sliders. Asked at the
## moment a row is built too, because the panel is rebuilt whenever its window changes,
## and a row built during a hand-over would otherwise come up taking the mouse.
func _row_mouse_filter() -> int:
	return Control.MOUSE_FILTER_IGNORE if external_control else Control.MOUSE_FILTER_STOP


func _build_help():
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", SECTION_COLOR)
	help_box.add_child(_status)

	_edit_banner = Label.new()
	_edit_banner.add_theme_font_size_override("font_size", 13)
	_edit_banner.visible = false
	help_box.add_child(_edit_banner)

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
		_section_labels[i].text = _header_text(_section_keys[i])
	_refresh_banner()
	for i in range(_help_labels.size()):
		_help_labels[i].text = _lang.text(HELP_KEYS[i])
	select(selected)


# --------------------------------------------------------------------------
# Arranging the panel
# --------------------------------------------------------------------------

## Enters or leaves the edit mode, in which the sections can be moved, put away and
## brought back. It is left with the same key, and the arrangement is saved as it goes
## and again on the way out.
##
## Refused on a projection that was told to show no panel: the operator cannot see
## what they would be moving. On the console there is nothing to refuse.
func set_editing(on: bool):
	if on == editing:
		return
	if on and hidden_for_good and not on_console:
		return
	editing = on
	if not on:
		layout.save(layout_path)
	relayout()
	_refresh_banner()
	wake()


func _refresh_banner():
	if _edit_banner == null:
		return
	_edit_banner.visible = editing
	_edit_banner.text = _lang.text("layout.help")
	_edit_banner.add_theme_color_override("font_color", Color.WHITE)


## The keys of the edit mode. Everything else falls through to the show, so the
## presets and the rest still answer while the panel is being arranged — but not
## SPACE and R, which the operator has no reason to press here and would fire in
## front of the room.
func _handle_edit_key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_UP, KEY_DOWN:
			var direction := -1 if event.keycode == KEY_UP else 1
			if event.shift_pressed:
				_apply_edit(layout.move_vertical(_plan(_group_by_section(), true), _edit_key, direction))
			else:
				_step_section(direction)
		KEY_LEFT, KEY_RIGHT:
			var direction := -1 if event.keycode == KEY_LEFT else 1
			_apply_edit(layout.move_horizontal(_plan(_group_by_section(), true), _edit_key, direction))
		KEY_ENTER, KEY_KP_ENTER, KEY_X:
			if _edit_key != "":
				_apply_edit(layout.toggle_hidden(_edit_key))
		KEY_BACKSPACE, KEY_DELETE:
			layout.reset()
			_apply_edit(true)
		KEY_SPACE, KEY_R:
			pass
		_:
			return false
	return true


func _apply_edit(changed: bool):
	if not changed:
		return
	layout.save(layout_path)
	relayout()


## Previous or next section in the order the panel shows them, wrapping.
func _step_section(direction: int):
	var order: Array = []
	for column in _plan(_group_by_section(), true):
		order.append_array(column)
	if order.is_empty():
		return
	var at := order.find(_edit_key)
	_choose_section(order[wrapi(at + direction, 0, order.size())])


func _choose_section(key: String):
	_edit_key = key
	for i in range(_section_labels.size()):
		_section_labels[i].text = _header_text(_section_keys[i])
		_style_header(_section_labels[i], _section_keys[i])


## The mouse in the edit mode. Answers whether it took the event.
##
## Everything is worked out in the panel's own canvas coordinates, from the on-screen
## rectangles of what is there. The columns may be scaled down to fit a small window,
## and a rectangle read through its transform is still right when they are.
func _edit_mouse(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var at := _canvas_position(event)
			if event.pressed:
				var key := _header_at(at)
				if key == "":
					return false
				_choose_section(key)
				if event.double_click:
					# Twice on a name puts the section away, or brings it back. Taken
					# on the second press, and its release is swallowed with it, so
					# that a hand still moving cannot start a drag from a section that
					# is about to be redrawn.
					_swallow_release = true
					_apply_edit(layout.toggle_hidden(key))
					get_viewport().set_input_as_handled()
					return true
				_pressed_key = key
				_press_at = at
				_dragging = false
				get_viewport().set_input_as_handled()
				return true
			if _swallow_release:
				_swallow_release = false
				get_viewport().set_input_as_handled()
				return true
			if _pressed_key != "":
				if _dragging:
					_drop(at)
				_end_drag()
				get_viewport().set_input_as_handled()
				return true
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _dragging:
				# The way out of a drag that was a mistake. Not ESC: that quits the show.
				_end_drag()
				get_viewport().set_input_as_handled()
				return true
			# Not dragging, the right button is free: on a name it puts the section
			# away, or brings it back, like a double click and like ENTER.
			var key := _header_at(_canvas_position(event))
			if key == "":
				return false
			_choose_section(key)
			_end_drag()
			_apply_edit(layout.toggle_hidden(key))
			get_viewport().set_input_as_handled()
			return true
	elif event is InputEventMouseMotion and _pressed_key != "":
		var at := _canvas_position(event)
		if not _dragging and at.distance_to(_press_at) > DRAG_THRESHOLD:
			_begin_drag()
		if _dragging:
			_update_drag(at)
		get_viewport().set_input_as_handled()
		return true
	return false


## Where an event is, in the coordinates the panel's controls are drawn in.
func _canvas_position(event: InputEvent) -> Vector2:
	var local := rows.make_input_local(event) as InputEventMouse
	return rows.get_global_transform() * local.position


static func _rect_of(control: Control) -> Rect2:
	var t := control.get_global_transform()
	return Rect2(t * Vector2.ZERO, Vector2.ZERO).expand(t * control.size)


## The section whose name is under this point, or "".
func _header_at(at: Vector2) -> String:
	for i in range(_section_labels.size()):
		if is_instance_valid(_section_labels[i]) and _rect_of(_section_labels[i]).has_point(at):
			return _section_keys[i]
	return ""


func _header_of(key: String) -> Label:
	var at := _section_keys.find(key)
	return _section_labels[at] if at >= 0 else null


func _begin_drag():
	_dragging = true
	if _ghost == null:
		_ghost = Label.new()
		_ghost.add_theme_font_size_override("font_size", 15)
		_ghost.add_theme_color_override("font_color", Color.WHITE)
		_ghost.modulate.a = 0.85
		_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost.z_index = 10
		add_child(_ghost)
		_marker = ColorRect.new()
		_marker.color = SECTION_COLOR
		_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_marker.z_index = 10
		add_child(_marker)
	_ghost.text = _lang.text(_pressed_key)
	_ghost.visible = true


## The section follows the pointer, and a bar shows where it would land — or nothing,
## where letting go would change nothing, so that the bar never promises a move that
## does not happen.
func _update_drag(at: Vector2):
	_ghost.position = at + Vector2(14.0, 10.0)
	var target := _drop_target(at)
	_marker.visible = false
	if target.is_empty() or not _would_change(target):
		return
	var wrappers := _columns.get_children()
	if target["column"] >= wrappers.size():
		var last := _rect_of(wrappers[-1])
		_marker.position = Vector2(last.end.x + NEW_COLUMN_MARGIN * 0.5, last.position.y)
		_marker.size = Vector2(3.0, last.size.y)
	else:
		var column := _rect_of(wrappers[target["column"]])
		var kept: Array = target["kept"]
		var y := column.end.y - 2.0
		if target["index"] < kept.size():
			y = _rect_of(_header_of(kept[target["index"]])).position.y - 8.0
		_marker.position = Vector2(column.position.x, y)
		_marker.size = Vector2(column.size.x, 3.0)
	_marker.visible = true


## Which column, and which place in it, a drop at this point means. `kept` is that
## column without the section being dragged, which is what `index` counts.
func _drop_target(at: Vector2) -> Dictionary:
	var plan := _plan(_group_by_section(), true)
	var wrappers := _columns.get_children()
	if plan.is_empty() or wrappers.size() != plan.size():
		return {}
	if at.x > _rect_of(wrappers[-1]).end.x + NEW_COLUMN_MARGIN:
		return {"column": plan.size(), "index": 0, "kept": []}

	var best := 0
	var best_gap := INF
	for i in range(wrappers.size()):
		var r := _rect_of(wrappers[i])
		var gap := 0.0 if (at.x >= r.position.x and at.x <= r.end.x) \
				else minf(absf(at.x - r.position.x), absf(at.x - r.end.x))
		if gap < best_gap:
			best = i
			best_gap = gap

	var kept: Array = plan[best].filter(func(k): return k != _pressed_key)
	var index := 0
	for key in kept:
		if _rect_of(_header_of(key)).get_center().y < at.y:
			index += 1
	return {"column": best, "index": index, "kept": kept}


func _would_change(target: Dictionary) -> bool:
	# Tried on a copy: the real layout is not touched until the drop.
	var trial := PanelLayout.from_dict(layout.to_dict())
	return trial.move_to(_plan(_group_by_section(), true), _pressed_key,
		target["column"], target["index"])


func _drop(at: Vector2):
	var target := _drop_target(at)
	if target.is_empty():
		return
	_apply_edit(layout.move_to(_plan(_group_by_section(), true), _pressed_key,
		target["column"], target["index"]))


func _end_drag():
	_pressed_key = ""
	_dragging = false
	if _ghost:
		_ghost.visible = false
		_marker.visible = false


# --------------------------------------------------------------------------
# Keeping values and display in step
# --------------------------------------------------------------------------

## A double click on a row — its slider, its name or its number — puts the setting back to
## the value it was declared with. On a slider the first click of the pair has already
## moved it to where it landed, and this then overrides it, so the double click ends at
## the default wherever it fell. Taken, so that the slider does not go on to start a drag
## from it.
func _on_slider_input(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and event.double_click:
		params[index].reset()
		select(index)
		wake()
		get_viewport().set_input_as_handled()


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
	# A setting in a hidden section is not on the panel to be selected: land on the
	# first one that is.
	if not _reading_order.is_empty() and not _reading_order.has(selected):
		selected = _reading_order[0]
	for i in range(params.size()):
		if _name_labels[i] == null:
			continue
		var on := i == selected
		var alpha := 1.0 if on else 0.5
		if _dimmed.has(i):
			on = false
			alpha = 0.2
		_name_labels[i].text = ("  ▸ " if on else "     ") + params[i].label()
		_name_labels[i].modulate = Color(1, 1, 1, alpha)
		_value_labels[i].modulate = Color(1, 1, 1, alpha)
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
	for row in [_sliders, _name_labels, _value_labels]:
		for control in row:
			if control != null:
				control.mouse_filter = _row_mouse_filter()
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
	if editing and _edit_mouse(event):
		return
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
	if event.keycode == KEY_F6:
		set_editing(not editing)
		return true
	if editing and _handle_edit_key(event):
		return true
	match event.keycode:
		KEY_UP:
			select(_step(-1))
		KEY_DOWN:
			select(_step(1))
		KEY_LEFT:
			if _reading_order.has(selected):
				params[selected].nudge(-1, event.shift_pressed)
		KEY_RIGHT:
			if _reading_order.has(selected):
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
	if rows.visible and not pinned and not editing and not on_console and _fade == null:
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

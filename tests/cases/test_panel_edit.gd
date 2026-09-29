extends TestCase

## The edit mode of the real panel: keys in, arrangement out. Pointed at a file of its
## own, so that it can never overwrite the layout of whoever runs the tests.

const PATH := "user://test_panel_edit.json"

var panel: Node


func _key(code: int, shift := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.shift_pressed = shift
	return e


func _begin():
	panel = show.panel
	panel.layout_path = PATH
	panel.layout = PanelLayout.new()
	panel.editing = false
	panel.relayout()


func _end():
	panel.layout = PanelLayout.new()
	panel.editing = false
	panel.relayout()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _columns_of_headers() -> Array:
	var out := []
	for wrapper in panel._columns.get_children():
		var grid = wrapper.get_child(0)
		var heads := []
		for label in panel._section_labels:
			if is_instance_valid(label) and label.get_parent() == grid:
				heads.append(label.text.strip_edges().trim_prefix("▸ "))
		out.append(heads)
	return out


func test_f6_toggles_the_edit_mode_and_the_banner():
	_begin()
	check(not panel.editing, "not editing to begin with")
	check(panel.handle_key(_key(KEY_F6)), "F6 is the panel's")
	check(panel.editing, "editing")
	check(panel._edit_banner.visible, "the banner says so")
	panel.handle_key(_key(KEY_F6))
	check(not panel.editing and not panel._edit_banner.visible, "and leaves it")
	_end()


func test_the_keys_of_the_show_pass_through_but_not_space_and_r():
	_begin()
	panel.handle_key(_key(KEY_F6))
	check(panel.handle_key(_key(KEY_SPACE)), "SPACE is swallowed, or it would glitch in front of the room")
	check(panel.handle_key(_key(KEY_R)), "and so is R")
	check(not panel.handle_key(_key(KEY_1)), "a preset key reaches the show")
	_end()


func test_moving_a_section_changes_the_panel_and_is_saved():
	_begin()
	var before := _columns_of_headers()
	panel.handle_key(_key(KEY_F6))
	var first: String = panel._edit_key
	panel.handle_key(_key(KEY_RIGHT))
	var after := _columns_of_headers()
	check(after != before, "the panel is not what it was")
	check(FileAccess.file_exists(PATH), "saved as it goes")
	var read := PanelLayout.load_from(PATH)
	check(read.custom, "as a custom layout")
	check(PanelLayout.load_from(PATH).plan(_infos(), 2000.0, true) != PanelLayout.auto_plan(_infos(), 2000.0),
		"that differs from the automatic one")
	check(first != "", "a section was chosen")
	_end()


func test_a_hidden_section_is_dimmed_while_editing_and_gone_after():
	_begin()
	panel.handle_key(_key(KEY_F6))
	var key: String = panel._edit_key
	var count_before: int = panel._reading_order.size()
	panel.handle_key(_key(KEY_ENTER))
	check(panel.layout.hidden.has(key), "put away")
	check(panel._reading_order.size() < count_before, "its settings are out of the reading order")
	check(not panel._dimmed.is_empty(), "but drawn, dimmed, so it can be brought back")
	panel.handle_key(_key(KEY_F6))
	var flat := []
	for column in _columns_of_headers():
		flat.append_array(column)
	check(not flat.has(panel._lang.text(key)), "gone from the panel once done")
	check(panel._dimmed.is_empty(), "nothing dimmed any more")
	# Hiding is display only: the settings still answer.
	var slug: String = panel.params[0].slug
	check(show.registry.find(slug) != null, "the setting is still there")
	_end()


func test_the_selection_never_lands_on_a_hidden_setting():
	_begin()
	panel.handle_key(_key(KEY_F6))
	panel.handle_key(_key(KEY_ENTER))
	panel.handle_key(_key(KEY_F6))
	for i in 60:
		panel.handle_key(_key(KEY_DOWN))
		check(panel._reading_order.has(panel.selected), "step %d is on a visible setting" % i)
		if not panel._reading_order.has(panel.selected):
			break
	_end()


func test_backspace_brings_the_automatic_layout_back():
	_begin()
	var automatic := _columns_of_headers()
	panel.handle_key(_key(KEY_F6))
	panel.handle_key(_key(KEY_RIGHT))
	panel.handle_key(_key(KEY_ENTER))
	panel.handle_key(_key(KEY_BACKSPACE))
	check(not panel.layout.custom and panel.layout.hidden.is_empty(), "reset")
	same(_columns_of_headers(), automatic, "the panel is as it was")
	_end()


func test_every_section_can_be_put_away_and_the_panel_still_answers():
	_begin()
	var sections: int = panel._group_by_section().size()
	panel.handle_key(_key(KEY_F6))
	for i in sections:
		panel.handle_key(_key(KEY_ENTER))
		panel.handle_key(_key(KEY_DOWN))
	panel.handle_key(_key(KEY_F6))
	same(panel.layout.hidden.size(), sections, "all of them put away")
	check(panel._reading_order.is_empty(), "nothing left to read")
	# The arrows have nothing to act on, and must not fault.
	for code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		panel.handle_key(_key(code))
	panel.handle_key(_key(KEY_F6))
	check(panel.editing, "and the way back in is still there")
	panel.handle_key(_key(KEY_BACKSPACE))
	panel.handle_key(_key(KEY_F6))
	check(not panel._reading_order.is_empty(), "reset brings everything back")
	_end()


func _infos() -> Array:
	var out := []
	for g in panel._group_by_section():
		out.append({"key": g["key"], "rows": g["params"].size()})
	return out


# --------------------------------------------------------------------------
# The mouse
# --------------------------------------------------------------------------

## Where a point of the panel's canvas is in the viewport, which is what an event
## carries. The two only differ when the window is stretched.
func _at(canvas_point: Vector2) -> Vector2:
	var through: Transform2D = panel.rows.get_global_transform_with_canvas() \
		* panel.rows.get_global_transform().affine_inverse()
	return through * canvas_point


func _button(canvas_point: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = _at(canvas_point)
	return e


func _move(canvas_point: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = _at(canvas_point)
	return e


func _centre(key: String) -> Vector2:
	return panel._rect_of(panel._header_of(key)).get_center()


## A container puts its children in place on the next frame, so a rectangle read
## straight after a rebuild is the rectangle of nothing yet.
func _settle():
	await show.get_tree().process_frame
	await show.get_tree().process_frame


func _plan() -> Array:
	return panel._plan(panel._group_by_section(), true)


## Press on a section's name, carry it to `to`, let go.
func _drag(key: String, to: Vector2):
	var from := _centre(key)
	panel._input(_button(from, true))
	panel._input(_move((from + to) * 0.5))
	panel._input(_move(to))
	panel._input(_button(to, false))


func test_a_click_on_a_name_chooses_the_section_and_moves_nothing():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	var at := _centre("section.mirror")
	check(panel._edit_mouse(_button(at, true)), "the press is the panel's")
	panel._input(_button(at, false))
	same(panel._edit_key, "section.mirror", "chosen")
	check(not panel.layout.custom, "and nothing was moved, so the layout is still automatic")
	_end()


func test_dragging_a_name_into_another_column_drops_it_where_it_is_let_go():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	var before := _plan()
	check(before.size() >= 3, "the panel has a few columns to move between")
	var target := _centre("section.lasers") - Vector2(0.0, 6.0)
	_drag("section.mirror", target)
	var after := _plan()
	check(not after[0].has("section.mirror"), "gone from its column")
	var column: Array = after.filter(func(c): return c.has("section.lasers"))[0]
	check(column.has("section.mirror"), "in the column it was dropped on")
	same(column.find("section.mirror"), column.find("section.lasers") - 1, "just above the one it was dropped on")
	check(panel.layout.custom, "the arrangement is now the operator's")
	check(FileAccess.file_exists(PATH), "and saved")
	_end()


func test_dropping_past_the_last_column_opens_a_new_one():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	var count := _plan().size()
	var last: Rect2 = panel._rect_of(panel._columns.get_children()[-1])
	_drag("section.mirror", Vector2(last.end.x + 80.0, last.get_center().y))
	var after := _plan()
	same(after.size(), count + 1, "one more column")
	same(after[-1], ["section.mirror"], "holding that section")
	_end()


func test_the_right_button_cancels_a_drag():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	var before := _plan()
	var from := _centre("section.mirror")
	var to := _centre("section.lasers")
	panel._input(_button(from, true))
	panel._input(_move(to))
	check(panel._dragging, "a drag is under way")
	check(panel._ghost.visible, "the name follows the pointer")
	panel._input(_button(to, true, MOUSE_BUTTON_RIGHT))
	check(not panel._dragging and not panel._ghost.visible, "cancelled")
	panel._input(_button(to, false))
	same(_plan(), before, "nothing moved")
	check(not panel.layout.custom, "and the layout is still automatic")
	_end()


func test_a_small_wobble_is_still_a_click():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	var from := _centre("section.mirror")
	panel._input(_button(from, true))
	panel._input(_move(from + Vector2(3.0, 2.0)))
	check(not panel._dragging, "under the threshold")
	panel._input(_button(from + Vector2(3.0, 2.0), false))
	check(not panel.layout.custom, "nothing moved")
	_end()


func test_the_bar_only_shows_where_a_drop_would_change_something():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	var from := _centre("section.mirror")
	panel._input(_button(from, true))
	panel._input(_move(from + Vector2(40.0, 0.0)))
	panel._input(_move(from + Vector2(0.0, 2.0)))
	check(not panel._marker.visible, "over its own place: no bar, because nothing would happen")
	panel._input(_move(_centre("section.lasers") - Vector2(0.0, 6.0)))
	check(panel._marker.visible, "over another column: a bar")
	panel._input(_button(from, false))
	check(not panel._marker.visible and not panel._ghost.visible, "both put away afterwards")
	_end()


func test_the_mouse_does_nothing_outside_the_edit_mode():
	_begin()
	await _settle()
	var at := _centre("section.mirror")
	panel._input(_button(at, true))
	check(panel._pressed_key == "", "not editing: the press is not taken")
	panel._input(_button(at, false))
	check(not panel.editing and not panel.layout.custom, "nothing changed")
	_end()


func test_a_press_that_is_not_on_a_name_is_left_alone():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	check(not panel._edit_mouse(_button(Vector2(1800.0, 5.0), true)), "empty space is not the panel's")
	_end()


func _double_click(canvas_point: Vector2) -> InputEventMouseButton:
	var e := _button(canvas_point, true)
	e.double_click = true
	return e


func test_a_double_click_on_a_name_puts_the_section_away_and_brings_it_back():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	var at := _centre("section.mirror")
	panel._input(_button(at, true))
	panel._input(_button(at, false))
	panel._input(_double_click(at))
	panel._input(_button(at, false))
	check(panel.layout.hidden.has("section.mirror"), "put away")
	check(panel._pressed_key == "" and not panel._dragging, "and no drag was started by the second press")
	check(FileAccess.file_exists(PATH), "saved")
	await _settle()
	var again := _centre("section.mirror")
	panel._input(_button(again, true))
	panel._input(_button(again, false))
	panel._input(_double_click(again))
	panel._input(_button(again, false))
	check(not panel.layout.hidden.has("section.mirror"), "brought back by the same gesture")
	_end()


func test_moving_after_a_double_click_does_not_drag():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	var at := _centre("section.mirror")
	panel._input(_button(at, true))
	panel._input(_button(at, false))
	panel._input(_double_click(at))
	panel._input(_move(at + Vector2(200.0, 0.0)))
	check(not panel._dragging, "the hand is still moving, and nothing is being dragged")
	panel._input(_button(at + Vector2(200.0, 0.0), false))
	check(not panel._swallow_release, "the release was taken")
	_end()


func test_a_double_click_outside_the_edit_mode_does_nothing():
	_begin()
	await _settle()
	var at := _centre("section.mirror")
	panel._input(_double_click(at))
	check(panel.layout.hidden.is_empty(), "nothing hidden")
	_end()


func test_the_right_button_on_a_name_puts_the_section_away_and_brings_it_back():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	var at := _centre("section.mirror")
	panel._input(_button(at, true, MOUSE_BUTTON_RIGHT))
	check(panel.layout.hidden.has("section.mirror"), "put away")
	await _settle()
	panel._input(_button(_centre("section.mirror"), true, MOUSE_BUTTON_RIGHT))
	check(not panel.layout.hidden.has("section.mirror"), "brought back")
	_end()


func test_the_right_button_still_cancels_a_drag_and_hides_nothing():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	var from := _centre("section.mirror")
	panel._input(_button(from, true))
	panel._input(_move(_centre("section.lasers")))
	panel._input(_button(_centre("section.lasers"), true, MOUSE_BUTTON_RIGHT))
	check(not panel._dragging, "cancelled")
	check(panel.layout.hidden.is_empty(), "and nothing was hidden by it")
	_end()


func test_the_right_button_off_a_name_is_left_alone():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	check(not panel._edit_mouse(_button(Vector2(1800.0, 5.0), true, MOUSE_BUTTON_RIGHT)), "empty space")
	check(panel.layout.hidden.is_empty(), "nothing hidden")
	_end()


# --------------------------------------------------------------------------
# A double click on a slider
# --------------------------------------------------------------------------

func _slider_click(double: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.double_click = double
	return e


func test_a_double_click_on_a_slider_puts_its_setting_back_to_the_default():
	_begin()
	var index: int = panel.params.find(show.registry.find("lasers/width"))
	var p: VJParam = panel.params[index]
	p.set_value(17.0)
	panel._sliders[index].gui_input.emit(_slider_click(false))
	same(p.value, 17.0, "a single click leaves it where the slider put it")
	panel._sliders[index].gui_input.emit(_slider_click(true))
	same(p.value, p.default_value, "a double click sends it back to the declared value")
	same(panel._sliders[index].value, p.default_value, "and the slider follows")
	same(panel.selected, index, "and the row is the selected one")
	_end()


func test_the_default_is_the_declared_one_after_a_preset_or_the_pilot_moved_it():
	_begin()
	var index: int = panel.params.find(show.registry.find("spot/radius"))
	var p: VJParam = panel.params[index]
	var declared: float = p.default_value
	same(declared, 200.0, "what _build_params declares, whatever an earlier case did to the value")
	p.set_value(500.0)
	p.apply_current()
	panel._sliders[index].gui_input.emit(_slider_click(true))
	same(p.value, declared, "not 500, and not whatever was last written")
	_end()


func test_only_a_left_double_click_resets():
	_begin()
	var index: int = panel.params.find(show.registry.find("lasers/width"))
	var p: VJParam = panel.params[index]
	p.set_value(17.0)
	var right := _slider_click(true)
	right.button_index = MOUSE_BUTTON_RIGHT
	panel._sliders[index].gui_input.emit(right)
	var release := _slider_click(true)
	release.pressed = false
	panel._sliders[index].gui_input.emit(release)
	var motion := InputEventMouseMotion.new()
	panel._sliders[index].gui_input.emit(motion)
	same(p.value, 17.0, "the right button, a release and a movement leave it alone")
	p.reset()
	_end()


# --------------------------------------------------------------------------
# Fitting the window
# --------------------------------------------------------------------------

func test_the_panel_stays_scaled_down_after_the_container_sorts_again():
	_begin()
	# A window far too short for the panel, so the fit has something to do.
	panel.vertical_margin = 1500.0
	panel.relayout()
	await _settle()
	var columns: Control = panel._columns
	check(columns.scale.x < 0.95, "shrunk to fit")
	var fitted := columns.scale.x
	# A container resets the scale of its children each time it sorts them. Whatever
	# sorts it, the fit has to be put back, or the panel springs back to full size and
	# runs off the edge of the screen.
	panel.rows.queue_sort()
	await _settle()
	panel.rows.queue_sort()
	await _settle()
	check(is_equal_approx(columns.scale.x, fitted), "still %.2f after two more sorts, not back to 1" % fitted)
	panel.vertical_margin = 48.0
	_end()


func test_a_panel_that_fits_is_not_touched():
	_begin()
	panel.vertical_margin = 0.0
	panel.relayout()
	await _settle()
	var needed: Vector2 = panel._columns.get_combined_minimum_size()
	var room: Vector2 = panel.get_viewport().get_visible_rect().size
	if needed.x <= room.x - 48.0 and needed.y <= room.y:
		same(panel._columns.scale, Vector2.ONE, "it only ever shrinks: a fitting panel keeps its size")
	else:
		check(panel._columns.scale.x <= 1.0, "it never grows")
	panel.vertical_margin = 48.0
	_end()


# --------------------------------------------------------------------------
# A double click on the name of a setting
# --------------------------------------------------------------------------

func test_a_double_click_on_the_name_or_the_number_resets_too():
	_begin()
	var index: int = panel.params.find(show.registry.find("lasers/width"))
	var p: VJParam = panel.params[index]
	for control in [panel._name_labels[index], panel._value_labels[index]]:
		p.set_value(17.0)
		control.gui_input.emit(_slider_click(false))
		same(p.value, 17.0, "a single click on it leaves the setting alone")
		control.gui_input.emit(_slider_click(true))
		same(p.value, p.default_value, "a double click sends it back to the declared value")
		same(panel.selected, index, "and selects the row")
	_end()


func test_the_names_and_numbers_take_the_mouse_only_when_they_can_use_it():
	_begin()
	var index: int = panel.params.find(show.registry.find("lasers/width"))
	same(panel._name_labels[index].mouse_filter, Control.MOUSE_FILTER_STOP, "a name has to be there to be hit")
	same(panel._value_labels[index].mouse_filter, Control.MOUSE_FILTER_STOP, "and so has a number")
	panel.set_external_control(true, 0.15)
	for control in [panel._sliders[index], panel._name_labels[index], panel._value_labels[index]]:
		same(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, "while a phone or a pad has the wheel, none of the row takes the mouse")
	panel.relayout()
	await _settle()
	same(panel._name_labels[index].mouse_filter, Control.MOUSE_FILTER_IGNORE, "and a row built during the hand-over comes up the same")
	panel.set_external_control(false, 0.15)
	for control in [panel._sliders[index], panel._name_labels[index], panel._value_labels[index]]:
		same(control.mouse_filter, Control.MOUSE_FILTER_STOP, "and they take it back when the wheel is handed back")
	_end()


func test_a_hidden_section_in_the_edit_mode_takes_no_double_click():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	panel.handle_key(_key(KEY_ENTER))
	await _settle()
	var away: Array = panel._dimmed.keys()
	check(not away.is_empty(), "a section is put away and dimmed")
	for index in away:
		same(panel._name_labels[index].mouse_filter, Control.MOUSE_FILTER_IGNORE, "its names are out of reach")
		same(panel._value_labels[index].mouse_filter, Control.MOUSE_FILTER_IGNORE, "and so are its numbers")
	_end()


# --------------------------------------------------------------------------
# A double click on the name of a section
# --------------------------------------------------------------------------

func _header_double_click(key: String):
	var e := _slider_click(true)
	panel._header_of(key).gui_input.emit(e)


func test_a_double_click_on_a_section_name_resets_all_of_its_settings():
	_begin()
	await _settle()
	var lasers: Array = panel.params.filter(func(p): return p.section == "section.lasers")
	check(lasers.size() >= 5, "the section has a few settings")
	for p in lasers:
		p.set_value(p.max_value)
	var other: VJParam = show.registry.find("spot/radius")
	other.set_value(500.0)
	_header_double_click("section.lasers")
	for p in lasers:
		same(p.value, p.default_value, "%s is back to its default" % p.slug)
	same(other.value, 500.0, "and a setting in another section is left alone")
	same(panel.selected, panel.params.find(lasers[0]), "the first row of the section is selected")
	other.reset()
	_end()


func test_a_single_click_on_a_section_name_does_nothing():
	_begin()
	await _settle()
	var p: VJParam = show.registry.find("lasers/width")
	p.set_value(17.0)
	panel._header_of("section.lasers").gui_input.emit(_slider_click(false))
	same(p.value, 17.0, "one click is not a reset")
	p.reset()
	_end()


func test_resetting_the_colour_section_leaves_the_colour_mode_random():
	_begin()
	await _settle()
	# Written channels flip the mode to manual; the reset has to end on the mode.
	show.registry.find("color/red").set_value(0.9)
	same(show.registry.find("color/mode").value, 1.0, "touching a channel made it manual")
	_header_double_click("section.color")
	same(show.registry.find("color/mode").value, show.registry.find("color/mode").default_value,
		"reset to random, not knocked back to manual by the channels")
	same(show.registry.find("color/red").value, show.registry.find("color/red").default_value, "and the channel is reset too")


func test_the_section_names_refuse_the_mouse_while_a_surface_is_driving():
	_begin()
	await _settle()
	var header: Label = panel._header_of("section.lasers")
	same(header.mouse_filter, Control.MOUSE_FILTER_STOP, "a name takes the double click")
	panel.set_external_control(true, 0.15)
	same(header.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and refuses it while a phone or a pad has the wheel")
	var p: VJParam = show.registry.find("lasers/width")
	p.set_value(17.0)
	panel.relayout()
	await _settle()
	same(panel._header_of("section.lasers").mouse_filter, Control.MOUSE_FILTER_IGNORE, "a header built during the hand-over comes up refusing it")
	panel.set_external_control(false, 0.15)
	same(panel._header_of("section.lasers").mouse_filter, Control.MOUSE_FILTER_STOP, "and takes it back after")
	p.reset()
	_end()


func test_in_the_edit_mode_the_same_double_click_hides_the_section_and_resets_nothing():
	_begin()
	panel.handle_key(_key(KEY_F6))
	await _settle()
	var p: VJParam = show.registry.find("lasers/width")
	p.set_value(17.0)
	var at := _centre("section.lasers")
	panel._input(_button(at, true))
	panel._input(_button(at, false))
	panel._input(_double_click(at))
	panel._input(_button(at, false))
	check(panel.layout.hidden.has("section.lasers"), "the section is put away")
	same(p.value, 17.0, "and its settings were not reset")
	p.reset()
	_end()

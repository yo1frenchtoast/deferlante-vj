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

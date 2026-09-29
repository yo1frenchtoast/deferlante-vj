extends TestCase

const NEEDS_SHOW := false

## Sections as the panel holds them: a key and how many settings it has.
const GROUPS := [
	{"key": "section.global", "rows": 8},
	{"key": "section.color", "rows": 5},
	{"key": "section.mirror", "rows": 3},
	{"key": "section.blur", "rows": 1},
	{"key": "section.lasers", "rows": 6},
	{"key": "section.spot", "rows": 14},
	{"key": "section.audio", "rows": 8},
	{"key": "section.sphere", "rows": 8},
	{"key": "section.warp", "rows": 5},
]

const TALL := 2000.0


func _layout() -> PanelLayout:
	return PanelLayout.new()


func test_automatic_puts_setup_first_then_instruments_in_their_order():
	var plan := _layout().plan(GROUPS, TALL, false)
	same(plan[0], ["section.global", "section.color", "section.mirror", "section.blur",
		"section.audio"], "the setup column, in the order the panel names them")
	# The instruments are capped at the height of the setup column, so they spread
	# sideways over as many columns as that takes.
	same(_flat(plan.slice(1)), ["section.spot", "section.lasers", "section.sphere", "section.warp"],
		"the instruments beside it, in their order")


func test_automatic_breaks_into_more_columns_on_a_short_screen_and_never_splits_a_section():
	var tall := PanelLayout.auto_plan(GROUPS, TALL)
	var short := PanelLayout.auto_plan(GROUPS, 400.0)
	check(short.size() > tall.size(), "a short screen needs more columns")
	var seen := []
	for column in short:
		seen.append_array(column)
	seen.sort()
	var every := GROUPS.map(func(g): return g["key"])
	every.sort()
	same(seen, every, "every section appears exactly once")


func test_a_section_nobody_named_joins_the_instruments():
	var groups := GROUPS.duplicate()
	groups.append({"key": "section.new", "rows": 3})
	var plan := PanelLayout.auto_plan(groups, TALL)
	var last: Array = plan[-1]
	check(last.has("section.new"), "not dropped from the panel")


func test_hidden_sections_leave_the_plan_but_stay_in_the_edit_view():
	var layout := _layout()
	layout.toggle_hidden("section.blur")
	var shown := layout.plan(GROUPS, TALL, false)
	check(not _flat(shown).has("section.blur"), "gone from the panel")
	check(_flat(layout.plan(GROUPS, TALL, true)).has("section.blur"), "still there to bring back")
	layout.toggle_hidden("section.blur")
	check(_flat(layout.plan(GROUPS, TALL, false)).has("section.blur"), "and back")


func test_the_first_move_starts_from_what_was_on_screen():
	var layout := _layout()
	var before := layout.plan(GROUPS, TALL, true)
	check(not layout.custom, "automatic to begin with")
	layout.move_vertical(before, "section.color", -1)
	check(layout.custom, "custom after a move")
	same(layout.plan(GROUPS, TALL, true)[0][0], "section.color", "the section moved up")
	same(layout.plan(GROUPS, TALL, true)[1], before[1], "the other column is as it was")


func test_moving_up_or_down_stops_at_the_edge_of_the_column():
	var layout := _layout()
	var plan := layout.plan(GROUPS, TALL, true)
	check(not layout.move_vertical(plan, plan[0][0], -1), "nothing above the first")
	var last: String = plan[0][-1]
	check(not layout.move_vertical(layout.plan(GROUPS, TALL, true), last, 1), "nothing below the last")


func test_moving_across_columns():
	var layout := _layout()
	var plan := layout.plan(GROUPS, TALL, true)
	check(layout.move_horizontal(plan, "section.mirror", 1), "into the instruments' column")
	var after := layout.plan(GROUPS, TALL, true)
	check(after[1].has("section.mirror"), "it is there")
	check(not after[0].has("section.mirror"), "and no longer in the first")
	check(not layout.move_horizontal(after, "section.global", -1), "nothing to the left of the first column")


func test_a_new_column_opens_to_the_right_but_not_for_a_lone_section():
	var layout := _layout()
	layout.custom = true
	layout.columns = [["section.a", "section.b"], ["section.c", "section.d"]]
	var groups := [{"key": "section.a", "rows": 1}, {"key": "section.b", "rows": 1},
		{"key": "section.c", "rows": 1}, {"key": "section.d", "rows": 1}]
	var plan := layout.plan(groups, TALL, true)
	check(layout.move_horizontal(plan, "section.d", 1), "out of the last column")
	var after := layout.plan(groups, TALL, true)
	same(after.size(), 3, "one more column")
	same(after[-1], ["section.d"], "holding that section")
	check(not layout.move_horizontal(after, "section.d", 1), "a section alone is not sent further right")


func test_the_automatic_layout_is_four_columns_on_a_tall_screen():
	var plan := PanelLayout.auto_plan(GROUPS, TALL)
	same(plan.size(), 4, "the setup column and three for what is played")
	var setup := PanelLayout.SETUP_SECTIONS.filter(func(k): return GROUPS.any(func(g): return g["key"] == k))
	same(plan[0], setup, "the setup column is still a column of its own, in the order the layout names")
	for column in plan:
		check(not column.is_empty(), "no column is empty")


func test_a_short_screen_still_gets_more_than_four():
	check(PanelLayout.auto_plan(GROUPS, 300.0).size() > 4, "the budget asks for more, and it gets them")


func test_fewer_sections_than_columns_do_not_make_empty_columns():
	var two := [{"key": "section.spot", "rows": 3}, {"key": "section.lasers", "rows": 3}]
	var plan := PanelLayout.auto_plan(two, TALL)
	same(plan.size(), 2, "two sections, two columns, not three")
	for column in plan:
		check(not column.is_empty(), "and neither is empty")
	same(PanelLayout.auto_plan([], TALL), [], "nothing in, nothing out")


func test_an_emptied_column_closes():
	var layout := _layout()
	var plan := [["section.a"], ["section.b", "section.c"]]
	var groups := [{"key": "section.a", "rows": 1}, {"key": "section.b", "rows": 1},
		{"key": "section.c", "rows": 1}]
	layout.move_horizontal(plan, "section.a", 1)
	same(layout.plan(groups, TALL, true), [["section.a", "section.b", "section.c"]],
		"the column it left is gone")


func test_custom_survives_a_section_that_disappeared_and_one_that_arrived():
	var layout := _layout()
	layout.custom = true
	layout.columns = [["section.gone", "section.spot"], ["section.global"]]
	var groups := [{"key": "section.spot", "rows": 1}, {"key": "section.global", "rows": 1},
		{"key": "section.fresh", "rows": 1}]
	same(layout.plan(groups, TALL, true), [["section.spot"], ["section.global", "section.fresh"]],
		"the missing one is left out, the new one joins the last column")


func test_a_section_listed_twice_is_placed_once():
	var layout := _layout()
	layout.custom = true
	layout.columns = [["section.spot", "section.spot"], ["section.spot"]]
	same(layout.plan([{"key": "section.spot", "rows": 1}], TALL, true), [["section.spot"]], "once")


func test_hiding_a_section_in_a_custom_layout_keeps_its_place():
	var layout := _layout()
	layout.move_vertical(layout.plan(GROUPS, TALL, true), "section.color", -1)
	var before := layout.plan(GROUPS, TALL, true)
	layout.toggle_hidden("section.color")
	layout.toggle_hidden("section.color")
	same(layout.plan(GROUPS, TALL, true), before, "hidden and shown again, where it was")


func test_reset_returns_to_automatic_with_everything_shown():
	var layout := _layout()
	layout.move_horizontal(layout.plan(GROUPS, TALL, true), "section.mirror", 1)
	layout.toggle_hidden("section.blur")
	layout.reset()
	same(layout.plan(GROUPS, TALL, false), PanelLayout.auto_plan(GROUPS, TALL), "as if never touched")
	same(layout.hidden.size(), 0, "nothing put away")


func test_move_to_lands_at_the_place_it_was_dropped():
	var layout := _layout()
	var plan := layout.plan(GROUPS, TALL, true)
	check(layout.move_to(plan, "section.warp", 0, 1), "into the first column, second place")
	var after := layout.plan(GROUPS, TALL, true)
	same(after[0][1], "section.warp", "there")
	check(not _flat(after.slice(1)).has("section.warp"), "and not where it was")


func test_the_index_counts_the_target_column_without_the_moved_section():
	var layout := _layout()
	layout.custom = true
	layout.columns = [["section.global", "section.color", "section.mirror"]]
	var groups := [{"key": "section.global", "rows": 1}, {"key": "section.color", "rows": 1},
		{"key": "section.mirror", "rows": 1}]
	var plan := layout.plan(groups, TALL, true)
	# Dropped in its own column, "after the one that is now second": the last place.
	check(layout.move_to(plan, "section.global", 0, 2), "the first, dropped at the end")
	same(layout.plan(groups, TALL, true)[0], ["section.color", "section.mirror", "section.global"], "at the end")
	check(not layout.move_to(layout.plan(groups, TALL, true), "section.global", 0, 2), "dropped where it already is")


func test_dropping_on_a_new_column_and_the_refusals():
	var layout := _layout()
	layout.custom = true
	layout.columns = [["section.a", "section.b"], ["section.c"]]
	var groups := [{"key": "section.a", "rows": 1}, {"key": "section.b", "rows": 1},
		{"key": "section.c", "rows": 1}]
	var plan := layout.plan(groups, TALL, true)
	check(layout.move_to(plan, "section.a", 2, 0), "a new column past the last")
	same(layout.plan(groups, TALL, true), [["section.b"], ["section.c"], ["section.a"]], "opened on the right")
	var now := layout.plan(groups, TALL, true)
	check(not layout.move_to(now, "section.a", 3, 0), "a section alone is not sent to a new column")
	check(not layout.move_to(now, "section.a", 9, 0), "a column that does not exist")
	check(not layout.move_to(now, "section.zzz", 0, 0), "a section that does not exist")
	check(not layout.move_to(now, "section.a", -1, 0), "a negative column")


func test_a_move_that_changes_nothing_leaves_an_automatic_layout_automatic():
	var layout := _layout()
	var plan := layout.plan(GROUPS, TALL, true)
	check(not layout.move_vertical(plan, plan[0][0], -1), "up from the top")
	check(not layout.move_horizontal(plan, plan[0][0], -1), "left from the first column")
	check(not layout.move_to(plan, plan[0][0], 0, 0), "dropped where it already is")
	check(not layout.custom, "still arranging itself, so it still follows the window")


func test_it_goes_to_disk_and_comes_back():
	var layout := _layout()
	layout.move_horizontal(layout.plan(GROUPS, TALL, true), "section.mirror", 1)
	layout.toggle_hidden("section.blur")
	var path := "user://test_panel_layout.json"
	check(layout.save(path), "written")
	var read := PanelLayout.load_from(path)
	same(read.plan(GROUPS, TALL, true), layout.plan(GROUPS, TALL, true), "the same arrangement")
	same(Array(read.hidden), ["section.blur"], "and the same sections put away")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_missing_or_broken_file_is_the_automatic_layout():
	var nothing := PanelLayout.load_from("user://no_such_layout.json")
	check(not nothing.custom and nothing.hidden.is_empty(), "no file")
	for junk in [null, 42, "text", [], {}, {"version": 99, "custom": true},
			{"version": 1, "custom": true, "columns": "nope", "hidden": 7},
			{"version": 1, "custom": true, "columns": [1, [2, "section.spot"], "x"], "hidden": [3, "a"]}]:
		var layout := PanelLayout.from_dict(junk)
		# Whatever it made must still lay the panel out without a fault.
		var plan := layout.plan(GROUPS, TALL, false)
		same(_flat(plan).size() + layout.hidden.size() >= 0, true, "%s does not break the panel" % var_to_str(junk))
	var partial := PanelLayout.from_dict({"version": 1, "custom": true,
		"columns": [1, [2, "section.spot"], "x"], "hidden": [3, "section.blur"]})
	same(Array(partial.hidden), ["section.blur"], "the good keys are kept")
	check(_flat(partial.plan(GROUPS, TALL, true)).size() == GROUPS.size(), "and no section is lost")


func _flat(plan: Array) -> Array:
	var out := []
	for column in plan:
		out.append_array(column)
	return out

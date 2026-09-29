extends TestCase

## The show as a whole: what its settings declare, and what the surfaces do to them.


func test_slugs_are_unique():
	var seen := {}
	for p in params():
		check(not seen.has(p.slug), "%s is declared twice" % p.slug)
		seen[p.slug] = true
	check(seen.size() > 40, "the show declares its settings")


func test_every_setting_reads_in_both_tongues():
	var lang := Lang.new()
	for p in params():
		check(Lang.LABELS.has(p.slug), "%s has no label in Lang.LABELS" % p.slug)
		check(Lang.TEXTS.has(p.section), "%s: section %s has no text" % [p.slug, p.section])
		for tongue in [Lang.EN, Lang.FR]:
			check(lang.label_in(p.slug, tongue) != "", "%s has an empty label" % p.slug)


func test_every_slug_named_in_the_code_exists():
	# `param()` answers null for a slug that is not there, and the caller dereferences
	# it. The compiler cannot see that a string is an address, so this reads them.
	var known := {}
	for p in params():
		known[p.slug] = true
	var pattern := RegEx.create_from_string('"([a-z]+/[a-z_]+)"')
	# Not settings, though they read like slugs: OSC addresses that take arguments,
	# and a MIME type.
	var not_slugs := ["color/rgb", "preset/recall", "preset/save", "application/json"]
	for file in DirAccess.get_files_at("res://scripts/"):
		if not file.ends_with(".gd") or file == "lang.gd":
			continue
		var source := FileAccess.get_file_as_string("res://scripts/" + file)
		for m in pattern.search_all(source):
			var slug := m.get_string(1)
			if slug in not_slugs or slug.begins_with("user") or slug.begins_with("res"):
				continue
			check(known.has(slug), "scripts/%s names %s, which is not a setting" % [file, slug])


func test_osc_sets_a_setting():
	osc("/deferlante/global/speed", [2.0])
	same(param("global/speed").value, 2.0, "an absolute value")
	osc("/deferlante/global/speed", [1.0])


func test_osc_normalised_spreads_over_the_range():
	osc("/deferlante/norm/global/speed", [0.5])
	same(param("global/speed").value, 0.0, "half of -3..3 is 0")
	osc("/deferlante/norm/global/speed", [5.0])
	same(param("global/speed").value, 3.0, "above 1 is clamped to the top")
	osc("/deferlante/global/speed", [1.0])


func test_osc_ignores_what_it_cannot_use():
	var before := param("global/speed").value
	osc("/deferlante/nowhere/nothing", [1.0])
	osc("/deferlante/global/speed", ["text"])
	osc("/deferlante/global/speed", [])
	same(param("global/speed").value, before, "nothing moved")


func test_osc_rgb_sets_the_three_channels():
	osc("/deferlante/color/rgb", [0.2, 0.4, 0.6])
	same([param("color/red").value, param("color/green").value, param("color/blue").value],
		[0.2, 0.4, 0.6], "one message, three channels")
	osc("/deferlante/color/rgb", [0.1])
	same(param("color/red").value, 0.2, "a short message changes nothing")


func test_touching_a_colour_leaves_random_mode():
	param("color/mode").set_value(0.0)
	param("color/red").set_value(0.5)
	same(param("color/mode").value, 1.0, "manual, so the slider is not a dead one")
	fire("randomize")
	same(param("color/mode").value, 0.0, "the randomise action is the way back")


func test_actions():
	check(fire("glitch"), "glitch")
	check(fire("randomize"), "randomize")
	check(fire("shuffle"), "shuffle")
	check(fire("shuffle:lasers"), "shuffle one section")
	check(not fire("nonsense"), "an unknown action is refused")
	check(not fire(""), "so is an empty one")
	check(not fire("preset:bad"), "and a preset with no slot")


func test_laser_count_follows_its_setting():
	param("lasers/count").set_value(6.0)
	same(show.rig.lasers.size(), 6, "grown")
	param("lasers/count").set_value(2.0)
	same(show.rig.lasers.size(), 2, "shrunk")
	param("lasers/count").set_value(3.0)


func test_a_new_laser_inherits_the_current_look():
	param("lasers/width").set_value(11.0)
	param("lasers/count").set_value(show.rig.lasers.size() + 2)
	same(show.rig.lasers.back().width, 11.0, "width")
	param("lasers/width").set_value(5.0)


func test_rest_reads_and_writes():
	var got := rest("GET", "/api/params/global/chaos")
	same(got["code"], 200, "a known setting")
	same(rest("GET", "/api/params/no/such")["code"], 404, "an unknown one")
	same(rest("PUT", "/api/params/global/chaos", '{"value": 0.5}')["code"], 200, "a write")
	same(param("global/chaos").value, 0.5, "which lands")
	same(rest("PUT", "/api/params/global/chaos", "{}")["code"], 400, "a body without a value")
	same(rest("DELETE", "/api/params/global/chaos")["code"], 405, "a verb it does not take")
	param("global/chaos").set_value(0.0)


func test_rest_actions_share_the_show_s_door():
	same(rest("POST", "/api/actions/glitch")["code"], 200, "a real one")
	same(rest("POST", "/api/actions/nonsense")["code"], 404, "an unknown one")
	same(rest("GET", "/api/actions/glitch")["code"], 405, "the wrong verb")


func test_the_spec_lists_every_setting_and_action():
	var spec: Dictionary = rest("GET", "/openapi.json")["body"]
	var text := JSON.stringify(spec)
	for p in params():
		check(text.contains(p.slug), "the OpenAPI document omits %s" % p.slug)
	for a in ShowActions.LIST:
		check(text.contains(a), "the OpenAPI document omits the action %s" % a)


func test_sound_never_writes_to_a_setting():
	param("lasers/width").set_value(5.0)
	param("audio/reactivity").set_value(1.0)
	for i in 5:
		await show.get_tree().process_frame
	same(param("lasers/width").value, 5.0, "the slider still says what it said")
	param("audio/reactivity").set_value(0.0)


func test_midi_profiles_only_name_what_the_show_answers_to():
	var files := DirAccess.get_files_at("res://midi/")
	check(files.size() >= 2, "the shipped profiles are found")
	for file in files:
		if not file.ends_with(".json"):
			continue
		var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://midi/" + file))
		var claimed := {}
		for control in profile["controls"]:
			var label := "%s / %s" % [file, control.get("label", "?")]
			check(MidiControl.MODES.has(control.get("mode", "")), "%s: unknown mode" % label)
			var why := []
			var typed := MidiControl.parse(control, why)
			check(typed != null, "%s: %s" % [label, why])
			check(typed != null and show.midi.map._target_exists(typed),
				"%s aims at %s, which nothing answers to" % [label, control.get("target", "")])
			var key = "cc%d" % control["cc"] if control.has("cc") else "note%d" % control["note"]
			check(not claimed.has(key), "%s: %s is claimed twice" % [label, key])
			claimed[key] = true


func test_the_launch_tab_describes_every_row_it_can_change():
	var described: Dictionary = show.launch_surface.describe()
	var keys := []
	for row in described["settings"]:
		keys.append(row["key"])
		check(["choice", "bool", "int"].has(row["type"]), "%s has an unknown type" % row["key"])
	same(keys.size(), 15, "the rows the launcher offers, minus the audio ones")
	check(keys.has("renderer") and keys.has("osc_port"), "the first and the last are there")
	# Unknown keys are refused before anything is written to disk.
	check(not show.launch_surface.apply("nonsense", 1), "an unknown key changes nothing")


func test_every_action_has_a_label_on_the_page():
	for a in ShowActions.LIST:
		check(Lang.TEXTS.has("action." + a), "the action %s has no label (action.%s)" % [a, a])

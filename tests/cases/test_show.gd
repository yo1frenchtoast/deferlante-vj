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


func test_the_effects_section_reads_effects_and_keeps_its_old_key_and_addresses():
	same(Lang.TEXTS["section.blur"], ["EFFECTS", "EFFETS"], "what the operator reads")
	check(PanelLayout.SETUP_SECTIONS.has("section.blur"), "the key is what saved layouts hold, so it stays")
	check(param("blur/amount") != null, "and TRAIL keeps the address a console is mapped to")
	same(param("blur/amount").section, "section.blur", "in the same section as the new ones")


func test_the_aberration_is_off_by_default_and_costs_nothing_until_asked():
	for slug in ["fx/aberration", "fx/aberration_radial", "fx/aberration_angle"]:
		check(param(slug) != null, "%s is declared" % slug)
		same(show.get_meta("defaults")[slug], 0.0, "%s starts at 0, so a show saved before it comes up unchanged" % slug)
		same(param(slug).section, "section.blur", "%s sits in the effects section" % slug)
	# Whatever an earlier case left it at: SHUFFLE rolls these like any other setting.
	param("fx/aberration").set_value(0.0)
	check(not show.aberration.rect.visible, "the pass is switched off at 0")
	param("fx/aberration").set_value(0.5)
	check(show.aberration.rect.visible, "and on above it")
	param("fx/aberration").set_value(0.0)
	check(not show.aberration.rect.visible, "and off again")


func test_the_aberration_settings_reach_the_shader():
	var material: ShaderMaterial = show.aberration.rect.material
	param("fx/aberration").set_value(1.0)
	param("fx/aberration_radial").set_value(0.5)
	param("fx/aberration_angle").set_value(0.25)
	same(material.get_shader_parameter("shift"), show.aberration.MAX_SHIFT, "the top of the slider is the most it moves")
	same(material.get_shader_parameter("radial"), 0.5, "the lens mix")
	check(is_equal_approx(material.get_shader_parameter("angle"), PI * 0.5), "a quarter turn, in radians")
	param("fx/aberration").set_value(0.5)
	check(is_equal_approx(material.get_shader_parameter("shift"), show.aberration.MAX_SHIFT * 0.5), "half way is half the distance")
	param("fx/aberration").set_value(0.0)
	param("fx/aberration_radial").set_value(0.0)
	param("fx/aberration_angle").set_value(0.0)


func test_the_chataigne_module_keeps_the_names_that_are_in_people_s_files():
	var module: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://chataigne/Deferlante/module.json"))
	var commands: Dictionary = module["commands"]
	check(commands.has("Motion Blur Trail"), "TRAIL is still 'Motion Blur Trail' on the console")
	if commands.has("Motion Blur Trail"):
		same(commands["Motion Blur Trail"]["callback"], "blurAmount", "and calls the same function")
		same(commands["Motion Blur Trail"]["menu"], "Motion Blur", "in the same menu")
	check(commands.has("Shuffle Motion Blur"), "and so is its shuffle")
	check(commands.has("Effects Aberration"), "the new effect has its own")


func test_the_drawn_aberration_follows_the_sound_and_comes_back_to_the_setting():
	param("fx/aberration").set_value(0.0)
	show.aberration.draw_amount(0.4)
	check(show.aberration.rect.visible, "the pass is on while the sound holds it open")
	same(show.aberration.rect.material.get_shader_parameter("shift"), 0.4 * show.aberration.MAX_SHIFT, "at the drawn strength")
	same(param("fx/aberration").value, 0.0, "and the setting still says 0")
	param("fx/aberration").set_value(0.0)
	check(not show.aberration.rect.visible, "the setting puts the drawing back, and the pass off")


func test_the_aberration_amount_is_off_by_default():
	same(show.get_meta("defaults")["audio/aberration"], 0.0, "a show saved before it existed hears no change")
	same(AudioModulation.new(show.registry, show.audio, show.rig, show.circle, show.sphere, show.warp).amounts["aberration"], 0.0, "and the modulation agrees")


func test_the_tunnel_runs_the_trail_pass_on_its_own_and_only_then():
	var blur = show.blur
	param("blur/amount").set_value(0.0)
	param("fx/tunnel").set_value(0.0)
	check(not blur.rect.visible, "trail 0 and tunnel 0: the pass is off, and the copy stops")
	param("fx/tunnel").set_value(0.5)
	check(blur.rect.visible, "the tunnel alone switches it on")
	same(blur.echo.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "and the copy of the frame starts")
	param("fx/tunnel").set_value(-0.5)
	check(blur.rect.visible, "backwards too")
	param("fx/tunnel").set_value(0.0)
	check(not blur.rect.visible, "and back off")


func test_the_tunnel_falls_outwards_forwards_and_inwards_backwards():
	var blur = show.blur
	var material: ShaderMaterial = blur.rect.material
	param("fx/tunnel").set_value(0.5)
	blur._process(1.0 / 60.0)
	check(material.get_shader_parameter("zoom") > 1.0, "positive magnifies the ghost: flying forward")
	param("fx/tunnel").set_value(-0.5)
	blur._process(1.0 / 60.0)
	check(material.get_shader_parameter("zoom") < 1.0, "negative shrinks it")
	param("fx/tunnel").set_value(0.0)


func test_the_tunnel_is_a_rate_not_a_step():
	var blur = show.blur
	var material: ShaderMaterial = blur.rect.material
	param("fx/tunnel").set_value(1.0)
	blur._process(1.0 / 60.0)
	var at_60: float = material.get_shader_parameter("zoom")
	blur._process(1.0 / 30.0)
	var at_30: float = material.get_shader_parameter("zoom")
	check(is_equal_approx(at_30, at_60 * at_60), "a slow frame falls twice as far, so the speed is the same at 30 fps")
	param("fx/tunnel").set_value(0.0)


func test_the_twist_turns_only_while_the_tunnel_is_on():
	var blur = show.blur
	var material: ShaderMaterial = blur.rect.material
	param("blur/amount").set_value(0.3)
	param("fx/tunnel_twist").set_value(1.0)
	blur._process(1.0 / 60.0)
	same(material.get_shader_parameter("turn"), 0.0, "twist alone does nothing to a plain trail")
	param("fx/tunnel").set_value(0.5)
	blur._process(1.0 / 60.0)
	check(material.get_shader_parameter("turn") > 0.0, "with the tunnel it turns")
	param("fx/tunnel_twist").set_value(-1.0)
	blur._process(1.0 / 60.0)
	check(material.get_shader_parameter("turn") < 0.0, "and the other way")
	param("fx/tunnel").set_value(0.0)
	param("fx/tunnel_twist").set_value(0.0)
	param("blur/amount").set_value(0.0)


func test_a_plain_trail_is_exactly_what_it_was():
	var blur = show.blur
	var material: ShaderMaterial = blur.rect.material
	param("blur/amount").set_value(0.5)
	blur._process(1.0 / 60.0)
	same(material.get_shader_parameter("zoom"), 1.0, "no magnification")
	same(material.get_shader_parameter("turn"), 0.0, "no turn")
	var expected := exp(-(1.0 / 60.0) / lerpf(blur.SHORTEST, blur.LONGEST, 0.5))
	check(is_equal_approx(material.get_shader_parameter("keep"), expected), "and the same decay as before the tunnel existed")
	param("blur/amount").set_value(0.0)


func test_the_tunnel_brings_its_own_ghost_and_the_trail_can_lengthen_it():
	var blur = show.blur
	param("blur/amount").set_value(0.0)
	param("fx/tunnel").set_value(0.5)
	same(blur._seconds(), blur.TUNNEL_SECONDS, "a tunnel with no trail still lasts long enough to be one")
	param("blur/amount").set_value(1.0)
	same(blur._seconds(), blur.LONGEST, "TRAIL makes it longer")
	param("blur/amount").set_value(0.1)
	same(blur._seconds(), blur.TUNNEL_SECONDS, "a short trail does not make it shorter")
	param("fx/tunnel").set_value(0.0)
	param("blur/amount").set_value(0.0)


func test_the_wave_is_off_by_default_and_costs_nothing_until_asked():
	same(show.get_meta("defaults")["fx/wave"], 0.0, "a show saved before it existed comes up unchanged")
	param("fx/wave").set_value(0.0)
	check(not show.wave.rect.visible, "the pass is off at 0")
	param("fx/wave").set_value(0.5)
	check(show.wave.rect.visible, "and on above it")
	param("fx/wave").set_value(0.0)
	check(not show.wave.rect.visible, "and off again")


func test_the_wave_settings_reach_the_shader():
	var material: ShaderMaterial = show.wave.rect.material
	param("fx/wave").set_value(1.0)
	param("fx/wave_count").set_value(9.0)
	same(material.get_shader_parameter("amplitude"), show.wave.MAX_AMPLITUDE, "the top of the slider is the most it pulls")
	same(material.get_shader_parameter("count"), 9.0, "the number of waves")
	param("fx/wave").set_value(0.5)
	check(is_equal_approx(material.get_shader_parameter("amplitude"), show.wave.MAX_AMPLITUDE * 0.5), "half way is half the pull")
	param("fx/wave").set_value(0.0)
	param("fx/wave_count").set_value(4.0)


func test_the_waves_travel_the_way_the_speed_says_and_stand_still_at_zero():
	var wave = show.wave
	var material: ShaderMaterial = wave.rect.material
	param("fx/wave").set_value(0.5)
	param("fx/wave_speed").set_value(1.0)
	wave._phase = 0.0
	wave._process(0.1)
	var forward: float = material.get_shader_parameter("phase")
	check(forward > 0.0, "positive moves the phase on")
	wave._phase = 0.0
	param("fx/wave_speed").set_value(-1.0)
	wave._process(0.1)
	check(material.get_shader_parameter("phase") != forward, "negative goes the other way round")
	param("fx/wave_speed").set_value(0.0)
	var before: float = wave._phase
	wave._process(0.5)
	same(wave._phase, before, "0 holds them still")
	param("fx/wave").set_value(0.0)


func test_the_waves_follow_the_global_speed():
	var wave = show.wave
	param("fx/wave").set_value(0.5)
	param("fx/wave_speed").set_value(1.0)
	param("global/speed").set_value(0.0)
	var before: float = wave._phase
	wave._process(0.5)
	same(wave._phase, before, "global speed 0 freezes the ripple with everything else")
	param("global/speed").set_value(1.0)
	wave._process(0.5)
	check(wave._phase != before, "and it moves again with the speed")
	param("fx/wave").set_value(0.0)
	param("fx/wave_speed").set_value(0.3)


func test_the_phase_stays_small_however_long_the_show_runs():
	var wave = show.wave
	param("fx/wave").set_value(0.5)
	param("fx/wave_speed").set_value(1.0)
	for i in 400:
		wave._process(1.0)
	check(wave._phase >= 0.0 and wave._phase < TAU * 4.0 + 0.001, "wrapped, so a sine never loses its precision")
	param("fx/wave").set_value(0.0)
	param("fx/wave_speed").set_value(0.3)

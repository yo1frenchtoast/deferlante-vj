extends Node

## Runs every case in `tests/cases/` and exits non-zero if one failed.
##
##     godot --headless --path . res://tests/run.tscn
##
## A scene rather than a `--script`: the `Launch` autoload has to exist, and only a
## scene run by the engine has it. No addon and nothing to install — the CI has a
## Godot binary already and this needs no more.

const CASES := "res://tests/cases/"


## `--name=value` after the bare `--`, or "" — a flatpak drops the environment, and
## the arguments are what every way of starting Godot passes on.
static func arg(name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return ""


func _ready():
	var files := DirAccess.get_files_at(CASES)
	files.sort()
	# `tests/run.sh --only=test_osc` runs one file.
	var only := arg("only")
	var checks := 0
	var failed: Array[String] = []

	# One show for every case that wants one: building it is most of the cost.
	var root: Node = load("res://scenes/main.tscn").instantiate()
	add_child(root)
	var show: Node = root.get_node("VJController")
	await get_tree().process_frame
	await get_tree().process_frame

	# What every setting says before any case has touched it. A case that fires SHUFFLE
	# or a preset leaves the settings wherever the dice put them, so "what is the
	# default" cannot be read back from the show halfway through.
	var defaults := {}
	for p in show.registry.all():
		defaults[p.slug] = p.value
	show.set_meta("defaults", defaults)

	for file in files:
		if not file.ends_with(".gd") or (only != "" and file.get_basename() != only):
			continue
		var script: GDScript = load(CASES + file)
		if script == null or not script.can_instantiate():
			failed.append("%s: does not load" % file)
			continue
		var case: TestCase = script.new()
		case.show = show if script.get_script_constant_map().get("NEEDS_SHOW", true) else null
		for method in script.get_script_method_list():
			if not method["name"].begins_with("test_"):
				continue
			var before := case.failures.size()
			await case.call(method["name"])
			var bad := case.failures.size() - before
			print("%s %s.%s" % ["FAIL" if bad > 0 else " ok ", file.get_basename(), method["name"]])
		checks += case.checks
		for f in case.failures:
			failed.append("%s: %s" % [file.get_basename(), f])

	print("\n%d checks, %d failed" % [checks, failed.size()])
	for f in failed:
		print("  ✗ " + f)
	get_tree().quit(1 if failed.size() > 0 else 0)

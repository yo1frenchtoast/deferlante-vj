extends Node

## Runs every case in `tests/cases/` and exits non-zero if one failed.
##
##     godot --headless --path . res://tests/run.tscn
##
## A scene rather than a `--script`: the `Launch` autoload has to exist, and only a
## scene run by the engine has it. No addon and nothing to install — the CI has a
## Godot binary already and this needs no more.

const CASES := "res://tests/cases/"


func _ready():
	var files := DirAccess.get_files_at(CASES)
	files.sort()
	var checks := 0
	var failed: Array[String] = []

	# One show for every case that wants one: building it is most of the cost.
	var root: Node = load("res://scenes/main.tscn").instantiate()
	add_child(root)
	var show: Node = root.get_node("VJController")
	await get_tree().process_frame
	await get_tree().process_frame

	for file in files:
		if not file.ends_with(".gd"):
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

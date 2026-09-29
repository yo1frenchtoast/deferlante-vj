extends TestCase

## Not an assertion: a photograph. With `--snap=<file>`, writes what the show
## answers on every surface to that file, so that a refactor can be checked by
## taking one photograph before it and one after, and diffing them. Without it
## this does nothing. The adapters at the top are the only lines that touch
## the show's internals.


func _all() -> Array:
	return params()


func _launch() -> Dictionary:
	return show.launch_surface.describe()


func _osc(address: String, args: Array):
	osc(address, args)


func _fire(name: String) -> bool:
	return fire(name)


func test_snapshot():
	var path: String = load("res://tests/run.gd").arg("snap")
	if path == "":
		return
	# The show draws from the one generator, so a fixed seed makes two runs of the
	# same code give the same photograph. Run it alone (`--only=zz_snapshot`): the other
	# cases leave the settings wherever they last put them.
	seed(1234)
	var out := {}
	var listed := []
	for p in _all():
		listed.append(p.describe(Lang.EN))
	out["params"] = listed
	var launch := _launch()
	# Machine-dependent rows are noise for a diff.
	launch.erase("can_restart")
	for s in launch["settings"]:
		if s["key"] in ["web_bind", "osc_bind", "auto_start"]:
			s.erase("choices")
	out["launch"] = launch

	var seq := [
		["/deferlante/global/speed", [2.0]],
		["/deferlante/norm/spot/radius", [0.5]],
		["/deferlante/norm/global/chaos", [2.0]],
		["/deferlante/lasers/count", [7]],
		["/deferlante/lasers/width", [9.0]],
		["/deferlante/lasers/parallel", [1.0]],
		["/deferlante/lasers/spin", [-0.5]],
		["/deferlante/color/rgb", [0.1, 0.2, 0.3]],
		["/deferlante/color/red", [0.9]],
		["/deferlante/nope/nothing", [1.0]],
		["/deferlante/global/speed", ["text"]],
		["/deferlante/global/speed", []],
		["/deferlante/audio/reactivity", [0.5]],
	]
	for m in seq:
		_osc(m[0], m[1])
	var values := {}
	for p in _all():
		values[p.slug] = p.value
	out["after_osc"] = values
	out["laser_count"] = show.rig.lasers.size()
	out["laser_width"] = show.rig.lasers[0].width if show.rig.lasers.size() > 0 else null

	var fired := {}
	for a in ["glitch", "randomize", "shuffle", "shuffle:lasers", "shuffle:nope",
			"preset:recall:99", "preset:bad", "unknown", ""]:
		fired[a] = _fire(a)
	out["fired"] = fired

	var api := {}
	for call in [["GET", "/api/params/global/speed", ""], ["GET", "/api/params/x/y", ""],
			["PUT", "/api/params/global/chaos", '{"value": 0.5}'],
			["PUT", "/api/params/global/chaos", "nonsense"], ["GET", "/api/presets", ""],
			["POST", "/api/actions/glitch", ""], ["POST", "/api/actions/zzz", ""],
			["GET", "/api/params", ""], ["GET", "/openapi.json", ""], ["GET", "/nothing", ""]]:
		api["%s %s" % [call[0], call[1]]] = rest(call[0], call[1], call[2])
	out["api"] = api

	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t", true))
	file.close()

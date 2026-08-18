class_name AudioRouting
extends RefCounted

## Points the machine's capture at the sound the machine is playing.
##
## Godot captures an *input* and music is an *output*. PipeWire publishes every
## output's monitor as a source, but Godot's PulseAudio backend filters monitors out
## of its own device list — and, measured, does not follow `AudioServer.input_device`
## anyway. So neither half of the obvious approach works: the source cannot be seen,
## and it could not be chosen if it were.
##
## What does work is going round the outside. The monitor is wrapped in an ordinary
## source, which Godot lists, and that source is made the system default, which Godot
## follows. This is `tools/listen-to-output.sh` expressed in the engine, so the
## operator picks an output on the launcher instead of remembering a script.
##
## Every call is a shell command. That is not elegant, but the alternative is a
## PipeWire binding for one machine's worth of work, and `pactl` is already the thing
## the documentation tells people to run.
##
## Linux and PipeWire (or PulseAudio) only. Everywhere else `available()` is false
## and the launcher falls back to offering Godot's own input list.

## The wrapper source. Shared verbatim with `tools/listen-to-output.sh`, so either
## can take over from the other and `--stop` undoes whichever one ran.
const SOURCE := "deferlante_capture"
const DESCRIPTION := "Deferlante-Capture"


## Is there a sound server here that answers?
##
## `pactl info` rather than the binary merely existing: the binary is installed on
## plenty of machines whose daemon is not running, and a list of outputs gathered
## from a dead daemon is an empty list that looks like a machine with no sound card.
static func available() -> bool:
	return _run("pactl info") == OK


## The outputs to choose between: `{name, label}`, in the order the daemon lists them.
##
## The name is what everything else here is addressed by; the label is what the
## operator reads. They are gathered separately because they have to be: the short
## listing is stable and machine-readable but carries no description, and the verbose
## one carries the description but has to be parsed. Anything without a description
## falls back to its name — long and ugly, but never blank.
static func outputs() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var labels := _labels("sinks")
	for row in _table("pactl list short sinks"):
		if row.size() > 1:
			found.append({"name": row[1], "label": labels.get(row[1], row[1])})
	return found


## The capture sources to choose between: `{name, label}`, our own tap excepted.
##
## Offered because the tap is not always the last word. A sound server can insist on
## handing recordings to something of its own — EasyEffects does — and then the honest
## question is not "which output do we tap" but "which link of the chain do we listen
## to". This is that list, monitors and processed sources included.
static func sources() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var labels := _labels("sources")
	for row in _table("pactl list short sources"):
		# Ours is what the first entry of the row already means, arrived at by
		# tapping an output. Listing it again would offer the same thing twice.
		if row.size() > 1 and row[1] != SOURCE:
			found.append({"name": row[1], "label": labels.get(row[1], row[1])})
	return found


## Capture from a named source, whatever it is and whoever feeds it.
##
## No tap, no monitor, no wrapping: the operator has said where to listen and this
## puts the machine's capture there. Which is still done by moving the default rather
## than by asking Godot, for the reason the file opens with.
static func capture_from(source: String) -> bool:
	if _index_of_source(source) == "":
		return false
	if _read("pactl get-default-source") == source:
		return true
	_remember_default()
	return _run("pactl set-default-source %s" % source) == OK


## The output the sound is currently going to.
static func default_output() -> String:
	return _read("pactl get-default-sink")


## The output the tap is currently listening to, or empty if there is no tap.
##
## Worth asking separately from whether the tap exists. The two drift apart on their
## own — plug an interface in, unplug it, and the default output moves while the tap
## stays pointed at yesterday's monitor — and the result is a capture that is open,
## healthy, and carrying nothing at all.
static func tapped_output() -> String:
	for line in _lines("pactl list short modules"):
		if not ("source_name=" + SOURCE) in line:
			continue
		# The listing separates its columns with tabs and the module's arguments
		# with spaces, and `master=` sits in the third column. Flattening both to
		# the same separator is the whole trick; splitting on spaces alone leaves
		# the index, the module name and the first argument stuck together.
		for word in line.replace("\t", " ").split(" ", false):
			if word.begins_with("master="):
				return word.substr(7).trim_suffix(".monitor")
	return ""


## Listen to `sink`, or to whatever is playing now if it is empty.
##
## Idempotent, and deliberately checks all three conditions before deciding there is
## nothing to do: the tap exists, it is on the right output, and it is the default
## source. Any two of those without the third is silence.
static func listen(sink: String) -> bool:
	if sink == "":
		sink = default_output()
	if sink == "":
		return false
	if _index_of_source(sink + ".monitor") == "":
		return false
	if is_listening_to(sink):
		return true
	# A tap on the wrong output is rebuilt rather than reported as success. This is
	# the whole reason the choice moved onto the launcher.
	_unload()
	if _run("pactl load-module module-remap-source master=%s.monitor source_name=%s"
			% [sink, SOURCE]
			+ " source_properties=device.description=%s" % DESCRIPTION) != OK:
		return false
	_remember_default()
	return _run("pactl set-default-source %s" % SOURCE) == OK


## Tapped, on this output, and actually being captured from.
static func is_listening_to(sink: String) -> bool:
	return tapped_output() == sink and _read("pactl get-default-source") == SOURCE


## Is anything actually recording from the tap?
##
## Not the same question as whether the tap exists, nor as whether it is the default,
## and the difference is the one that costs a set. A sound server is free to put a
## recording stream wherever its own policy says — measured here, EasyEffects in
## service mode pulls *every* capture onto its own source and undoes a
## `move-source-output` within the second — so the capture ends up open, healthy and
## listening to something else entirely.
##
## Asked this way round rather than by looking up our own stream: inside a Flatpak the
## sandbox has its own process ids, so what the daemon writes down for us is not the
## number this process knows itself by. A reader on the tap, on the other hand, can
## only be a show — the remap module reads the sink's monitor, not its own output.
static func tap_has_listener() -> bool:
	var index := _index_of_source(SOURCE)
	if index == "":
		return false
	for row in _table("pactl list short source-outputs"):
		if row.size() > 1 and row[1] == index:
			return true
	return false


## Put the machine's capture back the way it was found.
##
## Not called when the show ends: it would have to survive a crash and a relaunch to
## be worth anything, and a routing that half-restores is worse than one that stays
## put. `tools/listen-to-output.sh --stop` is the undo, and it reads the same note.
static func release():
	_restore_default()
	_unload()


# --------------------------------------------------------------------------
# The plumbing
# --------------------------------------------------------------------------

## Where the default source is noted down before we take it. Shared with the shell
## script, which is what puts it back.
static func _previous_path() -> String:
	var runtime := OS.get_environment("XDG_RUNTIME_DIR")
	return "%s/deferlante-previous-source" % (runtime if runtime != "" else "/tmp")


## Only ever remembers a default that is not ours. Setting up twice in a row would
## otherwise overwrite the note with our own source, and the undo would then restore
## exactly the thing it is in the middle of removing.
static func _remember_default():
	var current := _read("pactl get-default-source")
	if current == "" or current == SOURCE:
		return
	var file := FileAccess.open(_previous_path(), FileAccess.WRITE)
	if file != null:
		file.store_line(current)


static func _restore_default():
	if not FileAccess.file_exists(_previous_path()):
		return
	var previous := FileAccess.get_file_as_string(_previous_path()).strip_edges()
	if previous != "" and previous != SOURCE:
		_run("pactl set-default-source %s" % previous)
	DirAccess.remove_absolute(_previous_path())


static func _unload():
	for line in _lines("pactl list short modules"):
		if ("source_name=" + SOURCE) in line:
			_run("pactl unload-module %s" % line.split("\t")[0])


static func _index_of_source(name: String) -> String:
	for row in _table("pactl list short sources"):
		if row.size() > 1 and row[1] == name:
			return row[0]
	return ""


## Name to description, for the devices that carry one.
##
## Parsed from the text listing rather than `-f json`, which looks like the right
## answer and is not: measured on this machine, the JSON writer chokes on the
## non-ASCII in a French description and emits `(null)` for every device, so the two
## outputs that most need naming come back nameless.
static func _labels(what: String) -> Dictionary:
	var labels := {}
	var name := ""
	for line in _lines("pactl list %s" % what):
		if line.begins_with("Name:"):
			name = line.substr(5).strip_edges()
		elif line.begins_with("Description:") and name != "":
			labels[name] = line.substr(12).strip_edges()
			name = ""
	return labels


## Runs a shell line and hands back its exit code.
##
## Deliberately plain: no quotes, no `$`, no pipelines that need either. What reaches
## the shell here is parsed twice — measured, `awk \'$2 == "x"\'` arrives as
## `awk == x`, quotes stripped and fields expanded away to nothing — so every listing
## is fetched whole and picked apart in GDScript instead, where it stays readable and
## nothing can eat a character on the way.
##
## `LC_ALL=C` so the labels parsed above are the ones `pactl` prints; the device
## descriptions come from the daemon and stay in whatever tongue it speaks.
static func _run(script: String, output: Array = []) -> int:
	return OS.execute("sh", ["-c", "LC_ALL=C " + script], output)


## The output of a command, trimmed, or empty if it failed.
static func _read(script: String) -> String:
	var output := []
	if _run(script, output) != OK:
		return ""
	return "".join(output).strip_edges()


static func _lines(script: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line in _read(script).split("\n"):
		var trimmed := line.strip_edges()
		if trimmed != "":
			out.append(trimmed)
	return out


## The tab-separated listings, split into fields. `strip_edges` is not used on the
## lines here: it would eat the leading index of nothing, but the fields are cut on
## tabs and a stripped line is fine — what matters is that the split happens on the
## raw tab, not on runs of whitespace, since a sample specification contains spaces.
static func _table(script: String) -> Array:
	var rows := []
	for line in _lines(script):
		rows.append(line.split("\t", false))
	return rows

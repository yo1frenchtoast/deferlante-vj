class_name ShowDump
extends RefCounted

## The show describing itself to a generator, and then standing down.
##
## The Chataigne module used to be built by running regular expressions over the
## controller and over `lang.gd`, which made the *shape* of a declaration part of the
## contract — a setting wrapped onto two lines would have been missed — and left the
## tool keeping lists of its own beside it. One of those lists had already drifted in
## both directions unnoticed.
##
## So the show describes itself instead. English throughout, like the API and for the
## same reason: what reads this is a program, not a person in a room.


## The path a generator asked us to write to, or "" for an ordinary run.
##
## After a bare `--`, Godot hands the rest to the project, so this reads the user
## arguments rather than the engine's.
static func requested_path() -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--dump-params")
	if at == -1 or at + 1 >= args.size():
		return ""
	return args[at + 1]


static func payload(registry: ParamRegistry, presets: Node) -> Dictionary:
	var described: Array = []
	for p in registry.all():
		described.append(p.describe(Lang.EN))
	return {
		"osc_prefix": OscRouter.PREFIX,
		"params": described,
		"actions": ShowActions.LIST,
		"presets": {"count": presets.SLOTS},
	}


## True when the file was written.
static func write(path: String, registry: ParamRegistry, presets: Node) -> bool:
	var data := payload(registry, presets)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write the description to %s: %s"
			% [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("Described %d settings into %s" % [data["params"].size(), path])
	return true

class_name PanelLayout
extends RefCounted

## Which section of the panel sits in which column, and which are put away.
##
## No nodes in here: it works on lists of section keys, so that the rules can be
## tested without a screen. `control_panel.gd` asks it for a plan and draws it.
##
## There are two ways for the plan to come about. **Automatic** is what the panel has
## always done — count the columns the screen can hold and balance the sections over
## them, so that it cannot run off the bottom at any number of settings. **Custom** is
## what the operator arranged: fixed columns, in a fixed order. The first move turns
## automatic into custom, starting from whatever was on screen at that moment, so an
## edit never begins by rearranging everything. `reset()` goes back.
##
## Hiding is separate from both. A hidden section is not drawn, but its settings are
## still there — OSC, MIDI, the web page and the presets neither know nor care.

## What you settle before a set and then leave alone — the room, the track, the
## colour. It gets the first column to itself, so the hand goes to the same place
## every night whatever effects the show has gained since.
const SETUP_SECTIONS := ["section.global", "section.color", "section.mirror", "section.blur",
	"section.audio"]
## The instruments, which spread over the columns after it.
const PLAY_SECTIONS := ["section.spot", "section.lasers", "section.sphere", "section.warp"]

# Rough heights, used only to decide where to break into a new column. They do not
# have to be exact — being a few pixels out costs nothing, and the alternative is
# building the panel, measuring it, then rebuilding it a frame later.
const ROW_HEIGHT := 27
const HEADER_HEIGHT := 30

const PATH := "user://panel_layout.json"
const VERSION := 1

## False: the panel arranges itself. True: `columns` is what the operator made.
var custom: bool = false
## Section keys, one list per column, left to right. Only meaningful when `custom`.
var columns: Array = []
var hidden: PackedStringArray = []


# --------------------------------------------------------------------------
# The plan
# --------------------------------------------------------------------------

## `groups` is what the panel holds: `{"key": section key, "rows": setting count}`, in
## the order the show declared them. Answers a list of columns, each a list of keys.
##
## With `with_hidden`, hidden sections are kept in it — that is the view the operator
## edits in, where a hidden section still has to be there to be brought back.
func plan(groups: Array, budget: float, with_hidden: bool) -> Array:
	var shown: Array = []
	for group in groups:
		if with_hidden or not hidden.has(group["key"]):
			shown.append(group)

	if custom:
		return _reconcile(shown)
	return auto_plan(shown, budget)


## The panel's own arrangement: the setup sections in a column of their own, then the
## instruments beside them, capped at the setup column's height so that they spread
## sideways rather than tower over it. Anything neither list names goes in with the
## instruments — a section added to the show and forgotten here then reads oddly,
## which is a bug somebody reports, where a section quietly dropped is not.
static func auto_plan(groups: Array, budget: float) -> Array:
	var play := _ordered(groups, PLAY_SECTIONS, true)
	var setup := _run(_ordered(groups, SETUP_SECTIONS), budget)

	# Floored at the tallest single section, because a column shorter than that could
	# hold nothing, and a setup list that ever shrank would otherwise drive the count
	# of columns up without limit.
	var tallest := 0.0
	for group in play:
		tallest = maxf(tallest, height_of(group))
	var instruments := _run(play, clampf(setup["height"], tallest, budget))
	return setup["columns"] + instruments["columns"]


static func height_of(group: Dictionary) -> float:
	return HEADER_HEIGHT + group["rows"] * ROW_HEIGHT


## The groups this list names, in the order it names them. With `rest`, everything it
## does not name follows, in the order the show declared it.
static func _ordered(groups: Array, wanted: Array, rest: bool = false) -> Array:
	var out: Array = []
	for key in wanted:
		for group in groups:
			if group["key"] == key:
				out.append(group)
	for group in groups:
		if rest and not SETUP_SECTIONS.has(group["key"]) and not wanted.has(group["key"]):
			out.append(group)
	return out


## Fills as many columns as this run of sections needs, breaking only between them so a
## section is never split in two, and aiming for equal columns rather than filling the
## first to the brim: two lopsided columns read worse than two balanced ones. Answers
## the columns and the height of the tallest.
static func _run(groups: Array, budget: float) -> Dictionary:
	if groups.is_empty():
		return {"columns": [], "height": 0.0}

	var total := 0.0
	for group in groups:
		total += height_of(group)
	var wanted := maxi(1, ceili(total / maxf(1.0, budget)))
	var target := total / wanted

	var out: Array = [[]]
	var used := 0.0
	var remaining := wanted
	var tallest := 0.0
	for group in groups:
		var height := height_of(group)
		# Break when this section's midpoint would land past the target: the usual
		# balancing rule, and it keeps a section whole either side of the break.
		if used > 0.0 and remaining > 1 and used + height * 0.5 > target:
			out.append([])
			used = 0.0
			remaining -= 1
		out[-1].append(group["key"])
		used += height
		tallest = maxf(tallest, used)
	return {"columns": out, "height": tallest}


## The saved columns, held against the sections that exist now. A key that is gone —
## a section a later version dropped, or a file from another machine — is left out,
## and a section the file has never heard of is put at the end of the last column,
## because a section that quietly vanished from the panel would be the worse fault.
func _reconcile(groups: Array) -> Array:
	var present := {}
	for group in groups:
		present[group["key"]] = true

	var out: Array = []
	var placed := {}
	for column in columns:
		var kept: Array = []
		for key in column:
			if present.has(key) and not placed.has(key):
				kept.append(key)
				placed[key] = true
		if not kept.is_empty():
			out.append(kept)

	for group in groups:
		if not placed.has(group["key"]):
			if out.is_empty():
				out.append([])
			out[-1].append(group["key"])
	return out


# --------------------------------------------------------------------------
# Editing
# --------------------------------------------------------------------------

## Each of these takes the plan that is on screen, so that the first edit of an
## automatic layout starts from what the operator was looking at. They answer whether
## anything changed.

## One place up or down within the column. At the edge nothing happens: crossing to
## the next column is what left and right are for.
func move_vertical(current: Array, key: String, direction: int) -> bool:
	_adopt(current)
	var c := _column_of(key)
	if c < 0:
		return false
	var at: int = columns[c].find(key)
	var to := at + direction
	if to < 0 or to >= columns[c].size():
		return false
	columns[c][at] = columns[c][to]
	columns[c][to] = key
	return true


## One column left or right, landing at the same height where the target is that tall.
## Past the last column it opens a new one — unless the section is already alone in
## its column, which would only move an empty one along.
func move_horizontal(current: Array, key: String, direction: int) -> bool:
	_adopt(current)
	var c := _column_of(key)
	if c < 0:
		return false
	var to := c + direction
	if to < 0:
		return false
	var at: int = columns[c].find(key)
	if to >= columns.size():
		if columns[c].size() == 1:
			return false
		columns[c].remove_at(at)
		columns.append([key])
		return true
	columns[c].remove_at(at)
	columns[to].insert(mini(at, columns[to].size()), key)
	if columns[c].is_empty():
		columns.remove_at(c)
	return true


func toggle_hidden(key: String) -> bool:
	var at := hidden.find(key)
	if at >= 0:
		hidden.remove_at(at)
	else:
		hidden.append(key)
	return true


## Back to arranging itself, with everything on show.
func reset():
	custom = false
	columns = []
	hidden = PackedStringArray()


## The plan on screen becomes the arrangement, whether or not it was custom already:
## it is the saved one held against the sections that exist now, so it also carries a
## section that arrived since the file was written.
func _adopt(current: Array):
	custom = true
	columns = []
	for column in current:
		columns.append(column.duplicate())


func _column_of(key: String) -> int:
	for i in range(columns.size()):
		if columns[i].has(key):
			return i
	return -1


# --------------------------------------------------------------------------
# On disk
# --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": VERSION, "custom": custom, "columns": columns, "hidden": Array(hidden)}


## A layout from whatever was on disk. A file that is not one, or is from a version
## that does not exist yet, gives the automatic layout rather than an error: the
## panel must come up whatever is in there.
static func from_dict(data: Variant) -> PanelLayout:
	var layout := PanelLayout.new()
	if typeof(data) != TYPE_DICTIONARY or data.get("version", 0) != VERSION:
		return layout
	if typeof(data.get("hidden")) == TYPE_ARRAY:
		for key in data["hidden"]:
			if typeof(key) == TYPE_STRING:
				layout.hidden.append(key)
	if data.get("custom", false) == true and typeof(data.get("columns")) == TYPE_ARRAY:
		var read: Array = []
		for column in data["columns"]:
			if typeof(column) != TYPE_ARRAY:
				continue
			var keys: Array = []
			for key in column:
				if typeof(key) == TYPE_STRING:
					keys.append(key)
			read.append(keys)
		layout.custom = true
		layout.columns = read
	return layout


static func load_from(path: String = PATH) -> PanelLayout:
	if not FileAccess.file_exists(path):
		return PanelLayout.new()
	return from_dict(JSON.parse_string(FileAccess.get_file_as_string(path)))


func save(path: String = PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Panel: cannot save the layout to %s" % path)
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return true

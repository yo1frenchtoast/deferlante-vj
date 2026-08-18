class_name AudioProbe
extends Node

## Listens to a named capture source and reports how loud it is. The launcher's answer
## to "what am I about to listen to".
##
## **It does not use Godot to listen.** It cannot: this engine binds a capture to the
## default source when the stream opens and never looks again, and the assignment that
## ought to force it to look — `AudioServer.input_device` — kills the capture outright.
## Measured, and twice: the first reading comes through at 0.68 with music playing,
## every reopening after it reads 0.000 and the driver complains of a bad state. A
## meter that answers about the previous choice is worse than no meter at all.
##
## So it shells out. `parecord` writes raw samples into a file and this reads the tail
## of that file — no engine capture involved, nothing to reopen, and the source can be
## changed as often as the operator likes.
##
## One consequence worth knowing rather than hiding: what this measures is what a
## recording client on this machine actually receives, policy and all. If something
## intercepts recordings — EasyEffects does — the meter is subject to it too. That is
## the point. It shows what the show will get, not what the device theoretically holds.

signal level_changed(level: float)

## Mono, 8 kHz, 16-bit. A meter needs a magnitude, not a signal: this is a twentieth
## of the data of a real capture and reads exactly the same.
## The name every sample file starts with. Nothing else on the machine writes
## one, which is what makes the sweep below safe.
const FILES := "probe-"

## How long one sampling runs before it is replaced, in seconds. This is the ceiling
## on how long an orphan can outlive the show, and on how large its file can get.
const LIFETIME := 20

const RATE := 8000
## How much of the tail to look at, in samples. A twentieth of a second: long enough
## to catch a peak, short enough that the bar follows the music rather than averaging
## it away.
const WINDOW := 400

## The window the meter is drawn across. -60 dB is quiet-but-there; below that is the
## noise a silent line makes, and the bar should read empty rather than twitching.
const FLOOR_DB := -60.0
const SILENCE_DB := -70.0

## Rise fast, fall slowly. A meter that fell as fast as the signal would flicker on
## every kick and be unreadable at a glance, which is the only way it will be read.
const ATTACK := 0.05
const RELEASE := 0.4

## How long a line has to carry nothing before the meter says so. Two seconds: here
## somebody is watching the bar and waiting for it to answer, rather than running a
## set and hoping it stays quiet.
const PATIENCE := 2.0

var level: float = 0.0
## True when nothing has come in at all. Distinct from a level of zero, which is what
## the quiet between two kicks reads as.
var silent: bool = true
## What is being listened to, or empty when nothing is.
var source: String = ""

var _pid: int = -1
var _path: String = ""
var _quiet_for: float = 0.0
var _look_in: float = 0.0


## Point the meter at a source. Idempotent for the source already being read.
func listen(name: String):
	if name == source and _pid != -1:
		return
	stop()
	_sweep()
	source = name
	if name == "":
		return
	# Each sampling gets its own file. Reusing one means racing the previous
	# `parecord` for the same handle, and reading the last source's tail as if it
	# were this one's.
	_path = "%s/%s%d.raw" % [_temp_dir(), FILES, Time.get_ticks_msec()]
	# Run under `timeout` rather than bare. `parecord` is an ordinary child process:
	# kill the show rather than closing it — a crash, a pulled plug, a `timeout` of
	# our own — and it survives, still recording, still growing a file nobody will
	# ever read. Nothing in its API prevents that. Capping its life at LIFETIME does:
	# an orphan is gone within the minute and its file never passes a few hundred
	# kilobytes. `_process` starts another before this one is missed.
	_pid = OS.create_process("timeout", [
		str(LIFETIME),
		"parecord",
		"--device=" + name,
		"--raw",
		"--format=s16le",
		"--rate=%d" % RATE,
		"--channels=1",
		_path,
	])
	if _pid == -1:
		push_warning("Probe: cannot run parecord, the meter will stay empty")


## Clear away the sample files a previous run left behind.
##
## Only the files: the processes cap their own lives, which is the one approach that
## works from inside a Flatpak. There each launch gets its own process namespace, so
## a sweep by name cannot see — let alone kill — the orphan the last launch left.
func _sweep():
	var dir := DirAccess.open(_temp_dir())
	if dir == null:
		return
	for file in dir.get_files():
		if file.begins_with(FILES) and file.ends_with(".raw"):
			dir.remove(file)


func stop():
	if _pid != -1:
		# Both halves, and both are needed. `OS.kill` reaches the `timeout` wrapper
		# and stops there — killing it does not take the `parecord` underneath with
		# it, which would then outlive us with no cap left to end it. The pattern
		# reaches the child. Its brackets are not decoration: without them it matches
		# the very command line doing the matching, and the kill lands on itself.
		OS.execute("sh", ["-c", "pkill -f probe[-]"])
		OS.kill(_pid)
		_pid = -1
	if _path != "":
		DirAccess.remove_absolute(_path)
		_path = ""
	source = ""
	level = 0.0
	silent = true
	_quiet_for = 0.0


func _exit_tree():
	stop()


func _process(delta: float):
	if _pid == -1:
		return
	# Looked at ten times a second rather than every frame: the file is on disk and
	# the eye cannot read a bar faster than that anyway.
	_look_in -= delta
	if _look_in > 0.0:
		return
	_look_in = 0.1

	# The sampling has run its course and capped itself. Start another on the same
	# source: at a tenth of a second between looks, the seam does not show.
	if not OS.is_process_running(_pid):
		var again := source
		listen("")
		listen(again)
		return

	var db := _read_tail()
	if db <= SILENCE_DB:
		_quiet_for += 0.1
	else:
		_quiet_for = 0.0
	silent = _quiet_for >= PATIENCE

	var target := clampf(inverse_lerp(FLOOR_DB, 0.0, db), 0.0, 1.0)
	var speed := ATTACK if target > level else RELEASE
	level = lerpf(level, target, clampf(0.1 / speed, 0.0, 1.0))
	level_changed.emit(level)


## The loudest sample in the last window, in decibels, or silence if there is nothing
## to read yet — which is the ordinary state for the first tenth of a second.
func _read_tail() -> float:
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return SILENCE_DB - 1.0
	var length := file.get_length()
	var wanted := mini(length, WINDOW * 2)
	if wanted < 2:
		return SILENCE_DB - 1.0
	file.seek(length - wanted)
	var bytes := file.get_buffer(wanted)
	var peak := 0
	for i in range(0, bytes.size() - 1, 2):
		peak = maxi(peak, absi(bytes.decode_s16(i)))
	if peak == 0:
		return SILENCE_DB - 1.0
	return linear_to_db(float(peak) / 32768.0)


## Somewhere writable that is not the project. `user://` resolves to a real path on
## every platform this runs on, and the files are removed as soon as they stop being
## read.
func _temp_dir() -> String:
	return OS.get_user_data_dir()

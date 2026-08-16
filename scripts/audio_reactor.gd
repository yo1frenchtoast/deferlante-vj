extends Node

## Listens to the sound and turns it into three levels: bass, mid, treble.
##
## Godot captures an *input* and music is an *output*, so what gets read is the
## monitor of the main sink — wrapped in an ordinary source by
## `tools/listen-to-output.sh`, because Godot's PulseAudio backend hides monitors
## from its own device list. If that source is present it is picked automatically;
## otherwise the default input is used, which is what you want when the sound comes
## in through an interface instead.
##
## The captured bus is muted. It has to be: reading the output and playing it back
## into the output is a feedback loop.
##
## Levels are **normalised against a running peak** rather than a fixed gain. One
## track masters six decibels louder than the next, and a fixed gain that suits one
## either sits flat or clips on the other. The peak decays slowly, so a quiet
## passage opens the levels back up instead of going dead.

signal levels(bass: float, mid: float, treble: float)

@export var enabled: bool = true
## The capture source to look for. Anything containing this is preferred.
@export var preferred_device: String = "deferlante"

## Where each band is read, in hertz.
@export var bass_range := Vector2(30, 250)
@export var mid_range := Vector2(250, 2000)
@export var treble_range := Vector2(2000, 8000)

## Rise instantly, fall quickly but not instantly: a level that fell as fast as it
## rose would flicker on every kick rather than pulse with it, and one that sagged
## the way this used to would still be coming down when the next kick landed. The
## fall is what separates two hits into two, so it is set just long enough to read
## as a decay and no longer.
@export var attack: float = 0.03
@export var release: float = 0.3
## How fast the running peak forgets a loud moment, in decibels per second.
@export var peak_fall: float = 6.0
## The reading is not clipped: measured on a techno set, bass lives around -35 dB
## while the hi-hats sit between -60 and -100. Any floor high enough to gate a
## quiet room flattened the treble into a constant, so the reading runs free and
## `silence_db` does the gating instead.
@export var floor_db: float = -130.0
## Below this a band is silence and reads zero, whatever the running peak says.
@export var silence_db: float = -98.0
## The narrowest window the band is allowed to stretch across, in decibels. Below
## this the range is treated as noise rather than dynamics, so a steady tone does
## not get expanded into a full-scale flicker.
##
## This is the ceiling on the automatic gain, and it was set too cautiously. A bass
## line is nearly continuous: its loud moments sit a few decibels above its quiet
## ones, well inside the old 9 dB floor, so the whole band was divided by a range it
## never used and the kick topped out around 0.45 — measured, on the original
## settings, with the spotlight it drives barely moving. At 5 dB the same passage
## reaches 0.99 and spends 22 % of its time low instead of 63 %.
##
## Not lowered further than that. 3 dB was measured too and gains almost nothing on
## top (0.99 against 1.00), while every decibel here also expands whatever hum is in
## the room when nothing is playing. `silence_db` gates real silence; this is the
## guard for the quiet-but-not-silent case, and it is worth keeping some.
@export var min_range_db: float = 5.0
## Seconds the running average looks back over. This is the reference the level is
## measured *against*, so it wants to be a few bars: short enough to follow a build,
## long enough that a single bar does not become the new normal.
##
## Shortening it to 2 s was tried while sharpening the envelope, on the theory that a
## reference following the track more closely would show more. It showed *less*:
## measured back to back, every band moved less than at 4 s, because a reference that
## chases the signal rises to meet it and flattens exactly what it was meant to
## reveal. Left alone. The nervousness comes from `release`, not from here.
@export var average_window: float = 4.0
## The running peak never falls below this many dB. It has to sit under the
## quietest band's real peak — the treble's — or that band never leaves the floor.
@export var peak_floor_db: float = -92.0

## Response curve. 0 leaves the levels as measured; higher pushes the middle down
## so only the hits show. Adaptive scaling gets the range right but still leaves a
## busy track sitting high on average, and how much of that reads as "pulsing"
## rather than "loud" is a taste call, not a measurement.
##
## Left where it was when the envelope was sharpened. Raising it to 0.5 alongside
## the faster release compounded: the shorter decay already lowers the average, and
## squaring that on top left the bass reading 0.09 with 89 % of its time on the
## floor — the kick, which drives the biggest shape on screen, stopped registering
## at all. The nervousness wanted here comes from the envelope, not from the curve.
var punch: float = 0.35

var bass: float = 0.0
var mid: float = 0.0
var treble: float = 0.0
## Loudest of the three, which is what most things want to follow.
var level: float = 0.0

var capturing: bool = false
var device_name: String = ""
## Seconds every band has spent below `silence_db` without interruption.
##
## A capture pointed at the wrong source reads exactly this: open, healthy, and
## carrying nothing at all. It is the failure mode with no symptom — the bars simply
## never move — so it is worth counting rather than leaving to be discovered.
var silent_for: float = 0.0

## How long that has to last before it is reported. Longer than any gap in a set,
## shorter than the time it takes to start wondering why nothing is moving.
const SILENCE_GRACE := 10.0

const BUS := "DeferlanteCapture"

var _player: AudioStreamPlayer
var _analyser: AudioEffectSpectrumAnalyzerInstance
## The smoothed levels before the response curve. The curve has to be applied on
## the way out, never to these: written back into the state it compounds frame
## after frame — measured, every band collapsed to 0.00 within a second.
var _smoothed := [0.0, 0.0, 0.0]
var _peaks := [-92.0, -92.0, -92.0]
var _floors := [-92.0, -92.0, -92.0]
## Both ends start at the first reading rather than at the bottom of the scale.
## Starting at -92 dB with a floor that climbs a few decibels a second, it took
## half a minute to reach the music — and until it did, every band read 0.9 flat.
var _primed := false


func _ready():
	if not enabled:
		set_process(false)
		return
	_build_bus()
	# The device cannot be chosen from _ready — the assignment reads back as
	# "Default" — nor one frame later, where it reads back empty. It takes until
	# the driver has actually settled, so we wait a beat and then check.
	_delayed_start()


func _build_bus():
	var index := AudioServer.get_bus_index(BUS)
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
	AudioServer.add_bus_effect(index, AudioEffectSpectrumAnalyzer.new())
	# Muted, not quiet: what we are listening to is the output itself.
	AudioServer.set_bus_mute(index, true)
	_analyser = AudioServer.get_bus_effect_instance(index, 0)

	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = BUS
	add_child(_player)


func _delayed_start():
	await get_tree().create_timer(0.4).timeout
	_start_capture()


func _start_capture():
	# Still asked for, in case a future build honours it — but not relied on, and
	# not warned about when it fails, because the helper script has already made
	# the right source the default and that is what actually gets captured.
	var wanted := _pick_device()
	if wanted != "":
		AudioServer.input_device = wanted
	device_name = AudioServer.input_device
	_player.play()
	capturing = _analyser != null
	if capturing:
		print("Audio: capturing the default input%s" %
			(" (%s)" % device_name if device_name != "" else ""))
	else:
		push_warning("Audio: no spectrum analyser, reactivity is off")


## Prefers the monitor wrapper if the helper script has been run, and says nothing
## if it has not — capturing an interface's input is a perfectly good setup too.
##
## A source named at the launcher wins outright. That is the point of naming it: the
## automatic pick is a good guess about a machine nobody has configured, and a bad
## one about a machine where somebody has.
func _pick_device() -> String:
	if Launch.audio_device != "":
		return Launch.audio_device
	for device in AudioServer.get_input_device_list():
		if preferred_device.to_lower() in device.to_lower():
			return device
	return ""


## There is deliberately no way to re-open the capture at runtime.
##
## Godot binds to whatever the default source was when the stream started. Stopping
## and restarting the player does not re-read it — measured, the analyser then reads
## exactly 0.00000 and the capture is dead until the process restarts. A button that
## silently breaks capture is worse than no button, so the routing has to be in place
## before launch and that is what the documentation says.


func _process(delta: float):
	if not capturing:
		return

	var raw := [
		_read(bass_range),
		_read(mid_range),
		_read(treble_range),
	]

	if raw[0] <= silence_db and raw[1] <= silence_db and raw[2] <= silence_db:
		silent_for += delta
	else:
		silent_for = 0.0

	# Primed on the first frame that actually carries sound, not the first frame
	# full stop. The analyser has no data yet when _process first runs, so priming
	# there set the reference to -130 dB and left it crawling upwards for a minute
	# while every band read 0.95 — a plateau, exactly what this was meant to avoid.
	if not _primed and raw[0] > silence_db:
		_primed = true
		for i in range(3):
			_peaks[i] = raw[i]
			_floors[i] = raw[i]

	for i in range(3):
		# Both ends of the scale follow the music, not just the top. Tracking only
		# the peak and sitting a fixed number of decibels below it meant that a
		# track with six decibels of movement spent all its time in the top of the
		# range: technically adaptive, visually a constant.
		#
		# The peak jumps up and sags down; the floor drops instantly and climbs
		# slowly. Between them they stretch whatever range the music actually has
		# across the whole output, so a calm passage opens up and a loud one still
		# pulses instead of pinning.
		_peaks[i] = maxf(peak_floor_db, maxf(raw[i], _peaks[i] - peak_fall * delta))
		# The reference is the running *average*, not the running minimum. On
		# continuous music the quietest moment between two kicks is still loud, so
		# a minimum-tracking floor sat just under the signal and everything read
		# 0.85 — thick all the time with a slight tremble. Measured against the
		# average instead, the ordinary level of the track maps to zero and only
		# what rises above it shows: a pulse rather than a plateau.
		_floors[i] = lerpf(_floors[i], raw[i], clampf(delta / average_window, 0.0, 1.0))
		var span: float = maxf(_peaks[i] - _floors[i], min_range_db)
		var target: float = clampf((raw[i] - _floors[i]) / span, 0.0, 1.0)
		if raw[i] <= silence_db:
			target = 0.0
		var current: float = _smoothed[i]
		# Asymmetric smoothing: fast towards a louder value, slow away from it.
		var speed := attack if target > current else release
		_smoothed[i] = lerpf(current, target, clampf(delta / maxf(speed, 0.001), 0.0, 1.0))

	# Capped at 3: measured, a fourth power left even a loud track reading 0.01.
	var gamma := 1.0 + punch * 2.0
	bass = pow(_smoothed[0], gamma)
	mid = pow(_smoothed[1], gamma)
	treble = pow(_smoothed[2], gamma)

	level = maxf(bass, maxf(mid, treble))
	levels.emit(bass, mid, treble)


## Listening, and hearing nothing whatsoever. Distinct from `capturing`, which only
## says the analyser exists, and from a level of zero, which is what a quiet bar
## between two kicks reads as well.
func is_silent() -> bool:
	return capturing and silent_for >= SILENCE_GRACE


func _read(band: Vector2) -> float:
	# MAX rather than AVERAGE: averaging a narrow tone across a wide band divides
	# it by the silence either side of it. A 6 kHz tone read as nothing at all in
	# a 2–12 kHz band until this changed.
	var magnitude := _analyser.get_magnitude_for_frequency_range(
		band.x, band.y, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX
	).length()
	# Returned in decibels; the caller does the scaling against its running peak.
	return maxf(linear_to_db(magnitude), floor_db)

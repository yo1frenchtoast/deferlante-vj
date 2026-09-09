#!/usr/bin/env bash
# Give Godot the APC64's Custom port, which it cannot open by itself.
#
#     tools/apc64-bridge.sh          # connect, then say what it did
#
# The APC64 shows up as one ALSA rawmidi device with four subdevices — DAW,
# Notes, MIDI, Custom — and Godot's driver opens a device without naming a
# subdevice, so ALSA hands it number 0, the DAW port. That port stays silent in
# Custom Mode, which is the mode the show's profile is written for. Measured on
# Godot 4.7.2: `/proc/asound/cardN/midi0` shows Godot owning `Input 0` with zero
# bytes received while `Input 3` carries the traffic.
#
# The way through is a virtual cable. `snd-virmidi` cards are plain rawmidi
# devices, so Godot opens them like any other, and the ALSA sequencer can pour
# the Custom port into one. Godot opens every input it finds and `InputEventMIDI`
# carries no port, so the show reads the bridged notes without knowing.
#
# Run this after the APC64 is plugged in and before the show starts. It is
# idempotent: running it twice connects nothing twice.

set -euo pipefail

if [ ! -d /sys/module/snd_virmidi ]; then
	echo "snd-virmidi is not loaded; asking for it" >&2
	sudo modprobe snd-virmidi
fi

# `aconnect -l` prints a client line, then its ports indented under it. Both
# halves of an address have to come off the same walk, so awk keeps the client
# it last saw. `-i` and `-o` ask for readable and writable ports respectively,
# which is the difference between the two searches. The space before the colon
# in `client 28 : 'APC64'` is real and belongs in the pattern.
port_named() {
	LC_ALL=C aconnect "$1" -l | awk -v want="$2" '
		/^client [0-9]+ *:/ { client = $2; sub(":", "", client); next }
		index($0, want)     { print client ":" $1; exit }
	'
}

source_port=$(port_named -i "APC64 Custom")
if [ -z "$source_port" ]; then
	echo "no APC64 Custom port — is the APC64 plugged in and awake?" >&2
	exit 1
fi

# Any VirMIDI will do; the first keeps the choice boring and repeatable.
sink_port=$(port_named -o "VirMIDI")
if [ -z "$sink_port" ]; then
	echo "no VirMIDI port, though the module is loaded" >&2
	exit 1
fi

# ALSA already refuses a duplicate subscription, and says so on stderr. Reading
# its answer beats reading the connection table ourselves: no second way of
# deciding what "already connected" means, and no race against another run. The
# answer is translated, so it is asked for in C.
if err=$(LC_ALL=C aconnect "$source_port" "$sink_port" 2>&1); then
	echo "bridged: APC64 Custom ($source_port) -> VirMIDI ($sink_port)"
elif case "$err" in *"already subscribed"*) true ;; *) false ;; esac; then
	echo "already bridged: $source_port -> $sink_port"
else
	echo "$err" >&2
	exit 1
fi

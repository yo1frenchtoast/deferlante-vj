#!/usr/bin/env bash
# Expose the main output's monitor as a capture source Déferlante can read.
#
#   tools/listen-to-output.sh          # create it
#   tools/listen-to-output.sh --stop   # remove it
#
# Godot captures an *input*, and music is an *output*. PipeWire does publish the
# output's monitor as a source, but Godot's PulseAudio backend filters monitors out
# of its device list. This wraps the monitor in an ordinary source, which Godot does
# list.
#
# It then makes that source the default. Godot's AudioServer.input_device setter
# turned out not to hold in this build — assigned from _ready it reads back
# "Default", a frame later it reads back empty — so the only reliable way to point
# Godot at a particular source is to make it the one Godot gets anyway. The previous
# default is remembered and put back by --stop.
#
# Nothing about your playback changes: this taps the output, it does not reroute it.

set -euo pipefail

NAME=deferlante_capture
PREVIOUS="${XDG_RUNTIME_DIR:-/tmp}/deferlante-previous-source"

existing() {
    pactl list short modules 2>/dev/null | awk -v n="source_name=$NAME" '$0 ~ n {print $1}'
}

# Which sink the existing source is actually tapping, as opposed to which one is
# playing now. The two drift apart on their own: plug in an interface, unplug it,
# and the default sink moves while the remap stays pointed at yesterday's monitor.
master_of() {
    pactl list short modules 2>/dev/null \
        | awk -v n="source_name=$NAME" '$0 ~ n' \
        | grep -o 'master=[^[:space:]]*' | head -1 | cut -d= -f2
}

# Only remember a default that is not ours. Running this twice used to overwrite
# the note with "deferlante_capture" itself, so --stop then restored the source it
# was in the middle of deleting.
remember_default() {
    local current
    current=$(pactl get-default-source)
    if [[ "$current" != "$NAME" ]]; then
        echo "$current" > "$PREVIOUS"
    fi
}

if [[ "${1:-}" == "--stop" ]]; then
    ids=$(existing)
    if [[ -z "$ids" ]]; then
        echo "Nothing to remove."
        exit 0
    fi
    if [[ -f "$PREVIOUS" ]]; then
        pactl set-default-source "$(cat "$PREVIOUS")" 2>/dev/null || true
        echo "Default source restored to $(cat "$PREVIOUS")."
        rm -f "$PREVIOUS"
    fi
    for id in $ids; do pactl unload-module "$id"; done
    echo "Capture source removed."
    exit 0
fi

# The source existing is not the same as it being listened to. An earlier run can
# leave it behind while something else takes the default back, and bailing out here
# on the strength of the source alone reported success while capturing the wrong
# thing entirely.
sink=$(pactl get-default-sink)
monitor="${sink}.monitor"

# The source existing is not the same as it being listened to, and neither is the
# same as it listening to the right thing. Both have been the failure in practice:
# the capture stays open and healthy and simply carries nothing, which looks exactly
# like reactivity being broken. So check all three before deciding there is nothing
# to do, and rebuild rather than report success on a stale tap.
if [[ -n "$(existing)" ]]; then
    if [[ "$(master_of)" != "$monitor" ]]; then
        echo "Capture was tapping $(master_of), but the sound now goes to $sink."
        echo "Rebuilding it on the current output."
        for id in $(existing); do pactl unload-module "$id"; done
    elif [[ "$(pactl get-default-source)" == "$NAME" ]]; then
        echo "Already listening to $sink."
        exit 0
    else
        echo "Source exists but was not the default — pointing capture back at it."
        remember_default
        pactl set-default-source "$NAME"
        echo "Listening to: $sink"
        exit 0
    fi
fi

if ! pactl list short sources | grep -q "^[0-9]*[[:space:]]*${monitor}[[:space:]]"; then
    echo "No monitor found for the default sink ($sink)." >&2
    echo "Sources available:" >&2
    pactl list short sources | awk '{print "  " $2}' >&2
    exit 1
fi

pactl load-module module-remap-source \
    master="$monitor" \
    source_name="$NAME" \
    source_properties=device.description=Deferlante-Capture > /dev/null

remember_default
pactl set-default-source "$NAME"

echo "Listening to: $sink"
echo "Run with --stop to undo — it puts your default source back."

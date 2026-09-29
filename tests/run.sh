#!/usr/bin/env bash
# Runs the tests, and fails on a script error as well as on a failed check: an
# engine error inside a case is printed but does not stop the case, and a suite
# that goes green over one is worse than none.
#
#   tests/run.sh                       godot on the PATH
#   GODOT="flatpak run --command=godot org.godotengine.Godot" tests/run.sh
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
log=$(mktemp)
trap 'rm -f "$log"' EXIT
# The import brings the `class_name` cache up to date; a fresh checkout has none,
# and the cases could not name `TestCase` without it.
$GODOT --headless --path . --import >/dev/null 2>&1
timeout 120 $GODOT --headless --path . res://tests/run.tscn 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if grep -q -E 'SCRIPT ERROR|Parse Error' "$log"; then
	echo "✗ a script raised an error (see above)"
	exit 1
fi
exit "$status"

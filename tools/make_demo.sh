#!/usr/bin/env bash
# Films the pictures of the README, from the show itself.
#
#   tools/make_demo.sh                 the opening clip, docs/demo.gif
#   tools/make_demo.sh kaleidoscope    the second clip, docs/kaleidoscope.gif
#   tools/make_demo.sh screenshot      the still, docs/screenshot.png
#   tools/make_demo.sh all
#   GODOT="flatpak run --command=godot org.godotengine.Godot" tools/make_demo.sh
#
# Each one is a scene in `tools/demo/`, played under `--write-movie`, one PNG a frame, and
# ffmpeg turns the frames into a GIF with a palette made for it. A window opens on this
# screen for as long as the film takes, because the renderer needs one.
#
# Not for judging the show's timing: a movie is rendered on its own clock, and a real run
# behaves differently (see docs/in-the-room.md).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}

film() {  # film <scene name> -> frames in .godot/demo-frames
	local length frames
	length=$(grep -oP 'const LENGTH := \K[0-9.]+' "tools/demo/$1.gd")
	frames=$(python3 -c "print(round($length * 30))")
	rm -rf .godot/demo-frames && mkdir -p .godot/demo-frames
	# 30 a second, so that a tween is smooth and the GIF can pick every few frames.
	$GODOT --path . --write-movie "$PWD/.godot/demo-frames/f.png" --fixed-fps 30 \
		--quit-after "$frames" "res://tools/demo/$1.tscn" >/dev/null 2>&1
}

gif() {  # gif <output> <fps> <width> <colours>
	ffmpeg -y -loglevel error -framerate 30 -i .godot/demo-frames/f%08d.png \
		-vf "fps=$2,scale=$3:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=$4:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle" \
		-loop 0 "$1"
	ls -la "$1"
}

target=${1:-demo}
case "$target" in
	demo|all)
		film demo
		gif docs/demo.gif "${FPS:-8}" "${WIDTH:-640}" "${COLORS:-48}" ;;&
	kaleidoscope|all)
		film kaleidoscope
		gif docs/kaleidoscope.gif "${FPS:-10}" "${WIDTH:-640}" "${COLORS:-64}" ;;&
	screenshot|all)
		film screenshot
		last=$(ls .godot/demo-frames/f*.png | tail -1)
		ffmpeg -y -loglevel error -i "$last" -frames:v 1 docs/screenshot.png
		ls -la docs/screenshot.png ;;
	demo|kaleidoscope|screenshot|all) ;;
	*) echo "unknown picture: $target" >&2; exit 2 ;;
esac

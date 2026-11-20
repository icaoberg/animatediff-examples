#!/usr/bin/env bash
#
# Convert AnimateDiff GIFs to H.264 MP4 files that play in QuickTime, browsers and phones.
# Each <name>.gif gets a <name>.mp4 next to it; existing MP4s are overwritten.
#
# Usage:
#   ./to_mp4.sh samples/example0-2026-11-20T12-00-00/     # every GIF in a folder (recursive)
#   ./to_mp4.sh clip.gif other.gif                       # specific files
#
# AnimateDiff saves GIFs at 8 fps, but GIF delays are whole centiseconds (12/13 cs), so the
# timestamps are rebuilt (setpts) for an exact constant 8 fps. yuv420p is needed for
# QuickTime/Safari, and the scale filter rounds to even dimensions as H.264 requires.

set -euo pipefail

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "error: ffmpeg not found. Run 'conda activate animatediff' first." >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "usage: $0 <folder-or-gif>..." >&2
    exit 1
fi

convert() {
    local gif="$1" mp4="${1%.gif}.mp4"
    echo "==> $gif -> $mp4"
    ffmpeg -loglevel error -y -i "$gif" \
        -movflags +faststart -pix_fmt yuv420p \
        -vf "setpts=N/8/TB,scale=trunc(iw/2)*2:trunc(ih/2)*2" -r 8 \
        -c:v libx264 -crf 18 "$mp4"
}

for target in "$@"; do
    if [ -d "$target" ]; then
        while IFS= read -r -d '' gif; do
            convert "$gif"
        done < <(find "$target" -name '*.gif' -print0)
    else
        convert "$target"
    fi
done

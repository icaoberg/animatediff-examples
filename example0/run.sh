#!/usr/bin/env bash
#
# Generate the example0 clip: runs AnimateDiff's scripts/animate.py on example0.yaml,
# then converts the resulting GIF to MP4.
#
# Usage:
#   conda activate animatediff
#   ./run.sh                     # uses example0.yaml
#   ./run.sh my_prompts.yaml     # any config in the same format
#
# Output:
#   samples/<config>-<timestamp>/sample/0-<prompt>.gif   one GIF per prompt
#   samples/<config>-<timestamp>/sample.gif              all prompts in one grid
#   samples/<config>-<timestamp>/config.yaml             config with the seeds actually used
#   samples/<config>-<timestamp>/*.mp4                   MP4 copies (see to_mp4.sh)
#
# Takes about 2.5 minutes per prompt on an M4 Max (25 steps at ~6 s/step).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="${1:-example0.yaml}"

if ! python -c "import animatediff" 2>/dev/null && [ "${CONDA_DEFAULT_ENV:-}" != "animatediff" ]; then
    echo "warning: the 'animatediff' conda env does not look active (conda activate animatediff)." >&2
fi

# Run from this folder so the relative paths in the config resolve and samples/ lands here.
# PYTHONPATH makes the AnimateDiff clone importable (animatediff.*, scripts.animate).
cd "$SCRIPT_DIR"
before="$(ls -d samples/*/ 2>/dev/null || true)"

PYTHONPATH="$ROOT_DIR/AnimateDiff${PYTHONPATH:+:$PYTHONPATH}" \
    python -m scripts.animate \
        --pretrained-model-path "$ROOT_DIR/models/StableDiffusion/stable-diffusion-v1-5" \
        --config "$CONFIG"

# The newest samples/ subfolder is the one this run created.
outdir="$(ls -td samples/*/ | head -1)"
if [ -n "$before" ] && grep -qxF "$outdir" <<<"$before"; then
    echo "error: could not find the new output folder in samples/." >&2
    exit 1
fi

"$SCRIPT_DIR/to_mp4.sh" "$outdir"
echo "Done. Output is in $SCRIPT_DIR/$outdir"

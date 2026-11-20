#!/usr/bin/env bash
#
# Create (or update) the "animatediff" conda environment from environment.yml.
#
# Usage:
#   ./create.sh            # create the env, or update it if it already exists
#   ./create.sh --force    # remove the existing env and recreate it from scratch
#
# Afterwards:
#   conda activate animatediff

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/environment.yml"
ENV_NAME="$(awk '/^name:/ {print $2; exit}' "$ENV_FILE")"

# Always use conda (with the libmamba solver, the default since conda 23.10).
# A standalone mamba/micromamba 2.x has its own root prefix (e.g. ~/micromamba)
# and cannot see environments that live under conda's envs directory.
if ! command -v conda >/dev/null 2>&1; then
    echo "error: conda not found on PATH." >&2
    exit 1
fi
CONDA=conda

env_exists() {
    conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"
}

if [ "${1:-}" = "--force" ] && env_exists; then
    echo "==> Removing existing environment '$ENV_NAME'"
    conda env remove -y -n "$ENV_NAME"
fi

if env_exists; then
    echo "==> Updating environment '$ENV_NAME' from $ENV_FILE"
    "$CONDA" env update -n "$ENV_NAME" -f "$ENV_FILE" --prune
else
    echo "==> Creating environment '$ENV_NAME' from $ENV_FILE"
    "$CONDA" env create -f "$ENV_FILE"
fi

echo "Done. Activate it with: conda activate $ENV_NAME"

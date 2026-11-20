#!/usr/bin/env bash
#
# Download AnimateDiff models and add-ons from Hugging Face into models/,
# using the folder layout the AnimateDiff configs expect:
#
#   models/Motion_Module/     motion modules (v1, v2, v3, SDXL beta) + v3 domain adapter
#   models/MotionLoRA/        v2 camera-motion LoRAs
#   models/SparseCtrl/        v3 SparseCtrl RGB / scribble encoders
#   models/DreamBooth_LoRA/   community text-to-image checkpoints used by the example configs
#   models/StableDiffusion/   Stable Diffusion 1.5 base model (diffusers format)
#
# Usage:
#   conda activate animatediff
#   ./get_models.sh                     # everything (~40 GB)
#   ./get_models.sh motion sd15         # only selected groups
#   MODELS_DIR=/path/to/models ./get_models.sh
#
# Groups: motion, motionlora, sparsectrl, t2i, sd15
# Downloads resume and already-complete files are skipped, so re-running is safe.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="${MODELS_DIR:-$SCRIPT_DIR/models}"

ANIMATEDIFF_REPO="guoyww/animatediff"
T2I_REPO="guoyww/animatediff_t2i_backups"
SD15_REPO="stable-diffusion-v1-5/stable-diffusion-v1-5"

if ! command -v huggingface-cli >/dev/null 2>&1; then
    echo "error: huggingface-cli not found. Run 'conda activate animatediff' first." >&2
    exit 1
fi

download() {
    local repo="$1" dest="$2"
    shift 2
    echo "==> $repo -> $dest"
    mkdir -p "$dest"
    huggingface-cli download "$repo" "$@" --local-dir "$dest"
}

get_motion() {
    download "$ANIMATEDIFF_REPO" "$MODELS_DIR/Motion_Module" \
        mm_sd_v14.ckpt \
        mm_sd_v15.ckpt \
        mm_sd_v15_v2.ckpt \
        mm_sdxl_v10_beta.ckpt \
        v3_sd15_mm.ckpt \
        v3_sd15_adapter.ckpt
}

get_motionlora() {
    download "$ANIMATEDIFF_REPO" "$MODELS_DIR/MotionLoRA" \
        v2_lora_PanLeft.ckpt \
        v2_lora_PanRight.ckpt \
        v2_lora_RollingAnticlockwise.ckpt \
        v2_lora_RollingClockwise.ckpt \
        v2_lora_TiltDown.ckpt \
        v2_lora_TiltUp.ckpt \
        v2_lora_ZoomIn.ckpt \
        v2_lora_ZoomOut.ckpt
}

get_sparsectrl() {
    download "$ANIMATEDIFF_REPO" "$MODELS_DIR/SparseCtrl" \
        v3_sd15_sparsectrl_rgb.ckpt \
        v3_sd15_sparsectrl_scribble.ckpt
}

get_t2i() {
    download "$T2I_REPO" "$MODELS_DIR/DreamBooth_LoRA" \
        TUSUN.safetensors \
        leosamsFilmgirlUltra_velvia20Lora.safetensors \
        leosamsHelloworldXL_filmGrain20.safetensors \
        lyriel_v16.safetensors \
        majicmixRealistic_v4.safetensors \
        majicmixRealistic_v5Preview.safetensors \
        rcnzCartoon3d_v10.safetensors \
        realisticVisionV60B1_v20Novae.safetensors \
        realisticVisionV60B1_v51VAE.safetensors \
        toonyou_beta3.safetensors
}

get_sd15() {
    # Only the diffusers components AnimateDiff loads, in full-precision safetensors
    # (skips the fp16/non-EMA/.bin duplicates, the single-file checkpoints and the safety checker).
    download "$SD15_REPO" "$MODELS_DIR/StableDiffusion/stable-diffusion-v1-5" \
        --include \
        "model_index.json" \
        "feature_extractor/*" \
        "scheduler/*" \
        "tokenizer/*" \
        "text_encoder/config.json" "text_encoder/model.safetensors" \
        "unet/config.json" "unet/diffusion_pytorch_model.safetensors" \
        "vae/config.json" "vae/diffusion_pytorch_model.safetensors"
}

groups=("$@")
[ ${#groups[@]} -eq 0 ] && groups=(motion motionlora sparsectrl t2i sd15)

for group in "${groups[@]}"; do
    case "$group" in
        motion)     get_motion ;;
        motionlora) get_motionlora ;;
        sparsectrl) get_sparsectrl ;;
        t2i)        get_t2i ;;
        sd15)       get_sd15 ;;
        *) echo "error: unknown group '$group' (use: motion motionlora sparsectrl t2i sd15)" >&2; exit 1 ;;
    esac
done

# huggingface-cli keeps resume metadata here; it is not needed once downloads finish.
find "$MODELS_DIR" -type d -name .cache -prune -exec rm -rf {} +

echo "Done. Models are in $MODELS_DIR"

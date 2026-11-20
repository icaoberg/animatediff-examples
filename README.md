# AnimateDiff (local setup)

Local workspace for [AnimateDiff](https://github.com/guoyww/AnimateDiff) (Guo et al., ICLR 2024 Spotlight),
cloned into `AnimateDiff/`, with a conda environment defined in `environment.yml`.

This repo sets up AnimateDiff text-to-video generation on macOS / Apple Silicon. It wraps the upstream code with
scripts that create the environment, download every pretrained checkpoint, and run self-contained examples that
turn a text prompt into a short GIF/MP4 clip on the Apple GPU (MPS).

## Repository layout

| Path | What it is |
|---|---|
| `AnimateDiff/` | Upstream clone (its own git repo) with two local patches for MPS (see [Local changes](#local-changes-for-macos-apple-silicon)) and an extra `configs/prompts/mac/` test config |
| `environment.yml` | Conda environment (`animatediff`) pinned for macOS arm64 |
| `create.sh` | Creates the conda env, or updates it if it exists (`--force` recreates it) |
| `get_models.sh` | Downloads all checkpoints from Hugging Face into `models/` (~40 GB) |
| `models/` | Downloaded checkpoints: SD 1.5 base, motion modules, MotionLoRA, SparseCtrl, community T2I models (not tracked) |
| `example0/` | Self-contained example: a red fox walking through a snowy forest. Has its own config, `run.sh`, GIF-to-MP4 conversion and README |

## Quick start

```bash
./create.sh                          # create the conda env
conda activate animatediff
./get_models.sh motion t2i sd15      # checkpoint groups example0 needs
cd example0 && ./run.sh              # ~2.5 min on an M4 Max; output in example0/samples/
```

## What it does

AnimateDiff turns an existing **text-to-image** Stable Diffusion model into a **text-to-video** model.
You give it a prompt and get back a short animated clip (16 frames at 512×512 by default, saved as a GIF).

It works by inserting a **motion module** (temporal attention layers) into a frozen Stable Diffusion 1.5 UNet.
The motion module is trained once on real videos to learn general motion. Because the image model itself is
left untouched, the same motion module can be plugged into **any SD 1.5 community checkpoint**
(DreamBooth or LoRA models such as Realistic Vision or ToonYou) and that model's style starts moving without retraining.

Main components:

| Component | What it is | Example file |
|---|---|---|
| Base model | Stable Diffusion 1.5 (tokenizer, text encoder, VAE, UNet) in diffusers format | `stable-diffusion-v1-5/stable-diffusion-v1-5` |
| Motion module | Learned temporal layers, the core of AnimateDiff | `v3_sd15_mm.ckpt`, `mm_sd_v15_v2.ckpt` |
| Domain adapter (v3) | LoRA that reduces artifacts learned from the video training data | `v3_sd15_adapter.ckpt` |
| MotionLoRA (v2) | Small LoRAs for camera moves: zoom, pan, tilt, roll | `v2_lora_ZoomIn.ckpt` |
| SparseCtrl (v3) | Optional encoders that condition on a few RGB frames or sketches (image-to-video, keyframes) | `v3_sd15_sparsectrl_rgb.ckpt` |
| Personalized T2I | Any SD 1.5 DreamBooth or LoRA checkpoint, which sets the visual style | `realisticVisionV60B1_v51VAE.safetensors` |

## Are there pretrained models?

**Yes.** Every checkpoint is published on Hugging Face at
[`guoyww/animatediff`](https://huggingface.co/guoyww/animatediff). Example community T2I models are at
[`guoyww/animatediff_t2i_backups`](https://huggingface.co/guoyww/animatediff_t2i_backups).
`scripts/animate.py` **downloads them automatically** into `AnimateDiff/models/` the first time a config needs them.

| Checkpoint | Type | Size |
|---|---|---|
| `v3_sd15_mm.ckpt` | Motion module (latest SD 1.5) | 1.56 GB |
| `v3_sd15_adapter.ckpt` | Domain adapter | 97 MB |
| `v3_sd15_sparsectrl_rgb.ckpt` / `_scribble.ckpt` | SparseCtrl encoders | ~1.85 GB each |
| `mm_sd_v15_v2.ckpt` | Motion module v2 | 1.7 GB |
| `v2_lora_*.ckpt` (8 camera motions) | MotionLoRA | 74 MB each |
| `mm_sdxl_v10_beta.ckpt` | SDXL motion module (beta, `sdxl-beta` branch only) | 950 MB |

The Stable Diffusion 1.5 base model (~5 GB) comes from Hugging Face as well. The script's default ID,
`runwayml/stable-diffusion-v1-5`, was retired in 2024 and now only redirects, so pass the official mirror
explicitly (see below) or download it to `AnimateDiff/models/StableDiffusion/stable-diffusion-v1-5`.

### Downloading everything up front

`get_models.sh` downloads every checkpoint above, the community T2I models, and the SD 1.5 base model
(full-precision safetensors only) into `models/`, using the folder layout the configs expect. That's about 40 GB in total.

```bash
conda activate animatediff
./get_models.sh                  # everything
./get_models.sh motion sd15      # or pick groups: motion motionlora sparsectrl t2i sd15
```

Re-running it resumes partial downloads and skips files that are already complete. To keep the files elsewhere, set `MODELS_DIR=/path ./get_models.sh`.

## Do I need to train on my own data?

**No.** For generating videos you only run inference with the released checkpoints. To change the
look, swap in a different SD 1.5 community checkpoint. To add camera motion, use a MotionLoRA.
Neither requires training.

Training (`train.py` with `configs/training/`) is only needed to:

- train a new motion module from scratch on a large video dataset (the paper uses WebVid-10M), or
- fine-tune a motion module or MotionLoRA for a specific kind of motion on your own clips.

Training needs NVIDIA GPUs (CUDA, NCCL, xformers, decord) and **will not run on this Mac**.

## Environment

```bash
./create.sh              # or: conda env create -f environment.yml
conda activate animatediff
```

The pins follow upstream `requirements.txt` (torch 2.3.1, diffusers 0.11.1, transformers 4.25.1), adjusted for
macOS on Apple Silicon:

- `xformers` (CUDA-only) and `decord` (no arm64 macOS wheels, training only) are left out.
- `huggingface_hub`, `gradio_client`, `fastapi`/`pydantic`, `httpx`, `setuptools` and `wandb` are pinned to
  versions that still work with these 2023-era libraries. See the comments in `environment.yml`.

PyTorch's MPS (Apple GPU) backend is available in this environment.

## Running

```bash
cd AnimateDiff
python -m scripts.animate \
  --pretrained-model-path stable-diffusion-v1-5/stable-diffusion-v1-5 \
  --config configs/prompts/1_animate/1_1_animate_RealisticVision.yaml
```

Output goes to `AnimateDiff/samples/`. Other example configs:

- `configs/prompts/1_animate/*`: community-style text-to-video
- `configs/prompts/2_motionlora/*`: camera motion via MotionLoRA
- `configs/prompts/3_sparsectrl/*`: image-to-video, RGB, or sketch conditioning

`python app.py` starts a Gradio web UI.

### Local changes for macOS (Apple Silicon)

The clone in `AnimateDiff/` has two local patches so `scripts/animate.py` runs on the Apple GPU (MPS):

1. **`scripts/animate.py`:** the hardcoded `.cuda()` calls are replaced by a `--device` option
   (default: `cuda` if available, else `mps`, else `cpu`). The default base model is now the
   `stable-diffusion-v1-5/stable-diffusion-v1-5` mirror. On MPS the spatial attention layers use attention slicing.
   Without it, each 512×512×16-frame attention builds ~16 GB score tensors, the Mac swaps, and a step takes ~210 s
   instead of ~5 s. The motion-module (temporal) attention is left unsliced because it is tiny and its sliced code
   path is broken upstream.
2. **`animatediff/models/resnet.py`:** `InflatedConv3d` and `InflatedGroupNorm` now return `.contiguous()` tensors.
   Without this, the output is pure noise on MPS: in torch 2.3.1, `silu`/`gelu` on MPS return wrong values for
   non-contiguous (permuted) tensors, which corrupts every UNet step without raising any error.
   With the fix, MPS output matches CPU to about 2e-5.

Measured on an M4 Max (48 GB): about 5.3 s per denoising step, so a 16-frame 512×512 clip at 20–25 steps takes about 2–2.5 minutes.

The upstream example `configs/prompts/1_animate/1_1_animate_RealisticVision.yaml` is a good end-to-end check, and
it produces clips that match their prompts on this Mac. `configs/prompts/mac/mac_test.yaml` is a quicker one-prompt
test using plain SD 1.5. Expect weaker prompt-following from it: plain SD 1.5 is a poor base for AnimateDiff, and
the upstream examples always use a community checkpoint such as Realistic Vision.

`app.py` (Gradio) still only chooses between CUDA and CPU, so it runs on CPU on a Mac and is very slow.

## References

- Paper: [AnimateDiff: Animate Your Personalized Text-to-Image Diffusion Models without Specific Tuning](https://arxiv.org/abs/2307.04725)
- Code: <https://github.com/guoyww/AnimateDiff>
- Project page: <https://animatediff.github.io/>
- Diffusers integration (newer API): <https://huggingface.co/docs/diffusers/api/pipelines/animatediff>

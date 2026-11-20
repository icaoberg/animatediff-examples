# example0: a red fox in the snow

A minimal, self-contained AnimateDiff text-to-video example. It generates one 16-frame 512×512 clip
of a red fox walking through a snowy pine forest at golden hour, saves it as a GIF, and converts it to MP4.

Everything for this example lives in this folder. It reuses the AnimateDiff clone in `../AnimateDiff/`
and the checkpoints in `../models/`, and does not modify either one.

## Files

| File | What it does |
|---|---|
| `example0.yaml` | Prompt config: model, motion module, prompt, negative prompt, seed, steps |
| `run.sh` | Runs AnimateDiff on the config, then calls `to_mp4.sh` on the new output folder |
| `to_mp4.sh` | Converts AnimateDiff GIFs to H.264 MP4 (constant 8 fps, QuickTime-compatible) |
| `run.log` | Log from the reference run below |
| `samples/` | Output folders, one per run (`example0-<timestamp>/`) |

## Requirements

- The `animatediff` conda env (`../create.sh`), which includes `ffmpeg`.
- These checkpoints in `../models/` (from `../get_models.sh motion t2i sd15`):
  - `StableDiffusion/stable-diffusion-v1-5/`: SD 1.5 base model
  - `DreamBooth_LoRA/realisticVisionV60B1_v51VAE.safetensors`: Realistic Vision v5.1 (sets the look)
  - `Motion_Module/v3_sd15_mm.ckpt`: AnimateDiff v3 motion module (adds the motion)

## Usage

```bash
conda activate animatediff
cd example0
./run.sh                    # generate the clip from example0.yaml
./run.sh my_prompts.yaml    # or any other config in the same format
./to_mp4.sh samples/        # (re)convert every GIF under samples/ to MP4
```

`run.sh` can be called from any directory. It `cd`s into this folder so the relative paths in the config
resolve, and puts `../AnimateDiff` on `PYTHONPATH` so `python -m scripts.animate` and the `animatediff`
package import without copying anything.

### Output

```
samples/example0-<timestamp>/
├── config.yaml          # the config as run, including the seeds actually used
├── sample.gif / .mp4    # all prompts in one grid (just one clip here)
└── sample/
    └── 0-<prompt>.gif / .mp4   # one clip per prompt
```

## The config (`example0.yaml`)

The format is the same as the upstream `AnimateDiff/configs/prompts/*` files. It is a list of model blocks,
and each block can hold several prompts.

| Key | Value here | Meaning |
|---|---|---|
| `dreambooth_path` | Realistic Vision v5.1 | Community SD 1.5 checkpoint that sets the visual style |
| `inference_config` | `inference-v3.yaml` | UNet/motion-module architecture and scheduler settings; must match the motion module version |
| `motion_module` | `v3_sd15_mm.ckpt` | Temporal layers that animate the image model |
| `seed` | `[20261120]` | One per prompt (or one for all); `-1` means random. The seed used is recorded in the output `config.yaml` |
| `steps` | 25 | DDIM denoising steps |
| `guidance_scale` | 8 | Classifier-free guidance; higher follows the prompt more closely |
| `prompt` / `n_prompt` | fox in snow / artifacts | What to show and what to avoid. A single `n_prompt` applies to all prompts |

Optional keys `W`, `H` and `L` (width, height, frames) default to 512, 512 and 16.

To make something else, edit `prompt`, set `seed` to `-1` or another number, and run `./run.sh` again.
Realistic Vision works best with photographic prompts. For other styles, swap `dreambooth_path` for
another checkpoint in `../models/DreamBooth_LoRA/` (for example `toonyou_beta3.safetensors` for cartoon).

## Reference run

On an Apple M4 Max (48 GB, MPS): about 5.5 s per step, so **about 2 min 16 s** for 25 steps, plus model loading.
The run produced `samples/example0-2026-11-20T11-15-45/`: 16 frames at 512×512, 2 s at 8 fps. It shows a
fox walking toward the camera down a snowy path between pines in warm low light.

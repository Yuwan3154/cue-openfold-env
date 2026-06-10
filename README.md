# cue-openfold-env

uv-managed replacement for the conda `cue_openfold` / `cathfold` environment
(openfold + proteina + ProteinEBM + Frame2ConFind on torch 2.7.1+cu126 / Python 3.11.12).
Replaces the imperative `submit_cue_openfold_env.sh`.

## Layout requirement
Must sit beside the four code repos (editable installs use `../` paths):
```
SOLab/{cue-openfold-env, openfold, proteina, ProteinEBM, Frame2ConFind}
```

## Bootstrap (per host, on a node that can SEE the target GPU)
```bash
cd cue-openfold-env
CUE_HOST=a100 ./bootstrap.sh                       # a100 | supercloud | engaging
# engaging also: TORCH_CUDA_ARCH_LIST=8.0 CUE_HOST=engaging ./bootstrap.sh
source .venv/bin/activate && source ./activate.sh  # for interactive use afterward
```

## Two tiers
- **Tier A** (`pyproject.toml` + `uv.lock`, via `uv sync`): torch (cu126 index), flash-attn (URL wheel),
  plain PyPI deps, the openfold/proteina/Frame2ConFind editables, deepspeed (no-build-isolation).
- **Tier B** (`postsync.sh`, `uv pip --no-deps`, NOT locked): dgl, PyG companions (`+pt27cu126`),
  cuequivariance, the huhlim git forks, and ProteinEBM (`--no-deps` editable; its pins conflict).

## FOOTGUN
`uv sync` (and `uv run`) **prune everything in Tier B**. After any `uv sync`, re-run `./postsync.sh`.
Never `uv run` without `--no-sync`. The openfold CUDA extension is compiled per-GPU-arch, so each host
bootstraps its own `.venv` — only the lock + scripts are shared via git, never the venv.

## Per-host notes
- **A100**: system CUDA 12.6, no module system, sm_80.
- **SuperCloud**: `module load cuda/12.6` ONLY (never the conda pytorch module — it shadows the venv
  torch). Build on a GPU compute node (sm_70); prefetch network steps on a login node first (compute
  nodes lack internet).
- **Engaging**: `module load cuda`; set `TORCH_CUDA_ARCH_LIST` to the allocated GPU's arch.

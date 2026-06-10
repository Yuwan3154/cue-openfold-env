# cue-openfold-env

uv-managed replacement for the conda `cue_openfold` / `cathfold` environment
(openfold + proteina + ProteinEBM + Frame2ConFind on torch 2.7.1+cu126 / Python 3.11.12).
Replaces the imperative `submit_cue_openfold_env.sh`.

## Layout requirement
Must sit beside the four code repos (editable installs use `../` paths):
```
SOLab/{cue-openfold-env, openfold, proteina, ProteinEBM, Frame2ConFind}
```

## Bootstrap (per host; A100 = the GPU box, HPC = the login node — see "Building on HPC")
```bash
cd cue-openfold-env
CUE_HOST=a100 ./bootstrap.sh                        # a100 | supercloud | engaging
# engaging also needs an arch: TORCH_CUDA_ARCH_LIST=9.0 CUE_HOST=engaging ./bootstrap.sh
source .venv/bin/activate && source ./activate.sh   # for interactive use afterward
```

## Two tiers
- **Tier A** (`pyproject.toml` + `uv.lock`, via `uv sync`): torch (cu126 index), flash-attn (URL wheel),
  plain PyPI deps, and the openfold/proteina/Frame2ConFind editables (openfold built no-build-isolation).
- **Tier B** (`postsync.sh`, `uv pip --no-deps`, NOT locked): deepspeed (built with triton temporarily
  removed — see below), dgl, PyG companions (`+pt27cu126`), cuequivariance, the huhlim git forks, and
  ProteinEBM (`--no-deps` editable; its pins conflict).

## FOOTGUN
`uv sync` (and `uv run`) **prune everything in Tier B**. After any `uv sync`, re-run `./postsync.sh`.
Never `uv run` without `--no-sync`. The openfold CUDA extension is compiled per build host (sm-specific
on a GPU box, multi-arch on a GPU-less login node), so each host bootstraps its own `.venv` — only the
lock + scripts are shared via git, never the venv.

## Building on HPC (login node, no GPU needed)
SuperCloud/Engaging GPU nodes lack internet and login nodes lack a GPU driver, but the **login node has
nvcc + internet** — enough to build everything: openfold's kernel compiles for the default multi-arch
set when no GPU is present, and deepspeed's sdist build (which otherwise needs a GPU driver via triton)
is done with triton temporarily uninstalled, so its ops just defer to runtime JIT. Run the GPU
`smoke_test.sh` separately on a GPU node.

## Per-host notes
- **A100**: dedicated GPU box, system CUDA 12.6, no modules, sm_80. `CUE_HOST=a100 ./bootstrap.sh`.
- **SuperCloud**: `module load cuda/12.6` only (never the conda pytorch module — shadows the venv torch).
  `/tmp` has a 512M per-user quota, so bootstrap puts `TMPDIR` on the home FS. GPU smoke on xeon-g6-volta.
  `CUE_HOST=supercloud ./bootstrap.sh`.
- **Engaging**: Rocky 8 / glibc 2.28 (hence `openmm==8.3.1`, the newest with a manylinux_2_28 wheel); no
  `cuda/12.6`, so it loads `cuda/12.9.1` (still CUDA 12.x). Set `TORCH_CUDA_ARCH_LIST` (e.g. `8.9;9.0`
  for L40S/H100/H200). `CUE_HOST=engaging TORCH_CUDA_ARCH_LIST=9.0 ./bootstrap.sh`.

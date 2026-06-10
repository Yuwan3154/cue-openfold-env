#!/usr/bin/env bash
# HPC Lmod/module init (SuperCloud/Engaging); harmless on hosts without it. Must precede set -u.
[ -f /etc/profile ] && source /etc/profile >/dev/null 2>&1 || true
set -euo pipefail
cd "$(dirname "$0")"
# One-shot env build. Run on a node that can SEE the target GPU (openfold compiles per GPU arch).
#   CUE_HOST=a100|supercloud|engaging ./bootstrap.sh   (engaging also needs TORCH_CUDA_ARCH_LIST)

# Build temp on the home FS: some HPC /tmp has a tiny per-user quota (SuperCloud = 512M).
export TMPDIR="$PWD/.uvtmp"; mkdir -p "$TMPDIR"

# 1. uv (its binary lives in ~/.local/bin; put that on PATH BEFORE checking, so we don't reinstall)
export PATH="$HOME/.local/bin:$PATH"
command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh

# 2. venv + env vars
uv venv --clear --python 3.11.12 .venv
source .venv/bin/activate
source ./activate.sh

# 3. Seed torch + build tools so the no-build-isolation metadata/builds for openfold & deepspeed
#    can import torch during resolution (a fresh venv has no torch otherwise).
uv pip install torch==2.7.1 torchvision==0.22.1 torchaudio==2.7.1 \
  --index-url https://download.pytorch.org/whl/cu126
uv pip install ninja cython setuptools wheel numpy==1.26.4

# 4. CUTLASS (runtime: DeepSpeed Evoformer kernel; not needed at openfold build time)
[ -d ../openfold/cutlass ] || git clone --depth 1 -b v3.6.0 https://github.com/NVIDIA/cutlass.git ../openfold/cutlass

# 5. Tier A: sync (builds openfold CUDA ext). deepspeed is built in postsync (needs triton absent).
uv sync --no-install-package deepspeed

# 6. Tier B: --no-deps / build-tagged wheels / conflicting-pin editable (NOT in the lockfile).
bash ./postsync.sh

# 7. Self-contained MSA binaries (runtime tools; non-fatal so a download hiccup can't kill the env).
[ -x tools/bin/mmseqs ] || bash tools/install_msa_binaries.sh || echo "WARN: MSA binaries incomplete (see above)"

# 8. Optional: AlphaFold params (large; opt in with CUE_DOWNLOAD_PARAMS=1).
[ "${CUE_DOWNLOAD_PARAMS:-0}" = "1" ] && ../openfold/scripts/download_alphafold_params.sh ../openfold/resources

echo "=== bootstrap complete (host=$CUE_HOST). Use: source .venv/bin/activate && source ./activate.sh ==="

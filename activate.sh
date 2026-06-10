#!/usr/bin/env bash
# Source AFTER `source .venv/bin/activate`. Replaces conda's `env config vars`.
# Host autodetect; override with CUE_HOST=a100|supercloud|engaging.
: "${CUE_HOST:=$( if [[ -d /usr/local/cuda-12.6 && -z "${LMOD_CMD:-}" ]]; then echo a100;
  elif [[ -n "${SLURM_CLUSTER_NAME:-}" || "$(hostname -f 2>/dev/null)" == *mit.edu* ]]; then echo supercloud;
  else echo engaging; fi )}"

VENV="${VIRTUAL_ENV:?source .venv/bin/activate first}"
ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PATH="$HOME/.local/bin:$PATH"   # uv installs here; non-interactive shells don't get it otherwise

case "$CUE_HOST" in
  a100)
    export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda-12.6}"
    export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.0}"
    ;;
  supercloud)
    module load cuda/12.6 2>/dev/null || true
    : "${CUDA_HOME:=$(command -v nvcc >/dev/null 2>&1 && dirname "$(dirname "$(command -v nvcc)")" || true)}"
    export CUDA_HOME
    export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-7.0}"   # V100 sm_70
    ;;
  engaging)
    { module load cuda/12.6 2>/dev/null || module load cuda 2>/dev/null; } || true
    : "${CUDA_HOME:=$(command -v nvcc >/dev/null 2>&1 && dirname "$(dirname "$(command -v nvcc)")" || true)}"
    export CUDA_HOME
    export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:?set per allocated Engaging GPU, e.g. 7.0/8.0/9.0}"
    ;;
esac

export CUDA_PATH="$CUDA_HOME"
[ -n "${CUDA_HOME:-}" ] && export PATH="$CUDA_HOME/bin:$PATH"

# Self-contained MSA binaries (outside .venv -> survive `uv sync`)
export PATH="$ENV_DIR/tools/bin:$ENV_DIR/tools/hhsuite/bin:$PATH"
[ -d "$ENV_DIR/tools/hhsuite" ] && export HHLIB="$ENV_DIR/tools/hhsuite"

# CUTLASS for the DeepSpeed Evoformer attention kernel (cloned into openfold by bootstrap.sh)
export CUTLASS_PATH="$(cd "$ENV_DIR/.." && pwd)/openfold/cutlass"
export KMP_AFFINITY=none

# venv torch + pip nvidia/* wheel libs FIRST, then system CUDA (replaces conda $CONDA_PREFIX/lib)
PYV="$("$VENV/bin/python" -c 'import sys;print(f"python{sys.version_info.major}.{sys.version_info.minor}")')"
SITE="$VENV/lib/$PYV/site-packages"
NVLIB="$(find "$SITE/nvidia" -maxdepth 2 -type d -name lib 2>/dev/null | paste -sd: - || true)"  # nvidia/ absent before torch install; don't trip set -e/pipefail
export LD_LIBRARY_PATH="$SITE/torch/lib:${NVLIB:+$NVLIB:}${CUDA_HOME:+$CUDA_HOME/lib64:}${LD_LIBRARY_PATH:-}"

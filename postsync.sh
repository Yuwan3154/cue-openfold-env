#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Tier B: packages that resist the lockfile -- build-tagged +local wheels, --no-deps git forks, and
# the conflicting-pin editable (ProteinEBM). Run AFTER `uv sync`. A re-run of `uv sync` (or any
# `uv run`) PRUNES everything below -- re-run this script after any sync.

# deepspeed: build with triton temporarily removed. Its op enumeration imports triton, whose driver
# init fails on GPU-less build hosts ("0 active drivers"); with triton absent the ops just defer to
# runtime JIT and the sdist builds anywhere. torch/ninja for the build come from the synced venv.
uv pip uninstall triton 2>/dev/null || true
DS_BUILD_OPS=0 uv pip install --no-build-isolation --no-deps deepspeed==0.14.5
uv pip install triton==3.3.1

# PyG companions (build-tagged +pt27cu126) via flat index
uv pip install torch-scatter torch-sparse torch-cluster torch-spline-conv pyg_lib torch_geometric \
  -f https://data.pyg.org/whl/torch-2.7.1+cu126.html

# dgl: wheel built for torch2.4/cu124, ABI-compatible with torch2.7; --no-deps keeps torch 2.7
uv pip install --no-deps dgl==2.4.0+cu124 -f https://data.dgl.ai/wheels/torch-2.4/cu124/repo.html

# ProteinEBM editable, --no-deps (its pins torch 2.6.0 / numpy 2.3.3 / scipy 1.15.2 ... conflict)
uv pip install --no-deps -e ../ProteinEBM

# cuequivariance trio
uv pip install cuequivariance cuequivariance-torch cuequivariance-ops-torch-cu12

# huhlim forks, --no-deps (build isolation installs each fork's declared build deps:
# mdtraj's pyproject requires versioneer[toml]/Cython/numpy<3, so do NOT pass --no-build-isolation)
uv pip install --no-deps "git+https://github.com/huhlim/mdtraj.git"
uv pip install --no-deps "git+https://github.com/huhlim/SE3Transformer.git"
uv pip install --no-deps "git+http://github.com/huhlim/cg2all"   # http:// verbatim; https fallback

# flash-attn: the prebuilt wheel (Tier A) needs glibc 2.32. On older glibc (Engaging Rocky 8 / 2.28) it
# won't load -> rebuild from source against the local glibc + TORCH_CUDA_ARCH_LIST. Slow (~30-60 min);
# only triggers where the prebuilt wheel can't import, so newer-glibc hosts keep the fast wheel.
if ! python -c 'import flash_attn' >/dev/null 2>&1; then
  echo "flash-attn prebuilt wheel not importable (old glibc); rebuilding from source ..."
  uv pip uninstall flash-attn >/dev/null 2>&1 || true
  MAX_JOBS="${MAX_JOBS:-8}" FLASH_ATTENTION_FORCE_BUILD=TRUE uv pip install --no-build-isolation --no-deps flash-attn==2.8.3
fi

echo "=== postsync (Tier B) complete ==="

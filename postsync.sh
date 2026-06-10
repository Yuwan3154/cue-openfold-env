#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Tier B: packages that resist the lockfile -- build-tagged +local wheels, --no-deps git forks, and
# the conflicting-pin editable (ProteinEBM). Run AFTER `uv sync`. A re-run of `uv sync` (or any
# `uv run`) PRUNES everything below -- re-run this script after any sync.

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

echo "=== postsync (Tier B) complete ==="

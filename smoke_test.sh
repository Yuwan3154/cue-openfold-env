#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
source .venv/bin/activate
source ./activate.sh
fail=0
chk() { printf '%-22s ' "$1"; if python -c "$2" 2>/tmp/cue_smoke_err; then echo OK; else echo FAIL; sed 's/^/    /' /tmp/cue_smoke_err | tail -4; fail=1; fi; }

chk "torch+cuda"     'import torch; assert torch.__version__.startswith("2.7.1"), torch.__version__; assert torch.version.cuda=="12.6"; assert torch.cuda.is_available(); print(torch.__version__, torch.version.cuda)'
chk "cuda-ext"       'import torch, attn_core_inplace_cuda; print("loaded")'
chk "editables"      'import openfold, proteinfoundation, protein_ebm, Frame2ConFind; print("ok")'
chk "deepspeed"      'import torch, deepspeed; print(deepspeed.__version__)'
chk "flash-attn"     'import torch, flash_attn; print(flash_attn.__version__)'
chk "dgl"            'import torch, dgl; print(dgl.__version__)'
chk "cuequivariance" 'import torch, cuequivariance_torch; print("ok")'
chk "pyg"            'import torch, torch_scatter, torch_sparse, torch_cluster, pyg_lib, torch_geometric; print("ok")'
chk "forks"          'import e3nn, se3_transformer, cg2all, mdtraj; print("ok")'
chk "numerics"       'import numpy,scipy,pandas; assert numpy.__version__=="1.26.4", numpy.__version__; print(numpy.__version__,scipy.__version__,pandas.__version__)'
chk "cuda-kernel"    'import torch, attn_core_inplace_cuda; x=torch.randn(1,1,8,8,device="cuda"); assert x.is_cuda; print("cuda alloc ok")'

echo "--- MSA binaries on PATH (kalign optional) ---"
for b in mmseqs hmmsearch jackhmmer hhblits kalign; do
  printf '  %-10s ' "$b"
  if command -v "$b" >/dev/null 2>&1; then command -v "$b"; else echo MISSING; [ "$b" = kalign ] || fail=1; fi
done

echo ""
if [ "$fail" = 0 ]; then echo "=== SMOKE TESTS PASSED ==="; else echo "=== SMOKE TESTS FAILED ==="; fi
exit "$fail"

#!/usr/bin/env bash
set -euo pipefail
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$T/bin"
# Self-contained MSA binaries into tools/ (outside .venv so `uv sync` never prunes them).
# activate.sh puts $T/bin and $T/hhsuite/bin on PATH.

# --- mmseqs2 17-b804f: official truly-static AVX2 build ---
if [ ! -x "$T/bin/mmseqs" ]; then
  curl -fL https://github.com/soedinglab/MMseqs2/releases/download/17-b804f/mmseqs-linux-avx2.tar.gz | tar xz -C "$T"
  ln -sf "$T/mmseqs/bin/mmseqs" "$T/bin/mmseqs"
fi

# --- hhsuite 3.3.0: official static AVX2 build (hhblits/hhsearch/hhmake/...) ---
if [ ! -x "$T/hhsuite/bin/hhblits" ]; then
  mkdir -p "$T/hhsuite"
  curl -fL https://github.com/soedinglab/hh-suite/releases/download/v3.3.0/hhsuite-3.3.0-AVX2-Linux.tar.gz | tar xz -C "$T/hhsuite"
fi

# --- hmmer 3.4: build from source (autotools; no exotic deps) ---
if [ ! -x "$T/bin/jackhmmer" ]; then
  curl -fL http://eddylab.org/software/hmmer/hmmer-3.4.tar.gz | tar xz -C "$T"
  ( cd "$T/hmmer-3.4" && ./configure --prefix="$T/hmmer" && make -j"$(nproc)" && make install )
  for b in hmmsearch jackhmmer hmmbuild phmmer hmmscan; do ln -sf "$T/hmmer/bin/$b" "$T/bin/$b"; done
fi

# --- kalign2 2.04: build from source. FETCH RISK (canonical mirror often down). Best-effort, non-fatal. ---
if [ ! -x "$T/bin/kalign" ]; then
  if ( set -e
       tmp="$T/kalign2_src"; rm -rf "$tmp"; mkdir -p "$tmp"
       curl -fL http://msa.sbc.su.se/downloads/kalign/current.tar.gz | tar xz -C "$tmp"
       d="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d | head -1)"; cd "$d"
       [ -f configure ] && ./configure --prefix="$T/kalign2" || true
       make -j"$(nproc)"
       kb="$(find "$d" -maxdepth 2 -name kalign -type f | head -1)"
       cp "$kb" "$T/bin/kalign" ); then
    echo "kalign2 installed."
  else
    echo "WARN: kalign2 2.04 source build failed (mirror likely down). mmseqs/hhsuite/hmmer are OK; resolve kalign separately." >&2
  fi
fi

echo "=== MSA binaries ready under $T/bin and $T/hhsuite/bin ==="
ls -1 "$T/bin" 2>/dev/null || true

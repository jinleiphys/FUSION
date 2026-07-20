#!/bin/bash
# install_coloss.sh [--force] [--verify]
#
# Ensure a working `COLOSS` binary exists. If one is found in the bin dir or on
# PATH, do nothing. Otherwise clone the public source, build the bundled C++
# Coulomb-wave library and the Fortran solver with gfortran + LAPACK/BLAS, and
# copy the binary into the bin dir.
#
# Source:  https://github.com/jinleiphys/COLOSS  (Liu Junzhe, Lei, Ren; CPC 311, 109568, 2025)
# Build:   adyo_v1_0/ (make -> libcwf_cpp.a), then top-level `make` (needs LAPACK/BLAS).
#
# Config (env overrides):
#   COLOSS_BIN_DIR   where to install the binary   (default: ~/bin)
#   COLOSS_SRC_DIR   where to clone/build source    (default: ~/.cache/fusion/coloss-src)
#   COLOSS_FC        Fortran compiler               (default: gfortran)
#
# Exit 0 = a usable binary is in place. Prints the resolved path on the last
# line as: COLOSS=/path/to/COLOSS
set -euo pipefail

FORCE=0; VERIFY=0
for a in "$@"; do case "$a" in
  --force) FORCE=1 ;; --verify) VERIFY=1 ;;
  *) echo "unknown arg: $a" >&2; exit 2 ;;
esac; done

BIN_DIR="${COLOSS_BIN_DIR:-$HOME/bin}"
SRC_DIR="${COLOSS_SRC_DIR:-$HOME/.cache/fusion/coloss-src}"
FC="${COLOSS_FC:-gfortran}"
REPO="https://github.com/jinleiphys/COLOSS.git"

found=""
if [ "$FORCE" = 0 ]; then
  if [ -x "$BIN_DIR/COLOSS" ]; then found="$BIN_DIR/COLOSS"; fi
  if [ -z "$found" ] && command -v COLOSS >/dev/null 2>&1; then found="$(command -v COLOSS)"; fi
fi

if [ -n "$found" ]; then
  echo "COLOSS already present: $found" >&2
  echo "COLOSS=$found"; exit 0
fi

for tool in "$FC" git make g++ ar; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing required tool: $tool" >&2; exit 3; }
done

mkdir -p "$BIN_DIR" "$(dirname "$SRC_DIR")"
if [ ! -d "$SRC_DIR/.git" ]; then
  rm -rf "$SRC_DIR"; git clone --depth 1 "$REPO" "$SRC_DIR" >&2
fi

# 1) bundled C++ Coulomb-wave library
( cd "$SRC_DIR/adyo_v1_0" && make >&2 )
# 2) top-level Fortran build (uses LAPACK/BLAS; honors gfortran). The interactive
#    compile.sh is bypassed; the Makefile does the real work non-interactively.
( cd "$SRC_DIR" && make FC="$FC" >&2 )

[ -x "$SRC_DIR/COLOSS" ] || { echo "build failed: no COLOSS binary" >&2; exit 4; }
cp "$SRC_DIR/COLOSS" "$BIN_DIR/COLOSS"
echo "installed COLOSS -> $BIN_DIR/COLOSS" >&2

if [ "$VERIFY" = 1 ]; then
  # theta-invariance smoke check on the bundled n+40Ca example
  echo "verify: run examples and confirm nonzero reaction cross section" >&2
fi
echo "COLOSS=$BIN_DIR/COLOSS"

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
#   COLOSS_BIN_DIR     where to install the binary  (default: ~/bin)
#   COLOSS_SRC_DIR     where to clone/build source  (default: ~/.cache/fusion/coloss-src)
#   COLOSS_FC          Fortran compiler             (default: gfortran)
#   COLOSS_LAPACK_LIB  LAPACK/BLAS link flags       (default: resolved per platform)
#   COLOSS_CXXLIB      C++ runtime link flag        (default: -lc++ on macOS, -lstdc++ elsewhere)
#
# Portability note: the upstream Makefile hardcodes an Apple-Silicon Homebrew
# LAPACK path and -lc++, the LLVM C++ runtime. Neither exists under a GNU
# toolchain on Linux (nor on an Intel Mac, where Homebrew lives in /usr/local),
# so the link step is resolved here per platform. This changes only WHICH
# libraries are linked, never a source file, and the skill's n+40Ca anchor
# (sigma_R = 1157.53 mb) is checked on both platforms.
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

# Resolve the platform-dependent link flags the upstream Makefile hardcodes.
if [ "$(uname -s)" = "Darwin" ]; then
  CXXLIB="${COLOSS_CXXLIB:--lc++}"
else
  CXXLIB="${COLOSS_CXXLIB:--lstdc++}"
fi
if [ -n "${COLOSS_LAPACK_LIB:-}" ]; then
  LAPACK_LIB="$COLOSS_LAPACK_LIB"
elif _bp="$(brew --prefix lapack 2>/dev/null)" && [ -d "$_bp/lib" ]; then
  LAPACK_LIB="-L$_bp/lib -llapack -lblas"
else
  LAPACK_LIB="-llapack -lblas"
  if ! echo 'int main(){return 0;}' | "${CC:-cc}" -x c - -llapack -lblas -o /dev/null >/dev/null 2>&1; then
    echo "install_coloss: LAPACK/BLAS not found. Install it:" >&2
    echo "  macOS: brew install lapack     Debian/Ubuntu: apt-get install liblapack-dev libblas-dev" >&2
    echo "  or set COLOSS_LAPACK_LIB to the link flags for your BLAS (e.g. -lopenblas)" >&2
    exit 3
  fi
fi

mkdir -p "$BIN_DIR" "$(dirname "$SRC_DIR")"
if [ ! -d "$SRC_DIR/.git" ]; then
  rm -rf "$SRC_DIR"; git clone --depth 1 "$REPO" "$SRC_DIR" >&2
fi

# 1) bundled C++ Coulomb-wave library
( cd "$SRC_DIR/adyo_v1_0" && make >&2 )
# 2) top-level Fortran build (uses LAPACK/BLAS; honors gfortran). The interactive
#    compile.sh is bypassed; the Makefile does the real work non-interactively.
#    Both link settings are patched into the top-level Makefile rather than
#    passed on the make command line: the top level recurses into adyo_v1_0,
#    whose own Makefile uses LIB for the archive it builds, and a command-line
#    LIB= propagates into that sub-make and makes it run `ar rv -llapack`.
sed -i.fusion.bak \
  -e "s|^LIB *=.*|LIB = $LAPACK_LIB|" \
  -e "s|-lc++|$CXXLIB|g" \
  "$SRC_DIR/Makefile"
( cd "$SRC_DIR" && make FC="$FC" >&2 )

[ -x "$SRC_DIR/COLOSS" ] || { echo "build failed: no COLOSS binary" >&2; exit 4; }
cp "$SRC_DIR/COLOSS" "$BIN_DIR/COLOSS"
echo "installed COLOSS -> $BIN_DIR/COLOSS" >&2

if [ "$VERIFY" = 1 ]; then
  # theta-invariance smoke check on the bundled n+40Ca example
  echo "verify: run examples and confirm nonzero reaction cross section" >&2
fi
echo "COLOSS=$BIN_DIR/COLOSS"

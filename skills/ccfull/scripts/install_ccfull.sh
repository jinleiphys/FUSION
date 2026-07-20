#!/bin/bash
# install_ccfull.sh [--force]
#
# Ensure a working `ccfull` binary exists. If found in the bin dir or on PATH,
# do nothing. Otherwise fetch the canonical FORTRAN77 source from Hagino's page
# and build it with gfortran (legacy dialect).
#
# Source:  https://www2.yukawa.kyoto-u.ac.jp/~kouichi.hagino/ccfull/ccfull.f
#          K. Hagino, N. Rowley, A.T. Kruppa, Comput. Phys. Commun. 123 (1999) 143.
# Build:   gfortran -std=legacy -O2 -o ccfull ccfull.f
#
# Config (env overrides):
#   CCFULL_BIN_DIR   where to install   (default: ~/bin)
#   CCFULL_SRC_DIR   where to fetch/build (default: ~/.cache/fusion/ccfull-src)
#   CCFULL_FC        Fortran compiler   (default: gfortran)
#
# Exit 0 = usable binary in place. Prints: CCFULL=/path/to/ccfull
set -euo pipefail

FORCE=0
for a in "$@"; do case "$a" in --force) FORCE=1 ;; *) echo "unknown arg: $a" >&2; exit 2 ;; esac; done

BIN_DIR="${CCFULL_BIN_DIR:-$HOME/bin}"
SRC_DIR="${CCFULL_SRC_DIR:-$HOME/.cache/fusion/ccfull-src}"
FC="${CCFULL_FC:-gfortran}"
URL="https://www2.yukawa.kyoto-u.ac.jp/~kouichi.hagino/ccfull/ccfull.f"

found=""
if [ "$FORCE" = 0 ]; then
  if [ -x "$BIN_DIR/ccfull" ]; then found="$BIN_DIR/ccfull"; fi
  if [ -z "$found" ] && command -v ccfull >/dev/null 2>&1; then found="$(command -v ccfull)"; fi
fi
if [ -n "$found" ]; then echo "ccfull already present: $found" >&2; echo "CCFULL=$found"; exit 0; fi

for tool in "$FC" curl; do command -v "$tool" >/dev/null 2>&1 || { echo "missing tool: $tool" >&2; exit 3; }; done
mkdir -p "$BIN_DIR" "$SRC_DIR"
curl -fsSL "$URL" -o "$SRC_DIR/ccfull.f"
( cd "$SRC_DIR" && "$FC" -std=legacy -O2 -o ccfull ccfull.f )
[ -x "$SRC_DIR/ccfull" ] || { echo "build failed" >&2; exit 4; }
cp "$SRC_DIR/ccfull" "$BIN_DIR/ccfull"
echo "installed ccfull -> $BIN_DIR/ccfull" >&2
echo "CCFULL=$BIN_DIR/ccfull"

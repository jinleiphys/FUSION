#!/bin/bash
# install_fresco.sh [--force] [--verify]
#
# Ensure a working `fresco` (and `sfresco`) binary exists. If one is already
# found in the bin dir or on PATH, do nothing. Otherwise clone Ian Thompson's
# source, compile with gfortran, and copy both binaries into the bin dir.
#
# Source:  https://github.com/I-Thompson/fresco  (FRES 3.4)
# Build:   source/makefile, `make FC=gfortran` (default FFLAGS -O3).
#
# Config (env overrides):
#   FRESCO_BIN_DIR   where to install the binary   (default: ~/bin)
#   FRESCO_SRC_DIR   where to clone/build source    (default: ~/.cache/fusion/fresco-src)
#   FRESCO_FC        Fortran compiler               (default: gfortran)
#
# Exit 0 = a usable binary is in place (already, or freshly built).
# Prints the resolved binary path on the last line as: FRESCO=/path/to/fresco

set -euo pipefail

FORCE=0
VERIFY=0
for a in "$@"; do
  case "$a" in
    --force)  FORCE=1 ;;
    --verify) VERIFY=1 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done

BIN_DIR="${FRESCO_BIN_DIR:-$HOME/bin}"
SRC_DIR="${FRESCO_SRC_DIR:-$HOME/.cache/fusion/fresco-src}"
FC="${FRESCO_FC:-gfortran}"
REPO="https://github.com/I-Thompson/fresco"
BIN="$BIN_DIR/fresco"

# 1) Already installed? (bin dir first, then anything on PATH)
if [ "$FORCE" -eq 0 ]; then
  if [ -x "$BIN" ]; then
    echo "# fresco already installed at $BIN"
    echo "FRESCO=$BIN"
    exit 0
  fi
  if command -v fresco >/dev/null 2>&1; then
    P="$(command -v fresco)"
    echo "# fresco already on PATH at $P"
    echo "FRESCO=$P"
    exit 0
  fi
fi

echo "# no fresco binary found; building from source"

# 2) Toolchain check
if ! command -v "$FC" >/dev/null 2>&1; then
  echo "ERROR: Fortran compiler '$FC' not found." >&2
  echo "       macOS:  brew install gcc      (provides gfortran)" >&2
  echo "       Debian: sudo apt install gfortran make git" >&2
  echo "       or set FRESCO_FC=<your f90 compiler>" >&2
  exit 1
fi
for t in git make; do
  command -v "$t" >/dev/null 2>&1 || { echo "ERROR: '$t' not found" >&2; exit 1; }
done

# 3) Clone (or refresh) the source
if [ -d "$SRC_DIR/.git" ]; then
  echo "# reusing source at $SRC_DIR (git pull)"
  git -C "$SRC_DIR" pull --ff-only 2>&1 | sed 's/^/#   /' || echo "#   (pull skipped)"
else
  mkdir -p "$(dirname "$SRC_DIR")"
  echo "# cloning $REPO -> $SRC_DIR"
  git clone --depth 1 "$REPO" "$SRC_DIR" 2>&1 | sed 's/^/#   /'
fi

# 4) Compile
echo "# compiling with $FC (this takes ~1-2 min)"
make -C "$SRC_DIR/source" FC="$FC" 2>&1 | tail -3 | sed 's/^/#   /'
for b in fresco sfresco; do
  [ -x "$SRC_DIR/source/$b" ] || { echo "ERROR: build did not produce $b" >&2; exit 1; }
done

# 5) Install into bin dir, then recheck both binaries are executable
mkdir -p "$BIN_DIR"
cp -f "$SRC_DIR/source/fresco"  "$BIN_DIR/fresco"
cp -f "$SRC_DIR/source/sfresco" "$BIN_DIR/sfresco"
for b in fresco sfresco; do
  [ -x "$BIN_DIR/$b" ] || { echo "ERROR: installed $b is not executable at $BIN_DIR/$b" >&2; exit 1; }
done
echo "# installed fresco, sfresco -> $BIN_DIR"

# 6) Optional smoke verify against a known anchor (B1-elastic: sigma_R = 1575.175 mb)
if [ "$VERIFY" -eq 1 ]; then
  SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  DECK="$SKILL_DIR/examples/B1-elastic.in"
  if [ -f "$DECK" ]; then
    WORK="$(mktemp -d)"
    trap 'rm -rf "$WORK"' EXIT
    cp "$DECK" "$WORK/in"
    ( cd "$WORK" && "$BIN" < in > out 2>&1 ) || true
    GOT="$(grep -i 'CUMULATIVE REACTION' "$WORK/out" 2>/dev/null | tail -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
    echo "# verify B1-elastic: sigma_R = ${GOT:-?}  (reference 1575.175)"
  fi
fi

echo "FRESCO=$BIN"

#!/bin/bash
# run_ccfull.sh <input.inp> [workdir]
# Ensure the ccfull binary exists (auto-install), copy the input to a clean
# workdir as ccfull.inp (the name ccfull hard-codes), run, and show OUTPUT.
# CCFULL writes OUTPUT, cross.dat, spin.dat, s-wave.dat into cwd.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
IN="${1:?usage: run_ccfull.sh <input.inp> [workdir]}"
WORK="${2:-$(pwd)/ccfull-run}"

BIN_LINE="$(bash "$HERE/install_ccfull.sh")"
BIN="${BIN_LINE#CCFULL=}"
[ -x "$BIN" ] || { echo "no ccfull binary" >&2; exit 1; }

mkdir -p "$WORK"; cp "$IN" "$WORK/ccfull.inp"; cd "$WORK"
# CCFULL asks several interactive y/n questions on stdin (standard Woods-Saxon,
# beta_N vs beta_C per mode, AHV couplings, modify betas). Answering 'n' to all
# keeps the standard behavior the input file already specifies. Advanced runs
# (modified WS, separate nuclear beta) pipe answers via ANSWERS instead.
ANSWERS="${ANSWERS:-$(printf 'n\n%.0s' {1..12})}"
printf '%s' "$ANSWERS" | "$BIN" >/dev/null 2>&1 || true
echo "== OUTPUT ($WORK/OUTPUT) =="
cat OUTPUT
echo "== fusion cross section table also in cross.dat =="

#!/bin/bash
# run_coloss.sh <input.in> [workdir]
# Ensure the COLOSS binary exists (auto-install on first use), then run the given
# input in a clean working directory and print the total reaction cross section.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
IN="${1:?usage: run_coloss.sh <input.in> [workdir]}"
WORK="${2:-$(pwd)}"

# resolve / provision the binary
BIN_LINE="$(bash "$HERE/install_coloss.sh")"
BIN="${BIN_LINE#COLOSS=}"
[ -x "$BIN" ] || { echo "no COLOSS binary" >&2; exit 1; }

mkdir -p "$WORK"; cd "$WORK"
"$BIN" < "$IN" | tee coloss.out | \
  awk -F'|' '/\|.*\(.*\).*\|/ {v=$3; gsub(/[^0-9.eE+-]/,"",v); if(v!="") s+=v}
             END{printf "\nTotal reaction cross section = %.4f mb\n", s}'

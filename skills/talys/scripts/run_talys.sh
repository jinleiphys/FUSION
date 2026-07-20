#!/bin/bash
# run_talys.sh <deck.inp|deck-dir> [workdir]
#
# Build TALYS if needed, run a deck in a clean workdir, and report honestly.
#
# THE CRITICAL POINT: TALYS exits with status 0 even when it aborts on a fatal
# TALYS-error. Trusting $? alone will report a failed calculation as a success,
# which is exactly how a benchmark turns into a false positive. This script
# always greps the output for "TALYS-error" and fails on it regardless of the
# exit status.
#
# If the first argument is a directory (such as a sample's new/ directory) the
# whole directory is copied, not just talys.inp. Several sample cases ship an
# auxiliary input file (typically `energies`, an incident-energy grid) that the
# deck references by name; copying only talys.inp makes TALYS abort.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

SRC="${1:?usage: run_talys.sh <deck.inp|deck-dir> [workdir]}"
WORK="${2:-$(pwd)/talys-run}"

BIN_LINE="$(bash "$HERE/install_talys.sh")"
BIN="${BIN_LINE#TALYS=}"
[ -x "$BIN" ] || { echo "no talys binary" >&2; exit 1; }

# Stage the deck in a genuinely clean directory. Two things matter here, both
# learned from a real false positive: the copy must not fail silently, and the
# workdir must not retain a previous run's talys.inp, or an empty/malformed
# source directory leaves a STALE deck behind and the run "succeeds" on the
# wrong input.
abspath () { ( cd "$1" 2>/dev/null && pwd ) || echo "$1"; }

if [ -d "$SRC" ]; then
  [ -f "$SRC/talys.inp" ] || { echo "no talys.inp in source directory: $SRC" >&2; exit 1; }
  # The caller may legitimately stage the deck into the workdir itself and pass
  # the same path twice (verify_talys.sh does). Wiping would delete the input.
  if [ "$(abspath "$SRC")" = "$(abspath "$WORK")" ]; then
    mkdir -p "$WORK"
  else
    rm -rf "$WORK"; mkdir -p "$WORK"
    cp "$SRC"/talys.inp "$WORK"/ || { echo "failed to copy deck from $SRC" >&2; exit 1; }
    # Auxiliary inputs (energy grids and the like) travel with the deck.
    for f in "$SRC"/*; do
      b="$(basename "$f")"
      [ "$b" = "talys.inp" ] && continue
      [ -f "$f" ] || continue
      cp "$f" "$WORK"/ || { echo "failed to copy $b from $SRC" >&2; exit 1; }
    done
  fi
else
  [ -f "$SRC" ] || { echo "no such deck: $SRC" >&2; exit 1; }
  case "$(abspath "$(dirname "$SRC")")/$(basename "$SRC")" in
    "$(abspath "$WORK")/talys.inp") mkdir -p "$WORK" ;;
    *) rm -rf "$WORK"; mkdir -p "$WORK"
       cp "$SRC" "$WORK/talys.inp" || { echo "failed to copy deck $SRC" >&2; exit 1; } ;;
  esac
fi
[ -f "$WORK/talys.inp" ] || { echo "no talys.inp in $WORK" >&2; exit 1; }

cd "$WORK"
set +e
"$BIN" < talys.inp > talys.out 2> talys.err
rc=$?
set -e

# Fatal errors are reported in the output file, not via the exit status.
if grep -q "TALYS-error" talys.out 2>/dev/null; then
  echo "TALYS FAILED (it still exited $rc; the error is only in talys.out):" >&2
  grep -A2 "TALYS-error" talys.out | head -12 >&2
  exit 1
fi
if [ "$rc" -ne 0 ]; then
  echo "talys exited $rc" >&2
  tail -5 talys.out >&2
  exit "$rc"
fi
if ! grep -q "successful calculation" talys.out 2>/dev/null; then
  echo "WARNING: TALYS did not print its success banner; treat the result as suspect." >&2
  tail -5 talys.out >&2
fi

# IEEE underflow notes on stderr are normal and not an error.
if [ -s talys.err ] && ! grep -qi "IEEE" talys.err; then
  echo "== stderr ==" >&2; head -10 talys.err >&2
fi

nwarn=$(grep -c "TALYS-warning" talys.out || true)
echo "== $WORK =="
echo "output files: $(ls | wc -l | tr -d ' '), TALYS-warnings: $nwarn"
echo "main output: $WORK/talys.out"
echo "cross sections: cross_*.tot, exclusive channels *.L??, spectra *spec*"

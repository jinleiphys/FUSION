#!/bin/bash
# run_sky3d.sh
#
# Run a Sky3D deck in an isolated working directory and assert that the output is
# usable. Usage:
#
#   run_sky3d.sh --deck <input file> [--workdir <dir>] [--fragment <file>[:<dest>]]...
#
# --deck       the namelist input. It is COPIED to <workdir>/for005 because Sky3D
#              opens the literal filename 'for005' in the current directory; it
#              does NOT read standard input. See references/failure-modes.md.
# --workdir    defaults to a fresh mktemp -d. Sky3D writes for006, the .res
#              tables, the *.tdd density snapshots and the wavefunction file into
#              the current directory, so every run gets its own.
# --fragment   stage a wavefunction file needed by a &fragments deck. "path:dest"
#              places it at <workdir>/dest (dest may contain a relative
#              subdirectory, matching the ../Static/O16 style the shipped
#              collision deck uses). Repeatable.
#
# Prints RESULT_DIR=<workdir> and RESULT_FOR006=<workdir>/for006 on the last two
# lines.
#
# Sky3D is CPC non-profit licensed, not open source; see install_sky3d.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DECK=""
WORKDIR=""
FRAGMENTS=()

log () { echo "run_sky3d: $*" >&2; }
die () { log "$*"; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --deck)     DECK="${2:-}"; shift 2 ;;
    --workdir)  WORKDIR="${2:-}"; shift 2 ;;
    --fragment) FRAGMENTS+=("${2:-}"); shift 2 ;;
    -h|--help)  sed -n '2,30p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" ;;
  esac
done

[ -n "$DECK" ] || die "--deck is required"
[ -f "$DECK" ] || die "deck '$DECK' does not exist"
DECK="$(cd "$(dirname "$DECK")" && pwd)/$(basename "$DECK")"

# A deck that is not a namelist file will fail deep inside the Fortran read with
# an unhelpful message, so catch it here.
grep -q '&main' "$DECK" || die "deck '$DECK' has no &main namelist; is it really a Sky3D input?"

# Locate the executable.
if [ -n "${SKY3D:-}" ]; then
  BIN="$SKY3D"
else
  BIN="$("$HERE/install_sky3d.sh" | sed -n 's/^SKY3D=//p')"
fi
[ -x "$BIN" ] || die "no usable Sky3D executable (SKY3D='${SKY3D:-unset}')"

if [ -z "$WORKDIR" ]; then
  WORKDIR="$(mktemp -d)"
else
  mkdir -p "$WORKDIR"
fi
WORKDIR="$(cd "$WORKDIR" && pwd)"

cp "$DECK" "$WORKDIR/for005"

for spec in ${FRAGMENTS+"${FRAGMENTS[@]}"}; do
  src="${spec%%:*}"
  dest="${spec#*:}"
  [ "$dest" = "$spec" ] && dest="$(basename "$src")"
  [ -f "$src" ] || die "fragment file '$src' does not exist"
  # Reject a destination that escapes the working directory; a deck is data, and
  # data must not be able to write outside the sandbox it was given.
  case "$dest" in
    /*|*..*) die "fragment destination '$dest' must be relative and must not contain '..'" ;;
  esac
  mkdir -p "$WORKDIR/$(dirname "$dest")"
  cp "$src" "$WORKDIR/$dest"
done

log "running $(basename "$BIN") in $WORKDIR"
set +e
( cd "$WORKDIR" && "$BIN" > for006 2> stderr.txt )
STATUS=$?
set -e

# ---- guards. Content is the verdict, but a nonzero exit is never acceptable.
if [ "$STATUS" -ne 0 ]; then
  log "Sky3D exited with status $STATUS"
  [ -s "$WORKDIR/stderr.txt" ] && { log "stderr:"; tail -10 "$WORKDIR/stderr.txt" >&2; }
  exit 1
fi

[ -s "$WORKDIR/for006" ] || die "for006 is empty; the run produced no output"

# A Fortran runtime error can be written to stderr while the exit status stays
# usable in some builds, so inspect stderr rather than discarding it.
if grep -qiE 'Fortran runtime error|Error termination|Segmentation fault' "$WORKDIR/stderr.txt" 2>/dev/null; then
  log "the run wrote a fatal error to stderr:"; tail -10 "$WORKDIR/stderr.txt" >&2; exit 1
fi

# NaN or Infinity anywhere is fatal: it would otherwise sail through every
# downstream parser as a plausible-looking result.
if grep -qiE 'NaN|Infinity' "$WORKDIR/for006"; then
  log "for006 contains NaN or Infinity"
  grep -niE 'NaN|Infinity' "$WORKDIR/for006" | head -3 >&2
  exit 1
fi

# A Fortran numeric field that overflows its format prints as a run of asterisks,
# which downstream parsers skip silently. Sky3D decorates its headers the same
# way (" ***** Force definition *****"), so the check must exclude that symmetric
# header form first, or it fires on every healthy run. This guard is exercised in
# both directions by selftest_sky3d.sh.
if grep -vE '^[[:space:]]*\*{3,}.*\*{3,}[[:space:]]*$' "$WORKDIR/for006" | grep -qE '\*{4,}'; then
  log "for006 contains a Fortran numeric field overflow (a run of asterisks outside a header)"
  grep -vE '^[[:space:]]*\*{3,}.*\*{3,}[[:space:]]*$' "$WORKDIR/for006" | grep -nE '\*{4,}' | head -3 >&2
  exit 1
fi

ENERGY="$(grep -m1 '^ Total:.*MeV' "$WORKDIR/for006" | sed -E 's/^ Total: *([^ ]+) MeV.*/\1/' || true)"
[ -n "$ENERGY" ] || die "for006 has no 'Total: ... MeV' energy line; the run did not reach a printout"
python3 - "$ENERGY" <<'PY' || die "total energy '$ENERGY' is not finite"
import sys, math
sys.exit(0 if math.isfinite(float(sys.argv[1].replace('E', 'e'))) else 1)
PY

MODE="$(grep -oE 'imode *= *[0-9]+' "$WORKDIR/for005" | head -1 | grep -oE '[0-9]+' || echo 1)"
if [ "$MODE" = "1" ]; then
  ITERS="$(grep -c 'Static Iteration No' "$WORKDIR/for006" || true)"
  [ "${ITERS:-0}" -gt 0 ] || die "a static run (imode=1) printed no iterations"
  log "static run: $ITERS iterations, final total energy $ENERGY MeV"
else
  STEPS="$(grep -c 'Starting time step' "$WORKDIR/for006" || true)"
  [ "${STEPS:-0}" -gt 0 ] || die "a dynamic run (imode=2) printed no time steps"
  log "dynamic run: $STEPS time steps, first total energy $ENERGY MeV"
fi

echo "RESULT_DIR=$WORKDIR"
echo "RESULT_FOR006=$WORKDIR/for006"

#!/bin/bash
# run_cgmf.sh <ZAID> <Einc_MeV> <nevents> [outbase] [workdir]
#
# Run one CGMF case and report honestly. ZAID = 1000*Z+A of the TARGET (or the
# fissioning nucleus for spontaneous fission). Einc in MeV, 0.0 = spontaneous
# fission. nevents > 0 = event mode; nevents < 0 = initial-yields mode.
#
# CGMF is deterministic: event i uses seed i+startingEvent, so the same build
# and args give bit-identical output. That is what makes a Monte Carlo code
# regression-pinnable, and the repo ships byte-exact .reference files on it.
#
# CONTENT IS THE VERDICT. cgmf.x writes its history to <outbase>.0 (the MPI rank
# is always appended) and a run-average summary to stdout. Success is asserted
# from a well-formed history file whose header matches the request, plus a finite
# positive neutron multiplicity in the summary, never from exit status alone.
# The data-path resolution in particular fails by printing to stderr and
# exit(-1), so both are checked.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

ZAID="${1:?usage: run_cgmf.sh <ZAID> <Einc_MeV> <nevents> [outbase] [workdir]}"
EINC="${2:?missing incident energy in MeV (0.0 = spontaneous fission)}"
NEV="${3:?missing number of events}"
OUTBASE="${4:-histories.cgmf}"
WORK="${5:-$(pwd)/cgmf-run}"

# Validate the numeric arguments BEFORE running cgmf.x. Unvalidated input reaches
# both C's atoi (which reads "1.5" as 1 and "abc" as 0, then segfaults on a zero
# event count) and this script's own `$(( 2 * NEV ))` arithmetic (which errors on
# a non-integer). An earlier version passed "1.5" straight through and reported
# "OK ... over 1.5 events". Reject anything that is not what cgmf.x actually
# accepts, with a clear message, up front.
case "$ZAID" in ''|*[!0-9]*) echo "run_cgmf: ZAID must be a positive integer (got '$ZAID')" >&2; exit 2;; esac
[ "$ZAID" -gt 0 ] 2>/dev/null || { echo "run_cgmf: ZAID must be > 0 (got '$ZAID')" >&2; exit 2; }
case "$NEV" in ''|-|*[!0-9-]*|*-*[!0-9]*|?*-*) echo "run_cgmf: nevents must be a nonzero integer (got '$NEV')" >&2; exit 2;; esac
[ "$NEV" -ne 0 ] 2>/dev/null || { echo "run_cgmf: nevents must be nonzero (got '$NEV')" >&2; exit 2; }
python3 -c "import sys; float('$EINC')" 2>/dev/null || { echo "run_cgmf: Einc must be a number in MeV (got '$EINC')" >&2; exit 2; }
python3 -c "import sys; sys.exit(0 if float('$EINC')>=0 else 1)" 2>/dev/null || { echo "run_cgmf: Einc must be >= 0 (got '$EINC')" >&2; exit 2; }

# Resolve binary and data directory from the installer's last two lines.
# CGMF_BIN / CGMFDATA may be supplied directly (used by the self-test to inject
# a stub binary); otherwise resolve them from the installer.
if [ -n "${CGMF_BIN:-}" ] && [ -n "${CGMFDATA:-}" ]; then
  BIN="$CGMF_BIN"; DATA="$CGMFDATA"
else
  INSTALL_OUT="$(bash "$HERE/install_cgmf.sh")"
  BIN="$(echo "$INSTALL_OUT" | sed -n 's/^CGMF=//p' | tail -1)"
  DATA="$(echo "$INSTALL_OUT" | sed -n 's/^CGMFDATA=//p' | tail -1)"
fi
[ -x "$BIN" ] || { echo "run_cgmf: no usable cgmf.x" >&2; exit 1; }
[ -d "$DATA" ] || { echo "run_cgmf: data directory not found ($DATA)" >&2; exit 1; }

mkdir -p "$WORK"
cd "$WORK"
OUTFILE="${OUTBASE}.0"
rm -f "$OUTFILE"

LOG="$WORK/cgmf.stdout"; ERR="$WORK/cgmf.stderr"
set +e
CGMFDATA="$DATA" "$BIN" -n "$NEV" -e "$EINC" -i "$ZAID" -f "$OUTBASE" > "$LOG" 2> "$ERR"
RC=$?
set -e

# Exit status IS checked: cgmf.x returns 0 on a normal run and nonzero on a
# fatal path (e.g. the data-path failure exits -1). A nonzero exit is a failure
# even if it left a plausible-looking file behind.
if [ "$RC" -ne 0 ]; then
  echo "run_cgmf: cgmf.x exited $RC" >&2
  [ -s "$ERR" ] && head -5 "$ERR" >&2 || tail -8 "$LOG" >&2
  exit 1
fi
# The data-path failure and any fatal path also print to stderr; surface it.
if [ -s "$ERR" ]; then
  echo "run_cgmf: cgmf.x wrote to stderr:" >&2
  head -5 "$ERR" >&2
  exit 1
fi

[ -f "$OUTFILE" ] || {
  echo "run_cgmf: cgmf.x exited 0 but wrote no output file $OUTFILE" >&2
  tail -8 "$LOG" >&2; exit 1; }

# YIELDS MODE (negative n) is handled FIRST and separately, because a yields
# file has NO header line: its first line is already a fragment record
# (cgmf.cpp writes the Y(...) string to stdout, not to the file). Parsing a
# history header here would read that data row as a header and reject a valid
# run, which is exactly the defect an adversarial pass found. Detect negative n
# with a real numeric test, not string surgery.
if [ "$NEV" -lt 0 ] 2>/dev/null; then
  want=$(( -NEV ))
  # Each event contributes exactly two scission fragments (light + heavy), so a
  # complete yields file has exactly 2*want records. Require equality, not a
  # lower bound: an overlong file is as wrong as a short one, and the real
  # cgmf.x produces the exact count.
  recs="$(grep -c . "$OUTFILE" || true)"
  if [ "$recs" -ne $(( 2 * want )) ]; then
    echo "run_cgmf: yields file has $recs records, expected exactly $(( 2 * want )) for $want events" >&2
    tail -3 "$OUTFILE" >&2; exit 1
  fi
  echo "run_cgmf: OK, yields in $OUTFILE ($recs fragment records for $want events)"
  exit 0
fi

# --- EVENT MODE -------------------------------------------------------------
# The header is "# ZAID Einc timewindow". Assert it matches the request so a
# silently-substituted case cannot pass. Einc is compared numerically because
# 0.0 is written as 0 and 2.53e-8 stays in exponent form.
read -r hdr < "$OUTFILE"
h_zaid="$(echo "$hdr" | awk '{print $2}')"
h_einc="$(echo "$hdr" | awk '{print $3}')"
if [ "$h_zaid" != "$ZAID" ]; then
  echo "run_cgmf: output header ZAID $h_zaid != requested $ZAID" >&2; exit 1
fi
if ! python3 -c "import sys; sys.exit(0 if abs(float('$h_einc')-float('$EINC'))<=1e-6*max(1,abs(float('$EINC'))) else 1)"; then
  echo "run_cgmf: output header Einc $h_einc != requested $EINC" >&2; exit 1
fi

# Every event writes exactly two fragment-header lines (light then heavy), so a
# complete run has 2*NEV of them. This catches a run killed mid-write, which
# leaves a valid header and a partial body: header-plus-nubar alone is not proof
# the requested number of events completed.
FRAGH="$(grep -cE '^ *[0-9]+ +[0-9]+ +[-0-9.eE]+ +[0-9.]+ +[0-9-]+ +[0-9.]+ +[0-9.]+ +[0-9]+ +[0-9]+ +[0-9]+ *$' "$OUTFILE" || true)"
if [ "$FRAGH" -ne $(( 2 * NEV )) ]; then
  echo "run_cgmf: history has $FRAGH fragment blocks, expected $(( 2 * NEV )) for $NEV events (truncated run?)" >&2
  exit 1
fi

# Assert a finite, positive average total neutron multiplicity in the summary.
NU="$(sed -n 's/.*<nu>_tot = *\([0-9.eE+-]*\).*/\1/p' "$LOG" | tail -1)"
if [ -z "$NU" ] || ! python3 -c "
import math,sys
v=float('$NU'); sys.exit(0 if math.isfinite(v) and v>0 else 1)" 2>/dev/null; then
  echo "run_cgmf: summary has no finite positive <nu>_tot (got '${NU:-none}')" >&2
  tail -8 "$LOG" >&2; exit 1
fi

echo "run_cgmf: OK, <nu>_tot = $NU over $NEV events ($FRAGH fragment blocks); history in $OUTFILE"

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

# The data-path failure and any fatal path print to stderr; surface it.
if [ -s "$ERR" ]; then
  echo "run_cgmf: cgmf.x wrote to stderr (RC=$RC):" >&2
  head -5 "$ERR" >&2
  exit 1
fi

[ -f "$OUTFILE" ] || {
  echo "run_cgmf: cgmf.x exited $RC but wrote no output file $OUTFILE" >&2
  tail -8 "$LOG" >&2; exit 1; }

# The header is "# ZAID Einc timewindow". Assert it matches what was requested,
# so a silently-substituted case cannot pass. Einc is compared numerically
# because 0.0 is written as 0 and 2.53e-8 stays in exponent form.
read -r hdr < "$OUTFILE"
h_zaid="$(echo "$hdr" | awk '{print $2}')"
h_einc="$(echo "$hdr" | awk '{print $3}')"
if [ "$h_zaid" != "$ZAID" ]; then
  echo "run_cgmf: output header ZAID $h_zaid != requested $ZAID" >&2; exit 1
fi
if ! python3 -c "import sys; sys.exit(0 if abs(float('$h_einc')-float('$EINC'))<=1e-6*max(1,abs(float('$EINC'))) else 1)"; then
  echo "run_cgmf: output header Einc $h_einc != requested $EINC" >&2; exit 1
fi

if [ "${NEV%%-*}" = "" ] || [ "$NEV" -lt 0 ] 2>/dev/null; then
  # yields mode: assert at least one fragment record beyond the header
  [ "$(grep -c . "$OUTFILE")" -ge 2 ] || {
    echo "run_cgmf: yields file has no fragment records" >&2; exit 1; }
  echo "run_cgmf: OK, yields in $OUTFILE ($(($(grep -c . "$OUTFILE")-1)) records)"
  exit 0
fi

# Event mode: assert a finite, positive average total neutron multiplicity in
# the stdout summary. A diverged or empty run cannot fake this.
NU="$(sed -n 's/.*<nu>_tot = *\([0-9.eE+-]*\).*/\1/p' "$LOG" | tail -1)"
if [ -z "$NU" ] || ! python3 -c "
import math,sys
v=float('$NU'); sys.exit(0 if math.isfinite(v) and v>0 else 1)" 2>/dev/null; then
  echo "run_cgmf: summary has no finite positive <nu>_tot (got '${NU:-none}')" >&2
  tail -8 "$LOG" >&2; exit 1
fi

NBLK="$(grep -c '^ *[0-9]' "$OUTFILE" || true)"
echo "run_cgmf: OK, <nu>_tot = $NU over $NEV events; history in $OUTFILE"

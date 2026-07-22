#!/bin/bash
# run_swanlop.sh [fort1-file]
#
# Run one SWANLOP calculation and report honestly. [fort1-file] is a SWANLOP main
# input deck (the fort.1 format, see references/input-format.md); it defaults to
# the shipped quick-start (p+Pb208 elastic at 30.3 MeV, Tian-Pang-Ma nonlocal).
# The run happens in a scratch copy of the runs/ directory, so the shipped tree
# and its reference files are never touched.
#
# CONTENT IS THE VERDICT. swanlop.x writes zz.main (main output), zz.xaq (angular
# observables: dsigma/dOmega, Ay, Q, plus the reaction cross section) and zz.dsdt
# (dsigma/dt). Success means: a zero exit, and a zz.xaq carrying a finite positive
# reaction cross section. A nonzero exit is a failure.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ -n "${SWANLOP_RUNS:-}" ] && [ -n "${SWANLOP:-}" ]; then
  RUNS="$SWANLOP_RUNS"; BIN="$SWANLOP"
else
  INSTALL_OUT="$(bash "$HERE/install_swanlop.sh")"
  BIN="$(echo "$INSTALL_OUT"  | sed -n 's/^SWANLOP=//p' | tail -1)"
  RUNS="$(echo "$INSTALL_OUT" | sed -n 's/^SWANLOP_RUNS=//p' | tail -1)"
fi
[ -x "$BIN" ] || { echo "run_swanlop: no swanlop.x at $BIN" >&2; exit 1; }
[ -d "$RUNS" ] || { echo "run_swanlop: runs directory not found ($RUNS)" >&2; exit 1; }

FORT1="${1:-$RUNS/fort.quick-start}"
[ -f "$FORT1" ] || { echo "run_swanlop: fort.1 deck not found: $FORT1" >&2; exit 1; }

# Assemble a scratch run directory from the shipped inputs (NucChart is mandatory;
# experimental data files are copied so a chi-square-enabled deck can find them).
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$FORT1" "$WORK/fort.1"
cp "$RUNS/NucChart" "$WORK/" 2>/dev/null || { echo "run_swanlop: NucChart missing from $RUNS" >&2; exit 1; }
# Experimental data files (for chi-square) from the runs dir.
for d in "$RUNS"/dsdw.* "$RUNS"/*.dat; do [ -e "$d" ] && cp "$d" "$WORK/"; done 2>/dev/null || true
# A KPOT>=3 deck reads its potential from fort.2 (and KPOT=0 or KADD=1 from
# fort.22). Copy those from the deck's own directory if present, so an
# external-potential run finds its inputs instead of aborting on an empty fort.2.
FDIR="$(cd "$(dirname "$FORT1")" && pwd)"
for pf in fort.2 fort.22; do
  [ -f "$FDIR/$pf" ] && cp "$FDIR/$pf" "$WORK/"
done

set +e
( cd "$WORK" && "$BIN" > run.out 2> run.err )
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  echo "run_swanlop: swanlop.x exited $RC" >&2
  [ -s "$WORK/run.err" ] && head -8 "$WORK/run.err" >&2 || tail -8 "$WORK/run.out" >&2
  exit 1
fi
for f in zz.xaq zz.dsdt; do
  [ -f "$WORK/$f" ] || {
    echo "run_swanlop: swanlop.x exited 0 but wrote no $f" >&2
    tail -8 "$WORK/run.out" >&2; exit 1; }
done

python3 - "$WORK/zz.xaq" <<'PY'
import sys,re,math
t=open(sys.argv[1]).read()
m=re.search(r"Reactn xSectn\s*:\s*([-\d.eE+]+)",t)
if not m:
    sys.stderr.write("run_swanlop: zz.xaq has no reaction cross section line\n"); sys.exit(1)
x=float(m.group(1))
if not (math.isfinite(x) and x>0):
    sys.stderr.write("run_swanlop: reaction cross section not finite/positive: %r\n"%x); sys.exit(1)
# Count NUMERIC angular rows: a data row starts with a number (the angle). A
# non-comment line that is not numeric (garbage) does not count, so an output of
# a header plus prose does not masquerade as observables.
rows=0
for l in t.splitlines():
    s=l.strip()
    if not s or s.startswith('#'): continue
    try: float(s.split()[0])
    except (ValueError,IndexError): continue
    rows+=1
if rows<2:
    sys.stderr.write("run_swanlop: zz.xaq has fewer than 2 numeric angular rows (got %d)\n"%rows); sys.exit(1)
print("run_swanlop: OK  reaction cross section = %g b  (%d numeric angular rows in zz.xaq)"%(x,rows))
PY

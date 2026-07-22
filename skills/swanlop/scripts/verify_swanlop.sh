#!/bin/bash
# verify_swanlop.sh
#
# TIER 1 benchmark. The distribution ships reference outputs (zz.main.REF,
# zz.xaq.REF, zz.dsdt.REF) for the quick-start case, and this reproduces them.
# Run the quick-start (p+Pb208 elastic at 30.3 MeV, Tian-Pang-Ma nonlocal) in a
# scratch copy of runs/ and assert:
#
#   L1  zz.xaq (dsigma/dOmega, Ay, Q and the reaction cross section) and zz.dsdt
#       (dsigma/dt) are IDENTICAL to the shipped .REF files, line for line, once
#       the Date/Time/UTC header lines (which legitimately vary per run) are
#       removed. This is the code's own documented reference output.
#   L2  the reaction cross section in zz.xaq equals the shipped reference value
#       1.66084 b (a numeric anchor, independent of the line-diff).
#
# CONTENT IS THE VERDICT: compared against the shipped reference files, never from
# exit status. The shipped .REF are read live (a missing .REF fails loudly rather
# than matching an absent file).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

REACT_REF=1.66084   # b, from zz.xaq.REF

if [ -n "${SWANLOP_RUNS:-}" ] && [ -n "${SWANLOP:-}" ]; then
  RUNS="$SWANLOP_RUNS"; BIN="$SWANLOP"
else
  INSTALL_OUT="$(bash "$HERE/install_swanlop.sh")" || { echo "verify_swanlop: install failed" >&2; exit 1; }
  BIN="$(echo "$INSTALL_OUT"  | sed -n 's/^SWANLOP=//p' | tail -1)"
  RUNS="$(echo "$INSTALL_OUT" | sed -n 's/^SWANLOP_RUNS=//p' | tail -1)"
fi
[ -x "$BIN" ] || { echo "verify_swanlop: no swanlop.x at $BIN" >&2; exit 1; }
for r in zz.xaq.REF zz.dsdt.REF zz.main.REF fort.quick-start NucChart; do
  [ -f "$RUNS/$r" ] || { echo "verify_swanlop: shipped $r missing from $RUNS" >&2; exit 1; }
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$RUNS/fort.quick-start" "$WORK/fort.1"
cp "$RUNS/NucChart" "$WORK/"
cp "$RUNS/dsdw.pPb208-30.3" "$WORK/" 2>/dev/null || true

set +e
( cd "$WORK" && "$BIN" > verify.out 2> verify.err )
RC=$?
set -e
[ "$RC" -eq 0 ] || { echo "verify_swanlop: swanlop.x exited $RC" >&2; tail -8 "$WORK/verify.err" >&2; exit 1; }

# Strip ONLY the two per-run timestamp header lines, anchored so a stray data or
# injected line cannot be swallowed: the "... Date: YYYY:.. Time: .." comment
# (zz.xaq/zz.dsdt) and the "# YYYY:MM:DD .. UTC.." comment (zz.main). The .REF
# carry no CPU line, so CPU is deliberately NOT in the pattern (an earlier
# over-broad 'Date:|Time:|UTC|CPU' would have removed an appended bogus line from
# both sides and hidden a real difference).
strip () { grep -vE 'Date:.*Time:|^# [0-9]{4}:[0-9]{2}:[0-9]{2}[0-9:. ]*UTC' "$1"; }
ok=1
for f in zz.xaq zz.dsdt zz.main; do
  if [ ! -f "$WORK/$f" ]; then echo "  L1 $f  MISSING (not produced)"; ok=0; continue; fi
  if diff <(strip "$WORK/$f") <(strip "$RUNS/$f.REF") >/dev/null 2>&1; then
    n=$(strip "$WORK/$f" | grep -c .)
    echo "  L1 $f  IDENTICAL to shipped reference ($n lines, modulo timestamp)"
  else
    echo "  L1 $f  DIFFERS from shipped reference:"; diff <(strip "$WORK/$f") <(strip "$RUNS/$f.REF") | head -8; ok=0
  fi
done

# L2 numeric anchor
X="$(python3 -c "import re,sys; t=open('$WORK/zz.xaq').read(); m=re.search(r'Reactn xSectn\s*:\s*([-\d.eE+]+)',t); print(m.group(1) if m else 'nan')")"
if python3 -c "import sys; d=abs(float('$X')-$REACT_REF); sys.exit(0 if d<=5e-6 else 1)" 2>/dev/null; then
  echo "  L2 reaction cross section  $X b  vs reference $REACT_REF b   ok"
else
  echo "  L2 reaction cross section  $X b  vs reference $REACT_REF b   MISMATCH"; ok=0
fi

[ "$ok" -eq 1 ] && { echo "verify_swanlop: PASS  (tier 1: shipped reference reproduced)"; exit 0; } \
                || { echo "verify_swanlop: FAIL"; exit 1; }

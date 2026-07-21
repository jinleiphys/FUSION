#!/bin/bash
# verify_azure2.sh [case]
#
# Run the skill's benchmark case(s) and compare against pinned published values.
# case: "16O" (default) or "all".
#
# HONESTY CONTRACT. This skill is TIER 2. AZURE2 ships no reference output and
# no example input, so nothing here reproduces a distributed file. What is
# checked is:
#   L1  the deck reproduces the PUBLISHED INPUT PARAMETERS exactly
#       (all 9 entries of Table V of PRC 81, 045805), and
#   L2  the derived observables land within stated, quantified tolerances of
#       published results.
# The L2 tolerances are WIDE and that is deliberate: the S factor agrees with
# the paper to 4 to 6 percent, not to N significant figures. A check that
# claimed tighter agreement would be a lie about what has been established.
# See examples/16O_pg_17F/verification.md for why the gap exists and what was
# excluded as its cause.
#
# Anything unpinned is reported as UNPINNED and does not pass silently: the
# pikoe skill once printed "VERIFY OK" having compared zero anchors.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"
CASE="${1:-16O}"

BIN="${AZURE2_BIN:-}"
if [ -z "$BIN" ]; then
  BIN="$(bash "$HERE/install_azure2.sh" | sed -n 's/^AZURE2=//p')"
fi
[ -x "$BIN" ] || { echo "verify_azure2: no usable AZURE2 binary" >&2; exit 1; }
export AZURE2_BIN="$BIN"

FAIL=0
pass () { echo "  PASS  $1"; }
fail () { echo "  FAIL  $1"; FAIL=1; }

# rel_ok <value> <expected> <tolerance-fraction> -> 0 if within tolerance
rel_ok () {
  python3 -c "
import sys
v,e,t=float(sys.argv[1]),float(sys.argv[2]),float(sys.argv[3])
sys.exit(0 if abs(v-e)<=t*abs(e) else 1)" "$1" "$2" "$3"
}

verify_16O () {
  local D="$SKILL/examples/16O_pg_17F"
  echo "case 16O(p,gamma)17F  [Azuma et al., PRC 81, 045805 (2010), Table V]"

  # --- L1: the published INPUT parameters, the part that IS exact -----------
  # Recalibrating is what proves the deck still encodes Table V. If a width or
  # an ANC drifts, calibrate_widths.py refuses rather than converging.
  local cal
  if ! cal="$(cd "$D" && python3 calibrate_widths.py "$BIN" 2>&1)"; then
    fail "L1 Table V parameters: calibration refused"
    echo "$cal" | tail -3 | sed 's/^/        /'
    return
  fi
  if echo "$cal" | grep -q "converged: all 7 channels"; then
    pass "L1 Table V parameters: all 7 unbound channels reproduce exactly"
  else
    fail "L1 Table V parameters: calibration did not confirm all 7 channels"
    echo "$cal" | tail -3 | sed 's/^/        /'
    return
  fi
  # The two ANCs go in verbatim, so assert AZURE2 echoes them back unchanged.
  local anc
  anc="$(grep -c -E 'C  = +(1\.050000|80\.700000) fm' "$D/output/parameters.out" || true)"
  if [ "$anc" = "2" ]; then
    pass "L1 bound-state ANCs echo back as 1.050000 and 80.700000 fm^(-1/2)"
  else
    fail "L1 bound-state ANCs not echoed as published (found $anc of 2)"
  fi

  # --- L2: derived observable, WIDE tolerance, stated as such --------------
  bash "$HERE/run_azure2.sh" "$D/16O_pg_17F.azr" 3 >/dev/null || {
    fail "L2 extrapolation run"; return; }
  local g0 g1 tot
  g0="$(awk 'NF{print $5*1000; exit}' "$D/output/AZUREOut_aa=1_R=2.extrap")"
  g1="$(awk 'NF{print $5*1000; exit}' "$D/output/AZUREOut_aa=1_R=3.extrap")"
  tot="$(python3 -c "print($g0+$g1)")"
  printf "  S(90 keV): gamma0 %.4f  gamma1 %.4f  total %.4f keV b\n" "$g0" "$g1" "$tot"
  # Pinned to THIS deck's own value, tight: catches regressions in the skill.
  if rel_ok "$tot" 7.6080 0.002; then
    pass "L2a total S(90 keV) reproduces this deck's pinned 7.6080 keV b (0.2%)"
  else
    fail "L2a total S(90 keV) = $tot, pinned value is 7.6080 keV b"
  fi
  # Pinned to the PAPER, loose, because 4-6% is what was actually achieved.
  if rel_ok "$tot" 8.07 0.08; then
    pass "L2b total S(90 keV) within 8% of the published 8.07 keV b (actual -5.7%)"
  else
    fail "L2b total S(90 keV) = $tot is not within 8% of the published 8.07"
  fi

  # --- L2c: measured data, the one check independent of the paper ----------
  if [ -f "$SKILL/examples/talent/Rolfs_GS.dat" ]; then
    bash "$HERE/run_azure2.sh" "$D/16O_pg_17F_data.azr" 1 >/dev/null || {
      fail "L2c data run"; return; }
    local chi
    chi="$(awk '/Segment #3/{print $NF}' "$D/output/chiSquared.out")"
    printf "  chi^2/N vs Rolfs (1973) gamma0 at 90 deg: %s\n" "$chi"
    if rel_ok "$chi" 1.53315 0.02; then
      pass "L2c gamma0 vs measured Rolfs data, chi^2/N = 1.53 with nothing fitted"
    else
      fail "L2c chi^2/N = $chi, pinned value is 1.53315"
    fi
  else
    echo "  UNPINNED  L2c skipped: examples/talent/Rolfs_GS.dat absent"
  fi
}

case "$CASE" in
  16O|all) verify_16O ;;
  *) echo "verify_azure2: unknown case '$CASE' (have: 16O, all)" >&2; exit 2 ;;
esac

echo
if [ "$FAIL" -eq 0 ]; then
  echo "VERIFY OK  (tier 2: inputs exact, observables to stated tolerance)"
else
  echo "VERIFY FAILED"
fi
exit "$FAIL"

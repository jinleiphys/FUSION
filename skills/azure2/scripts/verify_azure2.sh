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
# Every check either passes or fails; there is no "skipped and therefore fine"
# path. The pikoe skill once printed "VERIFY OK" having compared zero anchors,
# and an earlier version of THIS script printed OK after skipping the one check
# that does not depend on the paper's own number.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"
CASE="${1:-all}"

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
  [ -n "${1:-}" ] && [ -n "${2:-}" ] || return 1
  python3 -c "
import sys
v,e,t=float(sys.argv[1]),float(sys.argv[2]),float(sys.argv[3])
sys.exit(0 if abs(v-e)<=t*abs(e) else 1)" "$1" "$2" "$3"
}

verify_16O () {
  local SRC="$SKILL/examples/16O_pg_17F"
  echo "case 16O(p,gamma)17F  [Azuma et al., PRC 81, 045805 (2010), Table V]"

  # VERIFY MUST NOT REPAIR WHAT IT IS CHECKING. calibrate_widths.py WRITES the
  # .azr, so running it against the shipped deck turns a corrupted deck into a
  # corrected one and then reports OK: an adversarial pass changed a proton
  # width by two orders of magnitude and still got VERIFY OK, with the file
  # silently rewritten. Two consequences, both applied here:
  #   (a) work on a COPY, so the shipped deck is never modified by verifying it;
  #   (b) require convergence on the FIRST iteration, which is the actual claim.
  #       A deck that already encodes Table V needs zero corrections; one that
  #       needs corrections was wrong when shipped, however good it looks after.
  # The data deck refers to ../talent/Rolfs_*.dat, so the copy must preserve the
  # sibling layout, not just the case directory.
  local TMP D; TMP="$(mktemp -d)"; D="$TMP/16O_pg_17F"
  mkdir -p "$D" "$TMP/talent"
  cp -R "$SRC/." "$D/"
  cp "$SKILL/examples/talent/"*.dat "$TMP/talent/" 2>/dev/null || true
  rm -rf "$D/output" "$D/checks"; mkdir -p "$D/output" "$D/checks"

  local cal
  if ! cal="$(cd "$D" && python3 calibrate_widths.py "$BIN" 2>&1)"; then
    fail "L1 Table V parameters: calibration refused"
    echo "$cal" | tail -3 | sed 's/^/        /'
    rm -rf "$TMP"; return
  fi
  if ! echo "$cal" | grep -q "converged: all 7 channels"; then
    fail "L1 Table V parameters: calibration did not confirm all 7 channels"
    echo "$cal" | tail -3 | sed 's/^/        /'
    rm -rf "$TMP"; return
  fi
  # "iteration 1 ... 0.000e+00" then converged == no correction was needed.
  if [ "$(echo "$cal" | grep -c '^iteration ')" -eq 1 ] \
     && echo "$cal" | grep -q '^iteration 1: worst relative deviation 0.000e+00'; then
    pass "L1 shipped deck already encodes all 7 Table V channels exactly (no correction needed)"
  else
    fail "L1 the shipped deck did NOT already encode Table V; calibration had to correct it"
    echo "$cal" | grep '^iteration ' | head -3 | sed 's/^/        /'
    rm -rf "$TMP"; return
  fi
  if ! diff -q "$SRC/16O_pg_17F.azr" "$D/16O_pg_17F.azr" >/dev/null; then
    fail "L1 verification modified the deck, which it must never do"
  fi
  local anc
  anc="$(grep -c -E 'C  = +(1\.050000|80\.700000) fm' "$D/output/parameters.out" || true)"
  if [ "$anc" = "2" ]; then
    pass "L1 bound-state ANCs echo back as 1.050000 and 80.700000 fm^(-1/2)"
  else
    fail "L1 bound-state ANCs not echoed as published (found $anc of 2)"
  fi

  # --- L2: derived observable, WIDE tolerance, stated as such --------------
  bash "$HERE/run_azure2.sh" "$D/16O_pg_17F.azr" 3 >/dev/null || {
    fail "L2 extrapolation run"; rm -rf "$TMP"; return; }
  local g0 g1 tot
  g0="$(awk 'NF{print $5*1000; exit}' "$D/output/AZUREOut_aa=1_R=2.extrap" 2>/dev/null || true)"
  g1="$(awk 'NF{print $5*1000; exit}' "$D/output/AZUREOut_aa=1_R=3.extrap" 2>/dev/null || true)"
  if [ -z "$g0" ] || [ -z "$g1" ]; then
    fail "L2 could not read S factors out of the extrapolation output"
    rm -rf "$TMP"; return
  fi
  tot="$(python3 -c "print($g0+$g1)")"
  printf "  S(90 keV): gamma0 %.4f  gamma1 %.4f  total %.4f keV b\n" "$g0" "$g1" "$tot"
  if rel_ok "$tot" 7.6080 0.002; then
    pass "L2a total S(90 keV) reproduces this deck's pinned 7.6080 keV b (0.2%)"
  else
    fail "L2a total S(90 keV) = $tot, pinned value is 7.6080 keV b"
  fi
  if rel_ok "$tot" 8.07 0.08; then
    pass "L2b total S(90 keV) within 8% of the published 8.07 keV b (actual -5.7%)"
  else
    fail "L2b total S(90 keV) = $tot is not within 8% of the published 8.07"
  fi

  # --- L2c: measured data, the one check independent of the paper ----------
  # Its inputs are SHIPPED IN THIS REPO, so their absence is a defect in the
  # skill, not an excuse to skip. An earlier version printed UNPINNED and then
  # VERIFY OK, which is the pikoe "passed having compared nothing" failure.
  if [ ! -f "$SKILL/examples/talent/Rolfs_GS.dat" ]; then
    fail "L2c inputs missing: examples/talent/Rolfs_GS.dat is shipped and should be present"
    rm -rf "$TMP"; return
  fi
  bash "$HERE/run_azure2.sh" "$D/16O_pg_17F_data.azr" 1 >/dev/null || {
    fail "L2c data run"; rm -rf "$TMP"; return; }
  local chi
  chi="$(awk '/Segment #3/{print $NF}' "$D/output/chiSquared.out" 2>/dev/null || true)"
  if [ -z "$chi" ]; then
    fail "L2c could not read chi^2/N for segment 3 out of chiSquared.out"
    rm -rf "$TMP"; return
  fi
  printf "  chi^2/N vs Rolfs (1973) gamma0 at 90 deg: %s\n" "$chi"
  if rel_ok "$chi" 1.53315 0.02; then
    pass "L2c gamma0 vs measured Rolfs data, chi^2/N = 1.53 with nothing fitted"
  else
    fail "L2c chi^2/N = $chi, pinned value is 1.53315"
  fi
  rm -rf "$TMP"
}

verify_14N () {
  local SRC="$SKILL/examples/14N_pg_15O_679"
  echo
  echo "case 14N(p,gamma)15O, 6.79 MeV transition  [same paper, Table II/III/IV]"
  local TMP D; TMP="$(mktemp -d)"; D="$TMP/14N"
  mkdir -p "$D"; cp -R "$SRC/." "$D/"
  rm -rf "$D/output" "$D/checks"; mkdir -p "$D/output" "$D/checks"

  bash "$HERE/run_azure2.sh" "$D/14N_pg_15O_679.azr" 3 >/dev/null || {
    fail "extrapolation run"; rm -rf "$TMP"; return; }
  local s0
  s0="$(awk 'NR==1{print $5*1000}' "$D/output/AZUREOut_aa=1_R=2.extrap" 2>/dev/null || true)"
  if [ -z "$s0" ]; then fail "could not read S(0) from the output"; rm -rf "$TMP"; return; fi
  printf "  S_6.79 at E_cm = 1 keV: %s keV b\n" "$s0"

  if rel_ok "$s0" 1.2572 0.002; then
    pass "S_6.79(0) reproduces this deck's pinned 1.2572 keV b (0.2%)"
  else
    fail "S_6.79(0) = $s0, pinned value is 1.2572 keV b"
  fi
  # The paper's OWN caption puts a 0.1 keV b data-selection sensitivity on this
  # number, so 5% is the honest window, not a generous one.
  if rel_ok "$s0" 1.30 0.05; then
    pass "S_6.79(0) within 5% of the published 1.30 keV b (actual -3.2%)"
  else
    fail "S_6.79(0) = $s0 is not within 5% of the published 1.30"
  fi
  rm -rf "$TMP"
}

case "$CASE" in
  16O) verify_16O ;;
  14N) verify_14N ;;
  all) verify_16O; verify_14N ;;
  *) echo "verify_azure2: unknown case '$CASE' (have: 16O, 14N, all)" >&2; exit 2 ;;
esac

echo
if [ "$FAIL" -eq 0 ]; then
  echo "VERIFY OK  (tier 2: inputs exact, observables to stated tolerance)"
else
  echo "VERIFY FAILED"
fi
exit "$FAIL"

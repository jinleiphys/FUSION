#!/bin/bash
# selftest_gibuu.sh
#
# Test the HARNESS, not the physics. Every guard gets a negative case that fails
# ONLY that guard, and each negative case asserts WHICH guard fired, because a
# test that fails for the wrong reason looks exactly like a test that passes.
# Runs in seconds and needs no GiBUU build: the runs use a stub executable.
#
# Two rules learned the hard way on the SMASH skill and applied here from the
# first version rather than after an adversarial pass:
#   * a fixture must ASSERT that its edit applied, or a substitution that
#     silently did nothing produces a test that proves the opposite of what it
#     claims;
#   * a guard is not tested until it has been shown to FLIP when disabled.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="$HERE/run_gibuu.sh"
CHECK="$HERE/check_gibuu_output.py"
PASS=0; FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# run_gibuu.sh canonicalises with `pwd -P`; on macOS mktemp returns /var/... and
# the canonical form is /private/var/... . Compare against the canonical
# spelling or a perfectly correct path reads as a mismatch.
TMPP="$(cd "$TMP" && pwd -P)"

ok  () { PASS=$((PASS+1)); echo "  ok    $*"; }
bad () { FAIL=$((FAIL+1)); echo "  FAIL  $*"; }
expect_pass () { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d (expected success, got failure)"; fi; }
expect_fail_with () {
  local d="$1" marker="$2"; shift 2
  local out; out="$("$@" 2>&1)" && { bad "$d (expected failure, got success)"; return; }
  case "$out" in
    *"$marker"*) ok "$d" ;;
    *) bad "$d (failed on the wrong guard: no '$marker' in the output)" ;;
  esac
}

# ------------------------------------------------------------------ fixtures
mkdir -p "$TMP/input"          # a stand-in buuinput directory
CARD="$TMP/card.job"
cat > "$CARD" <<'EOF'
&input
      eventtype       = 2
      numEnsembles    = -10
      numTimeSteps    = 10
      path_To_Input   = '~/GiBUU/buuinput'
      version = 2025
/

&initRandom
      SEED=45678                ! Seed for the random number
/
EOF

# A valid one-row cross-section table: 15 columns, identity satisfied.
# col5 + col6 = col7 = col8 by construction, as the real code writes it.
write_xs () {   # write_xs <path> <qesum> <abs> <total> <check>
  { echo '# elab, Sigma piMinus, Sigma piNull,Sigma piPlus, Sigma_QElastic, absorption_xSection, sigma Total, sigma Total(check), absorption Events ,number of runs, error of quasiElastic(-1:1), error of absorption_xSection, error of sigma Total'
    printf '   50.00       3189.       3226.       2453.       %s       %s       %s       %s            4290           1  0.1100E+06  0.1100E+06  0.1100E+06   9999.       9999.\n' "$2" "$3" "$4" "$5"
  } > "$1"
}
GOODXS="$TMP/good.dat"; write_xs "$GOODXS" 8869. -8153. 716.2 716.2

# A stub GiBUU: honours stdin, writes a plausible output set, and prints the
# completion banner. MODE breaks exactly one property.
write_stub () {
  local path="$TMP/$1" mode="$2"
  { echo '#!/bin/bash'
    echo "MODE=\"$mode\""
    cat <<'STUB'
CARD="$(cat)"                       # GiBUU reads its job card from stdin
SEED="$(printf '%s\n' "$CARD" | grep -iE '^[[:space:]]*SEED[[:space:]]*=' | head -1 | sed -E 's/.*=[[:space:]]*//; s/[[:space:]]*!.*$//')"
[ "$MODE" = "exitfail" ] && { echo "boom" >&2; exit 3; }
[ "$MODE" = "noboom" ]   && { echo "started but stopped"; exit 0; }
echo "Seed: ${SEED:-0}"
STUB
    echo 'case "$MODE" in'
    echo '  nooutput) echo "########## BUU simulation: finished"; exit 0 ;;'
    echo '  errorlog) echo " ERROR   something went wrong" ;;'
    echo 'esac'
    echo 'cp '"$GOODXS"' ./pionInduced_xSections.dat'
    cat <<'STUB2'
case "$MODE" in
  nan) sed -i.bak 's/716.2       716.2/716.2         NaN/' ./pionInduced_xSections.dat; rm -f ./pionInduced_xSections.dat.bak ;;
esac
echo "########## BUU simulation: finished"
exit 0
STUB2
  } > "$path"
  chmod +x "$path"
}
write_stub stub_ok ok
export GIBUU="$TMP/stub_ok" GIBUU_INPUT="$TMP/input" GIBUU_LIBPATH=""

echo "run_gibuu.sh argument handling"
expect_fail_with "missing --jobcard is rejected" "--jobcard is required" "$RUN"
expect_fail_with "a nonexistent job card is rejected" "does not exist" "$RUN" --jobcard "$TMP/nope"
printf 'just some text\n' > "$TMP/notacard"
expect_fail_with "a file with no &input namelist is rejected" "no '&input' namelist" "$RUN" --jobcard "$TMP/notacard"
expect_fail_with "an unknown argument is rejected" "unknown argument" "$RUN" --jobcard "$CARD" --bogus
expect_fail_with "an empty --seed value is rejected" "requires a non-empty value" "$RUN" --jobcard "$CARD" --seed ""
expect_fail_with "a non-integer --seed is rejected" "must be an integer" "$RUN" --jobcard "$CARD" --seed 1.5
expect_fail_with "an oversized --seed is rejected" "must be an integer" "$RUN" --jobcard "$CARD" --seed 9223372036854775808
expect_pass "the int64 maximum seed is accepted" "$RUN" --jobcard "$CARD" --outdir "$TMP/w_max" --seed 9223372036854775807

echo
echo "run_gibuu.sh seed policy (GiBUU reads Seed=0 as 'use the system clock')"
expect_pass "a card with a non-zero seed runs (control)" "$RUN" --jobcard "$CARD" --outdir "$TMP/w_ok" --seed 4242
grep -q "SEED=4242\|SEED = 4242" "$TMP/w_ok/jobcard_used.job" \
  && ok "the seed override reached the job card" || bad "the seed override did not reach the job card"
# ... and the card is not the only thing that matters: the binary must actually
# have used it. A misspelled Fortran namelist is SILENTLY IGNORED, so a card
# that looks right can still run with default physics.
grep -q "Seed: 4242" "$TMP/w_ok/out.log" \
  && ok "and GiBUU actually reported using that seed" \
  || bad "the job card carried the seed but GiBUU did not report using it"
sed 's/SEED=45678/SEED=0/' "$CARD" > "$TMP/seed0.job"
grep -q "SEED=0" "$TMP/seed0.job" && ok "fixture: Seed=0 substitution applied" || bad "fixture: Seed=0 substitution did NOT apply"
expect_fail_with "a card with Seed=0 is refused" "SYSTEM_CLOCK" "$RUN" --jobcard "$TMP/seed0.job" --outdir "$TMP/w_z"
sed '/&initRandom/,/^\//d' "$CARD" > "$TMP/noseed.job"
grep -qi "initRandom" "$TMP/noseed.job" && bad "fixture: initRandom was NOT removed" || ok "fixture: initRandom removed"
expect_fail_with "a card with no initRandom at all is refused" "sets no initRandom Seed" \
  "$RUN" --jobcard "$TMP/noseed.job" --outdir "$TMP/w_n"
expect_pass "--allow-random-seed accepts a Seed=0 card deliberately" \
  "$RUN" --jobcard "$TMP/seed0.job" --outdir "$TMP/w_allow" --allow-random-seed
expect_pass "--seed on a card with no initRandom appends the block" \
  "$RUN" --jobcard "$TMP/noseed.job" --outdir "$TMP/w_app" --seed 5150
grep -q "Seed: 5150" "$TMP/w_app/out.log" \
  && ok "and the appended block is really read by the binary" \
  || bad "the appended initRandom block was not honoured"

echo
echo "run_gibuu.sh input-path handling"
grep -q "$TMPP/input" "$TMP/w_ok/jobcard_used.job" \
  && ok "path_To_Input was rewritten to the real buuinput directory" \
  || bad "path_To_Input was not rewritten; GiBUU would read the author's own path"
sed '/path_To_Input/d' "$CARD" > "$TMP/nopath.job"
grep -q "path_To_Input" "$TMP/nopath.job" && bad "fixture: path_To_Input was NOT removed" || ok "fixture: path_To_Input removed"
expect_fail_with "a card with no path_To_Input is rejected" "no 'path_To_Input' entry" \
  "$RUN" --jobcard "$TMP/nopath.job" --outdir "$TMP/w_np" --seed 1
expect_fail_with "a nonexistent --input directory is rejected" "does not exist" \
  "$RUN" --jobcard "$CARD" --outdir "$TMP/w_ni" --seed 1 --input "$TMP/no_such_input"

echo
echo "run_gibuu.sh output guards (stub, one broken property each)"
for mode in exitfail noboom nooutput nan errorlog; do
  write_stub "stub_$mode" "$mode"
  case "$mode" in
    exitfail) d="a nonzero exit status fails";           m="exited with status" ;;
    noboom)   d="a missing completion banner fails";     m="stopped early" ;;
    nooutput) d="a run with no .dat output fails";       m="no non-empty .dat output" ;;
    nan)      d="NaN in the output fails";               m="NaN or Infinity" ;;
    errorlog) d="an ERROR line in the log fails";        m="logged an error" ;;
  esac
  GIBUU="$TMP/stub_$mode" expect_fail_with "$d" "$m" \
    "$RUN" --jobcard "$CARD" --outdir "$TMP/w_$mode" --seed 1
done

echo
echo "check_gibuu_output.py"
expect_pass "a well-formed table passes (control)" python3 "$CHECK" "$GOODXS"
expect_fail_with "a wrong pinned total fails" "sigma Total is" python3 "$CHECK" "$GOODXS" --expect-total 999.9
expect_pass "the pinned total matches" python3 "$CHECK" "$GOODXS" --expect-total 716.2
# The identity must FAIL when the two routes disagree, or it is decorative.
write_xs "$TMP/broken.dat" 8869. -8153. 716.2 800.0
expect_fail_with "a broken bookkeeping identity is caught" "events are being lost or double counted" \
  python3 "$CHECK" "$TMP/broken.dat"
# A column shift would survive the identity but not the sum rule.
write_xs "$TMP/shifted.dat" 1000. -8153. 716.2 716.2
expect_fail_with "a column that no longer satisfies col5+col6=col7 is caught" "not the ones this parser expects" \
  python3 "$CHECK" "$TMP/shifted.dat"
# Both totals zero would make the identity pass vacuously.
write_xs "$TMP/zeros.dat" 0. 0. 0. 0.
expect_fail_with "an all-zero table does not pass vacuously" "vacuously" python3 "$CHECK" "$TMP/zeros.dat"
# A changed column count must be an error, not a silent misread.
{ head -1 "$GOODXS"; echo "   50.00       3189.       3226."; } > "$TMP/short.dat"
expect_fail_with "a row with the wrong column count is rejected" "columns, expected 15" \
  python3 "$CHECK" "$TMP/short.dat"
{ head -1 "$GOODXS"; } > "$TMP/headeronly.dat"
expect_fail_with "a header with no data row is rejected" "no data row" python3 "$CHECK" "$TMP/headeronly.dat"
sed 's/716.2       716.2/716.2         NaN/' "$GOODXS" > "$TMP/nan.dat"
expect_fail_with "a non-finite value is rejected" "is not finite" python3 "$CHECK" "$TMP/nan.dat"
expect_fail_with "a non-positive tolerance is rejected" "must be positive" \
  python3 "$CHECK" "$GOODXS" --tolerance 0

echo
echo "-------------------------------------------"
echo "selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

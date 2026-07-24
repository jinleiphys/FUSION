#!/bin/bash
# selftest_thermalfist.sh
#
# Harness self-test: exercises every guard in check_output_thermalfist.py and the
# argument validation in run_/verify_thermalfist.sh, WITHOUT building Thermal-FIST.
# Each negative case asserts that the guard FIRES on its own targeted input, and
# each positive case asserts the guard does NOT over-fire on clean input. Run it
# after any edit to the harness.
#
# No em-dashes (user rule).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/check_output_thermalfist.py"
RUN="$HERE/run_thermalfist.sh"
VERIFY="$HERE/verify_thermalfist.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok   () { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad  () { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }

# run a command, capture rc and output
run () { OUT="$("$@" 2>&1)"; RC=$?; }

# expect_rc <want-rc> <label> -- <command...>
expect_rc () {
  local want="$1" label="$2"; shift 2; [ "$1" = "--" ] && shift
  run "$@"
  if [ "$RC" -eq "$want" ]; then ok "$label (rc=$RC)"; else bad "$label (want rc=$want, got $RC): ${OUT##*$'\n'}"; fi
}
# expect_msg <want-rc> <substring> <label> -- <command...>
expect_msg () {
  local want="$1" needle="$2" label="$3"; shift 3; [ "$1" = "--" ] && shift
  run "$@"
  # `--` stops grep from reading a needle that starts with '-' as an option.
  if [ "$RC" -eq "$want" ] && printf '%s' "$OUT" | grep -qF -- "$needle"; then
    ok "$label"
  else
    bad "$label (want rc=$want & '$needle', got rc=$RC): ${OUT##*$'\n'}"
  fi
}

echo "== check_output: structural validation =="

# A clean all-numeric table (cpc1-like).
CLEAN="$TMP/clean.out"
{
  echo "T[MeV] p/T^4 e/T^4"
  echo "150.000000 0.647513 3.846843"
  echo "151.000000 0.660000 3.900000"
} > "$CLEAN"
expect_rc 0 "clean numeric table passes" -- python3 "$CHECK" "$CLEAN" --min-rows 2 --min-cols 3

# A table with a leading label column (cpc3-like).
LABELED="$TMP/labeled.out"
{
  echo "Dataset T[MeV] muB[MeV]"
  echo "NA49-30GeV-4pi 143.5 440.6"
  echo "ALICE-2_76-0-5 152.9 4.4"
} > "$LABELED"
expect_rc 0 "labeled table (leading label col) passes" -- python3 "$CHECK" "$LABELED" --min-rows 2 --min-cols 2

# Empty file.
: > "$TMP/empty.out"
expect_msg 1 "empty" "empty file rejected" -- python3 "$CHECK" "$TMP/empty.out"

# Header only, no data rows, with --min-rows 1.
echo "T[MeV] p/T^4" > "$TMP/headeronly.out"
expect_msg 1 "at least 1" "header-only rejected under --min-rows 1" -- python3 "$CHECK" "$TMP/headeronly.out" --min-rows 1

# A label appearing AFTER a number (real defect, not a label column).
{
  echo "a b c"
  echo "1.0 2.0 xyz"
} > "$TMP/midlabel.out"
expect_msg 1 "non-numeric token after a number" "mid-row label rejected" -- python3 "$CHECK" "$TMP/midlabel.out"

# NaN and Inf.
{ echo "a b"; echo "1.0 nan"; } > "$TMP/nan.out"
expect_msg 1 "non-finite" "NaN rejected" -- python3 "$CHECK" "$TMP/nan.out"
{ echo "a b"; echo "1.0 inf"; } > "$TMP/inf.out"
expect_msg 1 "non-finite" "Inf rejected" -- python3 "$CHECK" "$TMP/inf.out"

# Inconsistent numeric column count.
{ echo "a b c"; echo "1 2 3"; echo "4 5"; } > "$TMP/ncols.out"
expect_msg 1 "numeric columns, expected" "inconsistent numeric columns rejected" -- python3 "$CHECK" "$TMP/ncols.out"

# Inconsistent label column count. Both rows have the SAME numeric column count
# (2) so the numeric-column guard does NOT fire first; only the label count
# differs (1 vs 0), isolating the label-column guard.
{ echo "d a b"; echo "L1 1 2"; echo "3 4"; } > "$TMP/nlabels.out"
expect_msg 1 "label columns, expected" "inconsistent label-column count rejected" -- python3 "$CHECK" "$TMP/nlabels.out"

# min-rows / min-cols not met.
expect_msg 1 "at least 5" "min-rows enforced" -- python3 "$CHECK" "$CLEAN" --min-rows 5
expect_msg 1 "at least 9" "min-cols enforced" -- python3 "$CHECK" "$CLEAN" --min-cols 9

# Bad argument values.
expect_msg 1 "must be positive" "non-positive accuracy rejected" -- python3 "$CHECK" "$CLEAN" --accuracy 0
expect_msg 1 "non-negative" "negative min-rows rejected" -- python3 "$CHECK" "$CLEAN" --min-rows -1

echo "== check_output: --reference comparison =="

REF="$TMP/ref.out"
cp "$CLEAN" "$REF"
expect_rc 0 "identical reference matches" -- python3 "$CHECK" "$CLEAN" --reference "$REF" --accuracy 1e-9
# Perturb one value beyond tolerance.
{ echo "T[MeV] p/T^4 e/T^4"; echo "150.000000 0.647613 3.846843"; echo "151.000000 0.660000 3.900000"; } > "$TMP/pert.out"
expect_msg 1 "diff" "reference mismatch caught" -- python3 "$CHECK" "$TMP/pert.out" --reference "$REF" --accuracy 1e-6
# But within a loose tolerance it passes.
expect_rc 0 "reference mismatch within loose tol passes" -- python3 "$CHECK" "$TMP/pert.out" --reference "$REF" --accuracy 1e-3
# Different row count.
{ echo "T p e"; echo "1 2 3"; } > "$TMP/short.out"
expect_msg 1 "rows" "reference row-count mismatch caught" -- python3 "$CHECK" "$TMP/short.out" --reference "$REF" --accuracy 1e-3
# Different column count.
{ echo "T p"; echo "150.0 0.647513"; echo "151.0 0.66"; } > "$TMP/narrow.out"
expect_msg 1 "columns" "reference col-count mismatch caught" -- python3 "$CHECK" "$TMP/narrow.out" --reference "$REF" --accuracy 1e-3

echo "== check_output: --row-at anchor =="

expect_rc 0 "row-at anchor matches" -- python3 "$CHECK" "$CLEAN" --row-at 0 150 --expect 1 0.647513 2 3.846843 --accuracy 1e-5
expect_msg 1 "no row with column" "row-at missing value caught" -- python3 "$CHECK" "$CLEAN" --row-at 0 999 --expect 1 0.647513 --accuracy 1e-5
expect_msg 1 "out of range" "row-at column out of range caught" -- python3 "$CHECK" "$CLEAN" --row-at 9 150 --expect 1 0.6 --accuracy 1e-5
expect_msg 1 "even number" "row-at odd --expect caught" -- python3 "$CHECK" "$CLEAN" --row-at 0 150 --expect 1 --accuracy 1e-5
expect_msg 1 "MISMATCH" "row-at wrong expected value caught" -- python3 "$CHECK" "$CLEAN" --row-at 0 150 --expect 1 0.999 --accuracy 1e-6

echo "== run_thermalfist: argument validation (no build) =="

# A fake examples dir so run does not try to install. The binaries need not be
# runnable for the argument-validation guards, which fire before execution.
FAKE="$TMP/fakeexamples"; mkdir -p "$FAKE"
for b in cpc1HRGTDep cpc2chi2 cpc3chi2NEQ; do printf '#!/bin/sh\nexit 0\n' > "$FAKE/$b"; chmod +x "$FAKE/$b"; done

expect_msg 1 "--example is required" "run: missing --example" -- env TFIST_EXAMPLES="$FAKE" bash "$RUN" --config 0
expect_msg 1 "--config is required"  "run: missing --config"  -- env TFIST_EXAMPLES="$FAKE" bash "$RUN" --example cpc1
expect_msg 1 "unknown --example"     "run: unknown example"   -- env TFIST_EXAMPLES="$FAKE" bash "$RUN" --example cpcX --config 0
expect_msg 1 "non-negative integer"  "run: non-integer config" -- env TFIST_EXAMPLES="$FAKE" bash "$RUN" --example cpc1 --config 1.5
expect_msg 1 "must be 0..2"          "run: cpc1 config out of range" -- env TFIST_EXAMPLES="$FAKE" bash "$RUN" --example cpc1 --config 3
expect_msg 1 "must be 0..1"          "run: cpc3 config out of range" -- env TFIST_EXAMPLES="$FAKE" bash "$RUN" --example cpc3 --config 2
expect_msg 1 "unknown argument"      "run: unknown flag"      -- env TFIST_EXAMPLES="$FAKE" bash "$RUN" --bogus
# Non-empty outdir refused.
NE="$TMP/nonempty"; mkdir -p "$NE"; : > "$NE/x"
expect_msg 1 "not empty" "run: non-empty outdir refused" -- env TFIST_EXAMPLES="$FAKE" bash "$RUN" --example cpc1 --config 0 --outdir "$NE"

# A stub cpc1 that writes NOTHING must be caught as "no table produced".
NOOUT="$TMP/noout"; mkdir -p "$NOOUT"
printf '#!/bin/sh\nexit 0\n' > "$NOOUT/cpc1HRGTDep"; chmod +x "$NOOUT/cpc1HRGTDep"
expect_msg 1 "no .out or .dat" "run: empty producer caught" -- env TFIST_EXAMPLES="$NOOUT" bash "$RUN" --example cpc1 --config 0 --outdir "$TMP/o_empty"

# A stub cpc1 that exits nonzero must be caught.
FAILP="$TMP/failp"; mkdir -p "$FAILP"
printf '#!/bin/sh\necho boom >&2\nexit 7\n' > "$FAILP/cpc1HRGTDep"; chmod +x "$FAILP/cpc1HRGTDep"
expect_msg 1 "exited with status 7" "run: nonzero exit caught" -- env TFIST_EXAMPLES="$FAILP" bash "$RUN" --example cpc1 --config 0 --outdir "$TMP/o_fail"

echo "== verify_thermalfist: argument + identity guards (no build) =="

expect_msg 1 "unknown argument" "verify: unknown flag" -- bash "$VERIFY" --bogus
# Identity must fail when TFIST_ROOT is not a git clone.
NOGIT="$TMP/notaclone"; mkdir -p "$NOGIT/build"; : > "$NOGIT/build/CMakeCache.txt"
printf '#!/bin/sh\nexit 0\n' > "$NOGIT/build/cpc1HRGTDep"; chmod +x "$NOGIT/build/cpc1HRGTDep"
expect_msg 1 "not a git clone" "verify: non-clone source rejected" -- \
  env TFIST="$NOGIT/build/cpc1HRGTDep" TFIST_BUILD="$NOGIT/build" TFIST_ROOT="$NOGIT" TFIST_EXAMPLES="$NOGIT/build" \
  bash "$VERIFY" --anchor-only

echo
echo "selftest_thermalfist: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
echo "SELFTEST OK"

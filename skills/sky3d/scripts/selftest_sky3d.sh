#!/bin/bash
# selftest_sky3d.sh
#
# Test the HARNESS, not the physics. Every guard in run_sky3d.sh, verify_sky3d.sh
# and compare_sky3d.py gets a negative case that fails ONLY that guard, so a
# guard cannot look tested when a different one is doing the work. Runs in a few
# seconds and needs no Sky3D build: the runs use a stub executable.
#
# The standing rule this file exists to satisfy (CLAUDE.md, 2026-07-22): a guard
# is not verified until it is shown to flip when disabled, and each guard needs a
# test that isolates it.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="$HERE/run_sky3d.sh"
CMP="$HERE/compare_sky3d.py"
PASS=0
FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ok   () { PASS=$((PASS+1)); echo "  ok    $*"; }
bad  () { FAIL=$((FAIL+1)); echo "  FAIL  $*"; }
# expect_fail <description> <command...>: the command MUST exit nonzero
expect_fail () { local d="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$d (expected failure, got success)"; else ok "$d"; fi; }
expect_pass () { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d (expected success, got failure)"; fi; }

# ------------------------------------------------------------------ fixtures
DECK="$TMP/deck"
cat > "$DECK" <<'EOF'
 &files wffile='x' /
 &force name='SV-bas', pairing='NONE' /
 &main mprint=1,mplot=0,imode=1,tfft=T,nof=0 /
 &grid nx=16,ny=16,nz=16,dx=1.0,periodic=F /
 &static nprot=8,nneut=8,maxiter=1,serr=1D-6 /
EOF

# A healthy for006, as the stub writes it. Header asterisks are present on
# purpose: they are what the overflow guard must NOT fire on.
healthy_for006 () {
  cat <<'EOF'
 ***** Running sequential version *****
 ***** Force definition *****
 Static Iteration No.     1  x0dmp=       0.4000
 ***** Iteration       1 *****
 Energies integrated from density functional:
 Total: -1.166577E+02 MeV. t0 part: -9.761758E+02 MeV. t1 part:  1.268929E+01 MeV. t2 part:  4.347195E+01 MeV
                           t3 part:  5.560523E+02 MeV. t4 part: -7.476126E-01 MeV. Coulomb:  1.354168E+01 MeV.
  #  Par   v**2   var_h1   var_h2    Norm     Ekin    Energy     Lx      Ly      Lz     Sx     Sy     Sz
   1  1. 1.00000  0.00000  0.00000 1.000000  10.141   -31.245   0.000   0.000  -0.000 -0.000  0.000  0.500
              Part.Num.   rms-radius   q20         <x**2>      <y**2>      <z**2>        <x>            <y>            <z>
    Total:      16.0000      2.6884  1.4983E-09  2.4092E+00  2.4092E+00  2.4092E+00 -3.1657359E-16 -2.7916011E-16 -3.8657262E-16
EOF
}

# A stub Sky3D. Each mode breaks exactly ONE property of a healthy run, so a
# failing test names the guard it exercised.
write_stub () {
  local path="$TMP/$1" mode="$2"
  {
    echo '#!/bin/bash'
    echo "MODE=\"$mode\""
    echo 'healthy () {'
    echo 'cat <<'"'"'EOT'"'"''
    healthy_for006
    echo 'EOT'
    echo '}'
    cat <<'STUB'
case "$MODE" in
  healthy)     healthy ;;
  exitfail)    healthy; exit 3 ;;
  emptyout)    : ;;
  stderrfatal) healthy; echo "Fortran runtime error: bad thing" >&2 ;;
  nan)         healthy | sed 's/-1.166577E+02/NaN/' ;;
  overflow)    healthy | sed 's/      16.0000/      ********/' ;;
  noenergy)    healthy | grep -v '^ Total:' ;;
  noiter)      healthy | grep -v 'Static Iteration No' ;;
  *) exit 99 ;;
esac
exit 0
STUB
  } > "$path"
  chmod +x "$path"
}

echo "run_sky3d.sh argument handling"
expect_fail "missing --deck is rejected"                 "$RUN"
expect_fail "nonexistent deck is rejected"               "$RUN" --deck "$TMP/nope"
printf 'not a namelist\n' > "$TMP/notadeck"
expect_fail "a file with no &main is rejected"           "$RUN" --deck "$TMP/notadeck"
expect_fail "unknown argument is rejected"               "$RUN" --deck "$DECK" --bogus x

echo
echo "run_sky3d.sh output guards (stub executable, one broken property each)"
write_stub stub_healthy healthy
SKY3D="$TMP/stub_healthy" expect_pass "a healthy stub run passes (control)" \
  "$RUN" --deck "$DECK" --workdir "$TMP/w_healthy"

# Control proves the header asterisks in the healthy fixture do NOT trip the
# overflow guard; without this the overflow test below would prove nothing.
if grep -q '\*\*\*\*\*' "$TMP/w_healthy/for006"; then
  ok "the passing control really does contain ***** header lines"
else
  bad "control fixture lost its ***** headers, the overflow test is not isolated"
fi

for mode in exitfail emptyout stderrfatal nan overflow noenergy noiter; do
  write_stub "stub_$mode" "$mode"
  case "$mode" in
    exitfail)    d="a nonzero exit status fails" ;;
    emptyout)    d="an empty for006 fails" ;;
    stderrfatal) d="a Fortran runtime error on stderr fails even with exit 0" ;;
    nan)         d="NaN in the output fails" ;;
    overflow)    d="a numeric field overflow (asterisks outside a header) fails" ;;
    noenergy)    d="a missing total-energy line fails" ;;
    noiter)      d="a static run with no printed iteration fails" ;;
  esac
  SKY3D="$TMP/stub_$mode" expect_fail "$d" "$RUN" --deck "$DECK" --workdir "$TMP/w_$mode"
done

echo
echo "run_sky3d.sh fragment staging"
: > "$TMP/frag"
SKY3D="$TMP/stub_healthy" expect_fail "an absolute fragment destination is rejected" \
  "$RUN" --deck "$DECK" --workdir "$TMP/w_absfrag" --fragment "$TMP/frag:/etc/passwd"
SKY3D="$TMP/stub_healthy" expect_fail "a fragment destination containing .. is rejected" \
  "$RUN" --deck "$DECK" --workdir "$TMP/w_dotdot" --fragment "$TMP/frag:../escape/O16"
SKY3D="$TMP/stub_healthy" expect_fail "a nonexistent fragment source is rejected" \
  "$RUN" --deck "$DECK" --workdir "$TMP/w_nofrag" --fragment "$TMP/absent:O16"
SKY3D="$TMP/stub_healthy" expect_pass "a relative fragment destination is staged" \
  "$RUN" --deck "$DECK" --workdir "$TMP/w_okfrag" --fragment "$TMP/frag:sub/O16"
[ -f "$TMP/w_okfrag/sub/O16" ] && ok "the staged fragment landed at sub/O16" \
  || bad "the staged fragment is missing from the work directory"

echo
echo "compare_sky3d.py"
A="$TMP/cand"; B="$TMP/ref"
healthy_for006 > "$A"; healthy_for006 > "$B"
expect_pass "identical files compare OK (control)"          python3 "$CMP" "$A" "$B"

sed 's/-1.166577E+02/-1.166578E+02/' "$B" > "$TMP/ref_energy"
expect_fail "a changed total energy fails"                  python3 "$CMP" "$A" "$TMP/ref_energy"

sed 's/  10.141   -31.245/  10.141   -31.246/' "$B" > "$TMP/ref_sp"
expect_fail "a changed single-particle energy fails"        python3 "$CMP" "$A" "$TMP/ref_sp"

sed 's/      2.6884/      2.6885/' "$B" > "$TMP/ref_rms"
expect_fail "a changed rms radius fails"                    python3 "$CMP" "$A" "$TMP/ref_rms"

# Degenerate-state orientation must NOT fail: this is the whole reason the
# comparator exists instead of diff.
sed 's/ -0.000 -0.000  0.000  0.500/  0.311  0.221  0.323  0.500/' "$B" > "$TMP/ref_orient"
expect_pass "a different degenerate-state orientation still passes" python3 "$CMP" "$A" "$TMP/ref_orient"

# q20 as a symmetry residue must be ignored, but q20 of a DEFORMED case must not.
sed 's/1.4983E-09/2.9983E-09/' "$B" > "$TMP/ref_q20noise"
expect_pass "a different symmetry-residue q20 passes (spherical case)" python3 "$CMP" "$A" "$TMP/ref_q20noise"
sed 's/1.4983E-09/3.0000E+01/' "$A" > "$TMP/cand_def"
sed 's/1.4983E-09/3.3000E+01/' "$B" > "$TMP/ref_def"
expect_fail "a differing q20 FAILS when the case is deformed" python3 "$CMP" "$TMP/cand_def" "$TMP/ref_def"

sed 's/-1.166577E+02/NaN/' "$A" > "$TMP/cand_nan"
expect_fail "a non-finite value in the candidate fails"     python3 "$CMP" "$TMP/cand_nan" "$B"

grep -v '^ Total:' "$A" > "$TMP/cand_noe"
expect_fail "a candidate with no energy block fails"        python3 "$CMP" "$TMP/cand_noe" "$B"

healthy_for006 > "$TMP/ref_short"; healthy_for006 >> "$TMP/ref_short"
expect_fail "a differing number of printed blocks fails"    python3 "$CMP" "$A" "$TMP/ref_short"

echo
echo "verify_sky3d.sh"
expect_fail "verify rejects an unknown argument"            "$HERE/verify_sky3d.sh" --bogus
SKY3D=/bin/true SKY3D_TESTS="$TMP/no_such_tests" \
  expect_fail "verify fails when the Test/ directory is absent" "$HERE/verify_sky3d.sh"
mkdir -p "$TMP/tests/Static"; : > "$TMP/tests/Static/for005.static"; : > "$TMP/tests/Static/for006.static"
SKY3D=/bin/true SKY3D_TESTS="$TMP/tests" \
  expect_fail "verify fails on an EMPTY distributed reference rather than skipping" "$HERE/verify_sky3d.sh"

echo
echo "-------------------------------------------"
echo "selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

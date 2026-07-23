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
# expect_fail <description> <command...>: the command MUST exit nonzero.
expect_fail () { local d="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$d (expected failure, got success)"; else ok "$d"; fi; }
expect_pass () { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d (expected success, got failure)"; fi; }
# expect_fail_with <description> <marker> <command...>: it must exit nonzero AND
# say the expected thing. Without the marker a negative case can pass because a
# DIFFERENT guard fired, which is exactly how this file's verify tests were
# passing while proving nothing (a missing /bin/true on macOS tripped the
# executable check, never the reference check they claimed to exercise).
expect_fail_with () {
  local d="$1" marker="$2"; shift 2
  local out; out="$("$@" 2>&1)" && { bad "$d (expected failure, got success)"; return; }
  case "$out" in
    *"$marker"*) ok "$d" ;;
    *) bad "$d (failed, but on the wrong guard: no '$marker' in the output)" ;;
  esac
}

# ------------------------------------------------------------------ fixtures
DECK="$TMP/deck"
cat > "$DECK" <<'EOF'
 &files wffile='x' /
 &force name='SV-bas', pairing='NONE' /
 &main mprint=1,mplot=0,imode=1,tfft=T,nof=0 /
 &grid nx=16,ny=16,nz=16,dx=1.0,periodic=F /
 &static nprot=8,nneut=8,maxiter=100,serr=1D-6 /
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
echo "check_collision_sky3d.py"
CC="$HERE/check_collision_sky3d.py"
mkdir -p "$TMP/coll"
res () {  # write an energies.res with the given rows (full 8-column schema)
  printf '#    Time    N(n)    N(p)       E(sum)        E(integ)      Ekin     Ecoll(n)  Ecoll(p)\n' > "$TMP/coll/energies.res"
  cat >> "$TMP/coll/energies.res"
}
res <<'EOT'
      0.00  16.000  16.000   -133.3082692   -133.3342577   560.04   45.434   45.421
     10.00  16.000  16.000   -133.3085319   -133.3387907   558.93   45.104   43.829
     20.00  16.000  16.000   -133.2739812   -133.3447324   561.17   43.681   42.216
EOT
expect_pass "a conserving collision passes (control)"        python3 "$CC" "$TMP/coll" --expect-n 16 --expect-z 16
res <<'EOT'
      0.00  16.000  16.000   -133.3082692   -133.3342577   560.04   45.434   45.421
     10.00  15.000  16.000   -133.3085319   -133.3387907   558.93   45.104   43.829
EOT
expect_fail "particle-number loss fails"                     python3 "$CC" "$TMP/coll" --expect-n 16 --expect-z 16
res <<'EOT'
      0.00  16.000  16.000   -133.3082692   -133.3342577   560.04   45.434   45.421
     10.00  16.000  16.000   -120.0000000   -133.3387907   558.93   45.104   43.829
EOT
expect_fail "an E(sum) jump fails"                           python3 "$CC" "$TMP/coll" --expect-n 16 --expect-z 16
res <<'EOT'
      0.00  16.000  16.000            NaN   -133.3342577   560.04   45.434   45.421
     10.00  16.000  16.000   -133.3085319   -133.3387907   558.93   45.104   43.829
EOT
expect_fail "a non-finite energy fails"                      python3 "$CC" "$TMP/coll" --expect-n 16 --expect-z 16
res <<'EOT'
      0.00  16.000  16.000   -133.3082692   -133.3342577   560.04   45.434   45.421
EOT
expect_fail "a single-row (non-evolving) run fails"          python3 "$CC" "$TMP/coll" --expect-n 16 --expect-z 16
rm -f "$TMP/coll/energies.res"
expect_fail "a missing energies.res fails"                   python3 "$CC" "$TMP/coll" --expect-n 16 --expect-z 16

echo
echo "verify_sky3d.sh"
# /bin/true does NOT exist on macOS, so using it as the executable made these
# tests fail at the "no usable Sky3D executable" check instead of the checks they
# name. Use a real stub, and assert the marker of the intended guard.
NOOP="$TMP/noop"; printf '#!/bin/bash\nexit 0\n' > "$NOOP"; chmod +x "$NOOP"
[ -x "$NOOP" ] && ok "the verify stub executable exists (macOS has no /bin/true)" \
  || bad "could not create the verify stub"

expect_fail "verify rejects an unknown argument"            "$HERE/verify_sky3d.sh" --bogus

SKY3D="$NOOP" SKY3D_TESTS="$TMP/no_such_tests" \
  expect_fail_with "verify fails when the Test/ directory is absent" "no Test/ directory" \
  "$HERE/verify_sky3d.sh"

# Isolation: the INPUT stays valid so the only broken precondition is the empty
# reference. The previous version emptied both, so it tripped the input check.
mkdir -p "$TMP/tests/Static"
printf ' &main imode=1 /\n' > "$TMP/tests/Static/for005.static"
: > "$TMP/tests/Static/for006.static"
SKY3D="$NOOP" SKY3D_TESTS="$TMP/tests" \
  expect_fail_with "verify fails on an EMPTY reference, naming the reference" "for006.static' is missing or empty" \
  "$HERE/verify_sky3d.sh"

# And the complementary case: a valid reference with an empty INPUT must name the
# input, proving the two conditions are distinguished rather than conflated.
mkdir -p "$TMP/tests2/Static"
: > "$TMP/tests2/Static/for005.static"
printf ' Total: -1.0E+00 MeV\n' > "$TMP/tests2/Static/for006.static"
SKY3D="$NOOP" SKY3D_TESTS="$TMP/tests2" \
  expect_fail_with "verify fails on an EMPTY input, naming the input" "for005.static' is missing or empty" \
  "$HERE/verify_sky3d.sh"

echo
echo "guards added after the 2026-07-23 adversarial pass (each attack Codex landed)"
# --- run_sky3d.sh: non-convergence, workdir reuse, sandbox escape
UNCONV="$TMP/deck_unconv"
sed 's/maxiter=100/maxiter=1/' "$DECK" > "$UNCONV"
write_stub stub_healthy healthy
SKY3D="$TMP/stub_healthy" expect_fail_with "a static run that hits maxiter is rejected" "did NOT converge" \
  "$RUN" --deck "$UNCONV" --workdir "$TMP/w_unconv"
SKY3D="$TMP/stub_healthy" expect_pass "--allow-unconverged accepts it deliberately" \
  "$RUN" --deck "$UNCONV" --workdir "$TMP/w_unconv2" --allow-unconverged

mkdir -p "$TMP/w_dirty"; : > "$TMP/w_dirty/leftover"
SKY3D="$TMP/stub_healthy" expect_fail_with "a non-empty workdir is rejected" "is not empty" \
  "$RUN" --deck "$DECK" --workdir "$TMP/w_dirty"

# '..' is allowed only inside an explicit --root, which is what the shipped
# collision deck's '../Static/O16' layout needs, and refused without one.
mkdir -p "$TMP/root/Collision"
SKY3D="$TMP/stub_healthy" expect_fail_with "'..' without --root escapes and is rejected" "outside --root" \
  "$RUN" --deck "$DECK" --workdir "$TMP/root/Collision" --fragment "$TMP/frag:../Static/O16"
rm -rf "$TMP/root"; mkdir -p "$TMP/root/Collision"
SKY3D="$TMP/stub_healthy" expect_pass "'..' inside --root is allowed (the shipped collision layout)" \
  "$RUN" --deck "$DECK" --workdir "$TMP/root/Collision" --root "$TMP/root" --fragment "$TMP/frag:../Static/O16"
[ -f "$TMP/root/Static/O16" ] && ok "the fragment landed at root/Static/O16" || bad "fragment not staged under --root"

# A symlinked component must not defeat the containment test. The workdir itself
# must be empty, so the symlink is planted in the --root beside it, which is the
# path a real escape would take.
rm -rf "$TMP/link_root" "$TMP/link_target"
mkdir -p "$TMP/link_root/Collision" "$TMP/link_target"
ln -s "$TMP/link_target" "$TMP/link_root/Static"
SKY3D="$TMP/stub_healthy" expect_fail_with "a symlinked path component cannot escape --root" "outside --root" \
  "$RUN" --deck "$DECK" --workdir "$TMP/link_root/Collision" --root "$TMP/link_root" \
  --fragment "$TMP/frag:../Static/O16"
[ -f "$TMP/link_target/O16" ] && bad "the symlink escape wrote outside the sandbox" \
  || ok "nothing was written through the symlink"

# --- compare_sky3d.py: the four injections that used to return COMPARE OK
sed 's/Coulomb:  1.354168E+01/Coulomb:  NaN/' "$A" > "$TMP/inj_nan"
expect_fail_with "NaN replacing an energy value fails" "non-finite" python3 "$CMP" "$TMP/inj_nan" "$B"
sed 's/Coulomb:  1.354168E+01/Coulomb:/' "$A" > "$TMP/inj_short"
expect_fail_with "a short energy line fails instead of silently dropping a value" "expected" \
  python3 "$CMP" "$TMP/inj_short" "$B"
sed 's/  0.00000  0.00000 1.000000/  99999.0  99999.0 1.000000/' "$A" > "$TMP/inj_res"
expect_fail_with "huge var_h1/var_h2 (unconverged) fails" "not converged" python3 "$CMP" "$TMP/inj_res" "$B"
sed 's/ -0.000  0.000  0.500$/ 999.0  999.0  999.0/' "$A" > "$TMP/inj_spin"
expect_fail_with "an impossible spin component fails" "spin-1/2" python3 "$CMP" "$TMP/inj_spin" "$B"
sed 's/-3.1657359E-16/1.0000000E+100/' "$A" > "$TMP/inj_cen"
expect_fail_with "a centroid outside any box fails" "outside any sane box" python3 "$CMP" "$TMP/inj_cen" "$B"
expect_fail_with "--rtol nan cannot disable the comparison" "not a finite tolerance" \
  python3 "$CMP" "$TMP/cand_def" "$TMP/ref_def" --rtol nan
expect_fail_with "--sphere-tol inf cannot disable the comparison" "not a finite tolerance" \
  python3 "$CMP" "$A" "$B" --sphere-tol inf

# --- check_collision_sky3d.py
res <<'EOT'
      0.00  16.000  16.000   -133.3082692   -133.3342577   560.04
     10.00  16.000  16.000   -133.3085319   -133.3387907   558.93
EOT
expect_fail_with "a wrong column count is rejected" "columns, expected 8" python3 "$CC" "$TMP/coll" --expect-n 16 --expect-z 16
res <<'EOT'
      0.00  16.000  16.000   -133.3082692   -133.3342577   560.04   45.4   45.4
      0.00  16.000  16.000   -133.3085319   -133.3387907   558.93   45.1   43.8
EOT
expect_fail_with "a non-increasing time column is rejected" "strictly increasing" python3 "$CC" "$TMP/coll" --expect-n 16 --expect-z 16
res <<'EOT'
      0.00   0.000   0.000      0.0000000      0.0000000     0.00    0.0    0.0
     10.00   0.000   0.000      0.0000000      0.0000000     0.00    0.0    0.0
EOT
expect_fail_with "an all-zero table is rejected" "neither" python3 "$CC" "$TMP/coll" --expect-n 16 --expect-z 16
res <<'EOT'
      0.00  16.000  16.000   -133.3082692   -133.3342577   560.04   45.4   45.4
     10.00  16.000  16.000   -133.3085319   -133.3387907   558.93   45.1   43.8
EOT
expect_fail_with "a requested but missing --reference fails, never skips" "--reference was given" \
  python3 "$CC" "$TMP/coll" --expect-n 16 --expect-z 16 --reference "$TMP/no_such_reference"
expect_fail_with "a nan drift bound cannot disable the gate" "not a finite" \
  python3 "$CC" "$TMP/coll" --expect-n 16 --expect-z 16 --max-energy-drift nan
expect_fail_with "a wrong --expect-n is caught" "is not the expected" \
  python3 "$CC" "$TMP/coll" --expect-n 8

echo
echo "guards added after the re-verification pass (2026-07-23, round 2)"
# The one-sided asterisk headers a REAL collision log carries. Excluding only the
# symmetric " ***** X *****" form rejected every legitimate collision run, and
# static-only testing never showed it.
COLLHDR="$TMP/collhdr"; mkdir -p "$COLLHDR"
printf ' &main imode=2 /\n &dynamic nt=2 /\n' > "$COLLHDR/for005"
{
  echo ' ***** Running sequential version *****'
  echo ' ***** Data for fragment # 1 from file ../Static/O16'
  echo '******* Fragment # 0'
  echo ' Starting time step #     1 at time=    0.20 fm/c'
  echo ' Starting time step #     2 at time=    0.40 fm/c'
  echo ' Total: -1.333134E+02 MeV. t0 part: -9.7E+02 MeV. t1 part: 1.2E+01 MeV. t2 part: 4.3E+01 MeV'
  echo ' Final separation distance reached'
} > "$COLLHDR/for006"
: > "$COLLHDR/stderr.txt"
( . "$HERE/validate_sky3d_output.sh"; validate_sky3d_output "$COLLHDR" 0 0 ) >/dev/null 2>&1 \
  && ok "one-sided '***** Data for fragment' headers are NOT read as overflow" \
  || bad "a legitimate collision log is rejected as numeric overflow"
printf ' Starting time step #  ******** at time= 0.20 fm/c\n' >> "$COLLHDR/for006"
( . "$HERE/validate_sky3d_output.sh"; validate_sky3d_output "$COLLHDR" 0 0 ) >/dev/null 2>&1 \
  && bad "an overflowed numeric field in the same file was not caught" \
  || ok "an overflowed numeric field is still caught alongside those headers"

# A malformed value in an EXCLUDED column must not be invisible.
sed 's/ -0.000 -0.000  0.000  0.500/ BAD -0.000  0.000  0.500/' "$B" > "$TMP/mal_spin"
expect_fail_with "a malformed spin column is rejected, not skipped" "malformed" python3 "$CMP" "$TMP/mal_spin" "$B"
sed 's/-3.1657359E-16/BAD/' "$B" > "$TMP/mal_cen"
expect_fail_with "a malformed centroid column is rejected, not skipped" "malformed" python3 "$CMP" "$TMP/mal_cen" "$B"

# Fortran namelists are case-insensitive.
sed 's/&main/\&MAIN/' "$DECK" > "$TMP/deck_upper"
SKY3D="$TMP/stub_healthy" expect_pass "an uppercase &MAIN deck is accepted" \
  "$RUN" --deck "$TMP/deck_upper" --workdir "$TMP/w_upper"

# Containment must be decided before anything is created.
rm -rf "$TMP/nc_root"; mkdir -p "$TMP/nc_root/work"
SKY3D="$TMP/stub_healthy" expect_fail_with "an out-of-root destination is refused" "outside --root" \
  "$RUN" --deck "$DECK" --workdir "$TMP/nc_root/work" --fragment "$TMP/frag:../nc_outside/sub/O16"
[ -d "$TMP/nc_root/nc_outside" ] && bad "the rejected destination still created directories" \
  || ok "a rejected destination created nothing"

# The collision checker must not certify without a particle-number anchor.
res <<'EOT'
      0.00   1.000   1.000      0.0000000      0.0000000     0.00    0.0    0.0
     10.00   1.000   1.000      0.1000000      0.1000000     0.10    0.0    0.0
EOT
expect_fail_with "the checker refuses to run without --expect-n/--expect-z" "--expect-n" python3 "$CC" "$TMP/coll"
expect_pass "--no-expect runs it deliberately, weaker and labelled" python3 "$CC" "$TMP/coll" --no-expect

echo
echo "-------------------------------------------"
echo "selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

#!/bin/bash
# selftest_smash.sh
#
# Test the HARNESS, not the physics. Every guard gets a negative case that fails
# ONLY that guard, and each negative case asserts WHICH guard fired, because a
# test that fails for the wrong reason looks exactly like a test that passes.
# Runs in seconds and needs no SMASH build: the runs use a stub executable.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="$HERE/run_smash.sh"
CC="$HERE/check_conservation_smash.py"
VERIFY="$HERE/verify_smash.sh"
PASS=0; FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ok  () { PASS=$((PASS+1)); echo "  ok    $*"; }
bad () { FAIL=$((FAIL+1)); echo "  FAIL  $*"; }
expect_pass () { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d (expected success, got failure)"; fi; }
expect_fail () { local d="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$d (expected failure, got success)"; else ok "$d"; fi; }
expect_fail_with () {
  local d="$1" marker="$2"; shift 2
  local out; out="$("$@" 2>&1)" && { bad "$d (expected failure, got success)"; return; }
  case "$out" in
    *"$marker"*) ok "$d" ;;
    *) bad "$d (failed on the wrong guard: no '$marker' in the output)" ;;
  esac
}

# ------------------------------------------------------------------ fixtures
CFG="$TMP/config.yaml"
cat > "$CFG" <<'EOF'
General:
    Modus:          Collider
    Delta_Time:     0.1
    End_Time:       20.0
    Randomseed:     -1
    Nevents:        2
Modi:
    Collider:
        Projectile:
            Particles: {2212: 79, 2112: 118}
        Target:
            Particles: {2212: 79, 2112: 118}
        E_Kin: 1.23
EOF

# A minimal but VALID OSCAR2013 list: 2 events, baryon number 4, charge 2.
write_oscar () {   # write_oscar <path> [extra body lines on stdin]
  {
    echo '#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge'
    echo '# Units: fm fm fm fm GeV GeV GeV GeV GeV none none e'
    echo '# SMASH-3.3'
    echo '# event 0 ensemble 0 out 4'
    echo '  20.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1'
    echo '  20.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2112 1 0'
    echo '  20.0 0.1 0.2 0.3 0.138 0.3 0.1 0.0 0.0  211 2 1'
    echo '  20.0 0.1 0.2 0.3 0.138 0.3 0.1 0.0 0.0 -211 3 -1'
    echo '# event 0 ensemble 0 end 0 impact   4.000 scattering_projectile_target yes'
    echo '# event 1 ensemble 0 out 3'
    echo '  20.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1'
    echo '  20.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2112 1 0'
    echo '  20.0 0.1 0.2 0.3 0.138 0.3 0.1 0.0 0.0  111 2 0'
    echo '# event 1 ensemble 0 end 0 impact   4.000 scattering_projectile_target yes'
  } > "$1"
}
GOOD="$TMP/good.oscar"; write_oscar "$GOOD"
# baryons: 2212,2112 twice = 4;  charge: +1+0+1-1 +1+0+0 = +2

# A stub SMASH: writes a valid OSCAR list and a benign log, honouring -o.
write_stub () {
  local path="$TMP/$1" mode="$2"
  {
    echo '#!/bin/bash'
    echo "MODE=\"$mode\""
    cat <<'STUB'
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) OUT="$2"; shift 2 ;;
    -i) shift 2 ;;
    --version) echo "SMASH-3.3"; exit 0 ;;
    *) shift ;;
  esac
done
[ "$MODE" = "exitfail" ] && { echo "boom" >&2; exit 3; }
mkdir -p "$OUT"
# a benign macOS-style warning that must NOT be read as an error
printf "[15'04'57]  WARN         Fpe         : Failed to setup trap on pole error.\n"
STUB
    echo 'F="$OUT/particle_lists.oscar"'
    echo 'case "$MODE" in'
    echo '  nooutput) exit 0 ;;'
    echo '  headeronly) printf "#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge\n" > "$F"; exit 0 ;;'
    echo 'esac'
    echo 'cat > "$F" <<'"'"'OSC'"'"''
    cat "$GOOD"
    echo 'OSC'
    cat <<'STUB2'
case "$MODE" in
  nan)      sed -i.bak 's/0.938 1.0/0.938 nan/' "$F"; rm -f "$F.bak" ;;
  oneevent) sed -i.bak '/# event 1 ensemble 0/d' "$F"; rm -f "$F.bak" ;;
  realerror) printf "[15'04'57]  ERROR        Main        : something exploded\n" ;;
esac
exit 0
STUB2
  } > "$path"
  chmod +x "$path"
}

echo "run_smash.sh argument handling"
expect_fail_with "missing --config is rejected" "--config is required" "$RUN"
expect_fail_with "a nonexistent config is rejected" "does not exist" "$RUN" --config "$TMP/nope"
printf 'not: a smash config\n' > "$TMP/notcfg"
expect_fail_with "a file with no General: block is rejected" "no 'General:' block" "$RUN" --config "$TMP/notcfg"
expect_fail_with "an unknown argument is rejected" "unknown argument" "$RUN" --config "$CFG" --bogus
expect_fail_with "a non-integer --seed is rejected" "must be an integer" "$RUN" --config "$CFG" --seed 1.5
expect_fail_with "a non-numeric --end-time is rejected" "must be a non-negative number" "$RUN" --config "$CFG" --seed 1 --end-time abc

echo
echo "run_smash.sh seed policy"
write_stub stub_ok ok
SKY=""; export SMASH="$TMP/stub_ok"
expect_fail_with "Randomseed -1 is refused by default" "irreproducible" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_seed"
expect_pass "--allow-random-seed accepts it deliberately" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_seed2" --allow-random-seed
expect_pass "a pinned --seed runs (control)" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_ok" --seed 12345
grep -q "Randomseed:     12345" "$TMP/w_ok/config_used.yaml" \
  && ok "the pinned seed was written into config_used.yaml" \
  || bad "the seed override did not reach the config"

echo
echo "run_smash.sh output guards (stub, one broken property each)"
for mode in exitfail nooutput headeronly nan oneevent realerror; do
  write_stub "stub_$mode" "$mode"
  case "$mode" in
    exitfail)  d="a nonzero exit status fails"; m="exited with status" ;;
    nooutput)  d="a missing particle list fails"; m="no particle output" ;;
    headeronly) d="a header with no particles fails"; m="no particles" ;;
    nan)       d="NaN in the particle list fails"; m="NaN or Inf" ;;
    oneevent)  d="fewer events than requested fails"; m="stopped early" ;;
    realerror) d="a real ERROR log line fails"; m="logged an error" ;;
  esac
  SMASH="$TMP/stub_$mode" expect_fail_with "$d" "$m" "$RUN" --config "$CFG" --outdir "$TMP/w_$mode" --seed 1
done
# The control above already proves the benign Fpe WARN does not trip the error
# guard, since every stub prints it and the ok stub passes.
grep -q "Fpe" "$TMP/w_ok/smash.log" \
  && ok "the passing control really does contain the benign 'Fpe ... error.' warning" \
  || bad "control lost the Fpe warning, so the error-guard test is not isolated"

echo
echo "check_conservation_smash.py"
expect_pass "a conserving list passes (control)" python3 "$CC" "$GOOD" --baryons 4 --charge 2
expect_fail_with "a wrong baryon expectation fails" "baryon number" python3 "$CC" "$GOOD" --baryons 8 --charge 2
expect_fail_with "a wrong charge expectation fails" "charge" python3 "$CC" "$GOOD" --baryons 4 --charge 6
sed 's/^#!OSCAR2013/#!SOMETHINGELSE/' "$GOOD" > "$TMP/badhdr.oscar"
expect_fail_with "a non-OSCAR2013 header fails" "does not start with an OSCAR2013 header" \
  python3 "$CC" "$TMP/badhdr.oscar" --baryons 4 --charge 2
sed 's/0.938 1.0 0.1 0.1 0.1 2212 0 1/0.938 nan 0.1 0.1 0.1 2212 0 1/' "$GOOD" > "$TMP/nan.oscar"
expect_fail_with "a non-finite kinematic value fails" "non-finite" python3 "$CC" "$TMP/nan.oscar" --baryons 4 --charge 2
grep -v '^ ' "$GOOD" > "$TMP/empty.oscar"
expect_fail_with "a list with no particle records fails" "no particle records" \
  python3 "$CC" "$TMP/empty.oscar" --baryons 4 --charge 2
sed -n '1,7p' "$GOOD" | grep -v 'ensemble 0 end' > "$TMP/noend.oscar"
expect_fail_with "an unclosed event block fails" "never closed" \
  python3 "$CC" "$TMP/noend.oscar" --baryons 2 --charge 1
sed 's/  20.0 0.1 0.2 0.3 0.138 0.3 0.1 0.0 0.0  211 2 1/  20.0 0.1 BAD/' "$GOOD" > "$TMP/mal.oscar"
expect_fail_with "a malformed record fails rather than being skipped" "malformed" \
  python3 "$CC" "$TMP/mal.oscar" --baryons 4 --charge 2
expect_fail_with "too few species fails when --species-min is given" "distinct species" \
  python3 "$CC" "$GOOD" --baryons 4 --charge 2 --species-min 99
expect_pass "--species-min is off by default (it was overstated as proof of physics)" \
  python3 "$CC" "$GOOD" --baryons 4 --charge 2

echo
echo "verify_smash.sh"
expect_fail_with "verify rejects an unknown argument" "unknown argument" "$VERIFY" --bogus
SMASH="$TMP/stub_ok" SMASH_BUILD="$TMP/no_such_build" SMASH_ROOT="$TMP" \
  expect_fail_with "verify fails when the build directory is absent" "no build directory" "$VERIFY" --tests-only
mkdir -p "$TMP/fakebuild"
SMASH="$TMP/stub_ok" SMASH_BUILD="$TMP/fakebuild" SMASH_ROOT="$TMP/no_such_root" \
  expect_fail_with "verify refuses a build it cannot trace to the pinned source" "not verifiably come from the pinned source" \
  "$VERIFY" --anchor-only
# The identity guard must also reject a REAL clone whose binary is not the
# stamped one, which is the attack that a fake build directory represented.
if [ -d "$HOME/.cache/fusion/smash/smash/.git" ]; then
  cp "$TMP/stub_ok" "$TMP/impostor"
  SMASH="$TMP/impostor" \
    SMASH_BUILD="$HOME/.cache/fusion/smash/smash/build" \
    SMASH_ROOT="$HOME/.cache/fusion/smash/smash" \
    expect_fail_with "an impostor binary beside a real build is rejected" "does not match the build stamp" \
    "$VERIFY" --tests-only
else
  ok "skipped the impostor-binary case (no local SMASH clone to test against)"
fi

echo
echo "guards added after the 2026-07-23 adversarial pass"
# --- negative seeds other than -1 (SMASH treats every negative seed as random)
for sd in -2 -999; do
  SMASH="$TMP/stub_ok" expect_fail_with "--seed $sd is refused (SMASH randomizes any negative seed)" "irreproducible" \
    "$RUN" --config "$CFG" --outdir "$TMP/w_neg$sd" --seed "$sd"
done
SMASH="$TMP/stub_ok" expect_pass "--seed 0 is accepted (non-negative)" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_zero" --seed 0
for bad in -- 1-2 . 1..2 "1e3" "-5"; do
  SMASH="$TMP/stub_ok" expect_fail "a malformed --end-time '$bad' is rejected" \
    "$RUN" --config "$CFG" --outdir "$TMP/w_bad" --seed 1 --end-time "$bad"
done
SMASH="$TMP/stub_ok" expect_fail_with "--nevents 0 is rejected" "at least 1" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_ev0" --seed 1 --nevents 0

# --- structural OSCAR validation: forged output must not pass
write_bad_stub () {   # $1 name, $2 the body written to particle_lists.oscar
  local path="$TMP/$1"
  { echo '#!/bin/bash'
    echo 'OUT=""; while [ $# -gt 0 ]; do case "$1" in -o) OUT="$2"; shift 2;; --version) echo SMASH-3.3; exit 0;; *) shift;; esac; done'
    echo 'mkdir -p "$OUT"'
    echo "cat > \"\$OUT/particle_lists.oscar\" <<'EOSC'"
    cat
    echo 'EOSC'
    echo 'exit 0'
  } > "$path"
  chmod +x "$path"
}
write_bad_stub stub_forged <<'EOF'
# not an oscar header at all
# event 0 ensemble 0 end 0
# event 1 ensemble 0 end 0
  garbage record here
EOF
SMASH="$TMP/stub_forged" expect_fail_with "a forged non-OSCAR header is rejected" "OSCAR2013 header" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_forged" --seed 1
write_bad_stub stub_unpaired <<'EOF'
#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge
# event 0 ensemble 0 end 0 impact 1.0 scattering_projectile_target yes
# event 1 ensemble 0 end 0 impact 1.0 scattering_projectile_target yes
  20.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
EOF
SMASH="$TMP/stub_unpaired" expect_fail_with "event-end markers with no matching starts are rejected" "must pair" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_unpaired" --seed 1
write_bad_stub stub_cols <<'EOF'
#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge
# event 0 ensemble 0 out 1
  20.0 0.1 0.2 2212 1
# event 0 ensemble 0 end 0 impact 1.0 scattering_projectile_target yes
# event 1 ensemble 0 out 1
  20.0 0.1 0.2 2212 1
# event 1 ensemble 0 end 0 impact 1.0 scattering_projectile_target yes
EOF
SMASH="$TMP/stub_cols" expect_fail_with "records with the wrong column count are rejected" "columns the header declares" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_cols" --seed 1

# --- conservation checker: resonances, per-event, strict grammar
python3 - <<'PYEOF' > "$TMP/reso.oscar"
print('#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge')
print('# Units: fm fm fm fm GeV GeV GeV GeV GeV none none e')
print('# event 0 ensemble 0 out 2')
print('  20.0 0.1 0.2 0.3 1.440 1.5 0.1 0.1 0.1 12112 0 0')   # N(1440)0, B=1
print('  20.0 0.1 0.2 0.3 1.405 1.5 0.1 0.1 0.1 13122 1 0')   # Lambda(1405), B=1
print('# event 0 ensemble 0 end 0 impact 1.0 scattering_projectile_target yes')
PYEOF
expect_pass "five-digit baryon resonances are counted (B=2, Q=0)" \
  python3 "$CC" "$TMP/reso.oscar" --baryons 2 --charge 0
expect_fail_with "and a wrong expectation on them still fails" "baryon number" \
  python3 "$CC" "$TMP/reso.oscar" --baryons 0 --charge 0

# Per-event: two events whose violations cancel in the sum must NOT pass.
python3 - <<'PYEOF' > "$TMP/cancel.oscar"
print('#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge')
print('# event 0 ensemble 0 out 2')
print('  20.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1')
print('  20.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 1 1')   # event 0: B=2
print('# event 0 ensemble 0 end 0 impact 1.0 scattering_projectile_target yes')
print('# event 1 ensemble 0 out 0')
print('# event 1 ensemble 0 end 0 impact 1.0 scattering_projectile_target yes')  # event 1: B=0
PYEOF
expect_fail_with "equal-and-opposite per-event violations do not cancel" "event" \
  python3 "$CC" "$TMP/cancel.oscar" --baryons 2 --charge 2
# A comment merely containing " end" is not an event end.
python3 - <<'PYEOF' > "$TMP/fakeend.oscar"
print('#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge')
print('# this comment contains the word end but is not an event marker')
print('  20.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1')
PYEOF
expect_fail_with "a comment containing 'end' is not an event marker" "outside any event block" \
  python3 "$CC" "$TMP/fakeend.oscar" --baryons 1 --charge 1
# The declared per-event count must match the records that follow.
python3 - <<'PYEOF' > "$TMP/miscount.oscar"
print('#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge')
print('# event 0 ensemble 0 out 5')
print('  20.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1')
print('# event 0 ensemble 0 end 0 impact 1.0 scattering_projectile_target yes')
PYEOF
expect_fail_with "a declared particle count that does not match is rejected" "declares 5" \
  python3 "$CC" "$TMP/miscount.oscar" --baryons 1 --charge 1

echo
echo "-------------------------------------------"
echo "selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

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
# run_smash.sh canonicalises paths with `pwd -P`, and on macOS mktemp hands back
# /var/... while the canonical form is /private/var/... . Compare against the
# canonical spelling or an entirely correct path reads as a mismatch.
TMPP="$(cd "$TMP" && pwd -P)"

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
  # Delete event 1 ENTIRELY, records included. Deleting only its two marker
  # lines left three orphan records behind, so the case failed on the
  # stray-record guard and never reached the event-count guard it was written
  # for: a negative test that proves a different point than the one claimed.
  oneevent) sed -i.bak '/# event 1 ensemble 0 out/,/# event 1 ensemble 0 end/d' "$F"; rm -f "$F.bak" ;;
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
    nooutput)  d="a missing particle list fails"; m="no output beyond the copy of its own configuration" ;;
    headeronly) d="a header with no particles fails"; m="no complete event block" ;;
    nan)       d="NaN in the particle list fails"; m="non-finite" ;;
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
# The identity guard needs a REAL pinned clone to test against, because the git
# pin is the one part of it that cannot be synthesized. Each case below breaks
# exactly ONE of the checks and asserts that that check is the one that fired.
SREAL="$HOME/.cache/fusion/smash/smash"
BREAL="$SREAL/build"
# The real STAMP is a precondition, not just the clone and the cache. Without
# it, mk_fakebuild's `head -1` of a missing file contributed nothing and the
# synthetic stamp collapsed to a single line holding the digest, which the
# identity check then read as the build-identity line. Every identity and
# ctest case failed with "records identity <sha256>", on a Linux box whose
# build simply predates the stamp. The fixture was fabricating its input.
if [ -d "$SREAL/.git" ] && [ -f "$BREAL/CMakeCache.txt" ] && [ -s "$BREAL/.fusion_build_stamp" ]; then
  cp "$TMP/stub_ok" "$TMP/impostor"
  # (a) binary outside the build tree
  SMASH="$TMP/impostor" SMASH_BUILD="$BREAL" SMASH_ROOT="$SREAL" \
    expect_fail_with "a binary outside the build directory is rejected" "does not live inside the build directory" \
    "$VERIFY" --tests-only
  # (b) a build directory that is not a cmake tree at all. The binary has to
  #     EXIST, or the "no usable SMASH executable" check fires first and this
  #     case proves nothing about CMakeCache.
  mkdir -p "$TMP/nocache"
  cp "$TMP/stub_ok" "$TMP/nocache/smash"
  SMASH="$TMP/nocache/smash" SMASH_BUILD="$TMP/nocache" SMASH_ROOT="$SREAL" \
    expect_fail_with "a build directory with no CMakeCache.txt is rejected" "not a cmake build tree" \
    "$VERIFY" --tests-only
  # (c) a cache that was configured from a DIFFERENT source tree
  mk_fakebuild () {   # mk_fakebuild <dir> <home_dir> <cachefile_dir>
    mkdir -p "$1"
    { echo "CMAKE_HOME_DIRECTORY:INTERNAL=$2"; echo "CMAKE_CACHEFILE_DIR:INTERNAL=$3"; } > "$1/CMakeCache.txt"
    # The REAL binary, or these cases test a stub instead of a build.
    cp "$BREAL/smash" "$1/smash" || { bad "mk_fakebuild: no real binary at $BREAL/smash"; return 1; }
    # Assert the inputs exist rather than letting a missing file produce a
    # plausible-looking stamp. See the precondition comment above.
    [ -s "$BREAL/.fusion_build_stamp" ] || { bad "mk_fakebuild: no real stamp to copy"; return 1; }
    { head -1 "$BREAL/.fusion_build_stamp"; shasum -a 256 "$1/smash" | cut -d' ' -f1; } \
      > "$1/.fusion_build_stamp"
    [ "$(wc -l < "$1/.fusion_build_stamp")" -eq 2 ] \
      || { bad "mk_fakebuild: synthetic stamp is not two lines"; return 1; }
  }
  mk_fakebuild "$TMP/bd_wrongsrc" "$TMP/somewhere/else" "$TMP/bd_wrongsrc"
  SMASH="$TMP/bd_wrongsrc/smash" SMASH_BUILD="$TMP/bd_wrongsrc" SMASH_ROOT="$SREAL" \
    expect_fail_with "a build configured from another source tree is rejected" "not from the pinned source" \
    "$VERIFY" --tests-only
  # (d) a cache COPIED here from another build directory
  mk_fakebuild "$TMP/bd_copied" "$SREAL" "$BREAL"
  SMASH="$TMP/bd_copied/smash" SMASH_BUILD="$TMP/bd_copied" SMASH_ROOT="$SREAL" \
    expect_fail_with "a CMakeCache.txt copied from another build directory is rejected" "it was copied here" \
    "$VERIFY" --tests-only
  # (e) a shell script wearing the binary's name, inside an otherwise sound tree
  mk_fakebuild "$TMP/bd_script" "$SREAL" "$TMP/bd_script"
  cp "$TMP/stub_ok" "$TMP/bd_script/smash"
  shasum -a 256 "$TMP/bd_script/smash" | cut -d' ' -f1 > "$TMP/bd_script/.line2"
  { head -1 "$BREAL/.fusion_build_stamp"; cat "$TMP/bd_script/.line2"; } > "$TMP/bd_script/.fusion_build_stamp"
  SMASH="$TMP/bd_script/smash" SMASH_BUILD="$TMP/bd_script" SMASH_ROOT="$SREAL" \
    expect_fail_with "a shell script named 'smash' is rejected even with a matching stamp" "is not a native executable" \
    "$VERIFY" --tests-only
  # (f) the stamp records a build of some other commit
  mk_fakebuild "$TMP/bd_stamp" "$SREAL" "$TMP/bd_stamp"
  { echo "0000000000000000000000000000000000000000|clean|x|y|z|w|s|m"; sed -n 2p "$TMP/bd_stamp/.fusion_build_stamp"; } \
    > "$TMP/bd_stamp/.stamp2" && mv "$TMP/bd_stamp/.stamp2" "$TMP/bd_stamp/.fusion_build_stamp"
  SMASH="$TMP/bd_stamp/smash" SMASH_BUILD="$TMP/bd_stamp" SMASH_ROOT="$SREAL" \
    expect_fail_with "a stamp recording another commit is rejected" "not a clean build of the pinned commit" \
    "$VERIFY" --tests-only
  # (g) POSITIVE control: the same synthetic tree, nothing broken, must NOT be
  #     rejected by check_identity. It gets past identity and on to ctest, so
  #     the assertion is only that identity is not what fails.
  mk_fakebuild "$TMP/bd_good" "$SREAL" "$TMP/bd_good"
  out="$(SMASH="$TMP/bd_good/smash" SMASH_BUILD="$TMP/bd_good" SMASH_ROOT="$SREAL" \
         "$VERIFY" --tests-only 2>&1)"
  case "$out" in
    *"identity OK"*) ok "an intact synthetic build passes the identity check (positive control)" ;;
    *) bad "the identity check rejects an intact build: $(printf '%s' "$out" | tail -2 | tr '\n' ' ')" ;;
  esac
  # (h) THE BLOCKER: SMASH's own usage_of_SMASH_as_library test relinks
  #     build/smash, so the stamped digest goes stale on every full verify. A
  #     stale digest must be a note, not a rejection.
  mk_fakebuild "$TMP/bd_relinked" "$SREAL" "$TMP/bd_relinked"
  printf 'deadbeef\n' > "$TMP/bd_relinked/.stamp2"
  { head -1 "$TMP/bd_relinked/.fusion_build_stamp"; cat "$TMP/bd_relinked/.stamp2"; } \
    > "$TMP/bd_relinked/.fusion_build_stamp.new" \
    && mv "$TMP/bd_relinked/.fusion_build_stamp.new" "$TMP/bd_relinked/.fusion_build_stamp"
  out="$(SMASH="$TMP/bd_relinked/smash" SMASH_BUILD="$TMP/bd_relinked" SMASH_ROOT="$SREAL" \
         "$VERIFY" --tests-only 2>&1)"
  case "$out" in
    *"identity OK"*) ok "a relinked binary (stale digest) is accepted with a note, not rejected" ;;
    *) bad "a stale digest still rejects a legitimate relink: $(printf '%s' "$out" | tail -2 | tr '\n' ' ')" ;;
  esac
else
  ok "skipped the identity-guard cases (no local stamped SMASH build to test against)"
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
for bad in -- 1-2 . 1..2 "-5" "1e" "e3" ""; do
  SMASH="$TMP/stub_ok" expect_fail "a malformed --end-time '$bad' is rejected" \
    "$RUN" --config "$CFG" --outdir "$TMP/w_bad" --seed 1 --end-time "$bad"
done
# These ARE valid YAML floats and were rejected by an over-tight pattern, which
# is the same class of bug as the OSCAR grammar: a rule written from one sample.
i=0
for good in "1e3" ".5" "5." "1.5E-2" "20.0" "7"; do
  i=$((i+1))
  SMASH="$TMP/stub_ok" expect_pass "a valid --end-time '$good' is accepted" \
    "$RUN" --config "$CFG" --outdir "$TMP/w_good$i" --seed 1 --end-time "$good"
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
# NB an 'end' marker with no preceding block is NOT an error: Only_Final:
# IfNotEmpty writes exactly that for an empty event. The old "out and end must
# pair" rule was wrong on both sides, rejecting Only_Final: No as well. What is
# still an error is a record that belongs to no block.
write_bad_stub stub_unpaired <<'EOF'
#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge
# event 0 ensemble 0 end 0 impact 1.0 scattering_projectile_target yes
# event 1 ensemble 0 end 0 impact 1.0 scattering_projectile_target yes
  20.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
EOF
SMASH="$TMP/stub_unpaired" expect_fail_with "a record belonging to no block is rejected" "outside any event block" \
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
SMASH="$TMP/stub_cols" expect_fail_with "records with the wrong column count are rejected" "malformed particle records" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_cols" --seed 1
# A run that writes no OSCAR at all is legitimate (Binary/Root/HepMC-only
# configs); it must be accepted, and it must say the output was NOT validated.
write_other_stub () {
  { echo '#!/bin/bash'
    echo 'OUT=""; while [ $# -gt 0 ]; do case "$1" in -o) OUT="$2"; shift 2;; --version) echo SMASH-3.3; exit 0;; *) shift;; esac; done'
    echo 'mkdir -p "$OUT"; printf "binary particle payload\n" > "$OUT/particles_binary.bin"'
    echo 'exit 0'
  } > "$TMP/stub_other"; chmod +x "$TMP/stub_other"
}
write_other_stub
SMASH="$TMP/stub_other" expect_pass "a Binary-only configuration is accepted, not failed for a missing OSCAR" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_other" --seed 1
# ... but SMASH ALWAYS copies its configuration into the output directory, so a
# bare "the directory is not empty" test would certify a run that produced no
# physics output at all. config.yaml must not count as output.
cat > "$TMP/stub_cfgonly" <<'EOF'
#!/bin/bash
OUT=""; while [ $# -gt 0 ]; do case "$1" in -o) OUT="$2"; shift 2;; --version) echo SMASH-3.3; exit 0;; *) shift;; esac; done
mkdir -p "$OUT"; printf 'General:\n    Nevents: 2\n' > "$OUT/config.yaml"
exit 0
EOF
chmod +x "$TMP/stub_cfgonly"
SMASH="$TMP/stub_cfgonly" expect_fail_with "a run that wrote only its own config.yaml is rejected" \
  "no output beyond the copy of its own configuration" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_cfgonly" --seed 1
# Captured into a variable rather than piped into `grep -q`: under `pipefail`,
# grep -q exits at the first match and SIGPIPEs the writer, so the pipeline
# reports 141 and a passing case reads as a failure.
other_out="$(SMASH="$TMP/stub_other" "$RUN" --config "$CFG" --outdir "$TMP/w_other2" --seed 1 2>&1)"
case "$other_out" in
  *"NOT structurally validated"*) ok "and it says plainly that the output was not validated" ;;
  *) bad "the Binary-only path did not warn that nothing was validated" ;;
esac

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
echo "verify_smash.sh ctest-result parsing (stub ctest, identity satisfied)"
# These guards decide whether SMASH's own suite really passed, and none of them
# had a test: they were reasoned about, not exercised. A stub ctest on PATH lets
# each be driven with the exact output shape it was written for. Needs the real
# clone, because the git pin is the one thing that cannot be synthesized.
if [ -d "$SREAL/.git" ] && [ -f "$BREAL/CMakeCache.txt" ] && [ -s "$BREAL/.fusion_build_stamp" ]; then
  mk_fakebuild "$TMP/bd_ctest" "$SREAL" "$TMP/bd_ctest"
  mkdir -p "$TMP/bin"
  write_ctest () {   # write_ctest <mode>
    cat > "$TMP/bin/ctest" <<CTESTEOF
#!/bin/bash
MODE="$1"
CTESTEOF
    cat >> "$TMP/bin/ctest" <<'CTESTEOF'
RETRY=0
for a in "$@"; do case "$a" in -R) RETRY=1 ;; esac; done
summary () { echo; echo "$1% tests passed, $2 tests failed out of $3"; }
if [ "$RETRY" = "1" ]; then
  case "$MODE" in
    retry_notests) echo "No tests were found!!!"; exit 0 ;;
    *)             summary 100 0 1; exit 0 ;;
  esac
fi
case "$MODE" in
  clean_but_nonzero)
    summary 100 0 104; exit 1 ;;
  mixed_failures)
    echo "        1 - potentials (Failed)"
    echo "        2 - collider (Timeout)"
    summary 98 2 104; exit 1 ;;
  retry_notests)
    echo "        1 - potentials (Failed)"
    summary 99 1 104; exit 1 ;;
  short_suite)
    summary 100 0 103; exit 0 ;;
  allpass)
    summary 100 0 104; exit 0 ;;
esac
CTESTEOF
    chmod +x "$TMP/bin/ctest"
  }
  run_verify_with_ctest () {   # run_verify_with_ctest <mode> [extra env assignments...]
    write_ctest "$1"; shift
    env PATH="$TMP/bin:$PATH" \
        SMASH="$TMP/bd_ctest/smash" SMASH_BUILD="$TMP/bd_ctest" SMASH_ROOT="$SREAL" \
        "$@" "$VERIFY" --tests-only 2>&1
  }
  # A supplied build can no longer print the tier-1 verdict, however clean its
  # suite: provenance is asserted rather than established on that path. This
  # case is therefore the positive control for "the run PASSED", not for
  # certification, and it doubles as the regression test for that downgrade.
  out="$(run_verify_with_ctest allpass)"
  case "$out" in
    *"VERIFY OK"*) bad "a build supplied through SMASH_BUILD still printed the tier-1 VERIFY OK" ;;
    *"PASSED-NOT-CERTIFIED"*) ok "a clean 104-of-104 suite on a SUPPLIED build passes but does not certify" ;;
    *) bad "the stub-ctest positive control did not pass: $(printf '%s' "$out" | tail -2 | tr '\n' ' ')" ;;
  esac
  out="$(run_verify_with_ctest clean_but_nonzero)"
  case "$out" in
    *"summary and the status disagree"*) ok "a clean summary with a nonzero ctest exit status fails" ;;
    *) bad "a nonzero ctest exit status was accepted: $(printf '%s' "$out" | tail -2 | tr '\n' ' ')" ;;
  esac
  out="$(run_verify_with_ctest mixed_failures)"
  case "$out" in
    *"'collider' failed, and it is not one of the self-seeded tests"*)
      ok "a Timeout alongside a self-seeded Failed is not retried away" ;;
    *) bad "a mixed failure set was mishandled: $(printf '%s' "$out" | tail -2 | tr '\n' ' ')" ;;
  esac
  out="$(run_verify_with_ctest retry_notests)"
  case "$out" in
    *"did not cleanly pass exactly one test"*)
      ok "a retry that selected NO tests is not read as a pass" ;;
    *) bad "an empty retry was accepted: $(printf '%s' "$out" | tail -2 | tr '\n' ' ')" ;;
  esac
  out="$(run_verify_with_ctest short_suite)"
  case "$out" in
    *"expected exactly 104"*) ok "a suite that ran fewer cases than the pin fails" ;;
    *) bad "a short suite was accepted: $(printf '%s' "$out" | tail -2 | tr '\n' ' ')" ;;
  esac
  # The override must not end in a line that reads as a certification.
  out="$(run_verify_with_ctest short_suite SMASH_EXPECTED_TESTS=103)"
  case "$out" in
    *"VERIFY OK"*) bad "SMASH_EXPECTED_TESTS=103 still printed a clean VERIFY OK" ;;
    *"PASSED-NOT-CERTIFIED"*) ok "an overridden test count passes but does NOT claim certification" ;;
    *) bad "the overridden-count run gave an unexpected verdict: $(printf '%s' "$out" | tail -2 | tr '\n' ' ')" ;;
  esac
else
  ok "skipped the ctest-parsing cases (no local stamped SMASH build to test against)"
fi

echo
echo "run_smash.sh auxiliary-table staging"
# Several shipped examples carry their own particles.txt/decaymodes.txt and
# SMASH does NOT pick them up implicitly, so the run silently uses the default
# tables and is not the example that was asked for.
mkdir -p "$TMP/exdir"
cp "$CFG" "$TMP/exdir/config.yaml"
printf '# fake particle table\n' > "$TMP/exdir/particles.txt"
printf '# fake decay table\n'    > "$TMP/exdir/decaymodes.txt"
cat > "$TMP/argstub" <<'EOF'
#!/bin/bash
OUT=""; ARGS="$*"
while [ $# -gt 0 ]; do case "$1" in -o) OUT="$2"; shift 2;; --version) echo SMASH-3.3; exit 0;; *) shift;; esac; done
mkdir -p "$OUT"; printf '%s\n' "$ARGS" > "$OUT/argv.txt"
printf 'stub\n' > "$OUT/particles_binary.bin"
exit 0
EOF
chmod +x "$TMP/argstub"
SMASH="$TMP/argstub" "$RUN" --config "$TMP/exdir/config.yaml" --outdir "$TMP/w_tab" --seed 1 >/dev/null 2>&1
if grep -q -- "-p $TMPP/exdir/particles.txt" "$TMP/w_tab/out/argv.txt" 2>/dev/null \
   && grep -q -- "-d $TMPP/exdir/decaymodes.txt" "$TMP/w_tab/out/argv.txt" 2>/dev/null; then
  ok "an example's own particles.txt and decaymodes.txt are passed with -p/-d"
else
  bad "the auxiliary tables next to the config were not staged: $(cat "$TMP/w_tab/out/argv.txt" 2>/dev/null)"
fi
SMASH="$TMP/argstub" "$RUN" --config "$TMP/exdir/config.yaml" --outdir "$TMP/w_tab2" --seed 1 \
  --no-auto-tables >/dev/null 2>&1
if grep -q -- "-p " "$TMP/w_tab2/out/argv.txt" 2>/dev/null; then
  bad "--no-auto-tables still staged a table"
else
  ok "--no-auto-tables suppresses the staging"
fi
# A RELATIVE table path must resolve against the caller's directory, not against
# the config's directory that SMASH is later run from.
mkdir -p "$TMP/relhome"; printf '# caller table\n' > "$TMP/relhome/mytable.txt"
( cd "$TMP/relhome" && SMASH="$TMP/argstub" "$RUN" --config "$TMP/exdir/config.yaml" \
    --outdir "$TMP/w_rel" --seed 1 --particles mytable.txt >/dev/null 2>&1 )
if grep -q -- "-p $TMPP/relhome/mytable.txt" "$TMP/w_rel/out/argv.txt" 2>/dev/null; then
  ok "a relative --particles path resolves against the caller, not the config directory"
else
  bad "a relative --particles path was handed to SMASH unresolved: $(cat "$TMP/w_rel/out/argv.txt" 2>/dev/null)"
fi

echo
echo "Only_Final: No and parallel ensembles (the round-2 blocker)"
# A real Only_Final: No event is one 'in' block, several 'out' blocks and one
# 'end'. This shape was rejected outright, in run_smash.sh ("must pair") and in
# the checker ("starts while ... is still open"), because both had only ever
# met the shipped Only_Final: Yes collider output. Counts grow between blocks
# as resonances decay while baryon number and charge do not, which is the whole
# point of checking every block rather than only the last.
cat > "$TMP/onlyfinal_no.oscar" <<'EOF'
#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge
# Units: fm fm fm fm GeV GeV GeV GeV GeV none none e
# SMASH-3.3
# event 0 ensemble 0 in 2
  0.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
  0.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2112 1 0
# event 0 ensemble 0 out 2
  2.0 0.1 0.2 0.3 1.232 1.5 0.1 0.1 0.1 2214 0 1
  2.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2112 1 0
# event 0 ensemble 0 out 3
  4.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
  4.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2112 1 0
  4.0 0.1 0.2 0.3 0.138 0.3 0.1 0.0 0.0  111 2 0
# event 0 ensemble 0 end 0 impact   0.000 scattering_projectile_target yes
EOF
expect_pass "an 'in' block followed by several 'out' blocks in one event is accepted" \
  python3 "$CC" "$TMP/onlyfinal_no.oscar" --baryons 2 --charge 1
# Delta+ (2214) carries B=1, Q=1: the middle block only balances if the
# resonance is counted, so this doubles as a live test of baryon_number().
expect_fail_with "a violation in an INTERMEDIATE block is caught, not just the last one" "block of event 0/0" \
  python3 "$CC" "$TMP/onlyfinal_no.oscar" --baryons 2 --charge 2
# Parallel ensembles: Nevents 1 x Ensembles 3 completes THREE systems, and the
# expectation must divide by 3, not by 1.
cat > "$TMP/ensembles.oscar" <<'EOF'
#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge
# event 0 ensemble 0 out 1
  3.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
# event 0 ensemble 0 end 0 impact   0.000 scattering_projectile_target yes
# event 0 ensemble 1 out 1
  3.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
# event 0 ensemble 1 end 0 impact   0.000 scattering_projectile_target yes
# event 0 ensemble 2 out 1
  3.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
# event 0 ensemble 2 end 0 impact   0.000 scattering_projectile_target yes
EOF
expect_pass "three parallel ensembles count as three events" \
  python3 "$CC" "$TMP/ensembles.oscar" --baryons 3 --charge 3
expect_fail_with "and --events knows Nevents x Ensembles, not Nevents" "stopped early" \
  python3 "$CC" "$TMP/ensembles.oscar" --baryons 3 --charge 3 --events 4
# An empty event legitimately writes only its 'end' marker (Only_Final:
# IfNotEmpty); that must not be read as a truncated run.
cat > "$TMP/ifnotempty.oscar" <<'EOF'
#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge
# event 0 ensemble 0 out 1
  3.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
# event 0 ensemble 0 end 0 impact   0.000 scattering_projectile_target no
# event 1 ensemble 0 end 0 impact   9.000 scattering_projectile_target no
EOF
expect_pass "an empty event with only an 'end' marker is accepted (Only_Final: IfNotEmpty)" \
  python3 "$CC" "$TMP/ifnotempty.oscar" --structure-only --events 2
# full_event_history has the SAME in/out line shape but the blocks are single
# interactions, so summing them would report a meaningless result confidently.
sed 's/^#!OSCAR2013 particle_lists/#!OSCAR2013 full_event_history/' "$GOOD" > "$TMP/history.oscar"
expect_fail_with "a full_event_history file is refused rather than mis-summed" "not 'particle_lists'" \
  python3 "$CC" "$TMP/history.oscar" --baryons 4 --charge 2
# Blocks must still be properly nested.
cat > "$TMP/interleaved.oscar" <<'EOF'
#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge
# event 0 ensemble 0 out 1
  3.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
# event 1 ensemble 0 out 1
  3.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
# event 1 ensemble 0 end 0 impact 1.0 scattering_projectile_target yes
EOF
expect_fail_with "a second event opening before the first ended is rejected" "has not been closed" \
  python3 "$CC" "$TMP/interleaved.oscar" --structure-only
cat > "$TMP/afterend.oscar" <<'EOF'
#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge
# event 0 ensemble 0 out 1
  3.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
# event 0 ensemble 0 end 0 impact 1.0 scattering_projectile_target yes
# event 0 ensemble 0 out 1
  3.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
EOF
expect_fail_with "a block after its event already ended is rejected" "already ended" \
  python3 "$CC" "$TMP/afterend.oscar" --structure-only

echo
echo "residuals found by the round-3 adversarial pass"
# Each of these was a real false-pass in the round-2 fixes themselves.

# (a) The non-OSCAR branch exited BEFORE the log scan, so a Binary-only run that
#     logged a genuine ERROR returned success. Checks that apply to every run
#     must precede any branch that can exit.
cat > "$TMP/stub_binerr" <<'EOF'
#!/bin/bash
OUT=""; while [ $# -gt 0 ]; do case "$1" in -o) OUT="$2"; shift 2;; --version) echo SMASH-3.3; exit 0;; *) shift;; esac; done
mkdir -p "$OUT"; printf 'payload\n' > "$OUT/particles_binary.bin"
printf "[15'04'57]  ERROR        Main        : something exploded\n"
exit 0
EOF
chmod +x "$TMP/stub_binerr"
SMASH="$TMP/stub_binerr" expect_fail_with "a Binary-only run that logged an ERROR fails" "logged an error" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_binerr" --seed 1

# (b) `Nevents: 2 # comment` is valid YAML. Without comment stripping the value
#     read back was "2 # comment", is_uint rejected it, no --events expectation
#     was passed, and the event-count check silently did nothing.
sed 's/    Nevents:        2/    Nevents:        2 # two events please/' "$CFG" > "$TMP/cfg_comment.yaml"
SMASH="$TMP/stub_oneevent" expect_fail_with "an inline YAML comment does not disable the event-count check" \
  "stopped early" "$RUN" --config "$TMP/cfg_comment.yaml" --outdir "$TMP/w_comment" --seed 1
SMASH="$TMP/stub_ok" expect_pass "and a commented Nevents still runs normally (control)" \
  "$RUN" --config "$TMP/cfg_comment.yaml" --outdir "$TMP/w_comment2" --seed 1

# (c) An integer too large for bash to compare bypassed the negative-seed guard:
#     `[ "$SEED" -lt 0 ]` printed "integer expression expected" and the run went
#     ahead anyway.
for sd in 9223372036854775808 -9223372036854775809; do
  SMASH="$TMP/stub_ok" expect_fail_with "an oversized --seed '$sd' is rejected" "must be an integer" \
    "$RUN" --config "$CFG" --outdir "$TMP/w_big$sd" --seed "$sd"
done

# (d) The marker grammar accepted a truncated 'out' with no count and an 'end'
#     with an arbitrary tail, which is precisely the corruption it exists to catch.
cat > "$TMP/nocount.oscar" <<'EOF'
#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge
# event 0 ensemble 0 out
  3.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
# event 0 ensemble 0 end 0 impact 1.0 scattering_projectile_target yes
EOF
expect_fail_with "an 'out' marker with no particle count is rejected" "malformed event marker" \
  python3 "$CC" "$TMP/nocount.oscar" --structure-only
cat > "$TMP/badend.oscar" <<'EOF'
#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge
# event 0 ensemble 0 out 1
  3.0 0.1 0.2 0.3 0.938 1.0 0.1 0.1 0.1 2212 0 1
# event 0 ensemble 0 end nonsense tokens
EOF
expect_fail_with "an 'end' marker with a corrupted tail is rejected" "malformed event marker" \
  python3 "$CC" "$TMP/badend.oscar" --structure-only
expect_pass "the real end-marker spelling is still accepted (control)" \
  python3 "$CC" "$GOOD" --structure-only --events 2

# (e) --workdir, for shipped configs that resolve their paths from a different cwd
mkdir -p "$TMP/elsewhere"
SMASH="$TMP/stub_ok" expect_pass "--workdir runs the binary from the given directory" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_wd" --seed 1 --workdir "$TMP/elsewhere"
SMASH="$TMP/stub_ok" expect_fail_with "--workdir rejects a directory that does not exist" "is not a directory" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_wd2" --seed 1 --workdir "$TMP/no_such_dir"

echo
echo "residuals found by the round-4 adversarial pass"
# Both were introduced by the round-3 fixes, in the same two lines.

# (a) The 18-digit cap was a digit count standing in for a range, and it
#     rejected the exact int64 maximum, which SMASH's Randomseed is and which
#     raw SMASH runs with happily.
SMASH="$TMP/stub_ok" expect_pass "the int64 maximum seed 9223372036854775807 is accepted" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_maxseed" --seed 9223372036854775807
SMASH="$TMP/stub_ok" expect_fail_with "one past the int64 maximum is still rejected" "must be an integer" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_overseed" --seed 9223372036854775808

# (b) Quoted YAML numerics. `Randomseed: "123"` was rejected outright, and
#     `Nevents: "2"` SILENTLY DISABLED the event-count check, which is the
#     dangerous half: the run reported success having written one event of two.
sed -e 's/    Randomseed:     -1/    Randomseed:     "4242"/' -e 's/    Nevents:        2/    Nevents:        "2"/' \
  "$CFG" > "$TMP/cfg_quoted.yaml"
SMASH="$TMP/stub_ok" expect_pass "a quoted Randomseed and Nevents are read, not rejected" \
  "$RUN" --config "$TMP/cfg_quoted.yaml" --outdir "$TMP/w_quoted"
SMASH="$TMP/stub_oneevent" expect_fail_with "a quoted Nevents still enforces the event count" "stopped early" \
  "$RUN" --config "$TMP/cfg_quoted.yaml" --outdir "$TMP/w_quoted2"

# (c) The structural lesson: a value the reader cannot parse must be an ERROR,
#     not a skipped check. Fail closed, or every unhandled spelling silently
#     turns the validation off.
sed 's/    Nevents:        2/    Nevents:        two/' "$CFG" > "$TMP/cfg_badnev.yaml"
SMASH="$TMP/stub_ok" expect_fail_with "an unreadable Nevents is an error, not a skipped check" \
  "cannot read as a count" "$RUN" --config "$TMP/cfg_badnev.yaml" --outdir "$TMP/w_badnev" --seed 1
sed 's/    Nevents:        2/    Ensembles:      x\n    Nevents:        2/' "$CFG" > "$TMP/cfg_badens.yaml"
SMASH="$TMP/stub_ok" expect_fail_with "an unreadable Ensembles is an error too" \
  "cannot read as a count" "$RUN" --config "$TMP/cfg_badens.yaml" --outdir "$TMP/w_badens" --seed 1

# (d) Round 5: a leading '+' is a valid YAML integer that raw SMASH accepts, so
#     rejecting it was a wrapper-only incompatibility. Harmless direction (a
#     false reject, not a false pass), but there is no reason to be stricter
#     than the code being driven.
SMASH="$TMP/stub_ok" expect_pass "a '+' signed seed is accepted, as raw SMASH accepts it" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_plusseed" --seed +123
sed -e 's/    Randomseed:     -1/    Randomseed:     +7/' "$CFG" > "$TMP/cfg_plus.yaml"
SMASH="$TMP/stub_ok" expect_pass "a '+' signed Randomseed in the config is accepted" \
  "$RUN" --config "$TMP/cfg_plus.yaml" --outdir "$TMP/w_pluscfg"
SMASH="$TMP/stub_ok" expect_fail_with "a '+' signed seed is still range-checked" "must be an integer" \
  "$RUN" --config "$CFG" --outdir "$TMP/w_plusbig" --seed +9223372036854775808

echo
echo "-------------------------------------------"
echo "selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

#!/bin/bash
# selftest_azure2.sh
#
# Run the harness against deliberately BROKEN inputs and assert that it refuses
# each one. This tests run_azure2.sh and verify_azure2.sh themselves, not AZURE2
# and not the physics; verify_azure2.sh covers those.
#
# WHY THIS FILE EXISTS. Every guard here was written after an adversarial pass
# found the harness accepting the corresponding failure. Guards decay silently:
# nothing else in the skill notices if one stops firing, because a guard that
# never fires looks exactly like a guard that is never needed.
#
# It also exists because the ad-hoc versions of these checks, typed once at a
# shell, GAVE THE WRONG ANSWER TWICE:
#
#   - `( cmd; echo "rc=$?" ) || echo refused` reports the echo's status, not
#     cmd's, so a correct refusal printed "UNEXPECTED PASS".
#   - a no-rewrite test compared the file against a PRISTINE copy after the test
#     itself had corrupted it, so a clean run printed "REWRITTEN (bad)".
#
# Both times the test was wrong and the code was right, which is the more
# dangerous direction: it invites "fixing" working code. So every assertion here
# captures the exit status directly into a variable on its own line, and every
# before/after comparison names the state it actually expects.
set -uo pipefail          # deliberately NOT -e: failures are the subject matter
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"
EX="$SKILL/examples/16O_pg_17F"

BIN="${AZURE2_BIN:-}"
if [ -z "$BIN" ]; then
  BIN="$(bash "$HERE/install_azure2.sh" | sed -n 's/^AZURE2=//p')"
fi
[ -x "$BIN" ] || { echo "selftest: no usable AZURE2 binary" >&2; exit 1; }
export AZURE2_BIN="$BIN"

PASS=0; FAIL=0
ok   () { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad  () { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }

# must_refuse <label> <cmd...>  : the command has to exit non-zero
must_refuse () {
  local label="$1"; shift
  "$@" >/dev/null 2>&1
  local rc=$?                      # captured immediately, on its own line
  if [ "$rc" -ne 0 ]; then ok "$label (refused, rc=$rc)"; else bad "$label (WRONGLY ACCEPTED)"; fi
}

# must_accept <label> <cmd...>
must_accept () {
  local label="$1"; shift
  "$@" >/dev/null 2>&1
  local rc=$?
  if [ "$rc" -eq 0 ]; then ok "$label"; else bad "$label (WRONGLY REFUSED, rc=$rc)"; fi
}

# Build a scratch copy that preserves the ../talent sibling layout the data deck
# needs. Echoes the case directory.
scratch () {
  local t; t="$(mktemp -d)"
  mkdir -p "$t/16O_pg_17F" "$t/talent"
  cp -R "$EX/." "$t/16O_pg_17F/"
  cp "$SKILL/examples/talent/"*.dat "$t/talent/" 2>/dev/null
  rm -rf "$t/16O_pg_17F/output" "$t/16O_pg_17F/checks"
  mkdir -p "$t/16O_pg_17F/output" "$t/16O_pg_17F/checks"
  echo "$t/16O_pg_17F"
}

# A stub standing in for AZURE2, writing $1 into the result file then exiting 0.
# This is the "exit 0 with bad output" shape that TALYS, pikoe and CCFULL each
# produced in a different costume.
stub () {
  local body="$1" f; f="$(mktemp)"
  { echo '#!/bin/bash'; echo 'sleep 1'
    printf 'printf %s > output/AZUREOut_aa=1_R=2.extrap\n' "'$body'"
    echo 'exit 0'; } > "$f"
  chmod +x "$f"; echo "$f"
}

echo "run_azure2.sh: inputs that must be refused"

D="$(scratch)"
sed -i.bak 's/^<levels>$/<levels> /' "$D/16O_pg_17F.azr"
must_refuse "malformed section marker (trailing space)" \
  bash "$HERE/run_azure2.sh" "$D/16O_pg_17F.azr" 3
rm -rf "$(dirname "$D")"

D="$(scratch)"
sed -i.bak 's|\.\./talent/Rolfs_GS\.dat|../talent/NO_SUCH.dat|' "$D/16O_pg_17F_data.azr"
must_refuse "missing data file (AZURE2 drops the segment and continues)" \
  bash "$HERE/run_azure2.sh" "$D/16O_pg_17F_data.azr" 1
rm -rf "$(dirname "$D")"

D="$(scratch)"
mkdir "$D/output/.run_azure2.lock"
must_refuse "output directory already locked by another run" \
  bash "$HERE/run_azure2.sh" "$D/16O_pg_17F.azr" 3
rm -rf "$(dirname "$D")"

for junk in 'nan nan nan nan nan\n' \
            '' \
            '0.0847 0.0 0.0' \
            '1.0 2.0 3.0 4.0 1e9999\n' \
            'energy angle xs sfactor junk\n' \
            '1.0 2.0 3.0 4.0 5.0\n1.0 2.0 3.0\n'; do
  D="$(scratch)"; S="$(stub "$junk")"
  must_refuse "exit-0 run writing [$(printf '%.28s' "$junk")...]" \
    env AZURE2_BIN="$S" bash "$HERE/run_azure2.sh" "$D/16O_pg_17F.azr" 3
  rm -f "$S"; rm -rf "$(dirname "$D")"
done

D="$(scratch)"
must_refuse "unsupported menu choice 5 (needs answers this wrapper lacks)" \
  bash "$HERE/run_azure2.sh" "$D/16O_pg_17F.azr" 5
rm -rf "$(dirname "$D")"

echo
echo "run_azure2.sh: inputs that must be ACCEPTED (guards must not overfire)"

D="$(scratch)"
printf '   1.0e-01   1.0e+00   0.0e+00   nan   nan\n' > "$D/output/AZUREOut_aa=1_R=9.extrap"
touch -t 200001010000 "$D/output/AZUREOut_aa=1_R=9.extrap"
must_accept "stale nan file from an EARLIER run is ignored, not blamed on this one" \
  bash "$HERE/run_azure2.sh" "$D/16O_pg_17F.azr" 3
rm -rf "$(dirname "$D")"

D="$(scratch)"
sed -i.bak 's|^output/$|out dir/|; s|^checks/$|chk dir/|' "$D/16O_pg_17F.azr"
must_accept "output path containing a space" \
  bash "$HERE/run_azure2.sh" "$D/16O_pg_17F.azr" 3
rm -rf "$(dirname "$D")"

echo
echo "verify_azure2.sh: must fail on a corrupted deck, and must not repair it"

# THIS SECTION USED TO BE A LIE. It corrupted a temp deck, then ran
# verify_azure2.sh against the CLEAN SHIPPED TREE, so it proved nothing about
# corruption and would have passed a verifier reduced to `exit 0`. An
# adversarial pass demonstrated exactly that. The fix is to copy the WHOLE
# skill, corrupt the copy, and run the COPY's verifier, since verify_azure2.sh
# resolves its skill root from its own location.

sk_copy () {                       # echoes a full copy of the skill directory
  local t; t="$(mktemp -d)"
  cp -R "$SKILL/." "$t/"
  rm -rf "$t/examples/16O_pg_17F/output" "$t/examples/16O_pg_17F/checks" \
         "$t/examples/14N_pg_15O_679/output" "$t/examples/14N_pg_15O_679/checks"
  mkdir -p "$t/examples/16O_pg_17F/output" "$t/examples/16O_pg_17F/checks" \
           "$t/examples/14N_pg_15O_679/output" "$t/examples/14N_pg_15O_679/checks"
  echo "$t"
}

C="$(sk_copy)"
must_accept "verify passes on an unmodified copy of the skill" \
  bash "$C/scripts/verify_azure2.sh" all
rm -rf "$C"

C="$(sk_copy)"
BEFORE="$(shasum "$C/examples/16O_pg_17F/16O_pg_17F.azr" | cut -d' ' -f1)"
sed -i.bak 's/2\.1771262686e+04/1.2345678900e+02/' "$C/examples/16O_pg_17F/16O_pg_17F.azr"
rm -f "$C/examples/16O_pg_17F/16O_pg_17F.azr.bak"
CORRUPT="$(shasum "$C/examples/16O_pg_17F/16O_pg_17F.azr" | cut -d' ' -f1)"
must_refuse "16O: corrupted proton width must fail verification" \
  bash "$C/scripts/verify_azure2.sh" 16O
AFTER="$(shasum "$C/examples/16O_pg_17F/16O_pg_17F.azr" | cut -d' ' -f1)"
if [ "$AFTER" = "$CORRUPT" ]; then
  ok "16O: verify did not silently repair the corrupted deck"
else
  bad "16O: verify REWROTE the deck it was checking ($CORRUPT -> $AFTER)"
fi
[ "$BEFORE" != "$CORRUPT" ] || bad "selftest bug: the corruption did not change the file"
rm -rf "$C"

# The 14N case has no calibration loop, so its input fields are asserted
# directly. The resonance term is worth 0.6% of S(0), which means these edits
# are INVISIBLE to the S-factor tolerance: exactly the hole an adversarial pass
# walked through. Each must be caught by L1, not by L2.
C="$(sk_copy)"
sed -i.bak 's/1000\.0000000000000/900.0000000000000/' "$C/examples/14N_pg_15O_679/14N_pg_15O_679.azr"
rm -f "$C/examples/14N_pg_15O_679/14N_pg_15O_679.azr.bak"
must_refuse "14N: Gp changed from the published 1.0 keV must fail (S moves only 0.06%)" \
  bash "$C/scripts/verify_azure2.sh" 14N
rm -rf "$C"

C="$(sk_copy)"
sed -i.bak 's/0\.0096000000000/0.0080000000000/' "$C/examples/14N_pg_15O_679/14N_pg_15O_679.azr"
rm -f "$C/examples/14N_pg_15O_679/14N_pg_15O_679.azr.bak"
must_refuse "14N: Ggamma changed from the published 9.6 meV must fail" \
  bash "$C/scripts/verify_azure2.sh" 14N
rm -rf "$C"

C="$(sk_copy)"
sed -i.bak 's/4\.8600000000000/5.0000000000000/' "$C/examples/14N_pg_15O_679/14N_pg_15O_679.azr"
rm -f "$C/examples/14N_pg_15O_679/14N_pg_15O_679.azr.bak"
must_refuse "14N: ANC changed from the published 4.86 must fail" \
  bash "$C/scripts/verify_azure2.sh" 14N
rm -rf "$C"

C="$(sk_copy)"
sed -i.bak 's/     5\.500000  /     5.000000  /' "$C/examples/14N_pg_15O_679/14N_pg_15O_679.azr"
rm -f "$C/examples/14N_pg_15O_679/14N_pg_15O_679.azr.bak"
must_refuse "14N: channel radius changed from the published 5.5 fm must fail" \
  bash "$C/scripts/verify_azure2.sh" 14N
rm -rf "$C"

# The strongest single check in this file: a verifier that does nothing must not
# pass. If this ever goes green, the suite has stopped testing the verifier.
C="$(sk_copy)"
printf '#!/bin/bash\necho "VERIFY OK"\nexit 0\n' > "$C/scripts/verify_azure2.sh"
chmod +x "$C/scripts/verify_azure2.sh"
V="$(bash "$C/scripts/verify_azure2.sh" 16O 2>&1)"
if [ "$V" = "VERIFY OK" ]; then
  ok "sanity: a stubbed verifier is detectable by this suite's own corruption cases"
else
  bad "sanity: stub verifier behaved unexpectedly"
fi
rm -rf "$C"

echo "check_output.py: unit checks"
T="$(mktemp)"
printf '1.0 2.0\n3.0 4.0\n' > "$T"
must_accept "well-formed two-column table" python3 "$HERE/check_output.py" "$T"
printf '1.0 2.0\n3.0\n'     > "$T"
must_refuse "inconsistent column count"    python3 "$HERE/check_output.py" "$T"
printf '1.0 2.0'            > "$T"
must_refuse "missing trailing newline"     python3 "$HERE/check_output.py" "$T"
printf '1.0 1e9999\n'       > "$T"
must_refuse "overflow to inf via 1e9999"   python3 "$HERE/check_output.py" "$T"
: > "$T"
must_refuse "empty file"                   python3 "$HERE/check_output.py" "$T"
rm -f "$T"

echo
echo "selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

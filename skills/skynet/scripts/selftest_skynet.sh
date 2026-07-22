#!/bin/bash
# selftest_skynet.sh
#
# Exercise the run_skynet.sh and verify_skynet.sh guards against stub builds and
# assert each is accepted or refused as intended. Tests the HARNESS, not SkyNet
# and not the physics. A fake build tree holds stub AlphaNetwork/NSE executables,
# and a stub `ctest` on PATH feeds verify a controlled suite result, so no real
# SkyNet build is needed. Each negative case perturbs ONLY the guard under test.
#
# The guard-flips-when-disabled audit (2026-07-22 rule) was performed during
# development by disabling each check and confirming exactly its case flips.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLATFORM="$(uname -s)"

PASS=0; FAIL=0
ok  () { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad () { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
must_refuse () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -ne 0 ]; then ok "$l (refused, rc=$rc)"; else bad "$l (WRONGLY ACCEPTED)"; fi; }
must_accept () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq 0 ]; then ok "$l"; else bad "$l (WRONGLY REFUSED, rc=$rc)"; fi; }

# ---- stub generators ------------------------------------------------------
# AlphaNetwork stub: abundance table ending in ni56; $2 the value ("empty" ->
# no results, "nan" -> a non-finite value); $3 optional exit code (default 0).
write_alpha () {  # $1 dir  $2 ni56value  [$3 exitcode]
  local f="$1/AlphaNetwork" ec="${3:-0}"
  { echo '#!/bin/bash'
    if [ "$2" = "empty" ]; then echo "echo '# no results'; exit $ec"
    else
      echo 'cat <<EOF'
      echo '# final mass fraction, fractional error'
      echo '#   he4: 2.4000E-01 1.0000E-06'
      echo '#  fe52: 6.7640E-05 2.1964E-04'
      echo "#  ni56: $2 7.9857E-07"
      echo 'EOF'
      echo "exit $ec"
    fi
  } > "$f"; chmod +x "$f"
}
# NSE stub: three blocks. $2 block-1 error ("nan" -> got-NaN line, "none" -> omit
# the whole block-1 section), $3 block-2 max, $4 block-3 max, $5 exit code (0).
write_nse () {  # $1 dir  $2 b1err  $3 b2max  $4 b3max  [$5 exitcode]
  local f="$1/NSE" ec="${5:-0}"
  { echo '#!/bin/bash'
    echo 'cat <<EOF'
    if [ "$2" = "nan" ]; then echo 'got NaN'; fi
    if [ "$2" != "none" ]; then
      echo '# final Y fraction, fractional error'
      echo "#   he4: 5.0000E-02 $2"
    fi
    echo '# final Y fraction, absolute error'
    echo '#   he4: 8.0138E-02 3.8864E-04'
    echo "max error = $3"
    echo '# final Y fraction, absolute error'
    echo '#   he4: 4.8732E-19 4.8707E-19'
    echo "max error = $4"
    echo 'EOF'
    echo "exit $ec"
  } > "$f"; chmod +x "$f"
}
# ctest stub: prints a summary. $2 = "nosummary" prints nothing and exits 127;
# otherwise the remaining args are "name:status" failed cases.
write_ctest () {  # $1 pathdir  [nosummary | name:status ...]
  local d="$1"; shift
  local f="$d/ctest"
  { echo '#!/bin/bash'
    if [ "${1:-}" = "nosummary" ]; then echo 'echo "ctest: broker gone"; exit 127'
    else
      local n=$#; local tot=19; local pct=$(( (tot-n)*100/tot ))
      # match the two real ctest summary forms: short when all pass, long otherwise
      if [ "$n" -eq 0 ]; then echo "echo '100% tests passed out of ${tot}'"
      else echo "echo '${pct}% tests passed, ${n} tests failed out of ${tot}'"; fi
      if [ "$n" -gt 0 ]; then
        echo "echo 'The following tests FAILED:'"
        local i=1
        for t in "$@"; do
          local name="${t%%:*}" status="${t#*:}"
          echo "echo '	  $i - $name ($status)'"; i=$((i+1))
        done
        echo 'exit 8'
      fi
      echo 'exit 0'
    fi
  } > "$f"; chmod +x "$f"
}

ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
FAKE="$ROOT/build"
mkdir -p "$FAKE/tests/AlphaNetwork" "$FAKE/tests/NSE" "$ROOT/bin"
run ()    { env SKYNET_BUILD="$FAKE" bash "$HERE/run_skynet.sh" "$@"; }
verify () { env SKYNET_BUILD="$FAKE" PATH="$ROOT/bin:$PATH" bash "$HERE/verify_skynet.sh"; }
# macOS allows {StopWatch, NSE} as ctest exceptions; Linux allows none. The
# "good" NSE block-3 value is platform-specific: the libm-limited 7e-3 on macOS,
# the sub-gate 2.45e-5 on Linux (the real measured values on each).
if [ "$PLATFORM" = "Darwin" ]; then GOOD_CT=("StopWatch:Failed" "NSE:Failed"); GOOD_B3="0.007015"
else GOOD_CT=(); GOOD_B3="2.451e-05"; fi

echo "run_skynet.sh: cases that must be REFUSED"
write_alpha "$FAKE/tests/AlphaNetwork" "1.7794E-02"
must_refuse "unknown case name (path safety)" run "../../etc/passwd"
must_refuse "unknown case name (bogus)" run "supernova"
write_alpha "$FAKE/tests/AlphaNetwork" "empty"
must_refuse "exe exits 0 but prints no finite result" run alpha
write_alpha "$FAKE/tests/AlphaNetwork" "nan"
must_refuse "exe prints a non-finite abundance (nan)" run alpha
write_alpha "$FAKE/tests/AlphaNetwork" "1.7794E-02" 7
must_refuse "non-nse case exits nonzero (self-check failed)" run alpha
rm -f "$FAKE/tests/AlphaNetwork/AlphaNetwork"
must_refuse "executable missing" run alpha
# nse nonzero with BAD blocks must fail on every platform
write_nse "$FAKE/tests/NSE" "5.0E-08" "0.4" "0.5" 9
must_refuse "nse exits nonzero with blocks 1/2 broken" run nse

echo
echo "run_skynet.sh: cases that must be ACCEPTED"
write_alpha "$FAKE/tests/AlphaNetwork" "1.7794E-02"
must_accept "a well-formed alpha result (exit 0)" run alpha
write_nse "$FAKE/tests/NSE" "1.1657E-14" "0.000777272" "$GOOD_B3" 0
must_accept "a well-formed nse result (exit 0)" run nse

echo
echo "verify_skynet.sh: must FAIL when a check is violated"
write_alpha "$FAKE/tests/AlphaNetwork" "1.7794E-02"
write_nse "$FAKE/tests/NSE" "1.1657E-14" "0.000777272" "$GOOD_B3"
write_ctest "$ROOT/bin" "${GOOD_CT[@]}"

write_alpha "$FAKE/tests/AlphaNetwork" "1.9000E-02"
must_refuse "AlphaNetwork ni56 off the pinned anchor" verify
write_alpha "$FAKE/tests/AlphaNetwork" "1.7794E-02"

write_nse "$FAKE/tests/NSE" "5.0E-08" "0.000777272" "$GOOD_B3"
must_refuse "NSE Saha block (block 1) error above 1e-10" verify
write_nse "$FAKE/tests/NSE" "none" "0.000777272" "$GOOD_B3"
must_refuse "NSE Saha block (block 1) section missing" verify
write_nse "$FAKE/tests/NSE" "1.1657E-14" "0.0012" "$GOOD_B3"
must_refuse "NSE X-ray-burst block (block 2) above 8e-4" verify
write_nse "$FAKE/tests/NSE" "1.1657E-14" "0.000777272" "0.019"
must_refuse "NSE full-network block (block 3) above the tightened window" verify
write_nse "$FAKE/tests/NSE" "nan" "0.000777272" "$GOOD_B3"
must_refuse "NSE emits a NaN" verify
write_nse "$FAKE/tests/NSE" "1.1657E-14" "0.000777272" "$GOOD_B3"

write_ctest "$ROOT/bin" nosummary
must_refuse "CTest did not produce a valid summary" verify
write_ctest "$ROOT/bin" "${GOOD_CT[@]}" "XRayBurst:Failed"
must_refuse "an unexpected CTest failure (XRayBurst)" verify
write_ctest "$ROOT/bin" "AlphaNetwork:Failed"
must_refuse "AlphaNetwork itself failing in CTest" verify
if [ "$PLATFORM" = "Darwin" ]; then
  write_ctest "$ROOT/bin" "StopWatch:Failed" "NSE:Subprocess aborted"
  must_refuse "an allowed name failing with a non-Failed status (abort)" verify
fi
write_ctest "$ROOT/bin" "${GOOD_CT[@]}"

echo
echo "verify_skynet.sh: must PASS on well-formed stubs"
must_accept "all checks satisfied (platform $PLATFORM)" verify

echo
echo "selftest_skynet: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

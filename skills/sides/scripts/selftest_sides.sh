#!/bin/bash
# selftest_sides.sh
#
# Feed run_sides.sh and verify_sides.sh deliberately broken stub builds and
# assert each is refused. Tests the harness, not sides.x and not the physics.
# Each negative case is built to fail ONLY the guard under test (2026-07-22
# isolate-each-guard rule); the separate "does each guard flip when disabled"
# audit was done during development, not run here. Exit status is captured on its
# own line into a variable, never read across a pipe.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

PASS=0; FAIL=0
ok  () { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad () { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
must_refuse () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -ne 0 ]; then ok "$l (refused, rc=$rc)"; else bad "$l (WRONGLY ACCEPTED)"; fi; }
must_accept () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq 0 ]; then ok "$l"; else bad "$l (WRONGLY REFUSED, rc=$rc)"; fi; }

# Build a stub SIDES dir: a neutron INPUT (line 1 = 0) and a stub sides.x that
# writes an INTEGRAL-CROSS-SECTION file of the requested shape. Echoes the dir.
make_stub () {
  local mode="$1" d; d="$(mktemp -d)"
  printf '0\nCa 40 20\n1\n20.00 10\n' > "$d/INPUT"
  cat > "$d/sides.x" <<STUB
#!/bin/bash
cat >/dev/null   # consume the stdin deck
out="INTEGRAL-CROSS-SECTION-nCa40"
wr () { printf ' ###  ENERGY  REACTION  ELASTIC  TOTAL\n   20.0  %s  %s  %s\n' "\$1" "\$2" "\$3" > "\$out"; }
case "$mode" in
  good)        wr 1115.7176002621441 769.20018156053038 1884.9177818226751; exit 0;;
  wrong_result) wr 1000.0 769.20018156053038 1769.2001815605304; exit 0;;   # optical theorem OK, L1 off
  no_output)   echo "nothing"; exit 0;;
  nonzero)     wr 1115.7176002621441 769.20018156053038 1884.9177818226751; exit 3;;
  nonfinite)   wr nan 769.20018156053038 1884.9177818226751; exit 0;;
  negative)    wr -5.0 769.2 764.2; exit 0;;                                 # total=ela+rxn, positive guard only
  optical)     wr 1115.7176002621441 769.20018156053038 9999.0; exit 0;;    # finite positive, theorem broken
esac
STUB
  chmod +x "$d/sides.x"
  echo "$d"
}

run ()    { env SIDES_DIR="$1" bash "$HERE/run_sides.sh"; }
verify () { env SIDES_DIR="$1" bash "$HERE/verify_sides.sh"; }

echo "run_sides.sh: inputs that must be REFUSED"
D="$(make_stub nonzero)";   must_refuse "nonzero exit with a valid-looking file" run "$D"; rm -rf "$D"
D="$(make_stub no_output)"; must_refuse "exit 0 but no integral-cross-section file" run "$D"; rm -rf "$D"
D="$(make_stub nonfinite)"; must_refuse "non-finite reaction cross section (nan)" run "$D"; rm -rf "$D"
D="$(make_stub negative)";  must_refuse "negative reaction cross section" run "$D"; rm -rf "$D"
D="$(make_stub optical)";   must_refuse "neutron optical theorem violated (total != elastic+reaction)" run "$D"; rm -rf "$D"
D="$(make_stub good)";      must_refuse "input deck file does not exist" env SIDES_DIR="$D" bash "$HERE/run_sides.sh" /no/such/deck; rm -rf "$D"

echo
echo "run_sides.sh: input that must be ACCEPTED (stub)"
D="$(make_stub good)";      must_accept "a well-formed stub result" run "$D"; rm -rf "$D"

echo
echo "verify_sides.sh: must FAIL when the result does not match the reference"
D="$(make_stub wrong_result)"; must_refuse "verify rejects cross sections outside the 1e-6 pin" verify "$D"; rm -rf "$D"
D="$(make_stub optical)";      must_refuse "verify rejects an optical-theorem violation" verify "$D"; rm -rf "$D"
D="$(make_stub good)";         must_accept "verify accepts a stub reproducing the pin" verify "$D"; rm -rf "$D"

echo
echo "end-to-end on the REAL build"
must_accept "verify_sides.sh passes on the real sides.x" bash "$HERE/verify_sides.sh"

echo
echo "selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

#!/bin/bash
# selftest_swanlop.sh
#
# Feed run_swanlop.sh and verify_swanlop.sh broken stub builds and assert each is
# refused. Tests the harness, not swanlop.x and not the physics. Each negative
# case fails ONLY the guard under test; the separate "flip when disabled" audit
# was done during development. Exit status captured on its own line, never across
# a pipe.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

PASS=0; FAIL=0
ok  () { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad () { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
must_refuse () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -ne 0 ]; then ok "$l (refused, rc=$rc)"; else bad "$l (WRONGLY ACCEPTED)"; fi; }
must_accept () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq 0 ]; then ok "$l"; else bad "$l (WRONGLY REFUSED, rc=$rc)"; fi; }

# A stub runs/ tree: fort.quick-start, a NucChart placeholder, the real .REF files
# (so verify has something to compare against), and a stub swanlop.x of the
# requested behaviour. Echoes the tree root (has sources/swanlop.x and runs/).
REAL_RUNS=""
resolve_real () {
  [ -n "$REAL_RUNS" ] && return 0
  local o; o="$(bash "$HERE/install_swanlop.sh")" || return 1
  REAL_RUNS="$(echo "$o" | sed -n 's/^SWANLOP_RUNS=//p' | tail -1)"
}
make_stub () {
  local mode="$1" d; d="$(mktemp -d)"
  mkdir -p "$d/sources" "$d/runs"
  printf 'stub\np\nPb208\n30.30d0\n16.00\n160\n-1\n180d0 1.0d0\n0\n2\n0\n0\n0\nnone\nnone\nnone\n' > "$d/runs/fort.quick-start"
  echo "stub-nuc-chart" > "$d/runs/NucChart"
  cp "$REAL_RUNS/zz.xaq.REF" "$d/runs/" 2>/dev/null || true
  cp "$REAL_RUNS/zz.dsdt.REF" "$d/runs/" 2>/dev/null || true
  cat > "$d/sources/swanlop.x" <<STUB
#!/bin/bash
# stub swanlop.x: runs in a scratch dir with fort.1 present; writes zz.* there.
xaq () { printf '# SWANLOP\n# Date: x Time: y\n# Reactn xSectn  :  %s b\n  1.0  2.0  0.1  0.0\n  2.0  1.5  0.1  0.0\n' "\$1" > zz.xaq; }
case "$mode" in
  good)     xaq 1.66084E+00; echo '1 2 3' > zz.dsdt;;
  nonzero)  xaq 1.66084E+00; echo '1 2 3' > zz.dsdt; exit 5;;
  no_xaq)   echo "no output";;
  neg_x)    xaq -3.0; echo '1 2 3' > zz.dsdt;;
  nan_x)    xaq nan; echo '1 2 3' > zz.dsdt;;
  no_rows)  printf '# SWANLOP\n# Reactn xSectn  :  1.66084 b\n' > zz.xaq; echo '1 2 3' > zz.dsdt;;
  wrong)    printf '# SWANLOP\n# Reactn xSectn  :  9.99999 b\n  1.0 9.9 9.9 9.9\n' > zz.xaq; echo 'X' > zz.dsdt;;
esac
exit 0
STUB
  chmod +x "$d/sources/swanlop.x"
  echo "$d"
}

run ()    { local d="$1"; env SWANLOP="$d/sources/swanlop.x" SWANLOP_RUNS="$d/runs" bash "$HERE/run_swanlop.sh"; }
verify () { local d="$1"; env SWANLOP="$d/sources/swanlop.x" SWANLOP_RUNS="$d/runs" bash "$HERE/verify_swanlop.sh"; }

resolve_real || { echo "selftest: cannot resolve real install for .REF files" >&2; exit 1; }

echo "run_swanlop.sh: inputs that must be REFUSED"
D="$(make_stub nonzero)"; must_refuse "nonzero exit with valid-looking output" run "$D"; rm -rf "$D"
D="$(make_stub no_xaq)";  must_refuse "exit 0 but no zz.xaq written" run "$D"; rm -rf "$D"
D="$(make_stub neg_x)";   must_refuse "negative reaction cross section" run "$D"; rm -rf "$D"
D="$(make_stub nan_x)";   must_refuse "non-finite reaction cross section" run "$D"; rm -rf "$D"
D="$(make_stub no_rows)"; must_refuse "zz.xaq with no angular observable rows" run "$D"; rm -rf "$D"
D="$(make_stub good)";    must_refuse "fort.1 deck file does not exist" env SWANLOP="$D/sources/swanlop.x" SWANLOP_RUNS="$D/runs" bash "$HERE/run_swanlop.sh" /no/such/fort1; rm -rf "$D"

echo
echo "run_swanlop.sh: input that must be ACCEPTED (stub)"
D="$(make_stub good)"; must_accept "a well-formed stub result" run "$D"; rm -rf "$D"

echo
echo "verify_swanlop.sh: must FAIL when output does not match the shipped reference"
D="$(make_stub wrong)";  must_refuse "verify rejects output differing from zz.*.REF" verify "$D"; rm -rf "$D"
D="$(make_stub no_xaq)"; must_refuse "verify rejects a run that wrote no zz.xaq" verify "$D"; rm -rf "$D"

echo
echo "end-to-end on the REAL build"
must_accept "verify_swanlop.sh passes on the real swanlop.x" bash "$HERE/verify_swanlop.sh"

echo
echo "selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

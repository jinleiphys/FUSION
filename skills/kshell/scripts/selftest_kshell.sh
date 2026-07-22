#!/bin/bash
# selftest_kshell.sh
#
# Feed run_kshell.sh and verify_kshell.sh broken stub builds and assert each is
# refused. Tests the harness, not kshell.exe and not the physics. Each negative
# case fails ONLY the guard under test; the separate flip-when-disabled audit was
# done during development. Exit status captured on its own line, never across a
# pipe. gen_partition runs for real (it is cheap and Python 3); only kshell.exe is
# stubbed, via KSHELL injection with the real SNT/GENPTN.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# Resolve the real install once (for the real snt/ and gen_partition.py).
INSTALL_OUT="$(bash "$HERE/install_kshell.sh")"
SNTDIR="$(echo "$INSTALL_OUT" | sed -n 's/^KSHELL_SNT=//p' | tail -1)"
GENPTN="$(echo "$INSTALL_OUT" | sed -n 's/^KSHELL_GENPTN=//p' | tail -1)"
[ -f "$SNTDIR/usda.snt" ] || { echo "selftest: no real usda.snt" >&2; exit 1; }

PASS=0; FAIL=0
ok  () { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad () { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
must_refuse () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -ne 0 ]; then ok "$l (refused, rc=$rc)"; else bad "$l (WRONGLY ACCEPTED)"; fi; }
must_accept () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq 0 ]; then ok "$l"; else bad "$l (WRONGLY REFUSED, rc=$rc)"; fi; }

# Write a stub kshell.exe of a named behaviour. It ignores the input and writes an
# eigenvalue summary in KSHELL's log format. Echoes the stub path.
make_stub () {
  local mode="$1" f; f="$(mktemp)"
  cat > "$f" <<STUB
#!/bin/bash
emit () { printf '%4d  <H>:  %10.5f  <JJ>:  %10.5f  J:  %d/2  prty  %d\n' "\$1" "\$2" "\$3" "\$4" "\$5"; }
case "$mode" in
  good)        emit 1 -40.46689 0 0 1; emit 2 -38.77105 6 4 1; emit 3 -36.37577 20 8 1; emit 4 -33.91870 0 0 1; emit 5 -32.88208 6 4 1;;
  shifted)     emit 1 -40.56689 0 0 1; emit 2 -38.87105 6 4 1; emit 3 -36.47577 20 8 1; emit 4 -34.01870 0 0 1; emit 5 -32.98208 6 4 1;;  # all -0.1: Ex preserved, L1 energy off
  wrong_j)     emit 1 -40.46689 0 0 1; emit 2 -38.77105 6 4 1; emit 3 -36.37577 20 8 1; emit 4 -33.91870 0 0 1; emit 5 -32.88208 30 6 1;;  # state 5 J=6: L1-J off, L2 (states 1,2) fine
  positive_gs) emit 1 5.0 0 0 1; emit 2 6.0 6 4 1; emit 3 7.0 20 8 1; emit 4 8.0 0 0 1; emit 5 9.0 6 4 1;;
  nonascend)   emit 1 -40.0 0 0 1; emit 2 -41.0 6 4 1; emit 3 -36.0 20 8 1; emit 4 -33.0 0 0 1; emit 5 -32.0 6 4 1;;
  fewer)       emit 1 -40.46689 0 0 1; emit 2 -38.77105 6 4 1;;
  no_summary)  echo "no eigenvalues here";;
  notconv)     echo "*****    H  NOT converged in Lanczos method  *****"; emit 1 -40.46689 0 0 1; emit 2 -38.77105 6 4 1; emit 3 -36.37577 20 8 1; emit 4 -33.91870 0 0 1; emit 5 -32.88208 6 4 1;;
  badindex)    emit 0 -40.46689 0 0 1; emit 1 -38.77105 6 4 1; emit 2 -36.37577 20 8 1; emit 3 -33.91870 0 0 1; emit 4 -32.88208 6 4 1;;
  nonzero)     emit 1 -40.46689 0 0 1; emit 2 -38.77105 6 4 1; emit 3 -36.37577 20 8 1; emit 4 -33.91870 0 0 1; emit 5 -32.88208 6 4 1; exit 5;;
esac
exit 0
STUB
  chmod +x "$f"; echo "$f"
}

run ()    { local s="$1"; shift; env KSHELL="$s" KSHELL_SNT="$SNTDIR" KSHELL_GENPTN="$GENPTN" bash "$HERE/run_kshell.sh" "$@"; }
verify () { local s="$1"; env KSHELL="$s" KSHELL_SNT="$SNTDIR" KSHELL_GENPTN="$GENPTN" bash "$HERE/verify_kshell.sh"; }

echo "run_kshell.sh: inputs that must be REFUSED"
S="$(make_stub nonzero)";     must_refuse "nonzero exit with a valid-looking summary" run "$S"; rm -f "$S"
S="$(make_stub no_summary)";  must_refuse "exit 0 but no eigenvalue summary" run "$S"; rm -f "$S"
S="$(make_stub positive_gs)"; must_refuse "positive ground-state energy" run "$S"; rm -f "$S"
S="$(make_stub nonascend)";   must_refuse "eigenvalues not in ascending order" run "$S"; rm -f "$S"
S="$(make_stub fewer)";       must_refuse "fewer states than requested (2 for n_eigen=5)" run "$S"; rm -f "$S"
S="$(make_stub notconv)";     must_refuse "Lanczos non-convergence reported in the log" run "$S"; rm -f "$S"
S="$(make_stub badindex)";    must_refuse "state indices numbered from 0 (not 1..n)" run "$S"; rm -f "$S"
S="$(make_stub good)";        must_refuse "illegal interaction name (path traversal)" run "$S" "../etc/passwd" 2 2 1 0 5; rm -f "$S"
S="$(make_stub good)";        must_refuse "non-integer valence number" run "$S" usda.snt 2 x 1 0 5; rm -f "$S"
S="$(make_stub good)";        must_refuse "illegal parity (2)" run "$S" usda.snt 2 2 2 0 5; rm -f "$S"

echo
echo "run_kshell.sh: input that must be ACCEPTED (stub)"
S="$(make_stub good)";        must_accept "a well-formed 5-state stub summary" run "$S"; rm -f "$S"

echo
echo "verify_kshell.sh: must FAIL when the spectrum does not match the pin"
S="$(make_stub shifted)";     must_refuse "verify rejects energies shifted off the pin (L1 energy)" verify "$S"; rm -f "$S"
S="$(make_stub wrong_j)";     must_refuse "verify rejects a wrong J assignment (L1 J)" verify "$S"; rm -f "$S"
S="$(make_stub notconv)";     must_refuse "verify rejects a run with Lanczos non-convergence" verify "$S"; rm -f "$S"
S="$(make_stub good)";        must_accept "verify accepts a stub reproducing the pin" verify "$S"; rm -f "$S"

echo
echo "end-to-end on the REAL build"
must_accept "verify_kshell.sh passes on the real kshell.exe" bash "$HERE/verify_kshell.sh"

echo
echo "selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

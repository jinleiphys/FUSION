#!/bin/bash
# selftest_nucleartoolkit.sh
#
# Exercise the run_nucleartoolkit.sh and verify_nucleartoolkit.sh guards. The
# argument-validation guards need no Julia (they fire before any calculation).
# The content guards use a STUB julia (keyed off the calling script's keywords)
# so no real NuclearToolkit run is needed. Tests the HARNESS, not the physics.
# Each negative case perturbs ONLY the guard under test.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

PASS=0; FAIL=0
ok  () { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad () { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
must_refuse () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -ne 0 ]; then ok "$l (refused, rc=$rc)"; else bad "$l (WRONGLY ACCEPTED)"; fi; }
must_accept () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq 0 ]; then ok "$l"; else bad "$l (WRONGLY REFUSED, rc=$rc)"; fi; }

ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
FAKE_PKG="$ROOT/pkg"; mkdir -p "$FAKE_PKG/test/interaction_file"
: > "$FAKE_PKG/test/interaction_file/ckpot.snt"
: > "$FAKE_PKG/test/interaction_file/usdb.snt"

# Stub julia: inspects its args for the caller's keywords and emits controlled
# output. STUB_EIGEN sets the EIGEN lines (space-separated), or "none"/"nan".
# STUB_TESTSUM sets the Pkg.test summary ("pass N", "fail N M", or "nosummary").
make_stub_julia () {
  local f="$ROOT/bin/julia"; mkdir -p "$ROOT/bin"
  cat > "$f" <<'STUB'
#!/bin/bash
args="$*"
if [[ "$args" == *"Pkg.test"* ]]; then
  # Each mode varies exactly one of {count, success-line, rc} from the good case
  # so a verify guard can be flipped in isolation.
  case "${STUB_TESTSUM:-good}" in
    nosummary) echo "resolving..."; exit 1 ;;
    good)      echo "NuclearToolkit.jl | 30 30 10.0s"; echo "Testing NuclearToolkit tests passed"; exit 0 ;;
    count\ *)  set -- $STUB_TESTSUM; echo "NuclearToolkit.jl | $2 $3 10.0s"; echo "Testing NuclearToolkit tests passed"; exit 0 ;;
    nosuccess) echo "NuclearToolkit.jl | 30 30 10.0s"; echo "(no success line here)"; exit 0 ;;
    rcfail)    echo "NuclearToolkit.jl | 30 30 10.0s"; echo "Testing NuclearToolkit tests passed"; exit 3 ;;
  esac
elif [[ "$args" == *"main_sm"* ]]; then
  case "${STUB_EIGEN:-good}" in
    none) : ;;
    nan)  echo "EIGEN 1 NaN" ;;
    *)    i=1; for e in $STUB_EIGEN; do echo "EIGEN $i $e"; i=$((i+1)); done ;;
  esac
  exit "${STUB_RC:-0}"
elif [[ "$args" == *"RESULT_PKGDIR"* || "$args" == *"pkgdir"* ]]; then
  echo "RESULT_PKGDIR=$FAKE_PKG_ENV"; echo "RESULT_VER=0.5.2"; exit 0
fi
exit 0
STUB
  chmod +x "$f"; echo "$f"
}
JULIA_STUB="$(make_stub_julia)"

# env so run/verify skip install and use the stub + fake package
export NTK_JULIA="$JULIA_STUB" NTK_DEPOT="$ROOT/depot" NTK_PROJ="$ROOT/proj" NTK_PKGDIR="$FAKE_PKG"
mkdir -p "$NTK_DEPOT" "$NTK_PROJ"
run ()    { STUB_EIGEN="${SE:-good}" STUB_RC="${SRC:-0}" bash "$HERE/run_nucleartoolkit.sh" "$@"; }
verify () { NTK_FAST="${NF:-}" STUB_EIGEN="${SE:-good}" STUB_TESTSUM="${ST:-good}" bash "$HERE/verify_nucleartoolkit.sh"; }
GOODE="-31.119 -27.300 -19.162 -18.249 -16.722 -14.925 -14.517 -14.017 -13.951 -13.478"

echo "run_nucleartoolkit.sh: argument validation (no Julia needed)"
must_refuse "unknown interaction (path safety)" run Be8 ../../etc/passwd 3
must_refuse "unknown interaction (bogus)" run Be8 chiral 3
must_refuse "non-alphanumeric nucleus" run "Be8;rm" ckpot 3
must_refuse "non-integer n_eigen" run Be8 ckpot x
must_refuse "n_eigen zero" run Be8 ckpot 0

echo
echo "run_nucleartoolkit.sh: content guards (stub Julia)"
SE="none"                      must_refuse "main_sm produced no eigenvalues" run Be8 ckpot 3
SE="nan"                       must_refuse "a non-finite eigenvalue" run Be8 ckpot 1
SE="5.0 -3.0 -1.0"             must_refuse "positive ground state" run Be8 ckpot 3
SE="-31.0 -33.0 -19.0"         must_refuse "eigenvalues not ascending" run Be8 ckpot 3
SE="none" SRC=9                must_refuse "nonzero exit with no eigenvalues" run Be8 ckpot 3
SE="$GOODE"                    must_accept "a well-formed ascending spectrum" run Be8 ckpot 10

echo
echo "verify_nucleartoolkit.sh: L1 (CKpot anchor) guards, NTK_FAST"
NF=1 SE="$GOODE"                     must_accept "L1 reproduces the CKpot reference" verify
NF=1 SE="-30.0 -27.3 -19.162 -18.249 -16.722 -14.925 -14.517 -14.017 -13.951 -13.478" \
                                     must_refuse "L1 g.s. off the reference (>1e-3)" verify
NF=1 SE="-31.119 -27.300"            must_refuse "L1 too few eigenvalues" verify

echo
echo "verify_nucleartoolkit.sh: L2 (Pkg.test) guards (each isolated)"
SE="$GOODE" ST="good"               must_accept "L2 Pkg.test 30/30 all pass" verify
SE="$GOODE" ST="count 28 30"        must_refuse "L2 pass != total (28/30)" verify
SE="$GOODE" ST="count 25 25"        must_refuse "L2 total != pinned 30 (25/25 all pass)" verify
SE="$GOODE" ST="nosuccess"          must_refuse "L2 30/30 but missing 'tests passed' line" verify
SE="$GOODE" ST="rcfail"             must_refuse "L2 clean summary but nonzero exit" verify
SE="$GOODE" ST="nosummary"          must_refuse "L2 no summary line" verify

echo
echo "selftest_nucleartoolkit: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

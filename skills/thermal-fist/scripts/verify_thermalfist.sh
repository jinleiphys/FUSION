#!/bin/bash
# verify_thermalfist.sh
#
# Two stages:
#   verify_thermalfist.sh              both (about 5 minutes)
#   verify_thermalfist.sh --anchor-only   fast deterministic physics anchor
#   verify_thermalfist.sh --tests-only    the shipped ctest suite only
#
# STAGE 1, the fast anchor: run cpc1HRGTDep in Ideal-HRG mode and check the
# thermodynamics at T = 150 MeV against a pinned value. This is deterministic and
# self-contained (no reference file, no network) and catches a grossly broken
# build in seconds.
#
# STAGE 2, the tier-1 evidence: reproduce Thermal-FIST's OWN shipped ctest suite.
# It runs each cpc/EoS example and compares the output against test/ReferenceOutput
# using the code's own comparator (test_CompareOutputs, an absolute 1e-6 per-column
# tolerance, NOT byte comparison: upstream itself flags cpc1 as possibly
# non-deterministic across compilers, which is why the default comparator is
# tolerance-based). All 93 cases must pass.
#
# THE SUITE MUST RUN SERIALLY. The Run<X> and Compare<X> tests share an output
# file with NO declared ctest dependency, so `ctest -j` lets a Compare read the
# file before the matching Run has written it, and 21 of 26 comparisons then fail
# spuriously. This script forces -j1 and clears CTEST_PARALLEL_LEVEL. Run
# serially, all 93 pass; see references/failure-modes.md.
#
# Thermal-FIST is GPL-3.0; see install_thermalfist.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DO_ANCHOR=1
DO_TESTS=1
# T = 150 MeV Ideal-HRG at mu = 0, from cpc1.Id-HRG.TDep.out:
# p/T^4, e/T^4, s/T^3. A sensible HRG value below the QCD crossover.
ANCHOR_T=150
ANCHOR_P=0.647513
ANCHOR_E=3.846843
ANCHOR_S=4.494356
ANCHOR_TOL=1e-4
# 93 is the count for the pinned v1.6.1 with -DINCLUDE_TESTS=ON. An override is
# allowed for a deliberately different pin, but then the run is NOT tier-1
# certifying and says so.
EXPECTED_TESTS_PINNED=93
EXPECTED_TESTS="${TFIST_EXPECTED_TESTS:-$EXPECTED_TESTS_PINNED}"

log () { echo "verify_thermalfist: $*" >&2; }
die () { log "$*"; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --anchor-only) DO_TESTS=0; shift ;;
    --tests-only)  DO_ANCHOR=0; shift ;;
    -h|--help)     sed -n '2,28p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" ;;
  esac
done

if [ -n "${TFIST:-}" ] && [ -n "${TFIST_BUILD:-}" ] && [ -n "${TFIST_ROOT:-}" ] && [ -n "${TFIST_EXAMPLES:-}" ]; then
  BIN="$TFIST"; BUILD="$TFIST_BUILD"; SRCROOT="$TFIST_ROOT"; EXAMPLES="$TFIST_EXAMPLES"
else
  OUT="$("$HERE/install_thermalfist.sh")" || die "install_thermalfist.sh failed"
  BIN="$(printf '%s\n' "$OUT" | sed -n 's/^TFIST=//p')"
  SRCROOT="$(printf '%s\n' "$OUT" | sed -n 's/^TFIST_ROOT=//p')"
  BUILD="$(printf '%s\n' "$OUT" | sed -n 's/^TFIST_BUILD=//p')"
  EXAMPLES="$(printf '%s\n' "$OUT" | sed -n 's/^TFIST_EXAMPLES=//p')"
fi
[ -x "$BIN" ] || die "no usable cpc1HRGTDep at '$BIN'"
[ -d "$BUILD" ] || die "no build directory at '$BUILD'"

# Identity: the tree must be the pinned commit, clean, and the build must be
# configured FROM that tree (CMakeCache binds build to source). A pre-set
# TFIST_* used to skip this, so a stray build next to the binary could certify.
PIN="${TFIST_PIN:-fe5c61af00cf84765afa4746120d0bdb58c419ae}"
check_identity () {
  local head cache_src src_canon
  [ -d "$SRCROOT/.git" ] || { log "'$SRCROOT' is not a git clone"; return 1; }
  head="$(cd "$SRCROOT" && git rev-parse HEAD 2>/dev/null || echo none)"
  [ "$head" = "$PIN" ] || { log "source tree is at $head, not the pinned $PIN"; return 1; }
  ( cd "$SRCROOT" && git diff --quiet HEAD 2>/dev/null ) || { log "source tree has uncommitted modifications"; return 1; }
  [ -f "$BUILD/CMakeCache.txt" ] || { log "no CMakeCache.txt in '$BUILD'; not a configured build"; return 1; }
  cache_src="$(sed -n 's/^ThermalFIST_SOURCE_DIR:STATIC=//p;s/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "$BUILD/CMakeCache.txt" | head -1)"
  src_canon="$(cd "$SRCROOT" && pwd -P)"
  if [ -n "$cache_src" ]; then
    local cc; cc="$(cd "$cache_src" 2>/dev/null && pwd -P || echo none)"
    [ "$cc" = "$src_canon" ] || { log "the build was configured from '$cc', not the pinned source '$src_canon'"; return 1; }
  fi
  case "$BIN" in "$BUILD"/*) : ;; *) log "the binary '$BIN' is not inside the build dir '$BUILD'"; return 1 ;; esac
  return 0
}
check_identity || die "refusing to certify: the build does not verifiably come from the pinned source (see above)"
log "identity OK: pinned commit, clean tree, build configured from that tree"

CERTIFIED=1
if [ "$EXPECTED_TESTS" != "$EXPECTED_TESTS_PINNED" ]; then
  log "NOTE: TFIST_EXPECTED_TESTS=$EXPECTED_TESTS overrides the pinned $EXPECTED_TESTS_PINNED;"
  log "      this run is NOT a tier-1 certification of v1.6.1"
  CERTIFIED=0
fi

FAILED=0

# ------------------------------------------------------------------ stage 1
if [ "$DO_ANCHOR" = "1" ]; then
  log "fast anchor: cpc1HRGTDep Ideal-HRG at T=$ANCHOR_T MeV"
  WD="$(mktemp -d)"
  if ! ( cd "$WD" && "$BIN" 0 ) >/dev/null 2>&1; then
    log "FAIL: cpc1HRGTDep exited nonzero"; FAILED=1
  elif python3 "$HERE/check_output_thermalfist.py" "$WD/cpc1.Id-HRG.TDep.out" \
        --row-at 0 "$ANCHOR_T" --expect 1 "$ANCHOR_P" 2 "$ANCHOR_E" 3 "$ANCHOR_S" \
        --accuracy "$ANCHOR_TOL"; then
    log "anchor: p/T^4, e/T^4, s/T^3 at T=$ANCHOR_T MeV reproduce the pinned values"
  else
    log "FAIL: the anchor thermodynamics do not match"; FAILED=1
  fi
  rm -rf "$WD"
fi

# ------------------------------------------------------------------ stage 2
if [ "$DO_TESTS" = "1" ]; then
  command -v ctest >/dev/null || die "ctest not found"
  LOG="$(mktemp)"
  log "running Thermal-FIST's own ctest suite SERIALLY (about 5 minutes)"
  # Force serial. -j1 AND CTEST_PARALLEL_LEVEL=1, because either alone can be
  # overridden: the env var wins over an absent -j, and a stray -j on the command
  # line would win over the env var. The Run/Compare pairs race under parallelism.
  set +e
  ( cd "$BUILD" && CTEST_PARALLEL_LEVEL=1 ctest -j1 ) > "$LOG" 2>&1
  CTEST_RC=$?
  set -e

  TOTAL="$(sed -nE 's/.* tests passed, [0-9]+ tests failed out of ([0-9]+).*/\1/p' "$LOG" | tail -1)"
  NFAIL="$(sed -nE 's/.* tests passed, ([0-9]+) tests failed out of [0-9]+.*/\1/p' "$LOG" | tail -1)"
  [ -n "$TOTAL" ] || { log "could not parse a ctest summary; last lines:"; tail -12 "$LOG" >&2; rm -f "$LOG"; exit 1; }

  # Exit status checked INDEPENDENTLY of the parsed text: a ctest that printed a
  # clean summary and then exited nonzero must not be accepted.
  if [ "$CTEST_RC" -ne 0 ] && [ "${NFAIL:-0}" -eq 0 ]; then
    log "FAIL: ctest exited $CTEST_RC while reporting no failures; the summary and status disagree"
    tail -12 "$LOG" >&2; FAILED=1
  fi
  # An EXACT count, never "at least": a suite that silently skipped cases (a
  # missing test binary, a configure without INCLUDE_TESTS) would otherwise pass.
  if [ "$TOTAL" != "$EXPECTED_TESTS" ]; then
    log "FAIL: ctest ran $TOTAL cases, expected exactly $EXPECTED_TESTS"
    log "      (set TFIST_EXPECTED_TESTS if you deliberately pinned a different version)"
    FAILED=1
  fi
  if [ "${NFAIL:-1}" -eq 0 ] && [ "$TOTAL" = "$EXPECTED_TESTS" ]; then
    log "test suite: $TOTAL of $TOTAL passed serially"
  elif [ "${NFAIL:-0}" -ne 0 ]; then
    log "FAIL: $NFAIL of $TOTAL ctest cases failed"
    grep -E "\(Failed\)|\(Not Run\)|\(Timeout\)" "$LOG" | head -25 >&2
    log "if these are Compare<X> failures, the suite was run in parallel; it MUST be serial (-j1)"
    FAILED=1
  fi
  rm -f "$LOG"
fi

if [ "$FAILED" = "0" ]; then
  if [ "$CERTIFIED" = "1" ]; then echo "VERIFY OK"; else echo "VERIFY PASSED-NOT-CERTIFIED"; fi
  exit 0
fi
echo "VERIFY FAILED"
exit 1

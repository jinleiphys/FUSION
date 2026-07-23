#!/bin/bash
# verify_smash.sh
#
# Reproduce SMASH's own test suite, then run a seeded physics anchor and check
# the conservation laws on it.
#
#   verify_smash.sh              both stages (about 8 minutes)
#   verify_smash.sh --tests-only
#   verify_smash.sh --anchor-only
#
# STAGE 1, the tier-1 evidence: SMASH ships 104 ctest cases and this reproduces
# them. Two of them are NOT deterministic, by upstream construction rather than
# by platform: src/tests/potentials.cc and src/tests/random.cc open with
#
#     TEST(set_random_seed) { std::random_device rd; random::set_seed(rd()); }
#
# and then assert statistical quantities to fixed tolerances, so they fail
# occasionally on a perfectly good build. Measured on macOS: `potentials` passed
# 4 of 5 consecutive standalone runs.
#
# The policy that follows is deliberately narrow. All 102 other tests must pass
# on the FIRST attempt; a single failure among them fails verification. Only
# those two named tests may be retried, once. A statistical fluke passes with a
# fresh seed; a genuinely broken build fails again. Do not widen this into
# "allow one failure", which is how a real regression walks through.
#
# STAGE 2: a seeded Au+Au run whose baryon number and electric charge are
# checked against the exact expectation. Those are conserved by the transport
# whatever the seed or platform, so they falsify a broken build in a way that
# comparing Monte Carlo multiplicities cannot.
#
# SMASH is GPL-3.0-or-later; see install_smash.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DO_TESTS=1
DO_ANCHOR=1
# The only tests permitted a retry, because they seed themselves from
# std::random_device. Keep this list minimal and justified.
FLAKY_TESTS="potentials random"
EXPECTED_TESTS="${SMASH_EXPECTED_TESTS:-104}"

log () { echo "verify_smash: $*" >&2; }
die () { log "$*"; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --tests-only)  DO_ANCHOR=0; shift ;;
    --anchor-only) DO_TESTS=0; shift ;;
    -h|--help)     sed -n '2,30p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" ;;
  esac
done

if [ -n "${SMASH:-}" ] && [ -n "${SMASH_BUILD:-}" ] && [ -n "${SMASH_ROOT:-}" ]; then
  BIN="$SMASH"; BUILD="$SMASH_BUILD"; SRCROOT="$SMASH_ROOT"; EIGEN="${SMASH_EIGEN3_ROOT:-}"
  GSL="${SMASH_GSL_PREFIX:-}"; PYPFX="${SMASH_PYTHIA_PREFIX:-}"
else
  OUT="$("$HERE/install_smash.sh")" || die "install_smash.sh failed"
  BIN="$(printf '%s\n' "$OUT" | sed -n 's/^SMASH=//p')"
  BUILD="$(printf '%s\n' "$OUT" | sed -n 's/^SMASH_BUILD=//p')"
  SRCROOT="$(printf '%s\n' "$OUT" | sed -n 's/^SMASH_ROOT=//p')"
  EIGEN="$(printf '%s\n' "$OUT" | sed -n 's/^SMASH_EIGEN3_ROOT=//p')"
  GSL="$(printf '%s\n' "$OUT" | sed -n 's/^SMASH_GSL_PREFIX=//p')"
  PYPFX="$(printf '%s\n' "$OUT" | sed -n 's/^SMASH_PYTHIA_PREFIX=//p')"
fi
[ -x "$BIN" ] || die "no usable SMASH executable"
[ -d "$BUILD" ] || die "no build directory at '$BUILD'"

FAILED=0

# The usage_of_SMASH_as_library test spawns a FRESH cmake for the library
# example, and that child inherits NONE of this build's -D cache variables, so
# every hint has to reach it through the ENVIRONMENT. Three were needed, each
# discovered by a different failure:
#   EIGEN3_ROOT     macOS, where the system Eigen is a 5.x it cannot parse
#   GSL hints       a cluster where GSL lives only inside a conda prefix
#   LD_LIBRARY_PATH the example BUILDS and then fails to RUN, because Pythia is
#                   installed under a custom prefix with no rpath
run_ctest () {
  ( cd "$BUILD" \
    && EIGEN3_ROOT="$EIGEN" \
       GSL_ROOT_DIR="$GSL" \
       PKG_CONFIG_PATH="${GSL:+$GSL/lib/pkgconfig:}${PKG_CONFIG_PATH:-}" \
       CMAKE_PREFIX_PATH="${GSL:+$GSL:}${CMAKE_PREFIX_PATH:-}" \
       LD_LIBRARY_PATH="${PYPFX:+$PYPFX/lib:}${GSL:+$GSL/lib:}${LD_LIBRARY_PATH:-}" \
       DYLD_LIBRARY_PATH="${PYPFX:+$PYPFX/lib:}${GSL:+$GSL/lib:}${DYLD_LIBRARY_PATH:-}" \
       ctest "$@" )
}

# ------------------------------------------------------------------ stage 1
if [ "$DO_TESTS" = "1" ]; then
  command -v ctest >/dev/null || die "ctest not found"
  LOG="$(mktemp)"
  log "running SMASH's own test suite (about 6 minutes)"
  set +e
  run_ctest -j"$( (command -v nproc >/dev/null && nproc) || sysctl -n hw.ncpu 2>/dev/null || echo 4 )" > "$LOG" 2>&1
  set -e

  TOTAL="$(sed -nE 's/.* tests passed, [0-9]+ tests failed out of ([0-9]+).*/\1/p' "$LOG" | tail -1)"
  NFAIL="$(sed -nE 's/.* tests passed, ([0-9]+) tests failed out of [0-9]+.*/\1/p' "$LOG" | tail -1)"
  [ -n "$TOTAL" ] || { log "could not parse a ctest summary; last lines:"; tail -10 "$LOG" >&2; rm -f "$LOG"; exit 1; }

  # An EXACT count, never "at least": a suite that silently skipped cases would
  # otherwise certify the build.
  if [ "$TOTAL" != "$EXPECTED_TESTS" ]; then
    log "FAIL: ctest ran $TOTAL cases, expected exactly $EXPECTED_TESTS"
    log "      (set SMASH_EXPECTED_TESTS if you deliberately pinned a different SMASH version)"
    FAILED=1
  fi

  if [ "${NFAIL:-0}" -eq 0 ]; then
    log "test suite: $TOTAL of $TOTAL passed on the first attempt"
  else
    FAILING="$(sed -nE 's/^[[:space:]]+[0-9]+ - ([A-Za-z0-9_]+) \(Failed\).*/\1/p' "$LOG" | sort -u)"
    [ -n "$FAILING" ] || { log "FAIL: $NFAIL tests failed but their names could not be parsed"; tail -10 "$LOG" >&2; FAILED=1; FAILING=""; }
    for t in $FAILING; do
      case " $FLAKY_TESTS " in
        *" $t "*)
          log "'$t' failed; it seeds itself from std::random_device, so retrying it once"
          set +e
          run_ctest -R "^$t\$" > "$LOG.retry" 2>&1
          RC=$?
          set -e
          if [ "$RC" -eq 0 ]; then
            log "'$t' passed on retry, which is what a statistical fluke does"
          else
            log "FAIL: '$t' failed twice, so this is not statistical"
            tail -15 "$LOG.retry" >&2
            FAILED=1
          fi
          rm -f "$LOG.retry"
          ;;
        *)
          log "FAIL: '$t' failed, and it is not one of the self-seeded tests ($FLAKY_TESTS)"
          FAILED=1
          ;;
      esac
    done
  fi
  rm -f "$LOG"
fi

# ------------------------------------------------------------------ stage 2
if [ "$DO_ANCHOR" = "1" ]; then
  CFG="$SRCROOT/input/config.yaml"
  [ -s "$CFG" ] || die "the shipped collider config is missing from '$CFG'"
  # Au+Au: 2 events x 2 nuclei x 197 nucleons = 788 baryons, x 79 protons = 316 e.
  WORK="$(mktemp -d)"
  log "running the seeded Au+Au anchor (2 events, 20 fm/c)"
  if ! SMASH="$BIN" "$HERE/run_smash.sh" --config "$CFG" --outdir "$WORK/run" \
        --seed 20260723 --nevents 2 --end-time 20.0 >/dev/null; then
    log "FAIL: the anchor run did not complete"
    FAILED=1
  elif python3 "$HERE/check_conservation_smash.py" "$WORK/run/out/particle_lists.oscar" \
        --baryons 788 --charge 316; then
    log "anchor: conservation laws hold exactly"
  else
    log "FAIL: the anchor run violates a conservation law"
    FAILED=1
  fi
  rm -rf "$WORK"
fi

if [ "$FAILED" = "0" ]; then
  echo "VERIFY OK"
  exit 0
fi
echo "VERIFY FAILED"
exit 1

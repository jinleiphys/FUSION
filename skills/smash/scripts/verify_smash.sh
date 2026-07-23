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
# 104 is the count for the pinned SMASH-3.3. An override is allowed for a
# deliberately different pin, but then the run is NOT tier-1 certifying and says
# so, because "reproduces the shipped suite" means the shipped suite.
EXPECTED_TESTS_PINNED=104
EXPECTED_TESTS="${SMASH_EXPECTED_TESTS:-$EXPECTED_TESTS_PINNED}"

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
  PRESET=1
else
  PRESET=0
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

# Pre-set SMASH/SMASH_BUILD/SMASH_ROOT used to skip every identity check, so a
# fake build directory next to the real binary certified tier 1.
#
# What this check is FOR, stated honestly: it catches the wrong build being
# certified by MISTAKE, which is the failure that actually happens. It is not
# an adversarial boundary and cannot be one, because everything it inspects
# lives inside a directory the caller can write. Do not add checks that only
# look like security; add checks that bind the binary to the pinned source.
#
# The binding that does real work is CMakeCache.txt: cmake records the source
# and build directories it was configured with, so a build directory borrowed
# from some other SMASH, or a cache copied in from elsewhere, is caught. The
# git pin plus a clean tree fixes WHICH source that is.
#
# What is deliberately NOT gated: the binary's SHA-256. SMASH's own
# `usage_of_SMASH_as_library` ctest case reruns cmake and `make install`, which
# RELINKS build/smash, so after any full verify the binary no longer matches the
# digest install_smash.sh stamped. Measured on macOS: two consecutive relinks of
# an unchanged source tree produced three different digests, because the link is
# not reproducible. Gating on that digest rejected legitimate builds and, since
# the stamp file is writable by anyone who can write the binary, bought no
# safety in exchange. The stamp's build-identity line (commit, tree state,
# compiler, dependency versions) IS stable across a relink, so that is what is
# checked; a digest mismatch is reported as a note, not a failure.
PIN="${SMASH_PIN:-d1a1c6cf0a0002ee064eec1b929b9a7c14b3d5bc}"
canon () { ( cd "$1" 2>/dev/null && pwd -P ); }
cache_value () {   # cache_value <key>: read a CMakeCache.txt INTERNAL entry
  sed -nE "s|^$1:[A-Z]+=(.*)$|\1|p" "$BUILD/CMakeCache.txt" 2>/dev/null | head -1
}
check_identity () {
  local head stamp
  [ -d "$SRCROOT/.git" ] || { log "'$SRCROOT' is not a git clone, so its commit cannot be established"; return 1; }
  head="$(cd "$SRCROOT" && git rev-parse HEAD 2>/dev/null || echo none)"
  [ "$head" = "$PIN" ] || { log "source tree is at $head, not the pinned $PIN"; return 1; }
  ( cd "$SRCROOT" && git diff --quiet HEAD 2>/dev/null ) || { log "source tree has uncommitted modifications"; return 1; }

  local csrc cbld wsrc wbld
  [ -f "$BUILD/CMakeCache.txt" ] || {
    log "no CMakeCache.txt in '$BUILD'; that directory is not a cmake build tree"; return 1; }
  wsrc="$(canon "$SRCROOT")"; wbld="$(canon "$BUILD")"
  csrc="$(canon "$(cache_value CMAKE_HOME_DIRECTORY)")"
  cbld="$(canon "$(cache_value CMAKE_CACHEFILE_DIR)")"
  [ -n "$csrc" ] && [ "$csrc" = "$wsrc" ] || {
    log "the build in '$BUILD' was configured from '$(cache_value CMAKE_HOME_DIRECTORY)', not from the pinned source '$wsrc'"
    return 1; }
  [ -n "$cbld" ] && [ "$cbld" = "$wbld" ] || {
    log "the CMakeCache.txt in '$BUILD' belongs to build directory '$(cache_value CMAKE_CACHEFILE_DIR)'; it was copied here"
    return 1; }

  # Canonicalised, so a symlink pointing out of the build tree is caught.
  local cbin
  cbin="$(canon "$(dirname "$BIN")")/$(basename "$BIN")"
  case "$cbin" in
    "$wbld"/*) : ;;
    *) log "the binary '$BIN' does not live inside the build directory '$wbld'"; return 1 ;;
  esac
  # A shell script that prints a SMASH banner satisfies every textual check
  # there is; requiring a native executable rules that whole class out. Match
  # the object format POSITIVELY (Mach-O on macOS, ELF on Linux): a pattern of
  # '*executable*' does NOT work, because `file` describes a shell script as
  # "Bourne-Again shell script text executable" and the stub sailed through.
  local ftype
  ftype="$(file -b "$cbin" 2>/dev/null)"
  case "$ftype" in
    Mach-O*|ELF*) : ;;
    *) log "'$BIN' is not a native executable (file says: $ftype)"; return 1 ;;
  esac
  local ver want_ver
  ver="$("$BIN" --version 2>/dev/null | head -1)" || { log "'$BIN' --version exited nonzero"; return 1; }
  want_ver="$(cd "$SRCROOT" && git describe 2>/dev/null || echo unknown)"
  [ "$ver" = "$want_ver" ] || {
    log "'$BIN' reports version '$ver' but the pinned source describes as '$want_ver'"; return 1; }

  stamp="$BUILD/.fusion_build_stamp"
  [ -f "$stamp" ] || { log "no build stamp at $stamp; this build was not produced by install_smash.sh"; return 1; }
  # Line 1 is "<commit>|<clean|DIRTY>|<compiler>|<pythia>|<eigen>|<gsl>|<os>|<arch>"
  # and survives a relink; line 2 is the digest and does not.
  local sid
  sid="$(head -1 "$stamp")"
  case "$sid" in
    "$PIN|clean|"*) : ;;
    *) log "the build stamp records identity '$sid', which is not a clean build of the pinned commit"; return 1 ;;
  esac
  if [ "$(sed -n 2p "$stamp")" != "$(shasum -a 256 "$cbin" 2>/dev/null | cut -d' ' -f1)" ]; then
    log "note: the binary has been relinked since it was stamped, which SMASH's own"
    log "      usage_of_SMASH_as_library test does on every full verify. Not an error."
  fi
  return 0
}
if ! check_identity; then
  die "refusing to certify: the build does not verifiably come from the pinned source (see above)"
fi
log "identity OK: pinned commit, clean tree, stamped binary"

FAILED=0
CERTIFIED=1

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
  CTEST_RC=$?
  set -e

  TOTAL="$(sed -nE 's/.* tests passed, [0-9]+ tests failed out of ([0-9]+).*/\1/p' "$LOG" | tail -1)"
  NFAIL="$(sed -nE 's/.* tests passed, ([0-9]+) tests failed out of [0-9]+.*/\1/p' "$LOG" | tail -1)"
  [ -n "$TOTAL" ] || { log "could not parse a ctest summary; last lines:"; tail -10 "$LOG" >&2; rm -f "$LOG"; exit 1; }

  # The exit status is checked INDEPENDENTLY of the parsed text. A ctest that
  # printed a clean "104 of 104" summary and then exited nonzero used to be
  # accepted, because only the text was read.
  if [ "$CTEST_RC" -ne 0 ] && [ "${NFAIL:-0}" -eq 0 ]; then
    log "FAIL: ctest exited $CTEST_RC while reporting no failures; the summary and the status disagree"
    tail -10 "$LOG" >&2
    FAILED=1
  fi

  # An EXACT count, never "at least": a suite that silently skipped cases would
  # otherwise certify the build.
  if [ "$EXPECTED_TESTS" != "$EXPECTED_TESTS_PINNED" ]; then
    log "NOTE: SMASH_EXPECTED_TESTS=$EXPECTED_TESTS overrides the pinned $EXPECTED_TESTS_PINNED;"
    log "      this run is NOT a tier-1 certification of the pinned release"
    # A note on stderr was not enough. The run still ended in "VERIFY OK" and
    # exit 0, so any caller reading either signal, including this skill's own
    # documentation, would record a certification that did not happen. The
    # final verdict line has to carry the caveat, because that is what gets read.
    CERTIFIED=0
  fi
  if [ "$TOTAL" != "$EXPECTED_TESTS" ]; then
    log "FAIL: ctest ran $TOTAL cases, expected exactly $EXPECTED_TESTS"
    log "      (set SMASH_EXPECTED_TESTS if you deliberately pinned a different SMASH version)"
    FAILED=1
  fi

  if [ "${NFAIL:-0}" -eq 0 ]; then
    log "test suite: $TOTAL of $TOTAL passed on the first attempt"
  else
    # Parse EVERY ctest failure status, not only "(Failed)": a case that timed
    # out or was not run is still a failure, and matching only "(Failed)" let a
    # real regression through while the one self-seeded flake was retried.
    FAILING="$(sed -nE 's/^[[:space:]]+[0-9]+ - ([A-Za-z0-9_.-]+) \(([A-Za-z ]+)\).*/\1/p' "$LOG" | sort -u)"
    NPARSED="$(printf '%s\n' "$FAILING" | grep -c . || true)"
    # The number of names parsed must equal the number ctest reported, or
    # something was missed and the retry logic below is reasoning about a
    # different set than the one that actually failed.
    if [ "${NPARSED:-0}" -ne "${NFAIL:-0}" ]; then
      log "FAIL: ctest reported $NFAIL failures but $NPARSED names could be parsed; refusing to guess"
      sed -nE 's/^[[:space:]]+[0-9]+ - .*/&/p' "$LOG" | head -10 >&2
      FAILED=1
      FAILING=""
    fi
    for t in $FAILING; do
      case " $FLAKY_TESTS " in
        *" $t "*)
          log "'$t' failed; it seeds itself from std::random_device, so retrying it once"
          set +e
          run_ctest -R "^$t\$" > "$LOG.retry" 2>&1
          RC=$?
          set -e
          # Exit status alone is not enough: `ctest -R` that matches NOTHING
          # prints "No tests were found!!!" and exits 0, which used to be read
          # as a clean retry. Require exactly one test selected and passed.
          RTOTAL="$(sed -nE 's/.* tests passed, [0-9]+ tests failed out of ([0-9]+).*/\1/p' "$LOG.retry" | tail -1)"
          RFAIL="$(sed -nE 's/.* tests passed, ([0-9]+) tests failed out of [0-9]+.*/\1/p' "$LOG.retry" | tail -1)"
          if [ "$RC" -eq 0 ] && [ "${RTOTAL:-0}" = "1" ] && [ "${RFAIL:-1}" = "0" ]; then
            log "'$t' passed on retry (1 of 1), which is what a statistical fluke does"
          else
            log "FAIL: retry of '$t' did not cleanly pass exactly one test (rc=$RC, total=${RTOTAL:-none}, failed=${RFAIL:-none})"
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
  # Deliberately NOT a superstring of "VERIFY OK": a caller grepping for that
  # must not match the uncertified verdict.
  if [ "$CERTIFIED" = "0" ]; then
    echo "VERIFY PASSED-NOT-CERTIFIED (the expected test count was overridden, so this"
    echo "  run does not certify the pinned SMASH-3.3 release at tier 1)"
    exit 0
  fi
  echo "VERIFY OK"
  exit 0
fi
echo "VERIFY FAILED"
exit 1

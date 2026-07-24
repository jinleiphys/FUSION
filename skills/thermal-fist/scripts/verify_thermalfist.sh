#!/bin/bash
# verify_thermalfist.sh
#
# Stages:
#   verify_thermalfist.sh              anchor + ctest suite + cpc3 (about 5 min)
#   verify_thermalfist.sh --anchor-only   fast deterministic physics anchor
#   verify_thermalfist.sh --tests-only    the shipped ctest suite + cpc3 only
#
# STAGE 1, the fast anchor: run cpc1HRGTDep in Ideal-HRG mode and compare its FULL
# output (181 rows, 7 numeric columns) against the shipped reference within the
# code's own 1e-6 tolerance, plus a named physics row at T = 150 MeV. Self-checks
# a grossly broken build in seconds.
#
# STAGE 2, the tier-1 evidence: reproduce Thermal-FIST's OWN shipped ctest suite,
# 93 cases, comparing each cpc/EoS example against test/ReferenceOutput with the
# code's own 1e-6 comparator (NOT a byte match; upstream flags cpc1 as
# compiler-dependent). All 93 must PASS; skipped or not-run cases are rejected,
# not counted as passes.
#
# STAGE 3, cpc3: the shipped ctest suite does NOT include cpc3 (its RunCPC3 /
# CompareCPC3 entries are commented out upstream), so this stage runs both cpc3
# configs and compares their numeric columns against the shipped reference, so
# cpc3 is covered rather than merely assumed.
#
# THE CTEST SUITE MUST RUN SERIALLY. The Run<X> and Compare<X> tests share an
# output file with NO declared dependency, so `ctest -j` lets a Compare read the
# file before the matching Run wrote it, and 21 of 26 comparisons fail
# spuriously. This script forces -j1 and clears CTEST_PARALLEL_LEVEL.
#
# Thermal-FIST is GPL-3.0; see install_thermalfist.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DO_ANCHOR=1
DO_TESTS=1
# T = 150 MeV Ideal-HRG at mu = 0: p/T^4, e/T^4, s/T^3. A sensible HRG value below
# the QCD crossover. The literals are the shipped reference values (6 decimals),
# so a fresh run agrees to <= 1e-6; the row tolerance carries the print rounding.
ANCHOR_T=150
ANCHOR_P=0.647513
ANCHOR_E=3.846843
ANCHOR_S=4.494356
ANCHOR_ROW_TOL=1e-5
REF_TOL=1e-6
ANCHOR_ROWS=181
ANCHOR_COLS=7
# The immutable pin of release v1.6.1. A DIFFERENT pin may be built and tested,
# but the run is then explicitly NOT a tier-1 certification of v1.6.1.
CANON_PIN=fe5c61af00cf84765afa4746120d0bdb58c419ae
PIN="${TFIST_PIN:-$CANON_PIN}"
EXPECTED_TESTS_PINNED=93
EXPECTED_TESTS="${TFIST_EXPECTED_TESTS:-$EXPECTED_TESTS_PINNED}"

log () { echo "verify_thermalfist: $*" >&2; }
die () { log "$*"; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --anchor-only) DO_TESTS=0; shift ;;
    --tests-only)  DO_ANCHOR=0; shift ;;
    -h|--help)     sed -n '2,32p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" ;;
  esac
done

# A pin is a 40-hex commit hash. Validating the FORMAT also blocks an
# option-injection like TFIST_PIN=--detach reaching git as a flag.
printf '%s' "$PIN" | grep -qE '^[0-9a-f]{40}$' || die "TFIST_PIN must be a 40-character hex commit hash, got '$PIN'"

CERTIFIED=1
if [ "$PIN" != "$CANON_PIN" ]; then
  log "NOTE: TFIST_PIN=$PIN is not the release v1.6.1 hash; this run is NOT a tier-1 certification"
  CERTIFIED=0
fi
if [ "$EXPECTED_TESTS" != "$EXPECTED_TESTS_PINNED" ]; then
  log "NOTE: TFIST_EXPECTED_TESTS=$EXPECTED_TESTS overrides the pinned $EXPECTED_TESTS_PINNED; NOT a tier-1 certification"
  CERTIFIED=0
fi

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

# Canonicalize a path, following symlinks, or print nothing.
canon () { cd "$1" 2>/dev/null && pwd -P || true; }

# A tree is pristine iff there are no tracked modifications AND no untracked
# files, INCLUDING git-ignored ones. `git status --porcelain` and
# `git diff --quiet HEAD` both skip ignored files, so an injected source added to
# .git/info/exclude would pass them while a glob build still compiled it.
# `git ls-files --others` (no --exclude-standard) lists every untracked file.
tree_pristine () {
  ( cd "$1" 2>/dev/null && git diff --quiet HEAD 2>/dev/null && [ -z "$(git ls-files --others 2>/dev/null)" ] )
}

# Identity: the tree must be the pinned commit, clean, and the build must be
# CONFIGURED FROM that tree (both CMake cache variables must be present, both
# must equal the canonical source, and INCLUDE_TESTS must be ON). The binary must
# be a regular file whose canonical path lies inside the canonical build dir.
check_identity () {
  local head src_canon cache
  [ -d "$SRCROOT/.git" ] || { log "'$SRCROOT' is not a git clone"; return 1; }
  head="$(cd "$SRCROOT" && git rev-parse HEAD 2>/dev/null || echo none)"
  [ "$head" = "$PIN" ] || { log "source tree is at $head, not the pin $PIN"; return 1; }
  tree_pristine "$SRCROOT" || { log "source tree has tracked modifications or untracked files (including ignored)"; return 1; }
  src_canon="$(canon "$SRCROOT")"
  [ -n "$src_canon" ] || { log "cannot canonicalize source '$SRCROOT'"; return 1; }
  cache="$BUILD/CMakeCache.txt"
  [ -f "$cache" ] || { log "no CMakeCache.txt in '$BUILD'; not a configured build"; return 1; }
  # BOTH source-dir variables must be present and both must resolve to the pinned
  # source. An empty or partial cache no longer skips the binding.
  local v1 v2 c1 c2
  v1="$(sed -n 's/^ThermalFIST_SOURCE_DIR:[A-Z]*=//p' "$cache" | head -1)"
  v2="$(sed -n 's/^CMAKE_HOME_DIRECTORY:[A-Z]*=//p' "$cache" | head -1)"
  [ -n "$v1" ] && [ -n "$v2" ] || { log "CMakeCache is missing its source-dir bindings; not a real configured build"; return 1; }
  c1="$(canon "$v1")"; c2="$(canon "$v2")"
  [ "$c1" = "$src_canon" ] || { log "the build's ThermalFIST_SOURCE_DIR ('$c1') is not the pinned source ('$src_canon')"; return 1; }
  [ "$c2" = "$src_canon" ] || { log "the build's CMAKE_HOME_DIRECTORY ('$c2') is not the pinned source ('$src_canon')"; return 1; }
  grep -qE '^INCLUDE_TESTS:BOOL=(ON|1|TRUE|YES)$' "$cache" || { log "the build was configured WITHOUT -DINCLUDE_TESTS=ON; the ctest suite is absent"; return 1; }
  # The binary must be a regular file inside the canonical build dir, not a
  # symlink pointing outside it.
  [ -f "$BIN" ] && [ ! -L "$BIN" ] || { log "the binary '$BIN' is missing or is a symlink"; return 1; }
  local bin_canon build_canon
  bin_canon="$(canon "$(dirname "$BIN")")/$(basename "$BIN")"
  build_canon="$(canon "$BUILD")"
  case "$bin_canon/" in "$build_canon"/*) : ;; *) log "the binary '$bin_canon' is not inside the build dir '$build_canon'"; return 1 ;; esac
  return 0
}
check_identity || die "refusing to certify: the build does not verifiably come from the pinned source (see above)"
log "identity OK: pinned commit, clean tree, build configured from that tree with tests on"

# The example binaries used by the anchor and by stage 3 must come from the
# identity-checked BUILD, NOT from a caller-supplied TFIST_EXAMPLES that could
# point at an external stub. Derive them from BUILD and require non-symlink
# regular files inside it.
EXAMPLES="$BUILD/bin/examples"
CPC1BIN="$EXAMPLES/cpc1HRGTDep"
CPC3BIN="$EXAMPLES/cpc3chi2NEQ"
for e in "$CPC1BIN" "$CPC3BIN"; do
  [ -f "$e" ] && [ ! -L "$e" ] || die "example binary '$e' is missing or a symlink; the build is not intact"
done
# The anchor uses cpc1 from the build, not the possibly-external $BIN.
BIN="$CPC1BIN"

FAILED=0

# ------------------------------------------------------------------ stage 1
if [ "$DO_ANCHOR" = "1" ]; then
  log "fast anchor: cpc1HRGTDep Ideal-HRG, full output vs shipped reference"
  WD="$(mktemp -d)"
  REF="$SRCROOT/test/ReferenceOutput/cpc1.Id-HRG.TDep.out"
  if ! ( cd "$WD" && "$BIN" 0 ) >/dev/null 2>&1; then
    log "FAIL: cpc1HRGTDep exited nonzero"; FAILED=1
  elif [ ! -s "$REF" ]; then
    log "FAIL: the shipped reference $REF is missing"; FAILED=1
  elif ! python3 "$HERE/check_output_thermalfist.py" "$WD/cpc1.Id-HRG.TDep.out" \
        --min-rows "$ANCHOR_ROWS" --min-cols "$ANCHOR_COLS" --reference "$REF" --accuracy "$REF_TOL" >/dev/null; then
    log "FAIL: the cpc1 output does not reproduce the shipped reference within $REF_TOL (or is truncated)"; FAILED=1
  elif python3 "$HERE/check_output_thermalfist.py" "$WD/cpc1.Id-HRG.TDep.out" \
        --row-at 0 "$ANCHOR_T" --expect 1 "$ANCHOR_P" 2 "$ANCHOR_E" 3 "$ANCHOR_S" --accuracy "$ANCHOR_ROW_TOL" >/dev/null; then
    log "anchor: full cpc1 output reproduces the reference, and T=$ANCHOR_T MeV row matches the pinned values"
  else
    log "FAIL: the anchor thermodynamics row does not match"; FAILED=1
  fi
  rm -rf "$WD"
fi

# ------------------------------------------------------------------ stage 2
if [ "$DO_TESTS" = "1" ]; then
  command -v ctest >/dev/null || die "ctest not found"
  LOG="$(mktemp)"
  log "running Thermal-FIST's own ctest suite SERIALLY (about 5 minutes)"
  set +e
  ( cd "$BUILD" && CTEST_PARALLEL_LEVEL=1 ctest -j1 ) > "$LOG" 2>&1
  CTEST_RC=$?
  set -e

  TOTAL="$(sed -nE 's/.* tests passed, [0-9]+ tests failed out of ([0-9]+).*/\1/p' "$LOG" | tail -1)"
  NFAIL="$(sed -nE 's/.* tests passed, ([0-9]+) tests failed out of [0-9]+.*/\1/p' "$LOG" | tail -1)"
  [ -n "$TOTAL" ] || { log "could not parse a ctest summary; last lines:"; tail -12 "$LOG" >&2; rm -f "$LOG"; exit 1; }

  # A test that SKIPPED or was NOT RUN is not a pass. ctest counts skips as
  # non-failures, so "93 passed, 0 failed" can be 93 skips. Count the actual
  # "Passed" per-test lines and require exactly EXPECTED, and reject any skip.
  PASSED_CT="$(grep -cE '   Passed +[0-9]' "$LOG" || true)"
  SKIP_CT="$(grep -cE '\*\*\*(Skipped|Not Run|Disabled|Timeout|Exception|Failed)' "$LOG" || true)"

  # ctest passes ONLY if ALL of these hold. Each is checked independently so no
  # single spoofed signal (a summary line, a Passed-line count) can carry the
  # verdict alone. A nonzero exit or a nonzero reported failure count is ALWAYS a
  # failure, regardless of how many "Passed" lines were printed.
  if [ "$CTEST_RC" -ne 0 ]; then
    log "FAIL: ctest exited $CTEST_RC"; tail -12 "$LOG" >&2; FAILED=1
  fi
  if [ "${NFAIL:-1}" -ne 0 ]; then
    log "FAIL: ctest reported $NFAIL failed cases"; FAILED=1
  fi
  if [ "$TOTAL" != "$EXPECTED_TESTS" ]; then
    log "FAIL: ctest ran $TOTAL cases, expected exactly $EXPECTED_TESTS (a configure without -DINCLUDE_TESTS gives 0)"
    FAILED=1
  fi
  if [ "${SKIP_CT:-1}" -ne 0 ]; then
    log "FAIL: $SKIP_CT ctest cases were skipped, not-run, disabled, timed out, or failed; a skipped case is NOT a pass"
    grep -E '\*\*\*(Skipped|Not Run|Disabled|Timeout|Exception|Failed)' "$LOG" | head -20 >&2
    FAILED=1
  fi
  if [ "${PASSED_CT:-0}" -ne "$EXPECTED_TESTS" ]; then
    log "FAIL: $PASSED_CT cases actually Passed, expected $EXPECTED_TESTS to have run and passed"
    log "      if these are Compare<X> failures, the suite was run in parallel; it MUST be serial (-j1)"
    FAILED=1
  fi
  if [ "$CTEST_RC" -eq 0 ] && [ "${NFAIL:-1}" -eq 0 ] && [ "$TOTAL" = "$EXPECTED_TESTS" ] \
     && [ "${SKIP_CT:-1}" -eq 0 ] && [ "${PASSED_CT:-0}" -eq "$EXPECTED_TESTS" ]; then
    log "test suite: $PASSED_CT of $TOTAL Passed serially, 0 skipped, 0 failed"
  fi
  rm -f "$LOG"

  # ---------------------------------------------------------------- stage 3
  # cpc3 is not in the ctest suite. Cover it here, but honestly: the EQUILIBRIUM
  # fit (config 0, gammaq=gammaS=1 fixed) is well-constrained and reproduces the
  # shipped reference within 1e-6, so it is compared strictly. The chemically-
  # frozen NEQ fit (config 1, gammaq and gammaS free) is under-constrained and
  # lands on a different minimum per build (muB differs by MeV, not the last
  # digit), which is exactly why upstream leaves cpc3 out of its suite; it is
  # therefore validated STRUCTURALLY only (runs, 5 rows, 9 numeric cols, finite),
  # never compared numerically.
  for spec in "0:cpc3.EQ.chi2.out:strict" "1:cpc3.NEQ.chi2.out:structure"; do
    cfg="${spec%%:*}"; rest="${spec#*:}"; fn="${rest%%:*}"; mode="${rest#*:}"
    cwd="$(mktemp -d)"; ref="$SRCROOT/test/ReferenceOutput/$fn"
    if ! ( cd "$cwd" && "$CPC3BIN" "$cfg" ) >/dev/null 2>&1; then
      log "FAIL: cpc3chi2NEQ $cfg exited nonzero"; FAILED=1
    elif [ "$mode" = "strict" ]; then
      if [ ! -s "$ref" ]; then
        log "FAIL: cpc3 reference $ref missing"; FAILED=1
      elif python3 "$HERE/check_output_thermalfist.py" "$cwd/$fn" --reference "$ref" --accuracy "$REF_TOL" >/dev/null; then
        log "cpc3 $fn (equilibrium fit) reproduces the shipped reference within $REF_TOL"
      else
        log "FAIL: cpc3 $fn does not reproduce the shipped reference within $REF_TOL"; FAILED=1
      fi
    else
      if python3 "$HERE/check_output_thermalfist.py" "$cwd/$fn" --rows 5 --cols 9 >/dev/null; then
        log "cpc3 $fn (NEQ fit) runs and is structurally valid (under-constrained, not compared)"
      else
        log "FAIL: cpc3 $fn is structurally invalid"; FAILED=1
      fi
    fi
    rm -rf "$cwd"
  done
fi

if [ "$FAILED" = "0" ]; then
  if [ "$CERTIFIED" = "1" ]; then echo "VERIFY OK"; else echo "VERIFY PASSED-NOT-CERTIFIED"; fi
  exit 0
fi
echo "VERIFY FAILED"
exit 1

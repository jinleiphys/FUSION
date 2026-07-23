#!/bin/bash
# verify_gibuu.sh
#
#   verify_gibuu.sh                 all stages (about 2 minutes)
#   verify_gibuu.sh --stage <n>     run one stage only (1, 2 or 3)
#
# WHAT TIER THIS IS, AND WHY. GiBUU ships NO reference output: there is no
# .ref file, no expected-result table, and the `testRun` directories hold test
# PROGRAMS rather than comparison data. So the tier-1 route used by SMASH and
# SWANLOP, "reproduce the numbers the distribution shipped", does not exist
# here. This is a TIER 2 skill in the same sense as pikoe: its goal is input
# alignment, and it is verified as builds + runs + reproduces itself + is
# internally consistent, with build integrity carried by cross-build
# reproduction rather than by an author's reference file.
#
# The three stages, and what each is actually worth:
#
#   1. DETERMINISM, both directions. The same non-zero seed must give
#      bit-identical output, and a different seed must NOT. The second half
#      matters: without it, a run that ignored the seed entirely and wrote a
#      constant would pass the first half perfectly.
#
#   2. REGRESSION against pinned values. These values were measured on this
#      pinned release and are bit-identical across macOS/ARM (gfortran 15.2)
#      and Linux/x86-64 (gfortran 13.3). That cross-build agreement is the
#      build-integrity evidence; this stage is the cheap daily re-check of it,
#      not a re-run of it. See references/verification.md.
#
#   3. A BOOKKEEPING IDENTITY, and it is deliberately not called a physics
#      check. The pion analysis writes the total by two routes: column 7 is
#      quasi-elastic plus absorption, column 8 is the flux that interacted.
#      Reading code/analysis/LoPionAnalysis.f90, absorption is "total minus all
#      escaping pions" and column 8 is "total minus non-interacting pions", so
#      the two agree BY CONSTRUCTION as set complements. It catches a lost or
#      double-counted event and nothing else. It would hold with the physics
#      entirely wrong, and is reported that way rather than dressed up as an
#      optical theorem.
#
# NOTHING HERE VALIDATES GiBUU's PHYSICS. That is not a gap this script can
# close, and no number it prints should be quoted as a benchmark.
#
# GiBUU is GPL-2.0; see install_gibuu.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE=0
FAILED=0

log () { echo "verify_gibuu: $*" >&2; }
die () { log "$*"; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --stage) STAGE="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" ;;
  esac
done
case "$STAGE" in 0|1|2|3) : ;; *) die "--stage must be 1, 2 or 3" ;; esac

if [ -n "${GIBUU:-}" ] && [ -n "${GIBUU_INPUT:-}" ] && [ -n "${GIBUU_ROOT:-}" ]; then
  BIN="$GIBUU"; SRCROOT="$GIBUU_ROOT"
else
  OUT="$("$HERE/install_gibuu.sh")" || die "install_gibuu.sh failed"
  BIN="$(printf '%s\n' "$OUT" | sed -n 's/^GIBUU=//p')"
  SRCROOT="$(printf '%s\n' "$OUT" | sed -n 's/^GIBUU_ROOT=//p')"
  export GIBUU="$BIN"
  export GIBUU_INPUT="$(printf '%s\n' "$OUT" | sed -n 's/^GIBUU_INPUT=//p')"
  export GIBUU_LIBPATH="$(printf '%s\n' "$OUT" | sed -n 's/^GIBUU_LIBPATH=//p')"
fi
[ -x "$BIN" ] || die "no usable GiBUU executable"

CARD="$SRCROOT/testRun/jobCards/002_Pion.job"
[ -s "$CARD" ] || die "the shipped pion job card is missing from '$CARD'"
XS=pionInduced_xSections.dat
SEED=20260723
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

runcase () {   # runcase <name> <seed>
  "$HERE/run_gibuu.sh" --jobcard "$CARD" --outdir "$WORK/$1" --seed "$2" >/dev/null 2>&1
}

# --------------------------------------------------------------- stage 1
if [ "$STAGE" = "0" ] || [ "$STAGE" = "1" ]; then
  log "stage 1: determinism, both directions"
  runcase a "$SEED"     || { log "FAIL: the first seeded run did not complete"; FAILED=1; }
  runcase b "$SEED"     || { log "FAIL: the second seeded run did not complete"; FAILED=1; }
  runcase c 987654321   || { log "FAIL: the differently-seeded run did not complete"; FAILED=1; }
  if [ "$FAILED" = "0" ]; then
    if cmp -s "$WORK/a/$XS" "$WORK/b/$XS"; then
      log "  same seed twice: output is bit-identical"
    else
      log "FAIL: two runs with seed $SEED produced different output; the seed does not pin the run"
      FAILED=1
    fi
    # The half that is easy to forget: if this passes, the seed is not being
    # used at all and the check above proved nothing.
    if cmp -s "$WORK/a/$XS" "$WORK/c/$XS"; then
      log "FAIL: a different seed produced IDENTICAL output; the seed is being ignored"
      FAILED=1
    else
      log "  different seed: output differs, so the seed really drives the run"
    fi
  fi
fi

# --------------------------------------------------------------- stage 2
if [ "$STAGE" = "0" ] || [ "$STAGE" = "2" ]; then
  log "stage 2: regression against the pinned values"
  [ -d "$WORK/a" ] || runcase a "$SEED" || { log "FAIL: the seeded run did not complete"; FAILED=1; }
  if [ -f "$WORK/a/$XS" ]; then
    python3 "$HERE/check_gibuu_output.py" "$WORK/a/$XS" --expect-elab 50.0 \
        --expect-qe 8869. --expect-total 716.2 --tolerance 1e-3 || FAILED=1
  else
    log "FAIL: no $XS was produced"; FAILED=1
  fi
fi

# --------------------------------------------------------------- stage 3
if [ "$STAGE" = "0" ] || [ "$STAGE" = "3" ]; then
  log "stage 3: the bookkeeping identity (NOT a physics check, see the header)"
  [ -d "$WORK/a" ] || runcase a "$SEED" || { log "FAIL: the seeded run did not complete"; FAILED=1; }
  if [ -f "$WORK/a/$XS" ]; then
    python3 "$HERE/check_gibuu_output.py" "$WORK/a/$XS" --identity-only || FAILED=1
  else
    log "FAIL: no $XS was produced"; FAILED=1
  fi
fi

if [ "$FAILED" = "0" ]; then
  echo "VERIFY OK (tier 2: no physics benchmark is claimed, see references/verification.md)"
  exit 0
fi
echo "VERIFY FAILED"
exit 1

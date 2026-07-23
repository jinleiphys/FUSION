#!/bin/bash
# verify_sky3d.sh
#
# Reproduce the benchmark cases that the Sky3D distribution itself ships, in a
# clean room, and compare against the distributed reference output.
#
#   verify_sky3d.sh                    static 16O case only (about 4 minutes)
#   verify_sky3d.sh --with-collision   also the 16O + 16O collision (about 45 min)
#
# The static case is the tier-1 anchor: Test/Static ships both the input
# (for005.static) and the authors' output (for006.static), so this is a genuine
# reproduction of distributed reference values, not a self-consistency check.
#
# What "reproduce" means here is defined by scripts/compare_sky3d.py, and it is
# deliberately not `diff`: the orientation of degenerate single-particle states
# inside a degenerate subspace is arbitrary and does not reproduce, while the
# energy functional, the single-particle energies and the determined moments do,
# exactly at printed precision. Read that script's header before loosening
# anything here.
#
# Sky3D is CPC non-profit licensed, not open source; see install_sky3d.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WITH_COLLISION=0
KEEP=0

log () { echo "verify_sky3d: $*" >&2; }
die () { log "$*"; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --with-collision) WITH_COLLISION=1; shift ;;
    --keep)           KEEP=1; shift ;;
    -h|--help)        sed -n '2,20p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" ;;
  esac
done

# ------------------------------------------------------------------ provision
if [ -n "${SKY3D:-}" ] && [ -n "${SKY3D_TESTS:-}" ]; then
  BIN="$SKY3D"; TESTS="$SKY3D_TESTS"
else
  INSTALL_OUT="$("$HERE/install_sky3d.sh")" || die "install_sky3d.sh failed"
  BIN="$(printf '%s\n' "$INSTALL_OUT" | sed -n 's/^SKY3D=//p')"
  TESTS="$(printf '%s\n' "$INSTALL_OUT" | sed -n 's/^SKY3D_TESTS=//p')"
fi
[ -x "$BIN" ] || die "no usable Sky3D executable"
[ -d "$TESTS" ] || die "no Test/ directory at '$TESTS'"

STATIC_IN="$TESTS/Static/for005.static"
STATIC_REF="$TESTS/Static/for006.static"

# A missing or empty reference must FAIL, never be skipped with a pass. A skipped
# check that prints OK is the single most common way these harnesses have lied.
for f in "$STATIC_IN" "$STATIC_REF"; do
  [ -s "$f" ] || die "distributed benchmark file '$f' is missing or empty; cannot verify"
done

WORK="$(mktemp -d)"
cleanup () { [ "$KEEP" = "1" ] && log "keeping $WORK" || rm -rf "$WORK"; }
trap cleanup EXIT

FAILED=0

# ------------------------------------------------------------- static 16O case
log "running the distributed static 16O case (SV-bas, 24^3 grid, serr=1e-6)"
mkdir -p "$WORK/Static"
cp "$STATIC_IN" "$WORK/Static/for005"
# Clean room: assert the reference is NOT present in the run directory, so the
# comparison cannot possibly be against a file the run itself read.
[ -e "$WORK/Static/for006.static" ] && die "clean-room violation: reference present in the work directory"

set +e
( cd "$WORK/Static" && "$BIN" > for006 2> stderr.txt )
STATUS=$?
set -e
[ "$STATUS" -eq 0 ] || { log "static run exited $STATUS"; tail -5 "$WORK/Static/stderr.txt" >&2; exit 1; }
[ -s "$WORK/Static/for006" ] || die "static run produced no output"

ITERS="$(grep -c 'Static Iteration No' "$WORK/Static/for006" || true)"
REF_ITERS="$(grep -c 'Static Iteration No' "$STATIC_REF" || true)"
if [ "$ITERS" != "$REF_ITERS" ]; then
  log "FAIL: iteration count $ITERS does not match the reference $REF_ITERS"
  log "      (the convergence path itself differs, so the comparison below is not like-for-like)"
  FAILED=1
else
  log "iteration count $ITERS matches the reference"
fi

if python3 "$HERE/compare_sky3d.py" "$WORK/Static/for006" "$STATIC_REF"; then
  log "static case: reproduces the distributed reference"
else
  log "FAIL: static case does not reproduce the distributed reference"
  FAILED=1
fi

# ---------------------------------------------------------- collision case
if [ "$WITH_COLLISION" = "1" ]; then
  COLL_IN="$TESTS/Collision/for005.coll"
  [ -s "$COLL_IN" ] || die "distributed collision input '$COLL_IN' is missing or empty"
  RES_LIST="energies.res dipoles.res momenta.res monopoles.res quadrupoles.res spin.res"
  for r in $RES_LIST; do
    [ -s "$TESTS/Collision/$r" ] || die "distributed collision reference '$r' is missing or empty"
  done

  # The collision deck reads its two fragments from ../Static/O16, which is the
  # wavefunction the static case above just wrote. Reproduce that layout.
  [ -s "$WORK/Static/O16" ] || die "the static run did not write the O16 wavefunction file the collision deck needs"
  mkdir -p "$WORK/Collision"
  cp "$COLL_IN" "$WORK/Collision/for005"

  log "running the distributed 16O + 16O collision case (E_cm = 100 MeV, b = 2 fm, 1000 steps)"
  log "this takes roughly 45 minutes"
  set +e
  ( cd "$WORK/Collision" && "$BIN" > for006 2> stderr.txt )
  STATUS=$?
  set -e
  [ "$STATUS" -eq 0 ] || { log "collision run exited $STATUS"; tail -5 "$WORK/Collision/stderr.txt" >&2; exit 1; }

  STEPS="$(grep -c 'Starting time step' "$WORK/Collision/for006" || true)"
  [ "${STEPS:-0}" -gt 0 ] || die "collision run printed no time steps"
  log "collision run: $STEPS time steps"

  if python3 "$HERE/compare_res_sky3d.py" "$WORK/Collision" "$TESTS/Collision" $RES_LIST; then
    log "collision case: reproduces the distributed .res tables"
  else
    log "FAIL: collision case does not reproduce the distributed .res tables"
    FAILED=1
  fi
fi

if [ "$FAILED" = "0" ]; then
  echo "VERIFY OK"
  exit 0
fi
echo "VERIFY FAILED"
exit 1

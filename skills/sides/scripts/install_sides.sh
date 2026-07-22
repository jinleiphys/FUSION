#!/bin/bash
# install_sides.sh
#
# Provision the SIDES executable: download from Mendeley Data, build with
# gfortran, prove it runs, and print
#   SIDES=<path to the sides.x executable>
#   SIDES_DIR=<source directory; sides.x reads INPUT and writes output files here>
# on the last two lines. run_sides.sh and verify_sides.sh parse those.
#
# SIDES (Schroedinger Integro-Differential Equation Solver) is the nonlocal-OMP
# elastic-scattering code of Blanchon, Dupuis, Arellano, Bernard and Morillon,
# Comput. Phys. Commun. 254, 107340 (2020), CPC Program Library, distributed on
# Mendeley Data (DOI 10.17632/cmpjgyrngr.1). Plain Fortran 90 + gfortran, no
# external libraries.
#
# ONE PACKAGING QUIRK: the shipped Makefile links the executable to `../sides`,
# a path OUTSIDE the source directory (the README assumes a src/ subdir that this
# release does not have). On some layouts `../sides` resolves onto a directory
# and the link fails with "ld: open() failed, errno=21". The build here overrides
# the target with `make exe=sides.x`, keeping the executable inside the source
# directory where it belongs. It also skips the shipped `make clean`, whose recipe
# would `rm -f ../sides` outside the package (see the build step).
set -euo pipefail

ROOT_DIR="${SIDES_ROOT:-$HOME/.cache/fusion/sides}"
URL="${SIDES_URL:-https://data.mendeley.com/public-files/datasets/cmpjgyrngr/files/d266ff3c-2bba-400f-9f99-867fa9611a7c/file_downloaded}"
ZIP="$ROOT_DIR/SIDES.zip"
EXTRACT="$ROOT_DIR/extract"

log () { echo "install_sides: $*" >&2; }

# Locate the directory that holds the source (sides.f90 + Makefile) after
# extraction, wherever the archive nests it. Echoes the path.
find_srcdir () {
  local f
  f="$(find "$EXTRACT" -name sides.f90 -type f 2>/dev/null | head -1)"
  [ -n "$f" ] && dirname "$f"
}

# Probe: run the shipped n+40Ca 20 MeV example and require finite, positive
# reaction/elastic/total cross sections in the integral-cross-section file
# (content, not exit status), plus the neutron optical theorem
# TOTAL = ELASTIC + REACTION. sides.x runs in ~0.1 s.
probe_binary () {
  local dir="$1"
  [ -x "$dir/sides.x" ] || { log "no sides.x in $dir"; return 1; }
  [ -f "$dir/INPUT" ]   || { log "shipped INPUT missing from $dir"; return 1; }
  rm -f "$dir/INTEGRAL-CROSS-SECTION-"*
  local rc
  set +e
  ( cd "$dir" && ./sides.x < INPUT > probe.out 2> probe.err )
  rc=$?
  set -e
  [ "$rc" -eq 0 ] || { log "sides.x exited $rc on the probe"; tail -5 "$dir/probe.err" >&2; return 1; }
  local icf
  icf="$(ls "$dir"/INTEGRAL-CROSS-SECTION-* 2>/dev/null | head -1)"
  [ -n "$icf" ] || { log "probe wrote no integral-cross-section file"; return 1; }
  python3 - "$icf" <<'PY' || { log "probe cross sections not finite/positive/consistent"; return 1; }
import sys,math
lines=[l for l in open(sys.argv[1]) if l.strip() and not l.strip().startswith('#') and 'ENERGY' not in l]
if not lines: sys.exit(1)
p=lines[-1].split()
# columns: energy reaction elastic total
try: e,rxn,ela,tot=(float(p[0]),float(p[1]),float(p[2]),float(p[3]))
except Exception: sys.exit(1)
if not all(math.isfinite(x) and x>0 for x in (rxn,ela,tot)): sys.exit(1)
# neutron optical theorem: total = elastic + reaction
if abs(tot-(ela+rxn))>1e-6*tot: sys.exit(1)
sys.exit(0)
PY
  return 0
}

# --- fast path -------------------------------------------------------------
if [ -z "${SIDES_FORCE:-}" ]; then
  SRC="$(find_srcdir || true)"
  if [ -n "$SRC" ] && [ -x "$SRC/sides.x" ] && probe_binary "$SRC"; then
    echo "SIDES=$SRC/sides.x"
    echo "SIDES_DIR=$SRC"
    exit 0
  fi
fi

command -v gfortran >/dev/null || { log "gfortran required"; exit 1; }
command -v curl     >/dev/null || { log "curl required";     exit 1; }
command -v unzip    >/dev/null || { log "unzip required";    exit 1; }

mkdir -p "$ROOT_DIR"
if [ ! -s "$ZIP" ]; then
  curl -sL -o "$ZIP" "$URL" || { log "failed to download SIDES from Mendeley"; exit 1; }
fi
# The download is a zip; guard against an HTML error page masquerading as one.
unzip -tq "$ZIP" >/dev/null 2>&1 || { log "downloaded SIDES.zip is not a valid archive"; rm -f "$ZIP"; exit 1; }

rm -rf "$EXTRACT"; mkdir -p "$EXTRACT"
unzip -q "$ZIP" -d "$EXTRACT" || { log "failed to extract SIDES.zip"; exit 1; }

SRC="$(find_srcdir || true)"
[ -n "$SRC" ] || { log "sides.f90 not found after extraction"; exit 1; }
[ -f "$SRC/Makefile" ] || { log "Makefile not found in $SRC"; exit 1; }

# NB do not run the shipped `make clean`: its recipe is `rm -f *.o *.mod ../sides
# *~`, which deletes `../sides` OUTSIDE the source directory. The extraction is
# fresh (rm -rf above) so there are no stale objects to clean anyway. Build only.
( cd "$SRC" && make exe=sides.x >make.log 2>&1 ) || {
  log "build failed; see $SRC/make.log"
  grep -iE "error|undefined" "$SRC/make.log" 2>/dev/null | head -8 >&2
  exit 1
}
[ -x "$SRC/sides.x" ] || { log "no sides.x after build"; exit 1; }

probe_binary "$SRC" || { log "freshly built sides.x failed its probe"; exit 1; }

echo "SIDES=$SRC/sides.x"
echo "SIDES_DIR=$SRC"

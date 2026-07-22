#!/bin/bash
# install_swanlop.sh
#
# Provision the SWANLOP executable: download from Mendeley Data, build with
# gfortran, prove it runs, and print
#   SWANLOP=<path to swanlop.x>
#   SWANLOP_RUNS=<the runs/ directory; swanlop.x is launched from here>
# on the last two lines. run_swanlop.sh and verify_swanlop.sh parse those.
#
# SWANLOP (Scattering Waves off Nonlocal Optical Potentials) is the nonlocal-OMP
# nucleon elastic-scattering code of H.F. Arellano and G. Blanchon, Comput. Phys.
# Commun. 259, 107543 (2021), CPC Program Library, distributed on Mendeley Data
# (DOI 10.17632/89gw9jdfv4.1). Plain Fortran + gfortran, no external libraries.
#
# The Mendeley dataset holds TWO files: swanlop.tar.gz (~8 MB, the code and the
# quick-start with its shipped reference outputs) and SupplementaryMaterial.tar.xz
# (~530 MB, precomputed potential tables only, NOT needed to build or to run the
# quick-start benchmark). This installer fetches only the code tarball.
set -euo pipefail

ROOT_DIR="${SWANLOP_ROOT:-$HOME/.cache/fusion/swanlop}"
URL="${SWANLOP_URL:-https://data.mendeley.com/public-files/datasets/89gw9jdfv4/files/6a3e17a4-1e49-491d-85d5-4f9894b59d45/file_downloaded}"
TGZ="$ROOT_DIR/swanlop.tar.gz"
EXTRACT="$ROOT_DIR/extract"

log () { echo "install_swanlop: $*" >&2; }

find_root () {  # dir containing sources/ and runs/
  local f
  f="$(find "$EXTRACT" -type d -name sources 2>/dev/null | head -1)"
  [ -n "$f" ] && dirname "$f"
}

# Probe: run the shipped quick-start (p+Pb208 30.3 MeV TPM) in a scratch COPY of
# runs/ and require the angular-observables file zz.xaq to appear with a finite
# positive reaction cross section (content, not exit status). ~1 s.
probe_binary () {
  local root="$1" bin="$1/sources/swanlop.x" runs="$1/runs"
  [ -x "$bin" ] || { log "no swanlop.x at $bin"; return 1; }
  [ -f "$runs/fort.quick-start" ] || { log "quick-start input missing"; return 1; }
  local w; w="$(mktemp -d)"
  cp "$runs/fort.quick-start" "$w/fort.1"
  cp "$runs/NucChart" "$w/" 2>/dev/null || true
  cp "$runs/dsdw.pPb208-30.3" "$w/" 2>/dev/null || true
  local rc
  set +e
  ( cd "$w" && "$bin" > probe.out 2> probe.err )
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then log "swanlop.x exited $rc on the probe"; tail -5 "$w/probe.err" >&2; rm -rf "$w"; return 1; fi
  if [ ! -f "$w/zz.xaq" ]; then log "probe wrote no zz.xaq"; rm -rf "$w"; return 1; fi
  python3 - "$w/zz.xaq" <<'PY'
import sys,re,math
t=open(sys.argv[1]).read()
m=re.search(r"Reactn xSectn\s*:\s*([-\d.eE+]+)",t)
sys.exit(0 if (m and math.isfinite(float(m.group(1))) and float(m.group(1))>0) else 1)
PY
  local ok=$?
  rm -rf "$w"
  [ "$ok" -eq 0 ] || { log "probe zz.xaq has no finite positive reaction cross section"; return 1; }
  return 0
}

# --- fast path -------------------------------------------------------------
if [ -z "${SWANLOP_FORCE:-}" ]; then
  R="$(find_root || true)"
  if [ -n "$R" ] && [ -x "$R/sources/swanlop.x" ] && probe_binary "$R"; then
    echo "SWANLOP=$R/sources/swanlop.x"
    echo "SWANLOP_RUNS=$R/runs"
    exit 0
  fi
fi

command -v gfortran >/dev/null || { log "gfortran required"; exit 1; }
command -v curl     >/dev/null || { log "curl required";     exit 1; }
command -v tar      >/dev/null || { log "tar required";      exit 1; }

mkdir -p "$ROOT_DIR"
if [ ! -s "$TGZ" ]; then
  curl -sL -o "$TGZ" "$URL" || { log "failed to download swanlop.tar.gz from Mendeley"; exit 1; }
fi
tar -tzf "$TGZ" >/dev/null 2>&1 || { log "downloaded swanlop.tar.gz is not a valid archive"; rm -f "$TGZ"; exit 1; }

rm -rf "$EXTRACT"; mkdir -p "$EXTRACT"
tar -xzf "$TGZ" -C "$EXTRACT" || { log "failed to extract swanlop.tar.gz"; exit 1; }

R="$(find_root || true)"
[ -n "$R" ] || { log "sources/ not found after extraction"; exit 1; }
[ -f "$R/sources/makefile" ] || { log "makefile not found in $R/sources"; exit 1; }

( cd "$R/sources" && make >make.log 2>&1 ) || {
  log "build failed; see $R/sources/make.log"
  grep -iE "error|undefined" "$R/sources/make.log" 2>/dev/null | head -8 >&2
  exit 1
}
[ -x "$R/sources/swanlop.x" ] || { log "no swanlop.x after build"; exit 1; }

probe_binary "$R" || { log "freshly built swanlop.x failed its probe"; exit 1; }

echo "SWANLOP=$R/sources/swanlop.x"
echo "SWANLOP_RUNS=$R/runs"

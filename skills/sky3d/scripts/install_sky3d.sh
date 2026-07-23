#!/bin/bash
# install_sky3d.sh
#
# Provision the Sky3D executable: clone the upstream repository at a pinned
# commit, build it with gfortran, prove it runs, and print
#   SKY3D=<path to the sky3d executable>
#   SKY3D_ROOT=<repository root>
#   SKY3D_TESTS=<Test/ directory holding the distributed benchmark cases>
# on the last three lines. run_sky3d.sh and verify_sky3d.sh parse those.
#
# Sky3D is the nuclear time-dependent Hartree-Fock code of J.A. Maruhn,
# P.-G. Reinhard, P.D. Stevenson and A.S. Umar, Comput. Phys. Commun. 185,
# 2195-2216 (2014), DOI 10.1016/j.cpc.2014.04.008, extended in version 1.1,
# Comput. Phys. Commun. 229, 211-213 (2018), DOI 10.1016/j.cpc.2018.03.012.
# Fortran 90 with optional OpenMP and MPI; needs FFTW3 and LAPACK/BLAS.
#
# LICENSE NOTE, READ BEFORE REDISTRIBUTING ANYTHING:
# Sky3D is NOT open source. There is no LICENSE file, no copyright header in the
# sources, and the CPC program summary states "Licensing provisions: none",
# which in the CPC template means the CPC non-profit use licence is sufficient.
# So use is restricted to non-profit purposes. This skill clones from the same
# public upstream a student would use and redistributes no Sky3D source, so each
# user receives the code from the authors under the authors' own terms (user
# ruling; see the private-code-boundary decision in CLAUDE.md). A commercial user
# must contact the authors. Do not vendor these sources into any distribution.
set -euo pipefail

ROOT_DIR="${SKY3D_ROOT_DIR:-$HOME/.cache/fusion/sky3d}"
REPO="${SKY3D_REPO:-https://github.com/manybody/sky3d}"
PIN="${SKY3D_PIN:-be42efc7fba93aeb3a18ed0b5155b5f6bc9c6c1b}"
SRCROOT="$ROOT_DIR/sky3d"
CODE="$SRCROOT/Code"
TESTS="$SRCROOT/Test"
STAMP="$CODE/.fusion_build_stamp"

log () { echo "install_sky3d: $*" >&2; }

# rm -rf safety. The devlog records this class of bug three times over; the guard
# must name the very path that is deleted, and refuse anything short or absolute.
safe_rmrf () {
  local target="$1"
  case "$target" in
    ""|"/"|"$HOME"|"$HOME/") log "refusing to delete '$target'"; return 1 ;;
  esac
  [ "${#target}" -ge 12 ] || { log "refusing to delete suspiciously short path '$target'"; return 1; }
  case "$target" in
    "$ROOT_DIR"|"$ROOT_DIR"/*) : ;;
    *) log "refusing to delete '$target' outside \$SKY3D_ROOT_DIR ($ROOT_DIR)"; return 1 ;;
  esac
  rm -rf "$target"
}

# Which executable the chosen make target produces.
case "$(uname -s)" in
  Darwin) MAKE_TARGET="${SKY3D_MAKE_TARGET:-apple}" ;;
  *)      MAKE_TARGET="${SKY3D_MAKE_TARGET:-seq}" ;;
esac
case "$MAKE_TARGET" in
  seq|debug|seq_debug|apple) EXE_NAME="sky3d.seq" ;;
  omp|omp_debug|apple_omp)   EXE_NAME="sky3d.omp" ;;
  *) log "unsupported make target '$MAKE_TARGET' (use seq, omp, apple, apple_omp, or a *_debug variant)"; exit 1 ;;
esac
BIN="$CODE/$EXE_NAME"

# ---------------------------------------------------------------- dependencies
# FFTW3 is the one dependency neither platform supplies by default. Locate it
# rather than trusting the Makefile's hardcoded /opt/homebrew/lib, which is wrong
# on Intel Macs (/usr/local) and on any Linux box.
find_fftw_prefix () {
  local p
  if [ -n "${SKY3D_FFTW_PREFIX:-}" ]; then echo "$SKY3D_FFTW_PREFIX"; return 0; fi
  if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists fftw3 2>/dev/null; then
    p="$(pkg-config --variable=libdir fftw3 2>/dev/null || true)"
    [ -n "$p" ] && [ -d "$p" ] && { echo "${p%/lib}"; return 0; }
  fi
  if command -v brew >/dev/null 2>&1; then
    p="$(brew --prefix fftw 2>/dev/null || true)"
    [ -n "$p" ] && [ -d "$p/lib" ] && { echo "$p"; return 0; }
  fi
  for p in /opt/homebrew /usr/local "$HOME/miniforge3/envs/sky3d" "${CONDA_PREFIX:-/nonexistent}" /usr; do
    if ls "$p"/lib/libfftw3.* >/dev/null 2>&1; then echo "$p"; return 0; fi
  done
  return 1
}

build_libs () {
  local fftw="$1"
  if [ "$(uname -s)" = "Darwin" ]; then
    # Accelerate supplies LAPACK and BLAS on macOS; -llapack does NOT work with a
    # Homebrew lapack unless its -L is given, so do not substitute it here.
    echo "-L$fftw/lib -lfftw3 -framework Accelerate"
  else
    echo "-L$fftw/lib -Wl,-rpath,$fftw/lib -lfftw3 -llapack -lopenblas"
  fi
}

# ----------------------------------------------------------------- fast path
# Skip the rebuild only when the binary exists AND was built from the pinned
# commit by this script with the same target. A bare "the file exists" fast path
# is how a stale binary from another commit silently certifies a later run.
build_identity () { echo "$PIN|$MAKE_TARGET|$(uname -s)|$(uname -m)"; }

if [ -x "$BIN" ] && [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$(build_identity)" ]; then
  log "found $EXE_NAME built from the pinned commit, probing it"
else
  # ------------------------------------------------------------------- clone
  if [ -d "$SRCROOT/.git" ]; then
    log "reusing clone at $SRCROOT"
  else
    command -v git >/dev/null || { log "git not found"; exit 1; }
    mkdir -p "$ROOT_DIR"
    # Clone to a temporary path and move into place, so an interrupted clone
    # never leaves a half-tree where a complete one used to be.
    TMPCLONE="$ROOT_DIR/.clone.$$"
    safe_rmrf "$TMPCLONE"
    log "cloning $REPO"
    git clone -q "$REPO" "$TMPCLONE" || { log "clone failed"; safe_rmrf "$TMPCLONE"; exit 1; }
    safe_rmrf "$SRCROOT"
    mv "$TMPCLONE" "$SRCROOT"
  fi

  # Pin the commit. A pin that only warns is not a pin: upstream can change the
  # physics under a skill whose benchmark numbers were measured elsewhere.
  ( cd "$SRCROOT" && git checkout -q "$PIN" 2>/dev/null ) || {
    log "cannot check out pinned commit $PIN"
    log "the upstream history moved or the clone is shallow; set SKY3D_PIN to re-pin deliberately"
    exit 1
  }
  log "pinned at $PIN"

  # ------------------------------------------------------------------- build
  command -v gfortran >/dev/null || { log "gfortran not found"; exit 1; }
  FFTW="$(find_fftw_prefix)" || {
    log "FFTW3 not found. Install it (macOS: brew install fftw; Linux: conda install -c conda-forge fftw,"
    log "or the distribution's libfftw3-dev) or set SKY3D_FFTW_PREFIX to its prefix."
    exit 1
  }
  log "FFTW3 prefix: $FFTW"
  LIBS="$(build_libs "$FFTW")"

  # Stale .mod files from another gfortran version make the next build die on a
  # message that names neither the cause nor the fix. This bit the pikoe skill.
  ( cd "$CODE" && rm -f ./*.o ./*.mod )
  log "building target '$MAKE_TARGET' with LIBS=$LIBS"
  ( cd "$CODE" && make "$MAKE_TARGET" LIBS_SKY="$LIBS" ) >"$ROOT_DIR/build.log" 2>&1 || {
    log "build failed, last 20 lines of $ROOT_DIR/build.log:"; tail -20 "$ROOT_DIR/build.log" >&2; exit 1; }
  [ -x "$BIN" ] || { log "build reported success but $BIN is missing"; exit 1; }
  build_identity > "$STAMP"
fi

# ------------------------------------------------------------------- probe
# Content is the verdict. A tiny 5-iteration static 16O run: require a zero exit
# AND a finite, negative, physically plausible total energy in the output. Runs
# in a scratch directory so nothing is written into the caller's cwd.
probe_binary () {
  local w; w="$(mktemp -d)"
  cat > "$w/for005" <<'EOF'
 &files wffile='probe' /
 &force name='SV-bas', pairing='NONE' /
 &main mprint=1,mplot=0,mrest=0,writeselect='r',imode=1,tfft=T,nof=0 /
 &grid nx=16,ny=16,nz=16,dx=1.0,dy=1.0,dz=1.0,periodic=F /
 &static nprot=8,nneut=8,radinx=3.1,radiny=3.1,radinz=3.1,
  x0dmp=0.40,e0dmp=100.0,tdiag=T,tlarge=F,maxiter=5,serr=1D-6 /
EOF
  ( cd "$w" && "$BIN" > for006 2> stderr.txt ) || {
    log "probe run exited nonzero"; tail -5 "$w/stderr.txt" >&2; rm -rf "$w"; return 1; }
  local e
  e="$(grep -m1 '^ Total:.*MeV' "$w/for006" | sed -E 's/^ Total: *([^ ]+) MeV.*/\1/' || true)"
  [ -n "$e" ] || { log "probe produced no total energy line"; rm -rf "$w"; return 1; }
  python3 - "$e" <<'PY' || { log "probe energy '$e' is not a finite, negative, plausible 16O energy"; rm -rf "$w"; return 1; }
import sys, math
v = float(sys.argv[1].replace('E','e'))
# 5 iterations from a Gaussian start is far from converged, so this is a wide
# sanity window, not a benchmark: it must be finite, bound, and not absurd.
sys.exit(0 if math.isfinite(v) and -400.0 < v < -20.0 else 1)
PY
  rm -rf "$w"
  return 0
}

probe_binary || { log "the built executable failed its probe"; exit 1; }
log "probe OK"

[ -d "$TESTS" ] || { log "Test/ directory missing from the clone at $TESTS"; exit 1; }

echo "SKY3D=$BIN"
echo "SKY3D_ROOT=$SRCROOT"
echo "SKY3D_TESTS=$TESTS"

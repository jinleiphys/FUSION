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
mkdir -p "$ROOT_DIR"
ROOT_CANON="$(cd "$ROOT_DIR" && pwd -P)"
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
  local target="$1" canon parent
  [ -n "$target" ] || { log "refusing to delete an empty path"; return 1; }
  case "$target" in
    /*) : ;;
    *) log "refusing to delete relative path '$target'"; return 1 ;;
  esac
  [ -e "$target" ] || return 0
  # Canonicalize both sides before the containment test: a string-prefix test
  # alone is defeated by a symlinked component, and the comment used to promise
  # a canonical check the code did not perform.
  parent="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || {
    log "cannot resolve the parent of '$target'"; return 1; }
  canon="$parent/$(basename "$target")"
  case "$canon" in
    "/"|"$HOME"|"$HOME/"|"/usr"|"/etc"|"/var"|"/tmp") log "refusing to delete '$canon'"; return 1 ;;
  esac
  [ "${#canon}" -ge 12 ] || { log "refusing to delete suspiciously short path '$canon'"; return 1; }
  case "$canon/" in
    "$ROOT_CANON"/*) : ;;
    *) log "refusing to delete '$canon' outside \$SKY3D_ROOT_DIR ($ROOT_CANON)"; return 1 ;;
  esac
  rm -rf "$canon"
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
# A prefix reaches the upstream Makefile's link recipe as unquoted shell text, so
# a semicolon or a command substitution in it would execute. Restrict it to a
# conservative path grammar and require it to exist.
valid_prefix () {
  case "$1" in
    /*) : ;;
    *) return 1 ;;
  esac
  case "$1" in
    *[!A-Za-z0-9/._+-]*) return 1 ;;
  esac
  [ -d "$1" ]
}

find_fftw_prefix () {
  local p
  if [ -n "${SKY3D_FFTW_PREFIX:-}" ]; then
    valid_prefix "$SKY3D_FFTW_PREFIX" || {
      log "SKY3D_FFTW_PREFIX='$SKY3D_FFTW_PREFIX' is not an existing absolute path over [A-Za-z0-9/._+-]"
      return 1
    }
    echo "$SKY3D_FFTW_PREFIX"; return 0
  fi
  if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists fftw3 2>/dev/null; then
    p="$(pkg-config --variable=libdir fftw3 2>/dev/null || true)"
    if [ -n "$p" ] && valid_prefix "${p%/lib}"; then echo "${p%/lib}"; return 0; fi
  fi
  if command -v brew >/dev/null 2>&1; then
    p="$(brew --prefix fftw 2>/dev/null || true)"
    if [ -n "$p" ] && [ -d "$p/lib" ] && valid_prefix "$p"; then echo "$p"; return 0; fi
  fi
  for p in /opt/homebrew /usr/local "$HOME/miniforge3/envs/sky3d" "${CONDA_PREFIX:-/nonexistent}" /usr; do
    if ls "$p"/lib/libfftw3.* >/dev/null 2>&1 && valid_prefix "$p"; then echo "$p"; return 0; fi
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

# Resolve FFTW up front: it is part of the build identity, and a binary linked
# against an FFTW that has since disappeared cannot run anyway.
FFTW_USED="$(find_fftw_prefix || true)"

# ----------------------------------------------------------------- fast path
# Skip the rebuild only when the binary exists AND was built from the pinned
# commit by this script with the same target. A bare "the file exists" fast path
# is how a stale binary from another commit silently certifies a later run.
# The stamp answers "is this binary the one this script would build right now?".
# A stamp of the requested pin alone answered a different and useless question:
# a clone sitting at another commit still matched it, so the fast path certified
# a binary built from source that was no longer there.
build_identity () {
  local head dirty fc
  head="$(cd "$SRCROOT" 2>/dev/null && git rev-parse HEAD 2>/dev/null || echo nohead)"
  if (cd "$SRCROOT" 2>/dev/null && git diff --quiet HEAD 2>/dev/null); then dirty=clean; else dirty=DIRTY; fi
  fc="$(gfortran -dumpversion 2>/dev/null || echo nofc)"
  echo "$head|$dirty|$MAKE_TARGET|$fc|$(uname -s)|$(uname -m)|${FFTW_USED:-unset}"
}

binary_digest () { shasum -a 256 "$BIN" 2>/dev/null | cut -d' ' -f1 || echo nodigest; }

fast_path_ok () {
  [ -x "$BIN" ] || return 1
  [ -f "$STAMP" ] || return 1
  local want_head want_rest
  # Recompute identity from the tree as it is NOW, and require the stamp to match
  # it, the requested pin, and the binary that is actually on disk.
  want_head="$(cd "$SRCROOT" 2>/dev/null && git rev-parse HEAD 2>/dev/null || echo nohead)"
  [ "$want_head" = "$PIN" ] || { log "clone HEAD $want_head is not the pinned $PIN, rebuilding"; return 1; }
  (cd "$SRCROOT" && git diff --quiet HEAD 2>/dev/null) || { log "clone has uncommitted modifications, rebuilding"; return 1; }
  want_rest="$(head -1 "$STAMP")"
  [ "$want_rest" = "$(build_identity)" ] || { log "build identity changed since the stamp, rebuilding"; return 1; }
  [ "$(sed -n 2p "$STAMP")" = "$(binary_digest)" ] || { log "the binary changed since it was stamped, rebuilding"; return 1; }
  return 0
}

if fast_path_ok; then
  log "found $EXE_NAME built from the pinned commit with a matching build identity, probing it"
else
  # ------------------------------------------------------------------- clone
  if [ -d "$SRCROOT/.git" ]; then
    log "reusing clone at $SRCROOT"
  elif [ -e "$SRCROOT" ]; then
    log "$SRCROOT exists but is not a git clone; refusing to delete a directory this script did not create"
    exit 1
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
  # git checkout of the commit you are already on leaves local modifications in
  # place, so a dirty tree has to be refused explicitly rather than assumed away.
  ( cd "$SRCROOT" && git diff --quiet HEAD 2>/dev/null ) || {
    log "the clone at $SRCROOT has uncommitted modifications; refusing to build from it"
    log "(remove the directory, or set SKY3D_ROOT_DIR to a fresh location)"
    exit 1
  }
  ( cd "$SRCROOT" && git checkout -q "$PIN" 2>/dev/null ) || {
    log "cannot check out pinned commit $PIN"
    log "the upstream history moved or the clone is shallow; set SKY3D_PIN to re-pin deliberately"
    exit 1
  }
  log "pinned at $PIN"

  # ------------------------------------------------------------------- build
  command -v gfortran >/dev/null || { log "gfortran not found"; exit 1; }
  FFTW="$FFTW_USED"
  [ -n "$FFTW" ] || {
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
  { build_identity; binary_digest; } > "$STAMP"
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

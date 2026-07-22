#!/bin/bash
# install_skynet.sh
#
# Provision a working SkyNet build and print, on the last four lines,
#   SKYNET_SRC=<source tree, patched>
#   SKYNET_BUILD=<cmake build dir, holds the test/example executables>
#   SKYNET_INSTALL=<install prefix, holds data/ and examples/>
#   SKYNET_DATA=<install prefix>/data
# run_skynet.sh and verify_skynet.sh parse those.
#
# SkyNet is the modular nuclear reaction network library of J. Lippuner and
# L. F. Roberts, ApJS 233, 18 (2017), arXiv:1706.06198, BSD 3-Clause
# (Caltech), https://bitbucket.org/jlippuner/skynet . It evolves nuclide
# abundances under a reaction network (r-process, rp-process, alpha network,
# NSE, ...) with a self-heating EOS and screening.
#
# BUILD NOTES (see references/failure-modes.md for the why of each):
#  - Dense LAPACK matrix solver (Accelerate on macOS, system LAPACK on Linux),
#    so no Pardiso/MKL/Trilinos/Armadillo license or extra dependency is needed.
#  - Python (SWIG) bindings and the movie maker are OFF: the physics benchmark
#    and the shipped network executables do not need them, and SWIG on a very
#    new Python is a portability liability. See input-format.md to turn the
#    Python interface on.
#  - Five source patches for Apple clang / libc++ / modern Boost / modern CMake
#    are applied from scripts/skynet_macos_portability.patch (generated against
#    upstream commit e37ae9c). They are portability only and are verified
#    behaviour-preserving by the 100% Linux ctest pass on the SAME patched
#    source (references/verification.md). On Linux they are no-ops or harmless.
set -euo pipefail

PINNED_COMMIT="e37ae9c505213afe47e141be2f734331494a0cce"
ROOT_DIR="${SKYNET_ROOT_DIR:-$HOME/.cache/fusion/skynet}"
REPO="${SKYNET_REPO:-https://bitbucket.org/jlippuner/skynet.git}"
SRC="$ROOT_DIR/skynet"                 # source tree (contains the INSTALL file)
BUILD="$ROOT_DIR/build"                # cmake build dir
# The install prefix must NOT be a case-insensitive match of the shipped
# "INSTALL" file in $SRC, or `make install` cannot create the directory on APFS.
# A sibling named skynet_install is safe (it is outside $SRC).
INSTALL="$ROOT_DIR/skynet_install"
DATA="$INSTALL/data"
HERE="$(cd "$(dirname "$0")" && pwd)"
PATCH="$HERE/skynet_macos_portability.patch"

log () { echo "install_skynet: $*" >&2; }

STAMP="$BUILD/.fusion_skynet_stamp"

# rm-safety: refuse a dangerous ROOT_DIR and confine every rm -rf under it, so a
# mis-set SKYNET_ROOT_DIR cannot delete $HOME/build, /build, or the like. This
# is the recurring wrong-operand-guard class the project has been burned by.
case "$ROOT_DIR" in
  ""|"/"|"$HOME"|"/usr"|"/usr/"*|"/etc"|"/var"|"/tmp"|"/bin"|"/opt"|"/System"*|"/Users")
    log "refusing an unsafe SKYNET_ROOT_DIR='$ROOT_DIR'"; exit 1 ;;
esac
case "$ROOT_DIR" in /*) : ;; *) log "SKYNET_ROOT_DIR must be an absolute path (got '$ROOT_DIR')"; exit 1 ;; esac
safe_rm () {  # rm -rf, but only for a path strictly under $ROOT_DIR
  local t="$1"
  case "$t" in
    "$ROOT_DIR"/*) rm -rf "$t" ;;
    *) log "internal error: refusing to rm outside root: '$t'"; exit 1 ;;
  esac
}

# Build-identity stamp: pinned commit + patch hash + build options. The fast
# path is taken only if the stamp matches AND the probe passes, so a build made
# by a different version of this script (different patch, solver, or prefix) is
# rebuilt rather than silently reused.
patch_hash () { shasum -a 256 "$PATCH" 2>/dev/null | awk '{print $1}' || echo nohash; }
STAMP_SIG="commit=$PINNED_COMMIT patch=$(patch_hash) solver=lapack swig=off movie=off cxxflags=-include-string prefix=$INSTALL"

# Probe: run the built AlphaNetwork executable and require the dominant product
# ni56 near its analytic value (content, not exit status). ~1 s. This alpha
# network is self-contained (no external trajectory) and cross-platform stable.
# Run from the executable's own directory so its .h5/.log output does not land
# in the caller's cwd.
probe_build () {
  local exe="$BUILD/tests/AlphaNetwork/AlphaNetwork"
  [ -x "$exe" ] || { log "no AlphaNetwork executable at $exe"; return 1; }
  [ -f "$DATA/webnucleo_nuc_v2.0.xml" ] || { log "install data missing at $DATA"; return 1; }
  # Write output to a file and pass its PATH to python (argv[1]): a heredoc
  # script cannot also read piped data on stdin, the heredoc consumes stdin.
  local tmp; tmp="$(mktemp)"
  ( cd "$(dirname "$exe")" && "$exe" ) >"$tmp" 2>/dev/null || { log "AlphaNetwork exited nonzero"; rm -f "$tmp"; return 1; }
  python3 - "$tmp" <<'PY'
import sys,re
ni56=None
for l in open(sys.argv[1]):
    m=re.match(r'#\s*ni56:\s*(\S+)',l)
    if m:
        try: ni56=float(m.group(1))   # matches nan/inf too
        except ValueError: pass
# analytic alpha-network ni56 mass fraction is ~1.78e-2; accept a wide band,
# this probe only proves the build computes a sane network, not the benchmark.
import math
sys.exit(0 if (ni56 is not None and math.isfinite(ni56) and 1.0e-2 < ni56 < 3.0e-2) else 1)
PY
  local rc=$?
  rm -f "$tmp"
  return $rc
}

# --- fast path -------------------------------------------------------------
if [ -z "${SKYNET_FORCE:-}" ] && [ -f "$STAMP" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$STAMP_SIG" ] && probe_build 2>/dev/null; then
  echo "SKYNET_SRC=$SRC"; echo "SKYNET_BUILD=$BUILD"; echo "SKYNET_INSTALL=$INSTALL"; echo "SKYNET_DATA=$DATA"
  exit 0
fi

command -v git      >/dev/null || { log "git required"; exit 1; }
command -v cmake    >/dev/null || { log "cmake required"; exit 1; }
command -v gfortran >/dev/null || { log "gfortran required (Fortran 2003; brew install gcc / apt install gfortran)"; exit 1; }
command -v python3  >/dev/null || { log "python3 required"; exit 1; }
[ -f "$PATCH" ] || { log "missing portability patch at $PATCH"; exit 1; }

# --- dependency prefixes ---------------------------------------------------
# HDF5 (with C++), GSL and Boost must be findable. On macOS these come from
# Homebrew; on Linux from the system (apt: libhdf5-dev libgsl-dev
# libboost-all-dev liblapack-dev) or a conda env. LAPACK comes from Accelerate
# on macOS and from the system on Linux.
PREFIX_PATH="${CMAKE_PREFIX_PATH:-}"
if [ "$(uname -s)" = "Darwin" ]; then
  command -v brew >/dev/null || { log "Homebrew required on macOS for hdf5/gsl/boost"; exit 1; }
  BP="$(brew --prefix)"
  for pkg in hdf5 gsl boost; do
    brew list --versions "$pkg" >/dev/null 2>&1 || { log "missing dependency: brew install $pkg"; exit 1; }
  done
  PREFIX_PATH="$BP:$PREFIX_PATH"
elif [ -n "${CONDA_PREFIX:-}" ]; then
  PREFIX_PATH="$CONDA_PREFIX:$PREFIX_PATH"
fi

# --- clone + pin + patch ---------------------------------------------------
mkdir -p "$ROOT_DIR"
if [ ! -d "$SRC/.git" ]; then
  TMPCLONE="$SRC.tmp.$$"
  safe_rm "$TMPCLONE"
  git clone -q "$REPO" "$TMPCLONE" || { log "failed to clone SkyNet from $REPO"; safe_rm "$TMPCLONE"; exit 1; }
  safe_rm "$SRC"
  mv "$TMPCLONE" "$SRC"
fi
[ -f "$SRC/CMakeLists.txt" ] || { log "SkyNet source incomplete at $SRC"; exit 1; }

# Reset to the PINNED commit and a clean tree, then apply the patch. Doing this
# every run makes the install idempotent (re-applying onto a dirty tree fails).
# The pinned commit is REQUIRED (fetched if the shallow clone lacks it); building
# an unpinned tree would break the reproducibility the benchmark claims.
( cd "$SRC"
  if ! git checkout -q "$PINNED_COMMIT" 2>/dev/null; then
    git fetch -q --depth 1 origin "$PINNED_COMMIT" 2>/dev/null || true
    git checkout -q "$PINNED_COMMIT" 2>/dev/null || { echo "PINFAIL"; exit 3; }
  fi
  git checkout -q -- . 2>/dev/null || true
  git clean -qfd src tests CMakeLists.txt CMakeLists_Requirements.txt 2>/dev/null || true
  git apply --whitespace=nowarn "$PATCH" ) || {
    log "could not prepare source: pinned commit $PINNED_COMMIT unavailable (upstream moved?) or patch failed to apply; refusing to build an unpinned/unpatched tree"
    exit 1; }

# --- configure -------------------------------------------------------------
# -DCMAKE_POLICY_VERSION_MINIMUM=3.5 : SkyNet declares cmake_minimum 3.1, which
#   modern CMake (>= 4.0, as shipped by Homebrew and conda-forge) refuses.
# -DCMAKE_CXX_FLAGS="-include string" : force-include <string> so libc++ has
#   std::to_string in the many files that rely on libstdc++ transitive includes.
safe_rm "$BUILD"; mkdir -p "$BUILD"
( cd "$BUILD" && cmake \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DSKYNET_MATRIX_SOLVER=lapack \
    -DUSE_SWIG=OFF \
    -DENABLE_SWIG=OFF \
    -DENABLE_MOVIE=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="-include string" \
    -DCMAKE_PREFIX_PATH="$PREFIX_PATH" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL" \
    "$SRC" >configure.log 2>&1 ) || {
  log "cmake configure failed; see $BUILD/configure.log"
  grep -iE "error|could not find|not found" "$BUILD/configure.log" 2>/dev/null | head -8 >&2
  log "on Linux install: libhdf5-dev libgsl-dev libboost-all-dev liblapack-dev (apt) or a conda env with hdf5 gsl boost"
  exit 1
}

# --- build + install -------------------------------------------------------
JOBS="$( (sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4) )"
( cd "$BUILD" && make -j"$JOBS" install >build.log 2>&1 ) || {
  log "build failed; see $BUILD/build.log"
  grep -iE "error:|Error [0-9]|undefined|ld:" "$BUILD/build.log" 2>/dev/null | head -12 >&2
  exit 1
}
[ -x "$BUILD/tests/AlphaNetwork/AlphaNetwork" ] || { log "no AlphaNetwork executable after build"; exit 1; }
[ -f "$DATA/webnucleo_nuc_v2.0.xml" ] || { log "install did not populate $DATA"; exit 1; }

probe_build || { log "freshly built SkyNet failed its AlphaNetwork probe"; exit 1; }

# Record the build identity so the fast path can trust this build later.
echo "$STAMP_SIG" > "$STAMP"

echo "SKYNET_SRC=$SRC"; echo "SKYNET_BUILD=$BUILD"; echo "SKYNET_INSTALL=$INSTALL"; echo "SKYNET_DATA=$DATA"

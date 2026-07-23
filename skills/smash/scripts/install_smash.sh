#!/bin/bash
# install_smash.sh
#
# Provision SMASH and its two awkward dependencies, then print
#   SMASH=<path to the smash executable>
#   SMASH_ROOT=<repository root>
#   SMASH_BUILD=<build directory, where ctest runs>
#   SMASH_EIGEN3_ROOT=<Eigen 3.4 prefix, see below: EXPORT THIS>
#   SMASH_GSL_PREFIX=<GSL prefix, also needed by the library-example sub-build>
#   SMASH_PYTHIA_PREFIX=<Pythia prefix; its lib/ must be on the loader path>
# on the last six lines. run_smash.sh and verify_smash.sh parse those.
#
# SMASH is the hadronic transport approach of J. Weil et al., Phys. Rev. C 94,
# 054905 (2016), DOI 10.1103/physrevc.94.054905; software release SMASH-3.3,
# DOI 10.5281/zenodo.3484711. GPL-3.0-or-later (LICENSE.md, and the Zenodo
# record's rightsList; GitHub reports NOASSERTION only because LICENSE.md also
# carries the BSD-3, CC0 and Unlicense terms of bundled third-party code).
#
# Two dependencies cost real time, and both fail in ways that point away from
# the cause. See references/failure-modes.md.
#
#  * Pythia must be EXACTLY 8.316 and is built from source. SMASH's own
#    INSTALL.md still gives the URL pythia.org/download/pythia83/..., which now
#    404s because Pythia moved everything under /releases/. The 404 body is a
#    3.7 KB HTML page, so a naive download writes that to pythia8316.tgz and the
#    first symptom is "tar: Unrecognized archive format". This script validates
#    that what it downloaded is really a gzip tarball before unpacking it.
#
#  * Eigen must be a 3.x. Homebrew now ships Eigen 5.0.1, which renamed
#    EIGEN_WORLD_VERSION, so SMASH 3.3's bundled FindEigen3.cmake cannot parse
#    the version and reports "at least version 3.0 is required", which reads as
#    "too old" when the truth is "too new". This script fetches the Eigen 3.4.0
#    headers (header-only, no build) rather than patching SMASH.
set -euo pipefail

ROOT_DIR="${SMASH_ROOT_DIR:-$HOME/.cache/fusion/smash}"
mkdir -p "$ROOT_DIR"
ROOT_CANON="$(cd "$ROOT_DIR" && pwd -P)"

REPO="${SMASH_REPO:-https://github.com/smash-transport/smash}"
PIN="${SMASH_PIN:-d1a1c6cf0a0002ee064eec1b929b9a7c14b3d5bc}"       # SMASH-3.3
PYTHIA_VERSION="${SMASH_PYTHIA_VERSION:-8316}"
PYTHIA_URL="${SMASH_PYTHIA_URL:-https://pythia.org/releases/pythia83/pythia${PYTHIA_VERSION}.tgz}"
EIGEN_VERSION="${SMASH_EIGEN_VERSION:-3.4.0}"
EIGEN_URL="${SMASH_EIGEN_URL:-https://gitlab.com/libeigen/eigen/-/archive/${EIGEN_VERSION}/eigen-${EIGEN_VERSION}.tar.gz}"

SRCROOT="$ROOT_DIR/smash"
BUILD="$SRCROOT/build"
BIN="$BUILD/smash"
PYTHIA_PREFIX="$ROOT_DIR/pythia-install"
EIGEN_ROOT="$ROOT_DIR/eigen-$EIGEN_VERSION"
STAMP="$BUILD/.fusion_build_stamp"
JOBS="${SMASH_JOBS:-$( (command -v nproc >/dev/null && nproc) || sysctl -n hw.ncpu 2>/dev/null || echo 4 )}"

log () { echo "install_smash: $*" >&2; }

safe_rmrf () {
  local target="$1" parent canon
  [ -n "$target" ] || { log "refusing to delete an empty path"; return 1; }
  case "$target" in /*) : ;; *) log "refusing to delete relative path '$target'"; return 1 ;; esac
  [ -e "$target" ] || return 0
  parent="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || { log "cannot resolve '$target'"; return 1; }
  canon="$parent/$(basename "$target")"
  case "$canon" in "/"|"$HOME"|"/usr"|"/etc"|"/var"|"/tmp") log "refusing to delete '$canon'"; return 1 ;; esac
  [ "${#canon}" -ge 12 ] || { log "refusing to delete short path '$canon'"; return 1; }
  case "$canon/" in "$ROOT_CANON"/*) : ;; *) log "refusing to delete '$canon' outside $ROOT_CANON"; return 1 ;; esac
  rm -rf "$canon"
}

# A download that silently produced an HTML error page is the trap this whole
# script exists to prevent, so check the magic bytes, not just the exit status.
fetch_tarball () {
  local url="$1" dest="$2" what="$3"
  log "downloading $what"
  curl -fsSL --retry 3 --max-time 900 -o "$dest" "$url" || {
    log "download of $what failed (HTTP error or timeout): $url"
    log "if this is Pythia, the upstream path moved once already; check pythia.org/releases/"
    rm -f "$dest"; return 1
  }
  # gzip magic is 1f 8b. An HTML 404 body starts with '<' and would otherwise
  # only surface later as "tar: Unrecognized archive format".
  local magic; magic="$(od -An -tx1 -N2 "$dest" | tr -d ' \n')"
  if [ "$magic" != "1f8b" ]; then
    log "$what did not download as a gzip archive (first bytes: $magic, size $(wc -c < "$dest") bytes)"
    head -c 120 "$dest" | tr -d '\0' >&2; echo >&2
    log "that is almost certainly an HTML error page saved under a .tgz name; the URL is wrong or moved"
    rm -f "$dest"; return 1
  fi
}

# ------------------------------------------------------------------- Eigen 3.4
if [ ! -d "$EIGEN_ROOT/Eigen" ]; then
  fetch_tarball "$EIGEN_URL" "$ROOT_DIR/eigen.tar.gz" "Eigen $EIGEN_VERSION headers" || exit 1
  ( cd "$ROOT_DIR" && tar xzf eigen.tar.gz ) || { log "unpacking Eigen failed"; exit 1; }
  rm -f "$ROOT_DIR/eigen.tar.gz"
fi
[ -f "$EIGEN_ROOT/Eigen/src/Core/util/Macros.h" ] || { log "Eigen headers missing from $EIGEN_ROOT"; exit 1; }
grep -q "define[[:space:]]\+EIGEN_WORLD_VERSION[[:space:]]\+3" "$EIGEN_ROOT/Eigen/src/Core/util/Macros.h" || {
  log "the Eigen at $EIGEN_ROOT is not a 3.x; SMASH 3.3 cannot parse Eigen 5's renamed version macros"
  exit 1
}

# --------------------------------------------------------------------- GSL
# SMASH's FindGSL uses pkg-config first. A machine with no system GSL (common on
# a cluster where everything lives in conda) then fails at configure time with a
# message about GSL rather than about where to find it, so look in the usual
# conda prefixes too and hand cmake an explicit root.
find_gsl_prefix () {
  local p
  if [ -n "${SMASH_GSL_PREFIX:-}" ]; then echo "$SMASH_GSL_PREFIX"; return 0; fi
  if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists gsl 2>/dev/null; then
    p="$(pkg-config --variable=prefix gsl 2>/dev/null || true)"
    [ -n "$p" ] && [ -d "$p" ] && { echo "$p"; return 0; }
  fi
  for p in "${CONDA_PREFIX:-/nonexistent}" "$HOME"/miniforge3/envs/*/ "$HOME"/miniconda3/envs/*/ \
           /opt/homebrew /usr/local /usr; do
    p="${p%/}"
    if [ -f "$p/lib/libgsl.so" ] || [ -f "$p/lib/libgsl.dylib" ] || [ -f "$p/lib/libgsl.a" ]; then
      echo "$p"; return 0
    fi
  done
  return 1
}
GSL_PREFIX="$(find_gsl_prefix || true)"
if [ -n "$GSL_PREFIX" ]; then
  log "GSL prefix: $GSL_PREFIX"
else
  log "GSL not found. Install it (macOS: brew install gsl; Linux: conda install -c conda-forge gsl,"
  log "or the distribution's libgsl-dev) or set SMASH_GSL_PREFIX."
  exit 1
fi

# ------------------------------------------------------------------ Pythia
if [ ! -x "$PYTHIA_PREFIX/bin/pythia8-config" ]; then
  if [ ! -d "$ROOT_DIR/pythia$PYTHIA_VERSION" ]; then
    fetch_tarball "$PYTHIA_URL" "$ROOT_DIR/pythia$PYTHIA_VERSION.tgz" "Pythia $PYTHIA_VERSION" || exit 1
    ( cd "$ROOT_DIR" && tar xzf "pythia$PYTHIA_VERSION.tgz" ) || { log "unpacking Pythia failed"; exit 1; }
    rm -f "$ROOT_DIR/pythia$PYTHIA_VERSION.tgz"
  fi
  log "building Pythia $PYTHIA_VERSION (several minutes, once)"
  ( cd "$ROOT_DIR/pythia$PYTHIA_VERSION" \
    && ./configure --prefix="$PYTHIA_PREFIX" \
    && make -j"$JOBS" && make install ) > "$ROOT_DIR/pythia-build.log" 2>&1 || {
    log "Pythia build failed, last 15 lines of $ROOT_DIR/pythia-build.log:"
    tail -15 "$ROOT_DIR/pythia-build.log" >&2; exit 1; }
fi
[ -x "$PYTHIA_PREFIX/bin/pythia8-config" ] || { log "pythia8-config missing from $PYTHIA_PREFIX"; exit 1; }
PYTHIA_ACTUAL="$("$PYTHIA_PREFIX/bin/pythia8-config" --version 2>/dev/null || echo unknown)"
log "Pythia $PYTHIA_ACTUAL at $PYTHIA_PREFIX"

# -------------------------------------------------------------------- clone
if [ -d "$SRCROOT/.git" ]; then
  log "reusing clone at $SRCROOT"
elif [ -e "$SRCROOT" ]; then
  log "$SRCROOT exists but is not a git clone; refusing to delete a directory this script did not create"
  exit 1
else
  command -v git >/dev/null || { log "git not found"; exit 1; }
  TMPCLONE="$ROOT_DIR/.clone.$$"
  if [ -e "$TMPCLONE" ] && [ ! -f "$TMPCLONE/.fusion_tmpclone" ]; then
    log "refusing to reuse '$TMPCLONE': not one of this script's temporary clones"; exit 1
  fi
  safe_rmrf "$TMPCLONE"
  mkdir -p "$TMPCLONE" && : > "$TMPCLONE/.fusion_tmpclone"
  git clone -q "$REPO" "$TMPCLONE/repo" || { log "clone failed"; safe_rmrf "$TMPCLONE"; exit 1; }
  mv "$TMPCLONE/repo" "$TMPCLONE.repo" && safe_rmrf "$TMPCLONE" && mv "$TMPCLONE.repo" "$SRCROOT"
fi

( cd "$SRCROOT" && git diff --quiet HEAD 2>/dev/null ) || {
  log "the clone at $SRCROOT has uncommitted modifications; refusing to build from it"; exit 1; }
( cd "$SRCROOT" && git checkout -q "$PIN" 2>/dev/null ) || {
  log "cannot check out pinned commit $PIN (shallow clone, or upstream history moved)"
  log "set SMASH_PIN to re-pin deliberately"; exit 1; }
log "pinned at $PIN"

# ------------------------------------------------------------------- build
build_identity () {
  local head dirty cxx
  head="$(cd "$SRCROOT" 2>/dev/null && git rev-parse HEAD 2>/dev/null || echo nohead)"
  if (cd "$SRCROOT" 2>/dev/null && git diff --quiet HEAD 2>/dev/null); then dirty=clean; else dirty=DIRTY; fi
  cxx="$(command -v c++ 2>/dev/null || echo nocxx)|$(c++ --version 2>/dev/null | head -1 || echo nover)"
  echo "$head|$dirty|$cxx|$PYTHIA_ACTUAL|$EIGEN_VERSION|$GSL_PREFIX|$(uname -s)|$(uname -m)"
}
binary_digest () { shasum -a 256 "$BIN" 2>/dev/null | cut -d' ' -f1 || echo nodigest; }

fast_path_ok () {
  [ -x "$BIN" ] || return 1
  [ -f "$STAMP" ] || return 1
  [ "$(cd "$SRCROOT" && git rev-parse HEAD)" = "$PIN" ] || { log "clone HEAD is not the pin, rebuilding"; return 1; }
  [ "$(head -1 "$STAMP")" = "$(build_identity)" ] || { log "build identity changed, rebuilding"; return 1; }
  [ "$(sed -n 2p "$STAMP")" = "$(binary_digest)" ] || { log "the binary changed since it was stamped, rebuilding"; return 1; }
  return 0
}

if fast_path_ok; then
  log "found smash built from the pinned commit with a matching build identity, probing it"
else
  command -v cmake >/dev/null || { log "cmake not found (3.16 or newer required)"; exit 1; }
  mkdir -p "$BUILD"
  log "configuring"
  ( cd "$BUILD" && rm -f CMakeCache.txt && rm -rf CMakeFiles \
    && EIGEN3_ROOT="$EIGEN_ROOT" \
       PKG_CONFIG_PATH="$GSL_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" \
       CMAKE_PREFIX_PATH="$GSL_PREFIX${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}" \
       cmake -DGSL_ROOT_DIR="$GSL_PREFIX" \
         -DPythia_CONFIG_EXECUTABLE="$PYTHIA_PREFIX/bin/pythia8-config" \
         -DEIGEN3_INCLUDE_DIR="$EIGEN_ROOT" .. ) > "$ROOT_DIR/cmake.log" 2>&1 || {
    log "cmake failed, last 15 lines of $ROOT_DIR/cmake.log:"; tail -15 "$ROOT_DIR/cmake.log" >&2; exit 1; }
  log "building with -j$JOBS (several minutes, once)"
  ( cd "$BUILD" && EIGEN3_ROOT="$EIGEN_ROOT" make -j"$JOBS" ) > "$ROOT_DIR/build.log" 2>&1 || {
    log "build failed, last 20 lines of $ROOT_DIR/build.log:"; tail -20 "$ROOT_DIR/build.log" >&2; exit 1; }
  [ -x "$BIN" ] || { log "build reported success but $BIN is missing"; exit 1; }
  { build_identity; binary_digest; } > "$STAMP"
fi

# ------------------------------------------------------------------- probe
# Content is the verdict AND the exit status must be zero. A crash after
# printing a plausible banner would otherwise pass.
probe_binary () {
  local out
  out="$("$BIN" --version 2>&1)" || { log "smash --version exited nonzero"; return 1; }
  case "$out" in
    SMASH-*) : ;;
    *) log "smash --version did not report a SMASH version: ${out%%$'\n'*}"; return 1 ;;
  esac
  log "probe: ${out%%$'\n'*}"
}
probe_binary || { log "the built executable failed its probe"; exit 1; }

echo "SMASH=$BIN"
echo "SMASH_ROOT=$SRCROOT"
echo "SMASH_BUILD=$BUILD"
echo "SMASH_EIGEN3_ROOT=$EIGEN_ROOT"
echo "SMASH_GSL_PREFIX=$GSL_PREFIX"
echo "SMASH_PYTHIA_PREFIX=$PYTHIA_PREFIX"

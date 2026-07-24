#!/bin/bash
# install_thermalfist.sh
#
# Provision Thermal-FIST from source, then print
#   TFIST=<a representative example binary, cpc1HRGTDep>
#   TFIST_ROOT=<repository root>
#   TFIST_BUILD=<build directory, where ctest runs>
#   TFIST_EXAMPLES=<directory holding the example binaries>
# on the last four lines. run_thermalfist.sh and verify_thermalfist.sh parse those.
#
# Thermal-FIST is the hadron-resonance-gas package of V. Vovchenko and H.
# Stoecker, "Thermal-FIST: A package for heavy-ion collisions and hadronic
# equation of state", Comput. Phys. Commun. 244, 295-310 (2019),
# DOI 10.1016/j.cpc.2019.06.024. GPL-3.0 (LICENSE, and the GitHub license API).
# Pinned to release v1.6.1, commit fe5c61af00cf.
#
# Unlike SMASH, Thermal-FIST carries no awkward external dependencies: Eigen
# 3.4.0 and Minuit2 are bundled under thirdparty/, and with no ROOTSYS in the
# environment the build uses the bundled standalone Minuit2. The ONLY network
# fetch is GoogleTest (release-1.12.1, via FetchContent), needed because this
# skill builds the test suite (-DINCLUDE_TESTS=ON). So configure needs network
# on the first build and nothing after. A Qt6 install is detected and, if
# present, an unused GUI is built as well; Qt is optional and its absence is not
# an error (see references/failure-modes.md).
set -euo pipefail

ROOT_DIR="${TFIST_ROOT_DIR:-$HOME/.cache/fusion/thermal-fist}"
mkdir -p "$ROOT_DIR"
ROOT_CANON="$(cd "$ROOT_DIR" && pwd -P)"

REPO="${TFIST_REPO:-https://github.com/vlvovch/Thermal-FIST.git}"
PIN="${TFIST_PIN:-fe5c61af00cf84765afa4746120d0bdb58c419ae}"       # release v1.6.1
# A pin is a 40-hex commit hash. Validating the FORMAT also blocks an
# option-injection like TFIST_PIN=--detach reaching `git checkout` as a flag.
printf '%s' "$PIN" | grep -qE '^[0-9a-f]{40}$' || { echo "install_thermalfist: TFIST_PIN must be a 40-char hex hash, got '$PIN'" >&2; exit 1; }

SRCROOT="$ROOT_DIR/src"
BUILD="$ROOT_DIR/build"
EXAMPLES="$BUILD/bin/examples"
BIN="$EXAMPLES/cpc1HRGTDep"
STAMP="$BUILD/.fusion_build_stamp"
JOBS="${TFIST_JOBS:-$( (command -v nproc >/dev/null && nproc) || sysctl -n hw.ncpu 2>/dev/null || echo 4 )}"

log () { echo "install_thermalfist: $*" >&2; }

# Delete only inside our own cache root, never a short or well-known path.
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

# A symlinked src or build lets git, cmake and the CMakeCache/CMakeFiles deletion
# operate on a directory OUTSIDE the cache root: a symlinked build would make
# `rm -rf CMakeFiles` escape, and a symlinked src would let `git fetch/checkout`
# mutate an external repository. Refuse both, and require anything that exists to
# resolve strictly inside the cache root.
for p in "$SRCROOT" "$BUILD"; do
  if [ -L "$p" ]; then log "refusing to use '$p': it is a symlink"; exit 1; fi
  if [ -e "$p" ]; then
    rp="$(cd "$p" 2>/dev/null && pwd -P || echo none)"
    case "$rp/" in "$ROOT_CANON"/*) : ;; *) log "refusing to use '$p': it resolves to '$rp', outside the cache root"; exit 1 ;; esac
  fi
done

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
( cd "$SRCROOT" && git fetch -q --all 2>/dev/null || true )
( cd "$SRCROOT" && git checkout -q "$PIN" 2>/dev/null ) || {
  log "cannot check out pinned commit $PIN (shallow clone, or upstream history moved)"
  log "set TFIST_PIN to re-pin deliberately"; exit 1; }
log "pinned at $PIN (release v1.6.1)"

# ------------------------------------------------------------------- build
build_identity () {
  local head dirty cxx
  head="$(cd "$SRCROOT" 2>/dev/null && git rev-parse HEAD 2>/dev/null || echo nohead)"
  if (cd "$SRCROOT" 2>/dev/null && git diff --quiet HEAD 2>/dev/null); then dirty=clean; else dirty=DIRTY; fi
  cxx="$(command -v c++ 2>/dev/null || echo nocxx)|$(c++ --version 2>/dev/null | head -1 || echo nover)"
  echo "$head|$dirty|$cxx|$(uname -s)|$(uname -m)"
}
binary_digest () { shasum -a 256 "$BIN" 2>/dev/null | cut -d' ' -f1 || echo nodigest; }

fast_path_ok () {
  [ -x "$BIN" ] || return 1
  [ -f "$STAMP" ] || return 1
  [ "$(cd "$SRCROOT" && git rev-parse HEAD)" = "$PIN" ] || { log "clone HEAD is not the pin, rebuilding"; return 1; }
  [ "$(head -1 "$STAMP")" = "$(build_identity)" ] || { log "build identity changed, rebuilding"; return 1; }
  # Unlike SMASH (whose own library ctest relinks the binary during a run, so a
  # digest change is expected and merely re-stamped), Thermal-FIST's examples are
  # never relinked by its tests. So an UNEXPLAINED digest change means the binary
  # was swapped or corrupted, and the honest response is to REBUILD from source,
  # not to bless whatever is there.
  [ "$(sed -n 2p "$STAMP")" = "$(binary_digest)" ] || { log "the binary's digest changed with no build-input change; rebuilding from source"; return 1; }
  return 0
}

if fast_path_ok; then
  log "found Thermal-FIST built from the pinned commit with a matching build identity, probing it"
else
  command -v cmake >/dev/null || { log "cmake not found (3.21 or newer required)"; exit 1; }
  mkdir -p "$BUILD"
  log "configuring (fetches GoogleTest on the first build; needs network once)"
  ( cd "$BUILD" && rm -f CMakeCache.txt && rm -rf CMakeFiles \
    && cmake -DCMAKE_BUILD_TYPE=Release -DINCLUDE_TESTS=ON "$SRCROOT" ) > "$ROOT_DIR/cmake.log" 2>&1 || {
    log "cmake failed, last 20 lines of $ROOT_DIR/cmake.log:"; tail -20 "$ROOT_DIR/cmake.log" >&2
    log "if the failure names googletest or a download, configure needs network for the FetchContent step"
    exit 1; }
  log "building with -j$JOBS (a few minutes, once)"
  ( cd "$BUILD" && cmake --build . -j"$JOBS" ) > "$ROOT_DIR/build.log" 2>&1 || {
    log "build failed, last 25 lines of $ROOT_DIR/build.log:"; tail -25 "$ROOT_DIR/build.log" >&2; exit 1; }
  [ -x "$BIN" ] || { log "build reported success but $BIN is missing"; exit 1; }
  { build_identity; binary_digest; } > "$STAMP"
fi

# ------------------------------------------------------------------- probe
# Content is the verdict AND the exit status must be zero. A crash after writing
# a partial banner would otherwise pass, and a substituted binary that merely
# prints 100+ lines used to slip through a line count. The probe now validates
# the FULL structure (181 rows, 7 numeric columns) and the physics anchor
# (T=150 MeV thermodynamics) via check_output_thermalfist.py.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/check_output_thermalfist.py"
probe_binary () {
  local wd
  wd="$(mktemp -d)"
  ( cd "$wd" && "$BIN" 0 ) > "$wd/stdout.txt" 2>&1 || { log "cpc1HRGTDep exited nonzero"; rm -rf "$wd"; return 1; }
  if [ ! -s "$wd/cpc1.Id-HRG.TDep.out" ]; then
    log "cpc1HRGTDep produced no cpc1.Id-HRG.TDep.out"; rm -rf "$wd"; return 1
  fi
  if ! python3 "$CHECK" "$wd/cpc1.Id-HRG.TDep.out" --min-rows 181 --min-cols 7 \
        --row-at 0 150 --expect 1 0.647513 2 3.846843 3 4.494356 --accuracy 1e-5 >/dev/null; then
    log "cpc1HRGTDep output failed structural/anchor validation (truncated, wrong shape, or wrong physics)"
    rm -rf "$wd"; return 1
  fi
  rm -rf "$wd"
  log "probe: cpc1HRGTDep output has 181 rows, 7 columns, and the T=150 MeV anchor matches"
}
probe_binary || { log "the built binary failed its probe"; exit 1; }

echo "TFIST=$BIN"
echo "TFIST_ROOT=$SRCROOT"
echo "TFIST_BUILD=$BUILD"
echo "TFIST_EXAMPLES=$EXAMPLES"

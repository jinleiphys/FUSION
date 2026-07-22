#!/bin/bash
# install_cnok.sh
#
# Provision the CNOK executable: clone, resolve yaml-cpp, apply the two
# portability patches, build with CMake, prove it runs, and print
#   CNOK=<path to the mom executable>
#   CNOK_BUILD=<build directory; mom must be run from here, it reads config/ by cwd>
#   CNOK_YAMLLIB=<directory holding libyaml-cpp, for the runtime loader path>
# on the last three lines. run_cnok.sh and verify_cnok.sh parse those.
#
# CNOK is the C++ Glauber single-nucleon-knockout code of Y.Z. Sun and S.T. Wang,
# Comput. Phys. Commun. 288, 108726 (2023), GPL-3.0, gitee.com/asiarabbit/cnok.
# It targets Linux + gcc; two edits are needed to build it under Apple clang /
# libc++, both proven behaviour-preserving by a four-build cross check (see
# references/verification.md):
#
#   1. fabs(std::complex<double>) in the templated Romberg/interpolation headers.
#      libstdc++ accepts it (returns the magnitude); libc++ has no such overload.
#      Rewritten to std::abs, which IS the magnitude for complex and is identical
#      to fabs for the real (double) instantiations. Applied on every platform:
#      the Linux gcc build gives bit-identical output with and without this edit,
#      so it changes portability, not numbers.
#   2. `ulong` in the FCI library header. It is a BSD/glibc alias that libc++ in
#      C++ mode does not expose; macOS ships only `u_long`. A typedef guarded by
#      __APPLE__ supplies it and is inert on Linux.
#
# A third difference is a link-time flag, not a source edit: CNOK's FCI shared
# library references symbols defined in the CNOK library, which a Linux .so
# resolves lazily but a macOS .dylib rejects by default. On Darwin the build adds
# -Wl,-undefined,dynamic_lookup (the final `mom` link supplies every symbol). The
# flag is a macOS ld spelling and is NOT passed on Linux.
set -euo pipefail

ROOT_DIR="${CNOK_ROOT:-$HOME/.cache/fusion/cnok}"
REPO="${CNOK_REPO:-https://gitee.com/asiarabbit/cnok}"
SRCDIR="$ROOT_DIR/cnok-src"
BUILD="$ROOT_DIR/build"
BIN="$BUILD/mom"
# The documented benchmark configuration ships in the repo at config/C/C16.
BENCH_BASEDIR="config/C/C16"
BENCH_NAME="1s11p"

log () { echo "install_cnok: $*" >&2; }

# ---------------------------------------------------------------------------
# yaml-cpp: mandatory. Resolve an include dir and a lib dir, provisioning from
# source on Linux if the system has none. Sets YAML_INC and YAML_LIB.
# ---------------------------------------------------------------------------
resolve_yamlcpp () {
  YAML_INC=""; YAML_LIB=""
  # 1. Homebrew (macOS, and Linuxbrew).
  if command -v brew >/dev/null 2>&1; then
    local p; p="$(brew --prefix yaml-cpp 2>/dev/null || true)"
    if [ -n "$p" ] && [ -f "$p/include/yaml-cpp/yaml.h" ]; then
      YAML_INC="$p/include"; YAML_LIB="$p/lib"; return 0
    fi
  fi
  # 2. System locations.
  local d
  for d in /usr /usr/local /opt/homebrew; do
    if [ -f "$d/include/yaml-cpp/yaml.h" ]; then
      YAML_INC="$d/include"
      for l in "$d/lib" "$d/lib64" "$d/lib/x86_64-linux-gnu"; do
        ls "$l"/libyaml-cpp.* >/dev/null 2>&1 && { YAML_LIB="$l"; break; }
      done
      [ -n "$YAML_LIB" ] && return 0
    fi
  done
  # 3. A previous source build in our cache.
  if [ -f "$ROOT_DIR/ycpp-inst/include/yaml-cpp/yaml.h" ]; then
    YAML_INC="$ROOT_DIR/ycpp-inst/include"
    for l in "$ROOT_DIR/ycpp-inst/lib" "$ROOT_DIR/ycpp-inst/lib64"; do
      ls "$l"/libyaml-cpp.* >/dev/null 2>&1 && { YAML_LIB="$l"; break; }
    done
    [ -n "$YAML_LIB" ] && return 0
  fi
  # 4. On macOS, tell the user to brew it (building GCC-less is not our job).
  if [ "$(uname -s)" = "Darwin" ]; then
    log "yaml-cpp not found. Install it with:  brew install yaml-cpp"
    return 1
  fi
  # 5. Linux: build yaml-cpp from source into the cache.
  log "yaml-cpp not found on the system; building it from source into $ROOT_DIR/ycpp-inst"
  command -v git   >/dev/null || { log "git required to fetch yaml-cpp"; return 1; }
  command -v cmake >/dev/null || { log "cmake required to build yaml-cpp"; return 1; }
  local yroot="$ROOT_DIR/yaml-cpp"
  rm -rf "$yroot"
  git clone -q --depth 1 https://github.com/jbeder/yaml-cpp.git "$yroot" \
    || git clone -q --depth 1 https://gitee.com/mirrors/yaml-cpp.git "$yroot" \
    || { log "failed to clone yaml-cpp"; return 1; }
  cmake -S "$yroot" -B "$ROOT_DIR/ycpp-build" \
        -DYAML_CPP_BUILD_TESTS=OFF -DYAML_BUILD_SHARED_LIBS=ON \
        -DCMAKE_INSTALL_PREFIX="$ROOT_DIR/ycpp-inst" >"$ROOT_DIR/ycpp-cmake.log" 2>&1 \
    && cmake --build "$ROOT_DIR/ycpp-build" -j4 >"$ROOT_DIR/ycpp-make.log" 2>&1 \
    && cmake --install "$ROOT_DIR/ycpp-build" >"$ROOT_DIR/ycpp-inst.log" 2>&1 \
    || { log "yaml-cpp build failed; see $ROOT_DIR/ycpp-*.log"; return 1; }
  YAML_INC="$ROOT_DIR/ycpp-inst/include"
  for l in "$ROOT_DIR/ycpp-inst/lib" "$ROOT_DIR/ycpp-inst/lib64"; do
    ls "$l"/libyaml-cpp.* >/dev/null 2>&1 && { YAML_LIB="$l"; break; }
  done
  [ -n "$YAML_LIB" ]
}

# ---------------------------------------------------------------------------
# Probe: run the documented benchmark and require finite, positive cross
# sections in the RESULT FILE (content, not exit status). mom is deterministic
# and takes ~8 s. Runs on both the cache fast path and after a fresh build.
# ---------------------------------------------------------------------------
probe_binary () {
  [ -x "$BIN" ] || { log "no mom executable at $BIN"; return 1; }
  # cmake copies the source config/ tree verbatim into the build dir, so the deck
  # lives at $BUILD/config/C/C16/..., i.e. $BUILD/$BENCH_BASEDIR (BENCH_BASEDIR
  # already begins with "config/"). basedir.yaml sits one level up.
  [ -f "$BUILD/$BENCH_BASEDIR/$BENCH_NAME.yaml" ] || {
    log "benchmark config $BENCH_BASEDIR/$BENCH_NAME.yaml missing from build tree"; return 1; }
  # Point basedir at the benchmark and clear any stale result files.
  perl -pi -e "s{^basedir:.*}{basedir: $BENCH_BASEDIR}" "$BUILD/config/basedir.yaml"
  rm -f "$BUILD/$BENCH_BASEDIR/${BENCH_NAME}"_*.txt
  local rc
  set +e
  ( cd "$BUILD" && DYLD_LIBRARY_PATH="$YAML_LIB:${DYLD_LIBRARY_PATH:-}" \
      LD_LIBRARY_PATH="$YAML_LIB:${LD_LIBRARY_PATH:-}" \
      ./mom "$BENCH_NAME" >probe.out 2>probe.err )
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    log "mom exited $rc on the $BENCH_NAME probe"; tail -5 "$BUILD/probe.err" >&2; return 1
  fi
  local res
  res="$(ls -t "$BUILD/$BENCH_BASEDIR/${BENCH_NAME}"_*.txt 2>/dev/null | head -1)"
  [ -n "$res" ] || { log "probe wrote no result file"; return 1; }
  # Extract the three cross sections and require all finite and > 0.
  python3 - "$res" <<'PY' || { log "probe result file has no finite positive cross sections"; return 1; }
import re,sys,math
t=open(sys.argv[1]).read()
labels={"Stripping":"Stripping c.s.:","Diffractive":"Diffractive c.s.:","Total":"Total knockout c.s.:"}
vals={}
for k,lab in labels.items():
    m=re.search(re.escape(lab)+r"\s+([-\d.eE+]+)",t)
    if not m: sys.exit(1)
    vals[k]=float(m.group(1))
sys.exit(0 if all(math.isfinite(v) and v>0 for v in vals.values()) else 1)
PY
  return 0
}

# --- fast path -------------------------------------------------------------
if [ -x "$BIN" ] && [ -z "${CNOK_FORCE:-}" ]; then
  if resolve_yamlcpp && probe_binary; then
    echo "CNOK=$BIN"
    echo "CNOK_BUILD=$BUILD"
    echo "CNOK_YAMLLIB=$YAML_LIB"
    exit 0
  fi
  log "cached build failed its probe (or yaml-cpp moved); rebuilding"
fi

command -v git   >/dev/null || { log "git required";   exit 1; }
command -v cmake >/dev/null || { log "cmake required"; exit 1; }

resolve_yamlcpp || { log "cannot proceed without yaml-cpp"; exit 1; }

mkdir -p "$ROOT_DIR"
if [ ! -d "$SRCDIR/.git" ]; then
  rm -rf "$SRCDIR"
  git clone -q --depth 1 "$REPO" "$SRCDIR" || { log "failed to clone CNOK from $REPO"; exit 1; }
fi
[ -f "$SRCDIR/CMakeLists.txt" ] || { log "CNOK source incomplete"; exit 1; }
[ -f "$SRCDIR/cnok/inc/TAIntegrate.hpp" ] || { log "CNOK source layout unexpected"; exit 1; }

# --- portability patches (idempotent) --------------------------------------
# 1. fabs -> std::abs in the two templated headers. Behaviour-preserving on both
#    platforms; required to compile under libc++. Apply only if not already done.
for hpp in cnok/inc/TAIntegrate.hpp cnok/inc/TAInterpolate.hpp; do
  if grep -q 'fabs(' "$SRCDIR/$hpp"; then
    perl -pi -e 's/fabs\(/std::abs(/g' "$SRCDIR/$hpp"
  fi
done
# 2. ulong typedef, self-guarded by __APPLE__ so it is inert on Linux.
if ! grep -q 'FUSION: macOS lacks the BSD ulong' "$SRCDIR/fci/inc/TABit.h"; then
  perl -0pi -e 's/(#include <bitset>\n)/$1#ifdef __APPLE__\ntypedef unsigned long ulong; \/\/ FUSION: macOS lacks the BSD ulong alias\n#endif\n/' \
    "$SRCDIR/fci/inc/TABit.h"
fi
grep -q 'std::abs(' "$SRCDIR/cnok/inc/TAIntegrate.hpp" || { log "fabs patch did not apply"; exit 1; }

# --- configure + build -----------------------------------------------------
CM_EXTRA=()
if [ "$(uname -s)" = "Darwin" ]; then
  CM_EXTRA+=(-DCMAKE_SHARED_LINKER_FLAGS="-Wl,-undefined,dynamic_lookup")
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"
(
  cd "$BUILD"
  export CPATH="$YAML_INC:${CPATH:-}" LIBRARY_PATH="$YAML_LIB:${LIBRARY_PATH:-}"
  cmake "$SRCDIR" "${CM_EXTRA[@]}" >cmake.log 2>&1 \
    && make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)" mom >make.log 2>&1
) || {
  log "build failed; see $BUILD/{cmake,make}.log"
  grep -iE "error:|CMake Error" "$BUILD/make.log" "$BUILD/cmake.log" 2>/dev/null | head -10 >&2
  exit 1
}

[ -x "$BIN" ] || { log "no mom executable after build"; exit 1; }

probe_binary || { log "freshly built mom failed its probe"; exit 1; }

echo "CNOK=$BIN"
echo "CNOK_BUILD=$BUILD"
echo "CNOK_YAMLLIB=$YAML_LIB"

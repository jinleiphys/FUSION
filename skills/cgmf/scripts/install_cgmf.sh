#!/bin/bash
# install_cgmf.sh
#
# Provision the CGMF binary: clone, build with CMake, verify it runs, and print
#   CGMF=<path to cgmf.x>
#   CGMFDATA=<path to the 102 MB data directory>
# on the last two lines. run_cgmf.sh and verify_cgmf.sh parse those.
#
# CGMF is the LANL fission-fragment de-excitation Monte Carlo code (Talou et al.,
# Comput. Phys. Commun. 269, 108087 (2021)), BSD-3-Clause, github.com/lanl/CGMF.
# It is plain C++ + CMake and builds clean on macOS and Linux with no patches,
# which is exactly why it is here and GEF (FreeBASIC, no ARM toolchain) is not.
#
# ONE THING THAT IS NOT OBVIOUS: cgmf.x never looks in the current directory for
# its data tables. It resolves the data path as -d flag, then $CGMFDATA, then two
# compiled-in CMake paths (the build tree's ../data, then an install prefix). If
# none resolves it prints "Cannot find valid path to CGMF data" and exits -1. A
# build-tree run therefore works only from a layout where the baked BUILD_DATADIR
# still points at the cloned data/. To be robust from any cwd, this script emits
# CGMFDATA explicitly and the run/verify wrappers export it.
set -euo pipefail

ROOT_DIR="${CGMF_ROOT:-$HOME/.cache/fusion/cgmf}"
REPO="${CGMF_REPO:-https://github.com/lanl/CGMF.git}"
SRCDIR="$ROOT_DIR/CGMF"
BIN="$SRCDIR/build/utils/cgmf/cgmf.x"
DATADIR="$SRCDIR/data"

# Prove a binary runs and produces a well-formed history file, rather than
# assuming its existence means it works. Two events, spontaneous 252Cf, in a
# scratch dir; assert a clean exit, clean stderr, and the expected header. Runs
# on BOTH the cache fast path and after a fresh build: an adversarial pass showed
# the fast path returning a cached binary that just exits nonzero, because
# presence was checked and behaviour was not. Returns 0 if the binary works.
probe_binary () {
  local probe; probe="$(mktemp -d)"
  local rc
  set +e
  ( cd "$probe" && CGMFDATA="$DATADIR" "$BIN" -n 2 -e 0.0 -i 98252 -f probe > run.out 2> run.err )
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    echo "install_cgmf: cgmf.x exited $rc on a 2-event probe" >&2
    tail -5 "$probe/run.err" 2>/dev/null >&2; rm -rf "$probe"; return 1
  fi
  if [ -s "$probe/run.err" ]; then
    echo "install_cgmf: cgmf.x wrote to stderr on a clean probe:" >&2
    head -5 "$probe/run.err" >&2; rm -rf "$probe"; return 1
  fi
  if ! head -1 "$probe/probe.0" 2>/dev/null | grep -q "^# 98252 0"; then
    echo "install_cgmf: probe history file lacks the expected '# 98252 0' header" >&2
    rm -rf "$probe"; return 1
  fi
  rm -rf "$probe"; return 0
}

if [ -x "$BIN" ] && [ -d "$DATADIR" ] && [ -z "${CGMF_FORCE:-}" ]; then
  if probe_binary; then
    echo "CGMF=$BIN"
    echo "CGMFDATA=$DATADIR"
    exit 0
  fi
  echo "install_cgmf: cached binary failed its probe; rebuilding" >&2
fi

command -v git   >/dev/null || { echo "install_cgmf: git required" >&2; exit 1; }
command -v cmake >/dev/null || { echo "install_cgmf: cmake required" >&2; exit 1; }

mkdir -p "$ROOT_DIR"
if [ ! -d "$SRCDIR/.git" ]; then
  git clone -q --depth 1 "$REPO" "$SRCDIR" || {
    echo "install_cgmf: failed to clone CGMF from $REPO" >&2; exit 1; }
fi
[ -f "$SRCDIR/CMakeLists.txt" ] || { echo "install_cgmf: CGMF source incomplete" >&2; exit 1; }
[ -d "$DATADIR" ] || { echo "install_cgmf: data/ directory missing from the clone" >&2; exit 1; }

rm -rf "$SRCDIR/build"
mkdir -p "$SRCDIR/build"
( cd "$SRCDIR/build" && cmake .. -DCMAKE_BUILD_TYPE=Release > cmake.log 2>&1 \
  && cmake --build . -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)" > build.log 2>&1 ) || {
  echo "install_cgmf: build failed; see $SRCDIR/build/{cmake,build}.log" >&2
  grep -iE "error:|CMake Error" "$SRCDIR/build/build.log" "$SRCDIR/build/cmake.log" 2>/dev/null | head -10 >&2
  exit 1
}

[ -x "$BIN" ] || { echo "install_cgmf: no cgmf.x after build" >&2; exit 1; }

probe_binary || { echo "install_cgmf: freshly built cgmf.x failed its probe" >&2; exit 1; }

echo "CGMF=$BIN"
echo "CGMFDATA=$DATADIR"

#!/bin/bash
# install_azure2.sh
#
# Provision the AZURE2 binary: clone, build the standalone Minuit2 it needs,
# build AZURE2 headless, and verify the binary runs.
# Prints "AZURE2=<path>" on success; run_azure2.sh parses that line.
#
# AZURE2 is the Notre Dame multichannel R-matrix code (Azuma et al., Phys. Rev.
# C 81, 045805 (2010)), GPLv3, github.com/rdeboer1/AZURE2.
#
# WHY THIS SCRIPT IS LONG. A stock `cmake .. && make` fails five separate ways
# on a current macOS toolchain, and four of the five produce error messages that
# point somewhere other than the cause. Each fix below is load-bearing:
#
#   1. CMake 4 removed compatibility with `cmake_minimum_required(VERSION <3.5)`,
#      which AZURE2 still declares. Needs CMAKE_POLICY_VERSION_MINIMUM=3.5.
#   2. Minuit2 is a hard dependency and is normally taken from a full ROOT
#      install (1 to 2 GB). The GooFit standalone Minuit2 supplies it in about a
#      minute, so this script builds that instead of pulling in ROOT.
#   3. AZURE2's FindMinuit2.cmake probes for `Minuit2/MnUserFcn.h`, a header
#      modern Minuit2 no longer installs (it moved into src/). The probe fails
#      even though ALL SIX headers AZURE2 actually includes are present. The fix
#      is to seed MINUIT2_INCLUDE_DIR and MINUIT2_LIBRARY directly rather than
#      let the finder run. Verified: AZURE2 includes only FCNBase.h,
#      FunctionMinimum.h, MnMigrad.h, MnMinos.h, MnPrint.h, MnUserParameters.h.
#   4. `coul/include/complex_functions.H` calls the legacy BSD `finite()`, which
#      POSIX removed in 2008 and macOS does not ship. This is the SAME upstream
#      pattern that breaks the GSM book codes on macOS (see the gsm skill); there
#      it recursed forever, here it is a hard compile error. Patched to
#      std::isfinite, idempotently.
#   5. OpenMP is REQUIRED by AZURE2's CMakeLists. Apple clang needs the
#      `-Xclang -fopenmp` shim, which this project's build mangles into a
#      "command not found". Building with Homebrew GCC avoids the shim entirely.
#      But then Minuit2 must ALSO be built with GCC: a clang-built Minuit2 is
#      libc++ (std::__1) and AZURE2 under GCC is libstdc++ (std::__cxx11), and
#      they will not link. Both are therefore pinned to the same compiler here.
#   6. Minuit2 installs TWO archives and AZURE2's finder links only one.
#      ROOT::Math::Util::TimingScope lives in libMinuit2Math.a, so both must be
#      passed or the link fails on missing vtables.
set -euo pipefail

ROOT_DIR="${AZURE2_ROOT:-$HOME/.cache/fusion/azure2}"
AZ_REPO="${AZURE2_REPO:-https://github.com/rdeboer1/AZURE2.git}"
M2_REPO="${MINUIT2_REPO:-https://github.com/GooFit/Minuit2.git}"

SRCDIR="$ROOT_DIR/AZURE2"
M2SRC="$ROOT_DIR/Minuit2"
M2INST="$ROOT_DIR/minuit2-install"
BIN="$SRCDIR/build/src/AZURE2"
# macOS builds the target into an .app bundle; the real executable is inside.
BIN_APP="$SRCDIR/build/src/AZURE2.app/Contents/MacOS/AZURE2"

resolve_bin () {
  if [ -x "$BIN" ]; then echo "$BIN"; return 0; fi
  if [ -x "$BIN_APP" ]; then echo "$BIN_APP"; return 0; fi
  return 1
}

if found="$(resolve_bin)" && [ -z "${AZURE2_FORCE:-}" ]; then
  echo "AZURE2=$found"
  exit 0
fi

command -v git >/dev/null || { echo "install_azure2: git required" >&2; exit 1; }
command -v cmake >/dev/null || { echo "install_azure2: cmake required" >&2; exit 1; }
command -v gsl-config >/dev/null || {
  echo "install_azure2: GSL not found (gsl-config missing). Install it:" >&2
  echo "  macOS: brew install gsl     Debian/Ubuntu: apt-get install libgsl-dev" >&2
  exit 1
}

# Pick a compiler pair with real OpenMP support (fix 5). Prefer GNU; fall back to
# the environment's choice only if the caller insists.
CC_BIN="${AZURE2_CC:-}"
CXX_BIN="${AZURE2_CXX:-}"
if [ -z "$CXX_BIN" ]; then
  for v in 15 14 13 12; do
    if command -v "g++-$v" >/dev/null 2>&1; then
      CC_BIN="$(command -v "gcc-$v")"
      CXX_BIN="$(command -v "g++-$v")"
      break
    fi
  done
fi
if [ -z "$CXX_BIN" ]; then
  echo "install_azure2: no GNU g++ found (looked for g++-15 down to g++-12)." >&2
  echo "  AZURE2 requires OpenMP; Apple clang needs a shim this build mangles." >&2
  echo "  macOS: brew install gcc      Or set AZURE2_CC / AZURE2_CXX yourself." >&2
  exit 1
fi
echo "install_azure2: using $CXX_BIN" >&2

mkdir -p "$ROOT_DIR"

# --- Minuit2, built with the SAME compiler as AZURE2 (fix 2 and fix 5) --------
if [ ! -f "$M2INST/lib/libMinuit2.a" ] || [ ! -f "$M2INST/lib/libMinuit2Math.a" ]; then
  [ -d "$M2SRC/.git" ] || git clone -q --depth 1 "$M2_REPO" "$M2SRC" || {
    echo "install_azure2: failed to clone Minuit2 from $M2_REPO" >&2; exit 1; }
  rm -rf "$M2SRC/build"
  mkdir -p "$M2SRC/build"
  ( cd "$M2SRC/build" && cmake .. \
      -DCMAKE_INSTALL_PREFIX="$M2INST" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_COMPILER="$CC_BIN" -DCMAKE_CXX_COMPILER="$CXX_BIN" \
      -Dminuit2_mpi=OFF -Dminuit2_omp=OFF > cmake.log 2>&1 \
    && make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)" install > make.log 2>&1 ) || {
    echo "install_azure2: Minuit2 build failed; see $M2SRC/build/make.log" >&2
    tail -20 "$M2SRC/build/make.log" 2>/dev/null >&2
    exit 1
  }
fi
for lib in libMinuit2.a libMinuit2Math.a; do
  [ -f "$M2INST/lib/$lib" ] || { echo "install_azure2: missing $lib after Minuit2 build" >&2; exit 1; }
done
# The header the finder wants does not exist in modern Minuit2 (fix 3); assert on
# one that AZURE2 genuinely includes instead.
[ -f "$M2INST/include/Minuit2/Minuit2/FCNBase.h" ] || {
  echo "install_azure2: Minuit2 headers not where expected under $M2INST" >&2; exit 1; }

# --- AZURE2 -------------------------------------------------------------------
[ -d "$SRCDIR/.git" ] || git clone -q --depth 1 "$AZ_REPO" "$SRCDIR" || {
  echo "install_azure2: failed to clone AZURE2 from $AZ_REPO" >&2; exit 1; }
[ -f "$SRCDIR/CMakeLists.txt" ] || { echo "install_azure2: AZURE2 source incomplete" >&2; exit 1; }

# Fix 4: legacy BSD finite() on complex. Idempotent, and asserted afterwards.
CF="$SRCDIR/coul/include/complex_functions.H"
if [ -f "$CF" ] && grep -q 'return (finite (x) && finite (y));' "$CF"; then
  echo "install_azure2: patching legacy finite() in complex_functions.H" >&2
  perl -pi -e 's/return \(finite \(x\) && finite \(y\)\);/return (std::isfinite (x) \&\& std::isfinite (y));/' "$CF"
fi
if [ -f "$CF" ] && grep -q 'return (finite (x) && finite (y));' "$CF"; then
  echo "install_azure2: finite() patch did not apply" >&2; exit 1
fi

rm -rf "$SRCDIR/build"
mkdir -p "$SRCDIR/build"
( cd "$SRCDIR/build" && cmake .. \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_GUI=OFF -DUSE_QWT=OFF -DUSE_READLINE=OFF \
    -DMINUIT2_INCLUDE_DIR="$M2INST/include/Minuit2" \
    -DMINUIT2_LIBRARY="$M2INST/lib/libMinuit2.a;$M2INST/lib/libMinuit2Math.a" \
    -DCMAKE_C_COMPILER="$CC_BIN" -DCMAKE_CXX_COMPILER="$CXX_BIN" \
    -DCMAKE_BUILD_TYPE=Release > cmake.log 2>&1 \
  && make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)" > make.log 2>&1 ) || {
  echo "install_azure2: AZURE2 build failed; see $SRCDIR/build/make.log" >&2
  grep -E "error:|Undefined symbols" "$SRCDIR/build/make.log" 2>/dev/null | head -10 >&2
  exit 1
}

found="$(resolve_bin)" || { echo "install_azure2: no AZURE2 binary after build" >&2; exit 1; }

# Prove the binary runs rather than assuming it. Two probes, because the two
# outputs differ and an earlier version of this check asserted the wrong one:
# with NO arguments AZURE2 prints only a short "A valid configuration file must
# be specified" plus a one-line syntax banner, while the full option list
# appears only under --help. Assert on both, each against its own output.
probe="$ROOT_DIR/probe.out"
set +e
"$found" > "$probe" 2>&1
set -e
if ! grep -q "Syntax: AZURE2" "$probe"; then
  echo "install_azure2: the built binary did not print its syntax banner." >&2
  head -5 "$probe" >&2
  exit 1
fi
set +e
"$found" --help > "$probe" 2>&1
set -e
if ! grep -q -- "--no-gui" "$probe"; then
  echo "install_azure2: --help did not list the expected console-mode options." >&2
  head -10 "$probe" >&2
  exit 1
fi
rm -f "$probe"

echo "AZURE2=$found"

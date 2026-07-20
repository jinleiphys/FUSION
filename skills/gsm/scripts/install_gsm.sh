#!/bin/bash
# install_gsm.sh [target ...] [--force]
#
# Ensure the Gamow Shell Model codes are fetched, patched, and built.
#
# Source:  https://github.com/GSMUTNSR/book_codes   (the address given in the book)
#          N. Michel, M. Ploszajczak, "Gamow Shell Model: The Unified Theory of
#          Nuclear Structure and Reactions", Lecture Notes in Physics 983,
#          Springer (2021). Academic Free License v3.0.
#
# The repository ships zip archives at top level, not an unpacked tree:
#   GSM_code_repository.zip  -> GSM_code/      (sources)
#   workspace_for_GSM.zip    -> workspace_for_GSM/ (interaction files)
#   Qbox_interaction.zip     -> Qbox wave functions (optional, large)
#
# Targets (name -> build dir : binary), default "one res gsm2":
#   one      Gamow_one/One_particle_dir      : run_one
#   one-ptg  Gamow_one/One_particle_PTG_dir  : run_one
#   res      Gamow_one/resonances_dir        : run_res
#   opt      Gamow_one/optimization_code_dir : run_opt
#   rotor    CC_rotor_dir                    : CC_rotor_exe
#   gsm2     GSM_two_dir                     : GSM_two_exe
#   gsm2rel  GSM_two_relative_dir            : GSM_two_relative_exe
#   gsm1d    GSM_dir_1D/GSM_dir              : GSM_exe
#   gsm2d    GSM_dir_2D/GSM_dir              : GSM_exe
#   cc1d     GSM_dir_1D/CC_dir               : CC_exe
#
# Config (env overrides):
#   GSM_ROOT     where to clone/build  (default: ~/.cache/fusion/gsm)
#   GSM_CXX      GNU C++ compiler      (default: autodetected g++-NN)
#   GSM_JOBS     parallel make jobs    (default: 8)
#
# Exit 0 = requested binaries in place. Prints: GSM_ROOT=/path/to/tree
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${GSM_ROOT:-$HOME/.cache/fusion/gsm}"
JOBS="${GSM_JOBS:-8}"
REPO="https://github.com/GSMUTNSR/book_codes.git"

FORCE=0; TARGETS=()
for a in "$@"; do
  case "$a" in
    --force) FORCE=1 ;;
    -*) echo "unknown flag: $a" >&2; exit 2 ;;
    *) TARGETS+=("$a") ;;
  esac
done
[ ${#TARGETS[@]} -gt 0 ] || TARGETS=(one res gsm2)

target_dir () {
  case "$1" in
    one)     echo "Gamow_one/One_particle_dir:run_one" ;;
    one-ptg) echo "Gamow_one/One_particle_PTG_dir:run_one" ;;
    res)     echo "Gamow_one/resonances_dir:run_res" ;;
    opt)     echo "Gamow_one/optimization_code_dir:run_opt" ;;
    rotor)   echo "CC_rotor_dir:CC_rotor_exe" ;;
    gsm2)    echo "GSM_two_dir:GSM_two_exe" ;;
    gsm2rel) echo "GSM_two_relative_dir:GSM_two_relative_exe" ;;
    gsm1d)   echo "GSM_dir_1D/GSM_dir:GSM_exe" ;;
    gsm2d)   echo "GSM_dir_2D/GSM_dir:GSM_exe" ;;
    cc1d)    echo "GSM_dir_1D/CC_dir:CC_exe" ;;
    *) echo "" ;;
  esac
}

for t in "${TARGETS[@]}"; do
  [ -n "$(target_dir "$t")" ] || { echo "unknown target: $t" >&2; exit 2; }
done

for tool in git unzip make perl; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing tool: $tool" >&2; exit 3; }
done

# ---------------------------------------------------------------- fetch/unpack
if [ ! -d "$ROOT/.git" ]; then
  mkdir -p "$(dirname "$ROOT")"
  echo "cloning GSM book codes into $ROOT" >&2
  git clone --depth 1 "$REPO" "$ROOT" >&2
fi
cd "$ROOT"
[ -d GSM_code ]          || unzip -q -o GSM_code_repository.zip >&2
[ -d workspace_for_GSM ] || unzip -q -o workspace_for_GSM.zip >&2

# ------------------------------------------------------------------- patch
# Portability fix, required on macOS and any platform whose libm no longer
# exposes the legacy BSD finite(double).  numlib/complex_add.cpp defines
# finite(const complex<double>&) and inside it calls finite(x) on a double,
# expecting the C library overload.  Where that overload is absent the double
# converts back to complex<double> and the function recurses into itself until
# the stack guard page is hit (SIGSEGV inside the prologue, no message).
# std::isfinite is the standard, always-present spelling.
#
# This must never fail quietly: an unapplied patch builds fine and only dies at
# run time, which looks like a bad input deck.  So the patch is verified after
# it runs, and applying it forces a rebuild of anything compiled before it.
CA="$ROOT/GSM_code/numlib/complex_add/complex_add.cpp"
PATCHED_NOW=0
# The self-call, tolerating any spacing: "= finite (x);", "=finite(x);", ...
SELFCALL='=[[:space:]]*finite[[:space:]]*\([[:space:]]*[xy][[:space:]]*\)[[:space:]]*;'

[ -f "$CA" ] || { echo "missing source file: $CA" >&2; exit 4; }

if grep -q 'std::isfinite' "$CA"; then
  : # already patched
elif grep -qE "$SELFCALL" "$CA"; then
  echo "applying finite() recursion patch to complex_add.cpp" >&2
  perl -pi -e 's/=\s*finite\s*\(\s*([xy])\s*\)\s*;/= std::isfinite ($1);/g' "$CA"
  PATCHED_NOW=1
else
  # Neither the bug nor the fix is recognisable: upstream changed this code.
  # Refuse rather than ship a binary that may recurse at run time.
  echo "ERROR: cannot recognise the finite() code in $CA." >&2
  echo "Upstream may have changed it. Check that finite(const complex<double>&)" >&2
  echo "does not call finite() on a double, then update install_gsm.sh." >&2
  exit 6
fi

# Verify the patch actually took, whatever path we came through.
if grep -qE "$SELFCALL" "$CA"; then
  echo "ERROR: the finite() recursion patch did not apply to $CA." >&2
  echo "Leaving it would produce a binary that segfaults (exit 139, empty stderr)" >&2
  echo "as soon as it evaluates a complex number." >&2
  exit 6
fi
grep -q 'std::isfinite' "$CA" || { echo "ERROR: patch left no std::isfinite call in $CA" >&2; exit 6; }

# Anything compiled before the patch still contains the recursion. Drop the
# stale object and every built binary so the build below genuinely redoes them.
if [ "$PATCHED_NOW" = 1 ]; then
  echo "patch applied: discarding objects and binaries built before it" >&2
  find "$ROOT/GSM_code" -name '*.o' -delete 2>/dev/null || true
  for b in run_one run_res run_opt CC_rotor_exe GSM_two_exe \
           GSM_two_relative_exe GSM_exe CC_exe; do
    find "$ROOT/GSM_code" -name "$b" -type f -delete 2>/dev/null || true
  done
fi

# ---------------------------------------------------------------- compiler
# The code needs a real GNU C++ compiler.  Apple clang rejects several
# out-of-line template definitions that GCC accepts, so clang is not usable.
CXX="${GSM_CXX:-}"
if [ -z "$CXX" ]; then
  for c in g++-16 g++-15 g++-14 g++-13 g++; do
    if command -v "$c" >/dev/null 2>&1 && "$c" --version 2>/dev/null | head -1 | grep -qi "g++\|GCC"; then
      # reject the g++ that is really Apple clang
      "$c" --version 2>/dev/null | grep -qi clang || { CXX="$c"; break; }
    fi
  done
fi
[ -n "$CXX" ] || { echo "no GNU g++ found (install: brew install gcc)" >&2; exit 3; }

MPICXX="$(command -v mpic++ || true)"
[ -n "$MPICXX" ] || { echo "no mpic++ found (install: brew install open-mpi)" >&2; exit 3; }

CXXFLAGS="-fopenmp -O2 -w"

# GCC 15 turned template-body diagnostics into hard errors (-Wtemplate-body).
# Two upstream declarations in numlib never match their definitions but are
# never instantiated either, so they are harmless; downgrade to warnings.
if "$CXX" --version 2>/dev/null | head -1 | grep -qE '\b(1[5-9]|[2-9][0-9])\.' ; then
  CXXFLAGS="$CXXFLAGS -fpermissive"
fi

# Homebrew GCC keeps a private fixincludes copy of the macOS headers.  After an
# Xcode SDK bump that copy goes stale and its _stdio.h includes a _bounds.h it
# cannot find.  Putting the live SDK headers first resolves it without touching
# the brew installation.
if [ "$(uname -s)" = "Darwin" ] && command -v xcrun >/dev/null 2>&1; then
  SDK="$(xcrun --show-sdk-path 2>/dev/null || true)"
  [ -n "$SDK" ] && CXXFLAGS="$CXXFLAGS -I$SDK/usr/include"
fi

export OMPI_CXX="$CXX"
export MPICH_CXX="$CXX"

# ------------------------------------------------------------------- build
for t in "${TARGETS[@]}"; do
  spec="$(target_dir "$t")"; d="${spec%%:*}"; bin="${spec##*:}"
  full="$ROOT/GSM_code/$d"
  [ -d "$full" ] || { echo "missing build dir: $full" >&2; exit 4; }
  if [ "$FORCE" = 0 ] && [ -x "$full/$bin" ]; then
    echo "$t already built: $full/$bin" >&2; continue
  fi
  echo "building $t in $d (CXX=$CXX)" >&2
  ( cd "$full" && [ "$FORCE" = 1 ] && make clean >/dev/null 2>&1 || true )
  # All build chatter goes to stderr: stdout carries only the GSM_ROOT= line,
  # which callers capture.
  ( cd "$full" && make -j"$JOBS" "CC = $MPICXX $CXXFLAGS" ) >&2
  [ -x "$full/$bin" ] || { echo "build failed for $t ($bin not produced)" >&2; exit 5; }
  echo "built $full/$bin" >&2
done

echo "GSM_ROOT=$ROOT"

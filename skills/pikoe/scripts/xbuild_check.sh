#!/bin/bash
# Cross-build reproduction test for pikoe.
#
# Rationale: the author's reference output was produced by the same source, so it
# can only certify BUILD INTEGRITY, not physics. Cross-compiler / cross-arch /
# cross-optimization agreement certifies the same thing and tests more
# configurations. -O0 vs -O2 additionally exposes uninitialized-variable UB,
# because the two pick up different memory garbage.
set -uo pipefail

SRC="${PIKOE_SRC:?set PIKOE_SRC to the pikoe1.1 dir}"
OUT="${1:?usage: xbuild.sh <outdir>}"
FC="${FC:-gfortran}"
mkdir -p "$OUT"
# Absolutize: every run cd's into its case dir, so a relative binary path breaks.
OUT="$(cd "$OUT" && pwd)"
SRC="$(cd "$SRC" && pwd)"

echo "== compiler: $($FC --version | head -1)"
echo "== arch: $(uname -m) $(uname -s)"

# Variant flag sets. trap = UB detector, not a performance build.
run_variant () {
  local name="$1"; shift
  local flags="$*"
  local vdir="$OUT/$name"
  mkdir -p "$vdir"
  echo "-- building $name [$flags]"
  # Stale .mod files in the SOURCE dir poison a build by a different gfortran
  # ("created by a different version of GNU Fortran"). They get there because
  # the skill's installer writes -J into the source dir. Clear them per variant.
  rm -f "$SRC"/*.mod
  $FC $flags -J "$vdir" -o "$vdir/pikoe" "$SRC/pikoe1.1.f90" 2> "$vdir/build.log"
  if [ ! -x "$vdir/pikoe" ]; then
    echo "   BUILD FAILED, see $vdir/build.log"; return 1
  fi
  for s in sample1:TDXnorm sample4:TDXinv sample5:QDXinv; do
    local sd="${s%%:*}" tag="${s##*:}"
    local deck; deck="$(ls "$SRC/$sd"/*.cnt 2>/dev/null | head -1)"
    [ -n "$deck" ] || { echo "   no deck in $sd"; continue; }
    # Decks reference ../elem and ../pot, so those live one level ABOVE the run
    # dir. Run in <tag>/case with the symlinks in <tag>/, matching the shipped
    # layout, so the decks are used verbatim and never rewritten.
    local cd_="$vdir/$tag/case"; mkdir -p "$cd_"
    ln -sfn "$SRC/elem" "$vdir/$tag/elem"; ln -sfn "$SRC/pot" "$vdir/$tag/pot"
    ( cd "$cd_" && "$vdir/pikoe" < "$deck" > run.stdout 2> run.stderr )
    # positive assertion: non-empty data output, never exit status
    local n; n=$(find "$cd_" -name '*.dat' -size +0 2>/dev/null | wc -l | tr -d ' ')
    echo "   $tag: $n non-empty .dat"
  done
}

run_variant O2   -O2
run_variant O0   -O0
run_variant trap -O2 -finit-real=snan -finit-integer=-99999 -finit-logical=false

echo "== done: $OUT"

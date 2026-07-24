#!/bin/bash
# install_vhlle.sh
#
# Clone, pin and build vHLLE (Karpenko, Huovinen, Bleicher, Comput. Phys. Commun.
# 185, 3016 (2014); GPL-2.0). Builds ONE binary per call, selected by VHLLE_EOS:
#
#   VHLLE_EOS=table  (default) -> hlle_visc, the production binary with the Laine
#                                 nf3 lattice EoS. This is what students use for
#                                 realistic collisions.
#   VHLLE_EOS=simple           -> hlle_visc_simple, the conformal p=e/3 EoS used
#                                 for the analytic Gubser-flow benchmark.
#
# The EoS is a COMPILE-TIME choice in src/eos.cpp (the code itself documents the
# TABLE/SIMPLE toggle; see README.txt). Selecting it is a benchmark configuration,
# not a source patch to functional code: only the two `#define` lines change and
# they are restored afterwards, leaving the working tree pristine.
#
# The EoS tables and sample initial states live in the official companion repo
# vhlle_params (README steps 3-4); this script clones it pinned and links eos/
# and ic/ into the build dir, exactly as the README instructs.
#
# Prints (KEY=value, one per line; do NOT `eval`, paths may contain spaces):
#   VHLLE=<the binary just built>
#   VHLLE_ROOT=<vhlle repo root>
#   VHLLE_PARAMS=<vhlle_params repo root>
#   VHLLE_BUILD=<same as VHLLE_ROOT; vHLLE builds in-tree>
#   VHLLE_EOS=<table|simple>
#
# Env overrides:
#   VHLLE_ROOT_DIR      cache location (default ~/.cache/fusion/vhlle)
#   VHLLE_PIN           vhlle commit (default the pinned main below)
#   VHLLE_PARAMS_PIN    vhlle_params commit (default pinned below)
#   VHLLE_EOS           table (default) | simple
#   VHLLE_JOBS          parallel make jobs (default: nproc/sysctl)
#   VHLLE_GSL_PREFIX    GSL install prefix if gsl-config is not on PATH
#   VHLLE_FORCE_BUILD=1 wipe and re-clone+rebuild from the pinned source (used by
#                       the certified verify path; the plain path reuses a cache)
set -euo pipefail

log () { echo "install_vhlle: $*" >&2; }
die () { log "$*"; exit 1; }

CANON_PIN=c3480d62b22ba8333015808c9188474ddea311df          # vhlle main, 2026-06-23
CANON_PARAMS_PIN=ae2ba98609ff1203e6ab6e9d201db0e708322717   # vhlle_params, 2025-11-20
PIN="${VHLLE_PIN:-$CANON_PIN}"
PARAMS_PIN="${VHLLE_PARAMS_PIN:-$CANON_PARAMS_PIN}"
EOS_MODE="${VHLLE_EOS:-table}"
ROOT_DIR="${VHLLE_ROOT_DIR:-$HOME/.cache/fusion/vhlle}"
# URLs are overridable so a mirror or a local clone can be used where GitHub is
# slow or blocked (e.g. behind a firewall). A file:/// or local-path mirror still
# carries the pinned commit, so the pin/pristine checks are unchanged.
VHLLE_URL="${VHLLE_URL:-https://github.com/yukarpenko/vhlle.git}"
PARAMS_URL="${VHLLE_PARAMS_URL:-https://github.com/yukarpenko/vhlle_params.git}"

case "$EOS_MODE" in
  table|simple) ;;
  *) die "VHLLE_EOS must be 'table' or 'simple', got '$EOS_MODE'" ;;
esac
# A pin is a 40-hex commit hash. Validating the format also blocks an
# option-injection like VHLLE_PIN=--upload-pack=... reaching git as a flag.
printf '%s' "$PIN"        | grep -qE '^[0-9a-f]{40}$' || die "VHLLE_PIN must be a 40-hex commit hash, got '$PIN'"
printf '%s' "$PARAMS_PIN" | grep -qE '^[0-9a-f]{40}$' || die "VHLLE_PARAMS_PIN must be a 40-hex commit hash, got '$PARAMS_PIN'"

if [ "${VHLLE_JOBS:-}" != "" ]; then
  printf '%s' "$VHLLE_JOBS" | grep -qE '^[1-9][0-9]*$' || die "VHLLE_JOBS must be a positive integer"
  JOBS="$VHLLE_JOBS"
else
  JOBS="$( (command -v nproc >/dev/null && nproc) || sysctl -n hw.ncpu 2>/dev/null || echo 4 )"
fi

# ---- resolve GSL -----------------------------------------------------------
GSL_CFG=""
if [ -n "${VHLLE_GSL_PREFIX:-}" ] && [ -x "$VHLLE_GSL_PREFIX/bin/gsl-config" ]; then
  GSL_CFG="$VHLLE_GSL_PREFIX/bin/gsl-config"
elif command -v gsl-config >/dev/null 2>&1; then
  GSL_CFG="$(command -v gsl-config)"
else
  # last resort: a conda env that carries GSL (common on GPU boxes without sudo)
  for c in "${CONDA_PREFIX:-}" "$HOME"/miniforge3/envs/* "$HOME"/miniconda3/envs/* "$HOME"/anaconda3/envs/*; do
    [ -n "$c" ] && [ -x "$c/bin/gsl-config" ] && { GSL_CFG="$c/bin/gsl-config"; break; }
  done
fi
[ -n "$GSL_CFG" ] || die "gsl-config not found. Install GSL (macOS: brew install gsl; Linux: conda install -c conda-forge gsl, or apt install libgsl-dev) and re-run, or set VHLLE_GSL_PREFIX."
GSL_INC="$("$GSL_CFG" --cflags)"
GSL_LIBS="$("$GSL_CFG" --libs)"
GSL_LIBDIR="$("$GSL_CFG" --prefix)/lib"
log "using GSL from $GSL_CFG (version $("$GSL_CFG" --version))"

SRC="$ROOT_DIR/vhlle"
PARAMS="$ROOT_DIR/vhlle_params"
# both EoS modes compile to the Makefile target `hlle_visc`; rename each to a
# distinct name so the table and simple binaries can coexist (a second build
# would otherwise clobber the first before it is renamed)
BIN_NAME="hlle_visc_table"; [ "$EOS_MODE" = "simple" ] && BIN_NAME="hlle_visc_simple"

# refuse to operate through a symlinked cache root or source (a symlink could
# redirect the pristine/build checks at a tree we did not clone)
if [ -L "$ROOT_DIR" ] || [ -L "$SRC" ] || [ -L "$PARAMS" ]; then
  die "cache path is a symlink; refusing (set VHLLE_ROOT_DIR to a real directory)"
fi

clone_pinned () { # url dir pin
  local url="$1" dir="$2" pin="$3"
  rm -rf "$dir"
  # `--` stops option parsing so a URL beginning with `-` cannot inject a git flag
  git clone -q -- "$url" "$dir" || die "git clone failed: $url"
  git -C "$dir" checkout -q "$pin" || die "git checkout $pin failed in $dir (unknown commit?)"
}

need_clone=1
if [ "${VHLLE_FORCE_BUILD:-0}" != "1" ] && [ -d "$SRC/.git" ] && [ -d "$PARAMS/.git" ]; then
  have="$(git -C "$SRC" rev-parse HEAD 2>/dev/null || true)"
  havep="$(git -C "$PARAMS" rev-parse HEAD 2>/dev/null || true)"
  if [ "$have" = "$PIN" ] && [ "$havep" = "$PARAMS_PIN" ]; then need_clone=0; fi
fi
if [ "$need_clone" = "1" ]; then
  log "cloning vhlle @ $PIN and vhlle_params @ $PARAMS_PIN into $ROOT_DIR"
  mkdir -p "$ROOT_DIR"
  clone_pinned "$VHLLE_URL"  "$SRC"    "$PIN"
  clone_pinned "$PARAMS_URL" "$PARAMS" "$PARAMS_PIN"
fi

# link the EoS/IC data next to the code, per README steps 3-4
ln -sfn "$PARAMS/eos" "$SRC/eos"
ln -sfn "$PARAMS/ic"  "$SRC/ic"

# ---- build -----------------------------------------------------------------
BIN="$SRC/$BIN_NAME"
CANON_BUILD=0
[ "$PIN" = "$CANON_PIN" ] && [ "$PARAMS_PIN" = "$CANON_PARAMS_PIN" ] && CANON_BUILD=1

rebuild=1
if [ "${VHLLE_FORCE_BUILD:-0}" != "1" ] && [ -x "$BIN" ] && [ "$need_clone" = "0" ]; then
  rebuild=0
fi

if [ "$rebuild" = "1" ]; then
  # verify the working tree is pristine before we touch eos.cpp (a modified tree
  # means a leftover edit or an injected file; certification must start clean)
  if [ "$CANON_BUILD" = "1" ]; then
    [ -z "$(git -C "$SRC" status --porcelain --untracked-files=no)" ] || die "vhlle tree has tracked modifications; refusing to build (re-run with VHLLE_FORCE_BUILD=1)"
    # untracked files under the CMake/Make source globs would be compiled in;
    # reject any that git does not ignore
    stray="$(git -C "$SRC" ls-files --others --exclude-per-directory=.gitignore -- 'src/*.cpp' 'src/*.h' 2>/dev/null || true)"
    [ -z "$stray" ] || die "untracked source files present under src/: $stray"
  fi
  log "building $BIN_NAME (EoS=$EOS_MODE) with $JOBS jobs"
  EOS_CPP="$SRC/src/eos.cpp"
  cp "$EOS_CPP" "$EOS_CPP.fusionbak"
  if [ "$EOS_MODE" = "simple" ]; then
    sed -i.sed_tmp 's|^#define TABLE  // Laine, etc|//#define TABLE  // Laine, etc|; s|^//#define SIMPLE  // p=e/3|#define SIMPLE  // p=e/3|' "$EOS_CPP"
    grep -q '^#define SIMPLE' "$EOS_CPP" || { mv "$EOS_CPP.fusionbak" "$EOS_CPP"; die "failed to select SIMPLE EoS in eos.cpp (upstream format changed?)"; }
  else
    grep -q '^#define TABLE' "$EOS_CPP" || { mv "$EOS_CPP.fusionbak" "$EOS_CPP"; die "eos.cpp default is not TABLE (upstream format changed?)"; }
  fi
  rm -f "$EOS_CPP.sed_tmp"
  ( cd "$SRC"
    rm -rf obj; mkdir -p obj
    make -j"$JOBS" \
      CXXFLAGS="-Wall -fPIC -O3 -std=c++17 $GSL_INC" \
      LDFLAGS="-O3 -Wl,-rpath,$GSL_LIBDIR" \
      SYSLIBS="$GSL_LIBS" >/tmp/vhlle_make.$$ 2>&1 ) || { mv "$EOS_CPP.fusionbak" "$EOS_CPP"; log "build failed:"; tail -20 /tmp/vhlle_make.$$ >&2; rm -f /tmp/vhlle_make.$$; die "make failed"; }
  rm -f /tmp/vhlle_make.$$
  # restore pristine eos.cpp and name the binary
  mv "$EOS_CPP.fusionbak" "$EOS_CPP"
  mv "$SRC/hlle_visc" "$BIN"
fi

[ -x "$BIN" ] || die "binary $BIN not produced"

# ---- probe: prove the binary actually runs ---------------------------------
# a tiny 2-step run in an isolated dir. Both EoS modes construct the hadronic EoS
# from eos/eosHadronLog.dat, so this also proves the data link is good.
PROBE="$(mktemp -d)"
trap 'rm -rf "$PROBE"' EXIT
if [ "$EOS_MODE" = "simple" ]; then IC=4; ETA=0.0; else IC=1; ETA=0.08; fi
cat > "$PROBE/p" <<EOF
outputDir  $PROBE/out
eosType    0
etaS       $ETA
zetaS      0.0
e_crit     0.5
nx         21
ny         21
nz         3
xmin      -6.0
xmax       6.0
ymin      -6.0
ymax       6.0
etamin    -0.3
etamax     0.3
icModel    $IC
glauberVar 1
epsilon0   20.0
impactPar  2.0
tau0       1.0
tauMax     1.05
dtau       0.05
EOF
if ! ( cd "$SRC" && "$BIN" -params "$PROBE/p" -outputDir "$PROBE/out" >"$PROBE/log" 2>&1 ); then
  tail -15 "$PROBE/log" >&2; die "probe run of $BIN_NAME failed"
fi
grep -q "fluid allocation done" "$PROBE/log" || die "probe run did not initialize the fluid (see $PROBE/log)"

echo "VHLLE=$BIN"
echo "VHLLE_ROOT=$SRC"
echo "VHLLE_PARAMS=$PARAMS"
echo "VHLLE_BUILD=$SRC"
echo "VHLLE_EOS=$EOS_MODE"
log "OK ($BIN_NAME ready)"

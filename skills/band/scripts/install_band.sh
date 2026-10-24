#!/bin/bash
# install_band.sh: provision the BAND framework's core Python tools in an ISOLATED,
# version-pinned environment, and print on the last lines
#   BAND_PYTHON=<python of that environment>
#   BAND_VERSIONS=<package versions actually installed>
# run_band.sh and verify_band.sh parse those.
#
# Installed: surmise 1.0.0 (calibration/emulation), Taweret 1.3.0 (Bayesian model mixing),
# nuclear-rose 1.1.8 (reduced-order scattering emulator; pulls jitr 2.x), pytest.
# The environment lives in ${BAND_ROOT_DIR:-~/.cache/fusion/band}/venv; the user's own Python
# and site-packages are never touched. Other BAND tools are installed on request, see SKILL.md.
#
# Routes, first that works:
#   1. uv (also looked for in ~/.local/bin and ~/.cargo/bin, which non-interactive shells miss)
#   2. python3.10-3.13 -m venv + pip
#   3. conda/mamba (conda-forge): used when neither of the above exists, or when one of them
#      failed. openbt (a Taweret dependency, shipped on PyPI as source only) needs an MPI compiler
#      wrapper (mpic++) and Eigen to compile; without Eigen its build tries to download it from
#      Meson's WrapDB, which fails on restricted networks. Both were missing on a lab server
#      (Ubuntu 24.04); conda-forge supplies Eigen, OpenMPI and a matching compiler.
#   BAND_USE_CONDA=1 goes straight to 3.
#
# numpy is pinned below 2.4: rose 1.1.8 calls np.trapz, which numpy 2.4 removed, although
# rose's own requirements allow numpy<2.5.
#
#   install_band.sh            install if absent, else verify the pins and exit
#   install_band.sh --force    rebuild the environment from scratch
set -euo pipefail

log () { echo "install_band: $*" >&2; }
PINS=(surmise==1.0.0 Taweret==1.3.0 nuclear-rose==1.1.8 "numpy>=2.0,<2.4" pytest)

# --- the root, canonicalised BEFORE any safety check (so $HOME/. or a symlink cannot alias $HOME)
ROOT_IN="${BAND_ROOT_DIR:-$HOME/.cache/fusion/band}"
case "$ROOT_IN" in /*) : ;; *) log "BAND_ROOT_DIR must be an absolute path"; exit 1 ;; esac
mkdir -p "$ROOT_IN"
ROOT_DIR="$(cd "$ROOT_IN" && pwd -P)"
HOME_C="$(cd "$HOME" && pwd -P)"
case "$ROOT_DIR" in
  "/"|"$HOME_C"|"/usr"|"/usr/"*|"/etc"|"/etc/"*|"/bin"|"/bin/"*|"/System"|"/System/"*|"/Users"|"/home"|"/private"|"/var"|"/opt"|"/tmp")
    log "refusing unsafe BAND_ROOT_DIR='$ROOT_IN' (resolves to $ROOT_DIR)"; exit 1 ;;
esac
VENV="$ROOT_DIR/venv"
PY="$VENV/bin/python"
MARK="$VENV/.fusion-band-owned"     # only a directory carrying this marker is ever deleted

remove_venv () {
  [ -d "$VENV" ] || return 0
  if [ -f "$MARK" ] || [ "${1:-}" = created-this-run ]; then
    rm -rf "${VENV:?}"
  else
    log "$VENV was not created by this installer (no marker); not deleting it. Remove it yourself or set BAND_ROOT_DIR."
    exit 1
  fi
}

versions () {
  "$PY" - <<'EOF'
from importlib.metadata import version
print(" ".join(f"{p}={version(p)}" for p in ("surmise", "Taweret", "nuclear-rose", "jitr", "numpy")))
EOF
}
pins_ok () {
  [ -x "$PY" ] || return 1
  "$PY" - <<'EOF' >/dev/null 2>&1
import sys
from importlib.metadata import version
exact = {"surmise": "1.0.0", "Taweret": "1.3.0", "nuclear-rose": "1.1.8"}
if any(version(p) != v for p, v in exact.items()):
    sys.exit(1)
def vt(p):
    return tuple(int(x) for x in version(p).split(".")[:2])
if not ((2, 0) <= vt("numpy") < (2, 4)):   # np.trapz, see header
    sys.exit(1)
if not ((2, 1) <= vt("jitr") < (2, 4)):    # rose 1.1.8 requires jitr>=2.1.1,<2.4
    sys.exit(1)
# the modules the examples actually exercise, compiled parts included
import surmise.emulationsupport.matern_covmat, surmise.emulation, surmise.calibration
import Taweret.mix.gaussian, Taweret.models.samba_models
import rose, rose.training, numba, pytest
EOF
}

if [ "${1:-}" = "--force" ]; then
  log "removing $VENV"
  remove_venv
fi

if pins_ok; then
  log "already installed in $VENV"
else
  [ -e "$VENV" ] && { log "$VENV exists but does not match the pins; rerun with --force to rebuild"; exit 1; }
  # A failed attempt must not leave a half-built environment behind (the next run would refuse
  # it); only what this run created is removed.
  trap 'rc=$?; if [ $rc -ne 0 ] && [ -d "$VENV" ]; then remove_venv created-this-run; log "install failed; removed the partial $VENV"; fi' EXIT

  try_uv () {
    local uv; uv="$(command -v uv || true)"
    for c in "$HOME/.local/bin/uv" "$HOME/.cargo/bin/uv"; do [ -z "$uv" ] && [ -x "$c" ] && uv="$c"; done
    [ -n "$uv" ] || return 1
    log "creating $VENV with $uv (Python 3.12)"
    "$uv" venv -q --python 3.12 "$VENV" && touch "$MARK" &&
      { log "installing ${PINS[*]} (about a minute)"; "$uv" pip install -q --python "$PY" "${PINS[@]}"; }
  }
  try_venv () {
    local base="" c
    for c in python3.13 python3.12 python3.11 python3.10 python3; do
      if command -v "$c" >/dev/null && "$c" -c 'import sys; sys.exit(0 if (3,10) <= sys.version_info[:2] < (3,14) else 1)'; then base="$(command -v "$c")"; break; fi
    done
    [ -n "$base" ] || { log "no Python 3.10-3.13 on PATH (macOS's /usr/bin/python3 is 3.9)"; return 1; }
    log "creating $VENV with $base"
    "$base" -m venv "$VENV" >/dev/null 2>&1 || { log "$base cannot create a venv (Debian/Ubuntu: python3-venv missing, needs sudo)"; return 1; }
    touch "$MARK"
    "$PY" -m pip install -q --upgrade pip
    log "installing ${PINS[*]} (a few minutes)"
    "$PY" -m pip install -q "${PINS[@]}"
  }
  try_conda () {
    local conda="" c
    for c in mamba conda "$HOME/miniforge3/bin/mamba" "$HOME/miniforge3/bin/conda" "$HOME/mambaforge/bin/mamba" "$HOME/miniconda3/bin/conda" "$HOME/anaconda3/bin/conda"; do
      if command -v "$c" >/dev/null 2>&1; then conda="$(command -v "$c")"; break; fi
    done
    [ -n "$conda" ] || { log "no conda or mamba found"; return 1; }
    log "creating $VENV with $conda (conda-forge: python 3.12, eigen, openmpi, compilers)"
    "$conda" create -q -y -p "$VENV" -c conda-forge --override-channels \
      python=3.12 eigen pkg-config openmpi cxx-compiler >/dev/null && touch "$MARK" || return 1
    log "installing ${PINS[*]} (several minutes: openbt compiles against conda's Eigen and MPI)"
    # The rpath lets openbt's compiled openbtcli find conda's libmpi at run time; without it
    # it fails with exit 127 (libmpi.so.40 not found) whenever LD_LIBRARY_PATH is not set.
    PATH="$VENV/bin:$PATH" PKG_CONFIG_PATH="$VENV/lib/pkgconfig:$VENV/share/pkgconfig" \
      LDFLAGS="-Wl,-rpath,$VENV/lib ${LDFLAGS:-}" "$PY" -m pip install -q --no-cache-dir "${PINS[@]}"
  }
  reset_for_next () { [ -d "$VENV" ] && remove_venv created-this-run; return 0; }

  mkdir -p "$ROOT_DIR"
  done_ok=0
  if [ "${BAND_USE_CONDA:-0}" != 1 ]; then
    if try_uv && pins_ok; then done_ok=1; else [ -d "$VENV" ] && log "the uv route failed (often openbt: no MPI or Eigen)"; reset_for_next; fi
    if [ $done_ok = 0 ] && try_venv && pins_ok; then done_ok=1; elif [ $done_ok = 0 ]; then reset_for_next; fi
  fi
  if [ $done_ok = 0 ]; then
    log "falling back to conda"
    if try_conda && pins_ok; then done_ok=1; fi
  fi
  if [ $done_ok = 0 ]; then
    log "could not build the environment by any route. Without sudo, installing uv"
    log "(curl -LsSf https://astral.sh/uv/install.sh | sh) or Miniforge usually fixes it;"
    log "not done automatically, since both write to your home directory."
    exit 1
  fi
fi

echo "BAND_PYTHON=$PY"
echo "BAND_VERSIONS=$(versions)"

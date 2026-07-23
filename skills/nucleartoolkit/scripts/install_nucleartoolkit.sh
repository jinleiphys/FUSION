#!/bin/bash
# install_nucleartoolkit.sh
#
# Provision NuclearToolkit.jl in an ISOLATED Julia depot + project (so the user's
# own global Julia environment is never touched) and print, on the last lines,
#   NTK_JULIA=<julia binary>
#   NTK_DEPOT=<isolated JULIA_DEPOT_PATH>
#   NTK_PROJ=<isolated project dir>
#   NTK_PKGDIR=<installed NuclearToolkit source root>
#   NTK_VERSION=<installed version>
# run_nucleartoolkit.sh and verify_nucleartoolkit.sh parse those.
#
# NuclearToolkit.jl is the Julia nuclear-structure package of Sota Yoshida,
# J. Open Source Softw. 7(79), 4694 (2022), DOI 10.21105/joss.04694, MIT license,
# https://github.com/SotaYoshida/NuclearToolkit.jl . It generates chiral-EFT
# interactions and runs HFMBPT, (VS-)IMSRG and valence shell-model calculations.
#
# A Julia package needs no source patches (Julia is cross-platform); the only
# provisioning is a pinned Pkg.add + precompile in an isolated depot.
set -euo pipefail

PINNED_VERSION="${NTK_PIN:-0.5.2}"
# NTK_PIN is interpolated into the Pkg.add call, so require a strict semver to
# keep a malformed or hostile override out of the install code.
case "$PINNED_VERSION" in
  *[!0-9.]*|""|.*|*.) echo "install_nucleartoolkit: NTK_PIN must be a semver like 0.5.2 (got '$PINNED_VERSION')" >&2; exit 1 ;;
esac
[ "$(printf '%s' "$PINNED_VERSION" | tr -cd . | wc -c)" -eq 2 ] || { echo "install_nucleartoolkit: NTK_PIN must be MAJOR.MINOR.PATCH (got '$PINNED_VERSION')" >&2; exit 1; }
ROOT_DIR="${NTK_ROOT_DIR:-$HOME/.cache/fusion/nucleartoolkit}"
DEPOT="$ROOT_DIR/depot"
PROJ="$ROOT_DIR/proj"
STAMP="$PROJ/.fusion_ntk_stamp"
HERE="$(cd "$(dirname "$0")" && pwd)"

log () { echo "install_nucleartoolkit: $*" >&2; }

# rm-safety: refuse a dangerous ROOT_DIR and confine any rm under it.
case "$ROOT_DIR" in
  ""|"/"|"$HOME"|"/usr"|"/usr/"*|"/etc"|"/var"|"/tmp"|"/bin"|"/opt"|"/System"*|"/Users") log "refusing unsafe NTK_ROOT_DIR='$ROOT_DIR'"; exit 1 ;;
esac
case "$ROOT_DIR" in /*) : ;; *) log "NTK_ROOT_DIR must be an absolute path"; exit 1 ;; esac

JULIA="${NTK_JULIA_BIN:-$(command -v julia || true)}"
[ -n "$JULIA" ] || { log "julia not found (install Julia >= 1.7 from julialang.org)"; exit 1; }

# Probe + identity in ONE julia call (Julia startup is slow, so avoid repeats):
# run the self-contained CKpot Be-8 shell-model case, require a finite physical
# ground state near -31.1 MeV (content, not exit status), and on success emit the
# package dir and version as RESULT_ lines. ckpot.snt is resolved from the
# installed package, not hardcoded. main_sm's own chatter is left on stdout and
# filtered out by the RESULT_ grep.
probe_and_identify () {  # echoes "PKGDIR=... VER=..." on success; returns nonzero on failure
  local out
  out="$(JULIA_DEPOT_PATH="$DEPOT" "$JULIA" --project="$PROJ" --startup-file=no -e '
    using NuclearToolkit
    pd = pkgdir(NuclearToolkit)
    ck = joinpath(pd, "test", "interaction_file", "ckpot.snt")
    isfile(ck) || (println("PROBE_FAIL no ckpot.snt"); exit(1))
    E = main_sm(ck, "Be8", 1, Int[]; q=2, is_block=true)
    gs = E[1]
    if isfinite(gs) && -32.0 < gs < -30.0
        println("RESULT_PKGDIR=", pd)
        println("RESULT_VER=", pkgversion(NuclearToolkit))
        exit(0)
    else
        println("PROBE_FAIL gs=", gs); exit(1)
    end
  ' 2>/dev/null)" || return 1
  local pd ver
  pd="$(echo "$out" | sed -n 's/^RESULT_PKGDIR=//p' | tail -1)"
  ver="$(echo "$out" | sed -n 's/^RESULT_VER=//p' | tail -1)"
  [ -n "$pd" ] && [ -f "$pd/test/interaction_file/ckpot.snt" ] || return 1
  # Reject a cache whose actual installed version is not the pin, even if the
  # stamp and the CKpot probe pass (an altered Manifest could drift the version).
  [ "$ver" = "$PINNED_VERSION" ] || { log "installed version $ver != pinned $PINNED_VERSION"; return 1; }
  echo "PKGDIR=$pd VER=$ver"
}

emit_vars () {  # $1 "PKGDIR=... VER=..."
  local pd="${1#PKGDIR=}"; pd="${pd%% VER=*}"
  local ver="${1##* VER=}"
  echo "NTK_JULIA=$JULIA"; echo "NTK_DEPOT=$DEPOT"; echo "NTK_PROJ=$PROJ"; echo "NTK_PKGDIR=$pd"; echo "NTK_VERSION=$ver"
}

# --- fast path -------------------------------------------------------------
if [ -z "${NTK_FORCE:-}" ] && [ -f "$STAMP" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$PINNED_VERSION" ]; then
  if IDENT="$(probe_and_identify)"; then emit_vars "$IDENT"; exit 0; fi
  log "cached install failed its probe; reinstalling"
fi

# --- install (pinned) into the isolated depot ------------------------------
mkdir -p "$PROJ"
log "installing NuclearToolkit v$PINNED_VERSION into an isolated depot (first run precompiles ~400 deps, several minutes)"
JULIA_DEPOT_PATH="$DEPOT" "$JULIA" --project="$PROJ" --startup-file=no -e "
  using Pkg
  Pkg.add(name=\"NuclearToolkit\", version=\"$PINNED_VERSION\")
  Pkg.precompile()
  using NuclearToolkit
  println(\"installed \", pkgversion(NuclearToolkit))
" > "$PROJ/install.log" 2>&1 || {
  log "Pkg.add/precompile failed; see $PROJ/install.log"
  grep -iE "error|ERROR|failed" "$PROJ/install.log" 2>/dev/null | head -8 >&2
  exit 1
}

IDENT="$(probe_and_identify)" || { log "freshly installed NuclearToolkit failed its CKpot Be-8 probe"; exit 1; }
echo "$PINNED_VERSION" > "$STAMP"
emit_vars "$IDENT"

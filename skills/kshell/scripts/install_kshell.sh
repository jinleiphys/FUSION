#!/bin/bash
# install_kshell.sh
#
# Provision the KSHELL executable: clone the maintained fork, build with gfortran,
# prove it runs, and print
#   KSHELL=<path to kshell.exe>
#   KSHELL_ROOT=<repo root>
#   KSHELL_SNT=<snt/ interaction directory>
#   KSHELL_GENPTN=<bin/gen_partition.py, Python 3>
# on the last four lines. run_kshell.sh and verify_kshell.sh parse those.
#
# KSHELL is the M-scheme large-scale shell-model code of N. Shimizu, T. Mizusaki,
# Y. Utsuno and Y. Tsunoda, Comput. Phys. Commun. 244, 372 (2019) (thick-restart
# block Lanczos; original arXiv:1310.5431). Fortran 90 + OpenMP, needs LAPACK/BLAS
# and Python 3 for the partition-file generator.
#
# LICENSE NOTE: KSHELL ships NO license (no LICENSE file, no source-header
# copyright, GitHub reports license:None). It is public-clonable and published;
# this skill clones from the same public upstream a student would and does not
# redistribute the source (user ruling; see CLAUDE.md private-code-boundary
# decision). We use the maintained GaffaSnobb fork because its Python tooling is
# Python 3; the older jorgenem mirror is Python 2 and will not run on a modern Mac.
set -euo pipefail

ROOT_DIR="${KSHELL_ROOT_DIR:-$HOME/.cache/fusion/kshell}"
REPO="${KSHELL_REPO:-https://github.com/GaffaSnobb/kshell}"
SRCROOT="$ROOT_DIR/kshell"
BIN="$SRCROOT/bin/kshell.exe"
SNT="$SRCROOT/snt"
GENPTN="$SRCROOT/bin/gen_partition.py"

log () { echo "install_kshell: $*" >&2; }

# Probe: build the 20Ne USDA partition, run kshell, and require a finite negative
# ground-state energy in the log (content, not exit status). ~1 s.
probe_binary () {
  [ -x "$BIN" ] || { log "no kshell.exe at $BIN"; return 1; }
  [ -f "$SNT/usda.snt" ] || { log "usda.snt missing from $SNT"; return 1; }
  command -v python3 >/dev/null || { log "python3 required for gen_partition"; return 1; }
  local w; w="$(mktemp -d)"
  cp "$SNT/usda.snt" "$w/"
  ( cd "$w" && python3 "$GENPTN" usda.snt p.ptn 2 2 1 <<< "0" >genptn.log 2>&1 ) || {
    log "gen_partition failed"; tail -3 "$w/genptn.log" >&2; rm -rf "$w"; return 1; }
  [ -s "$w/p.ptn" ] || { log "gen_partition wrote an empty partition file"; rm -rf "$w"; return 1; }
  printf '&input\n fn_int="usda.snt"\n fn_ptn="p.ptn"\n hw_type=2\n is_double_j=.false.\n max_lanc_vec=200\n maxiter=300\n mode_lv_hdd=0\n mtot=0\n n_eigen=2\n n_restart_vec=15\n&end\n' > "$w/probe.input"
  local rc
  set +e
  ( cd "$w" && "$BIN" probe.input > probe.log 2>&1 )
  rc=$?
  set -e
  [ "$rc" -eq 0 ] || { log "kshell.exe exited $rc on probe"; tail -5 "$w/probe.log" >&2; rm -rf "$w"; return 1; }
  python3 - "$w/probe.log" <<'PY' || { log "probe log has no finite negative ground-state energy"; rm -rf "$w"; return 1; }
import sys,re,math
gs=None
for l in open(sys.argv[1]):
    m=re.match(r'\s*1\s+<H>:\s+([-\d.]+)',l)
    if m: gs=float(m.group(1)); break
sys.exit(0 if (gs is not None and math.isfinite(gs) and gs<0) else 1)
PY
  rm -rf "$w"; return 0
}

# --- fast path -------------------------------------------------------------
if [ -x "$BIN" ] && [ -z "${KSHELL_FORCE:-}" ]; then
  if probe_binary; then
    echo "KSHELL=$BIN"; echo "KSHELL_ROOT=$SRCROOT"; echo "KSHELL_SNT=$SNT"; echo "KSHELL_GENPTN=$GENPTN"
    exit 0
  fi
  log "cached binary failed its probe; rebuilding"
fi

command -v git      >/dev/null || { log "git required"; exit 1; }
command -v gfortran >/dev/null || { log "gfortran required"; exit 1; }
command -v python3  >/dev/null || { log "python3 required"; exit 1; }

mkdir -p "$ROOT_DIR"
if [ ! -d "$SRCROOT/.git" ]; then
  # Clone into a fresh temp dir and move it into place only on success, so a
  # failed clone never destroys an existing (possibly user-populated) $SRCROOT.
  TMPCLONE="$SRCROOT.tmp.$$"
  rm -rf "$TMPCLONE"
  git clone -q --depth 1 "$REPO" "$TMPCLONE" || { log "failed to clone KSHELL from $REPO"; rm -rf "$TMPCLONE"; exit 1; }
  rm -rf "$SRCROOT"
  mv "$TMPCLONE" "$SRCROOT"
fi
[ -f "$SRCROOT/src/Makefile" ] || { log "KSHELL source incomplete"; exit 1; }

# LAPACK/BLAS: on macOS the Accelerate framework provides both and is always
# present; on Linux use the system -llapack -lblas. The Makefile already carries
# -fallow-argument-mismatch (gfortran 10+ rejects the code's rank mismatches
# otherwise), so only LIBS needs overriding per platform.
if [ "$(uname -s)" = "Darwin" ]; then
  LIBS_OVERRIDE="-framework Accelerate -lm"
else
  LIBS_OVERRIDE="-llapack -lblas -lm"
fi

( cd "$SRCROOT/src" && make clean >/dev/null 2>&1 || true
  make FFLAGS="-O3 -fopenmp -fallow-argument-mismatch" LIBS="$LIBS_OVERRIDE" >make.log 2>&1 ) || {
  log "build failed; see $SRCROOT/src/make.log"
  grep -iE "error|cannot find|undefined|ld:" "$SRCROOT/src/make.log" 2>/dev/null | head -10 >&2
  exit 1
}
[ -x "$BIN" ] || { log "no kshell.exe after build"; exit 1; }

probe_binary || { log "freshly built kshell.exe failed its probe"; exit 1; }

echo "KSHELL=$BIN"; echo "KSHELL_ROOT=$SRCROOT"; echo "KSHELL_SNT=$SNT"; echo "KSHELL_GENPTN=$GENPTN"

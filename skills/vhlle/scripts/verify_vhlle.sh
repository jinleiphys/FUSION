#!/bin/bash
# verify_vhlle.sh
#
#   verify_vhlle.sh                 build (or rebuild) from pinned source, then
#                                   run the Gubser analytic + Glauber production
#                                   benchmarks. About 1.5 min.
#   verify_vhlle.sh --gubser-only   just the analytic Gubser check
#   verify_vhlle.sh --glauber-only  just the production-path Glauber check
#
# STAGE 1 (Gubser, physics): build the SIMPLE (conformal p=e/3) binary, run the
# analytic Gubser deck (icModel 4), and compare vHLLE cell by cell against the
# CODE-INDEPENDENT analytic ideal-conformal Gubser solution at tau=1.5. Requires
# eps within a set tolerance of analytic, exact left-right symmetry, and the
# pinned central energy density. This is the paper's Section 4.1 test.
#
# STAGE 2 (Glauber, production path): build the default TABLE (Laine lattice EoS)
# binary and run an optical-Glauber viscous deck to tau=3.05. There is no analytic
# reference; the check is that the run completes, the output is finite, and the
# central energy density and temperature match the pinned values (a regression
# gate on the production code path students actually use).
#
# CERTIFICATION. A `VERIFY OK` requires verify to BUILD BOTH binaries from the
# SHA-pinned, pristine source in this run (install_vhlle.sh with VHLLE_FORCE_BUILD
# re-clones and rebuilds), so the binaries are produced by make here and cannot be
# a hand-forged drop-in. If you instead preset VHLLE_TABLE_BIN / VHLLE_SIMPLE_BIN
# to hand it existing binaries, it validates them but ends in
# `VERIFY PASSED-NOT-CERTIFIED`.
#
# vHLLE is GPL-2.0; the EoS/IC data come from the companion repo vhlle_params.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log () { echo "verify_vhlle: $*" >&2; }
die () { log "$*"; exit 1; }

DO_GUBSER=1; DO_GLAUBER=1
while [ $# -gt 0 ]; do
  case "$1" in
    --gubser-only)  DO_GLAUBER=0; shift ;;
    --glauber-only) DO_GUBSER=0; shift ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" ;;
  esac
done

# ---- pinned canonical benchmark numbers (macOS/ARM clang 21 == Linux/x86 gcc 13.3)
CANON_PIN=c3480d62b22ba8333015808c9188474ddea311df
CANON_PARAMS_PIN=ae2ba98609ff1203e6ab6e9d201db0e708322717
PIN="${VHLLE_PIN:-$CANON_PIN}"
PARAMS_PIN="${VHLLE_PARAMS_PIN:-$CANON_PARAMS_PIN}"
# Gubser analytic tolerances: measured max eps reldiff 0.0247, vx absdiff 0.0127
# at tau=1.5 on the shipped deck; thresholds sit above with headroom.
GUBSER_TAU=1.5
GUBSER_XCUT=5.0
GUBSER_MAX_EPS=0.030
GUBSER_MAX_VX=0.020
GUBSER_CENTER_EPS=0.157676     # eps(tau=1.5, x=0), identical on both platforms
GUBSER_CENTER_TOL=1e-3
# Glauber production anchors (last timestep tau=3.05, central cell)
GLAUBER_LASTTAU=3.05
GLAUBER_CENTER_EPS=3.211810
GLAUBER_CENTER_T=0.213454
GLAUBER_CENTER_TOL=2e-3

CERTIFIED=1
# BOTH pins gate certification: vhlle_params carries the EoS/hadron tables, which
# are physics inputs, so a non-canonical params pin is not a certified v-of-record.
[ "$PIN" != "$CANON_PIN" ] && { log "NOTE: VHLLE_PIN=$PIN is not the canonical pin; NOT a certification"; CERTIFIED=0; }
[ "$PARAMS_PIN" != "$CANON_PARAMS_PIN" ] && { log "NOTE: VHLLE_PARAMS_PIN=$PARAMS_PIN is not the canonical params pin; NOT a certification"; CERTIFIED=0; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# ---- obtain the two binaries -----------------------------------------------
TABLE_BIN=""; SIMPLE_BIN=""; ROOT=""
if [ -n "${VHLLE_TABLE_BIN:-}" ] || [ -n "${VHLLE_SIMPLE_BIN:-}" ]; then
  # preset path: validate what was handed to us, but do not certify
  CERTIFIED=0
  log "using preset binaries (VHLLE_TABLE_BIN / VHLLE_SIMPLE_BIN); NOT a certification"
  TABLE_BIN="${VHLLE_TABLE_BIN:-}"; SIMPLE_BIN="${VHLLE_SIMPLE_BIN:-}"
  ROOT="${VHLLE_ROOT:-}"
  [ "$DO_GUBSER" = 0 ]  || [ -x "$SIMPLE_BIN" ] || die "VHLLE_SIMPLE_BIN not executable"
  [ "$DO_GLAUBER" = 0 ] || [ -x "$TABLE_BIN" ]  || die "VHLLE_TABLE_BIN not executable"
  [ -d "$ROOT" ] || die "VHLLE_ROOT must be set (repo root, for eos/ic links) with preset binaries"
else
  # certified path: force a clean re-clone+rebuild of BOTH binaries from the pin.
  log "building the TABLE binary from the pinned pristine source (clean rebuild)"
  OUT_T="$(VHLLE_FORCE_BUILD=1 VHLLE_EOS=table bash "$HERE/install_vhlle.sh")" || die "table build failed"
  TABLE_BIN="$(printf '%s\n' "$OUT_T" | sed -n 's/^VHLLE=//p')"
  ROOT="$(printf '%s\n' "$OUT_T" | sed -n 's/^VHLLE_ROOT=//p')"
  log "building the SIMPLE binary from the same clone (no re-clone)"
  OUT_S="$(VHLLE_EOS=simple bash "$HERE/install_vhlle.sh")" || die "simple build failed"
  SIMPLE_BIN="$(printf '%s\n' "$OUT_S" | sed -n 's/^VHLLE=//p')"
fi
[ -d "$ROOT" ] || die "repo root not resolved"

run_deck () { # binary paramfile outdir
  local bin="$1" pf="$2" od="$3"
  mkdir -p "$od"
  ( cd "$ROOT" && "$bin" -params "$pf" -outputDir "$od" >"$od/log" 2>&1 ) \
    || { tail -20 "$od/log" >&2; die "run failed: $bin on $(basename "$pf")"; }
  [ -s "$od/outx.dat" ] || die "no outx.dat produced by $(basename "$pf")"
}

# ---- STAGE 1: Gubser analytic ----------------------------------------------
if [ "$DO_GUBSER" = 1 ]; then
  [ -x "$SIMPLE_BIN" ] || die "SIMPLE binary missing for the Gubser stage"
  log "STAGE 1: analytic Gubser flow (conformal EoS)"
  run_deck "$SIMPLE_BIN" "$HERE/../examples/gubser.params" "$WORK/gubser"
  python3 "$HERE/check_gubser.py" "$WORK/gubser/outx.dat" \
    --tau "$GUBSER_TAU" --xcut "$GUBSER_XCUT" \
    --max-eps-reldiff "$GUBSER_MAX_EPS" --max-vx-absdiff "$GUBSER_MAX_VX" \
    --center-eps "$GUBSER_CENTER_EPS" --center-tol "$GUBSER_CENTER_TOL" \
    || die "Gubser analytic check FAILED"
  log "STAGE 1 OK: vHLLE reproduces the analytic Gubser solution within tolerance"
fi

# ---- STAGE 2: Glauber production path ---------------------------------------
if [ "$DO_GLAUBER" = 1 ]; then
  [ -x "$TABLE_BIN" ] || die "TABLE binary missing for the Glauber stage"
  log "STAGE 2: optical-Glauber viscous run (Laine EoS, production path)"
  run_deck "$TABLE_BIN" "$HERE/../examples/glauber.params" "$WORK/glauber"
  python3 "$HERE/check_output.py" "$WORK/glauber/outx.dat" --min-rows 100 --min-cols 20 \
    || die "Glauber output validation FAILED"
  python3 "$HERE/check_glauber.py" "$WORK/glauber/outx.dat" \
    --last-tau "$GLAUBER_LASTTAU" --center-eps "$GLAUBER_CENTER_EPS" \
    --center-T "$GLAUBER_CENTER_T" --tol "$GLAUBER_CENTER_TOL" \
    || die "Glauber production anchor FAILED"
  log "STAGE 2 OK: Glauber central anchors matched, last tau=$GLAUBER_LASTTAU"
fi

if [ "$CERTIFIED" = 1 ]; then
  echo "VERIFY OK"
else
  echo "VERIFY PASSED-NOT-CERTIFIED"
fi

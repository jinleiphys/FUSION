#!/bin/bash
# run_vhlle.sh: run a vHLLE parameter deck with the correct binary, in an
# isolated output directory, then validate the output tables.
#
#   run_vhlle.sh --params FILE [--eos table|simple] [--outdir DIR]
#                [--is-input FILE] [--system SYS]
#
# --eos selects which binary: 'table' (default, Laine lattice EoS) or 'simple'
#       (conformal p=e/3, required for the Gubser deck). If the requested binary
#       is not yet built, install_vhlle.sh builds it.
# --is-input / --system pass through vHLLE's -ISinput / -system options, needed
#       only for tabulated initial states (Glissando, Trento, ...); the shipped
#       Gubser and optical-Glauber decks need neither.
#
# vHLLE reads eos/ and ic/ RELATIVE to the current directory, so this runs from
# the repo root. --outdir (absolute) receives the output files.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log () { echo "run_vhlle: $*" >&2; }
die () { log "$*"; exit 1; }

PARAMS=""; EOS_MODE="table"; OUTDIR=""; ISINPUT=""; SYSTEM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --params)   PARAMS="${2:-}"; shift 2 ;;
    --eos)      EOS_MODE="${2:-}"; shift 2 ;;
    --outdir)   OUTDIR="${2:-}"; shift 2 ;;
    --is-input) ISINPUT="${2:-}"; shift 2 ;;
    --system)   SYSTEM="${2:-}"; shift 2 ;;
    -h|--help)  sed -n '2,20p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" ;;
  esac
done
[ -n "$PARAMS" ] || die "--params is required"
[ -f "$PARAMS" ] || die "params file not found: $PARAMS"
case "$EOS_MODE" in table|simple) ;; *) die "--eos must be table or simple" ;; esac

# resolve the binary and the repo root (respect a caller-provided environment)
if [ -n "${VHLLE:-}" ] && [ -n "${VHLLE_ROOT:-}" ] && [ -x "${VHLLE:-}" ] && \
   { { [ "$EOS_MODE" = simple ] && case "$VHLLE" in *hlle_visc_simple) true;; *) false;; esac; } || \
     { [ "$EOS_MODE" = table ]  && case "$VHLLE" in *hlle_visc_table) true;; *) false;; esac; }; }; then
  BIN="$VHLLE"; ROOT="$VHLLE_ROOT"
else
  INSTALL_OUT="$(VHLLE_EOS="$EOS_MODE" bash "$HERE/install_vhlle.sh")" || die "install failed"
  BIN="$(printf '%s\n' "$INSTALL_OUT" | sed -n 's/^VHLLE=//p')"
  ROOT="$(printf '%s\n' "$INSTALL_OUT" | sed -n 's/^VHLLE_ROOT=//p')"
fi
[ -x "$BIN" ] || die "binary not executable: $BIN"
[ -d "$ROOT" ] || die "repo root not found: $ROOT"

PARAMS_ABS="$(cd "$(dirname "$PARAMS")" && pwd)/$(basename "$PARAMS")"
if [ -z "$OUTDIR" ]; then OUTDIR="$(mktemp -d)"; fi
mkdir -p "$OUTDIR"
OUTDIR_ABS="$(cd "$OUTDIR" && pwd)"

# clear any stale output in the target dir so a no-op or crashing binary cannot
# pass validation against leftover files from a previous run
rm -f "$OUTDIR_ABS"/out*.dat "$OUTDIR_ABS"/vhlle.log

ARGS=(-params "$PARAMS_ABS" -outputDir "$OUTDIR_ABS")
if [ -n "$ISINPUT" ]; then [ -f "$ISINPUT" ] || die "IS input not found: $ISINPUT"; ARGS+=(-ISinput "$(cd "$(dirname "$ISINPUT")" && pwd)/$(basename "$ISINPUT")"); fi
if [ -n "$SYSTEM" ]; then ARGS+=(-system "$SYSTEM"); fi

log "running $(basename "$BIN") (cwd=$ROOT) -> $OUTDIR_ABS"
if ! ( cd "$ROOT" && "$BIN" "${ARGS[@]}" >"$OUTDIR_ABS/vhlle.log" 2>&1 ); then
  tail -20 "$OUTDIR_ABS/vhlle.log" >&2
  die "vHLLE exited non-zero"
fi

# validate the rectangular profile tables (finite numbers, sensible columns).
# outdiag.dat is deliberately excluded: it wraps each record across two physical
# lines (8 + 12 fields), so it is not a rectangular table.
shopt -s nullglob
produced=0
for f in "$OUTDIR_ABS"/outx.dat "$OUTDIR_ABS"/outy.dat "$OUTDIR_ABS"/outz.dat; do
  [ -s "$f" ] || continue
  produced=1
  python3 "$HERE/check_output.py" "$f" --min-rows 10 --min-cols 20 || die "output validation failed: $f"
done
[ "$produced" = "1" ] || die "no non-empty profile output produced (see $OUTDIR_ABS/vhlle.log)"

echo "RESULT_DIR=$OUTDIR_ABS"
echo "RESULT_FILES=$(cd "$OUTDIR_ABS" && ls out*.dat 2>/dev/null | tr '\n' ' ')"
log "OK"

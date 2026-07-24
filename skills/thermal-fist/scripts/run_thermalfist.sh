#!/bin/bash
# run_thermalfist.sh
#
# Run one of Thermal-FIST's cpc example programs in an isolated directory and
# assert the output is a usable numeric table. Usage:
#
#   run_thermalfist.sh --example <cpc1|cpc2|cpc3> --config <int> [--outdir <dir>]
#
# --example  which paper (CPC 244, 295) calculation to run:
#              cpc1  temperature dependence of HRG thermodynamics at mu=0
#                    (cpc1HRGTDep), config 0 Id-HRG, 1 EV-HRG, 2 QvdW-HRG
#              cpc2  chi^2 of a thermal fit vs temperature (cpc2chi2), config 0..3
#              cpc3  equilibrium vs chemically-frozen chi^2 (cpc3chi2NEQ), config 0..1
# --config   the integer selecting the model variant (see above). Required.
# --outdir   defaults to a fresh mktemp -d. Must be new or empty. The example
#            writes its output file(s) into CWD, so the wrapper runs there.
#
# Prints RESULT_DIR= and RESULT_FILES= on its last lines.
#
# NOTE cpc4 (cpc4mcHRG) is a Monte Carlo sampler and is intentionally NOT exposed
# here: its output is not reproducible without pinning the event count and RNG,
# and the tier-1 evidence for this skill is the shipped ctest suite, not a run
# through this wrapper. Thermal-FIST is GPL-3.0; see install_thermalfist.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE=""; CONFIG=""; OUTDIR=""

log () { echo "run_thermalfist: $*" >&2; }
die () { log "$*"; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --example) EXAMPLE="${2:-}"; shift 2 ;;
    --config)  CONFIG="${2:-}"; shift 2 ;;
    --outdir)  OUTDIR="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" ;;
  esac
done

[ -n "$EXAMPLE" ] || die "--example is required (cpc1, cpc2 or cpc3)"
[ -n "$CONFIG" ]  || die "--config is required"

# Map the example to its binary and the CLOSED set of config values the source
# accepts. cpc1HRGTDep reads config with atoi and branches 0/1/2; anything else
# is a silent fall-through, so we reject it here rather than run something the
# source does not define.
case "$EXAMPLE" in
  cpc1) BINNAME="cpc1HRGTDep"; MAXCFG=2 ;;
  cpc2) BINNAME="cpc2chi2";    MAXCFG=3 ;;
  cpc3) BINNAME="cpc3chi2NEQ"; MAXCFG=1 ;;
  *) die "unknown --example '$EXAMPLE' (expected cpc1, cpc2 or cpc3)" ;;
esac

# Full-match integer validation before the value is passed to the binary.
printf '%s' "$CONFIG" | grep -qE '^[0-9]+$' || die "--config must be a non-negative integer, got '$CONFIG'"
[ "$CONFIG" -le "$MAXCFG" ] || die "--config for $EXAMPLE must be 0..$MAXCFG, got $CONFIG"

# Resolve the example binary.
if [ -n "${TFIST_EXAMPLES:-}" ]; then
  BINDIR="$TFIST_EXAMPLES"
else
  INSTALL_OUT="$("$HERE/install_thermalfist.sh")" || die "install_thermalfist.sh failed"
  BINDIR="$(printf '%s\n' "$INSTALL_OUT" | sed -n 's/^TFIST_EXAMPLES=//p')"
fi
BIN="$BINDIR/$BINNAME"
[ -x "$BIN" ] || die "no usable $BINNAME at '$BIN' (TFIST_EXAMPLES='${TFIST_EXAMPLES:-unset}')"

# Isolated output directory.
if [ -z "$OUTDIR" ]; then
  OUTDIR="$(mktemp -d)"
else
  if [ -e "$OUTDIR" ]; then
    [ -d "$OUTDIR" ] || die "outdir '$OUTDIR' exists and is not a directory"
    [ -n "$(ls -A "$OUTDIR" 2>/dev/null)" ] && die "outdir '$OUTDIR' is not empty; give a fresh directory"
  else
    mkdir -p "$OUTDIR"
  fi
fi
OUTDIR="$(cd "$OUTDIR" && pwd -P)"

log "running $BINNAME $CONFIG in $OUTDIR"
set +e
( cd "$OUTDIR" && "$BIN" "$CONFIG" ) > "$OUTDIR/stdout.txt" 2> "$OUTDIR/stderr.txt"
STATUS=$?
set -e
if [ "$STATUS" -ne 0 ]; then
  log "$BINNAME exited with status $STATUS"
  tail -15 "$OUTDIR/stderr.txt" >&2 2>/dev/null
  tail -5 "$OUTDIR/stdout.txt" >&2 2>/dev/null
  exit 1
fi

# The example writes one or more tables (.out / .dat) into CWD. Require at least
# one, and validate every one structurally: header, all-numeric rows, no NaN/Inf,
# consistent column count. A plain glob loop, not `mapfile`, because the default
# macOS bash is 3.2 and mapfile is a bash 4 builtin.
TABLES=()
for f in "$OUTDIR"/*.out "$OUTDIR"/*.dat; do
  [ -e "$f" ] || continue
  TABLES+=("$(basename "$f")")
done
[ "${#TABLES[@]}" -ge 1 ] || die "$BINNAME produced no .out or .dat table in $OUTDIR"

for t in "${TABLES[@]}"; do
  python3 "$HERE/check_output_thermalfist.py" "$OUTDIR/$t" --min-rows 2 --min-cols 2 >/dev/null \
    || die "$BINNAME output '$t' failed structural validation"
  log "output table OK: $t"
done

log "run complete: ${#TABLES[@]} table(s)"
echo "RESULT_DIR=$OUTDIR"
echo "RESULT_FILES=${TABLES[*]}"

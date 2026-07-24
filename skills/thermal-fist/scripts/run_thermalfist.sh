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

# Full-match integer validation before the value is used anywhere.
printf '%s' "$CONFIG" | grep -qE '^[0-9]+$' || die "--config must be a non-negative integer, got '$CONFIG'"

# Map (example, config) to its binary, the CLOSED set of config values the source
# accepts, and the EXACT output file and shape the source produces. cpc1HRGTDep
# reads config with atoi and branches 0/1/2; anything outside the set is a silent
# fall-through, rejected here. Shapes are from the shipped test/ReferenceOutput.
case "$EXAMPLE" in
  cpc1)
    BINNAME="cpc1HRGTDep"; MAXCFG=2; EXPROWS=181; EXPCOLS=7
    case "$CONFIG" in 0) EXPFILE="cpc1.Id-HRG.TDep.out";; 1) EXPFILE="cpc1.EV-HRG.TDep.out";; 2) EXPFILE="cpc1.QvdW-HRG.TDep.out";; esac ;;
  cpc2)
    BINNAME="cpc2chi2"; MAXCFG=3; EXPROWS=151; EXPCOLS=4
    case "$CONFIG" in
      0) EXPFILE="cpc2.Id-HRG.ALICE2_76.chi2.TDep.out";;
      1) EXPFILE="cpc2.EV-HRG-TwoComponent.ALICE2_76.chi2.TDep.out";;
      2) EXPFILE="cpc2.EV-HRG-BagModel.ALICE2_76.chi2.TDep.out";;
      3) EXPFILE="cpc2.QvdW-HRG.ALICE2_76.chi2.TDep.out";;
    esac ;;
  cpc3)
    BINNAME="cpc3chi2NEQ"; MAXCFG=1; EXPROWS=5; EXPCOLS=9
    # cpc3 config 1 is the chemically-frozen (NEQ) fit with gammaq AND gammaS
    # free. That minimisation is under-constrained (a near-flat chi2 direction),
    # so it lands on a DIFFERENT minimum on different builds: the shipped
    # reference and a fresh run disagree by MeV in muB, not at the last digit.
    # This is why upstream leaves cpc3 out of its ctest suite. So the NEQ output
    # is validated structurally only, never compared to the reference.
    case "$CONFIG" in
      0) EXPFILE="cpc3.EQ.chi2.out"; REPRO=1 ;;
      1) EXPFILE="cpc3.NEQ.chi2.out"; REPRO=0 ;;
    esac ;;
  *) die "unknown --example '$EXAMPLE' (expected cpc1, cpc2 or cpc3)" ;;
esac
REPRO="${REPRO:-1}"
[ "$CONFIG" -le "$MAXCFG" ] || die "--config for $EXAMPLE must be 0..$MAXCFG, got $CONFIG"

# Resolve the example binary, and the repository root (for the shipped reference).
# Only fall back to a build when the binary directory is unknown; the root is
# needed only for the optional reference comparison, so a preset TFIST_EXAMPLES
# without TFIST_ROOT must NOT trigger a build.
BINDIR="${TFIST_EXAMPLES:-}"
ROOT="${TFIST_ROOT:-}"
if [ -z "$BINDIR" ]; then
  INSTALL_OUT="$("$HERE/install_thermalfist.sh")" || die "install_thermalfist.sh failed"
  BINDIR="$(printf '%s\n' "$INSTALL_OUT" | sed -n 's/^TFIST_EXAMPLES=//p')"
  [ -n "$ROOT" ] || ROOT="$(printf '%s\n' "$INSTALL_OUT" | sed -n 's/^TFIST_ROOT=//p')"
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

# The example must write the EXACT file the source produces for this config, with
# the EXACT shape from test/ReferenceOutput. Requiring the specific filename and
# shape is what rejects a stub that wrote an unrelated or truncated table and
# exited zero. A missing expected file, or one with the wrong row/column count, is
# a failed run.
OUT="$OUTDIR/$EXPFILE"
[ -s "$OUT" ] || die "$BINNAME did not produce the expected output '$EXPFILE' in $OUTDIR"
python3 "$HERE/check_output_thermalfist.py" "$OUT" --rows "$EXPROWS" --cols "$EXPCOLS" >/dev/null \
  || die "$BINNAME output '$EXPFILE' failed structural validation (expected EXACTLY $EXPROWS rows, $EXPCOLS numeric cols)"
log "output table OK: $EXPFILE"

# If the repository root is known AND this output is reproducible, compare against
# the shipped reference at the code's own 1e-6 tolerance. This turns a run into a
# full check: exact rows, exact numeric columns, exact label text, and numeric
# agreement, not just a shape. The under-constrained cpc3 NEQ fit is exempt (see
# the REPRO note above): its parameters are not reproducible across builds, so it
# is validated structurally only.
REF="$ROOT/test/ReferenceOutput/$EXPFILE"
if [ "$REPRO" = "0" ]; then
  log "note: $EXPFILE is an under-constrained fit; validated shape only, not compared to the reference"
elif [ -n "$ROOT" ] && [ -s "$REF" ]; then
  python3 "$HERE/check_output_thermalfist.py" "$OUT" --reference "$REF" --accuracy 1e-6 >/dev/null \
    || die "$BINNAME output '$EXPFILE' does not reproduce the shipped reference within 1e-6"
  log "output reproduces the shipped reference within 1e-6"
else
  log "note: no shipped reference found at '$REF'; validated shape only, not numeric values"
fi

log "run complete"
echo "RESULT_DIR=$OUTDIR"
echo "RESULT_FILE=$EXPFILE"

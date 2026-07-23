#!/bin/bash
# run_gibuu.sh
#
# Run a GiBUU job card in an isolated directory and assert the output is usable.
#
#   run_gibuu.sh --jobcard <file.job> [--outdir <dir>] [--seed <int>]
#                [--input <buuinput dir>] [--allow-random-seed]
#
# --jobcard   a GiBUU job card (Fortran namelists). Copied into the output
#             directory, so the run records the input it actually used.
# --outdir    defaults to a fresh mktemp -d. Must be new or empty.
# --seed      overwrite the initRandom Seed.
# --input     buuinput directory; defaults to the one install_gibuu.sh provides.
#             The job card's path_To_Input is rewritten to point at it, because
#             every shipped card carries the author's own '~/GiBUU/buuinput'.
#
# Prints RESULT_DIR= on the last line.
#
# THE SEED TRAP. GiBUU's initRandom namelist defaults to `Seed = 0`, and zero
# does NOT mean "use zero": code/numerics/random.f90 reads it as "draw one from
# SYSTEM_CLOCK()". Measured: two runs of the same card with Seed = 0 printed
# "Resetting Seed via system clock" and used 735342345 and 1426869522, and their
# physics output differed. A card with an explicit non-zero seed is bit
# reproducible, on one machine AND across platforms. So this wrapper refuses a
# zero or absent seed unless --allow-random-seed is given.
#
# GiBUU is GPL-2.0; see install_gibuu.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBCARD=""; OUTDIR=""; SEED=""; INPUT=""; ALLOW_RANDOM=0

log () { echo "run_gibuu: $*" >&2; }
die () { log "$*"; exit 1; }

# An option given an EMPTY value is a caller bug, not a request for the default.
need_val () { [ -n "${2:-}" ] || die "$1 requires a non-empty value"; printf '%s' "$2"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --jobcard) JOBCARD="$(need_val "$1" "${2:-}")" || exit 1; shift 2 ;;
    --outdir)  OUTDIR="$(need_val "$1" "${2:-}")" || exit 1; shift 2 ;;
    --seed)    SEED="$(need_val "$1" "${2:-}")" || exit 1; shift 2 ;;
    --input)   INPUT="$(need_val "$1" "${2:-}")" || exit 1; shift 2 ;;
    --allow-random-seed) ALLOW_RANDOM=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" ;;
  esac
done

[ -n "$JOBCARD" ] || die "--jobcard is required"
[ -f "$JOBCARD" ] || die "job card '$JOBCARD' does not exist"
JOBCARD="$(cd "$(dirname "$JOBCARD")" && pwd -P)/$(basename "$JOBCARD")"
# A GiBUU job card is a set of Fortran namelists and must contain &input.
grep -qiE '^[[:space:]]*&input([[:space:]]|$)' "$JOBCARD" \
  || die "job card '$JOBCARD' has no '&input' namelist; is it a GiBUU job card?"

# Range-checked, not digit-counted: a digit count is not a range, and an integer
# too large for the shell to compare would otherwise slip past the zero test.
in_int64 () {
  python3 -c 'import sys
try:
    v = int(sys.argv[1])
except ValueError:
    sys.exit(1)
sys.exit(0 if -(2**63) <= v < 2**63 else 1)' "$1" 2>/dev/null
}
is_int () { printf '%s' "$1" | grep -qE '^[+-]?[0-9]+$' && in_int64 "$1"; }

if [ -n "$SEED" ]; then
  is_int "$SEED" || die "--seed must be an integer, got '$SEED'"
fi

if [ -n "${GIBUU:-}" ] && [ -n "${GIBUU_INPUT:-}" ]; then
  BIN="$GIBUU"; DEFAULT_INPUT="$GIBUU_INPUT"; LIBPATH="${GIBUU_LIBPATH:-}"
else
  OUT="$("$HERE/install_gibuu.sh")" || die "install_gibuu.sh failed"
  BIN="$(printf '%s\n' "$OUT" | sed -n 's/^GIBUU=//p')"
  DEFAULT_INPUT="$(printf '%s\n' "$OUT" | sed -n 's/^GIBUU_INPUT=//p')"
  LIBPATH="$(printf '%s\n' "$OUT" | sed -n 's/^GIBUU_LIBPATH=//p')"
fi
[ -x "$BIN" ] || die "no usable GiBUU executable (GIBUU='${GIBUU:-unset}')"
[ -n "$INPUT" ] || INPUT="$DEFAULT_INPUT"
[ -d "$INPUT" ] || die "the buuinput directory '$INPUT' does not exist"
INPUT="$(cd "$INPUT" && pwd -P)"

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

WORKCARD="$OUTDIR/jobcard_used.job"
cp "$JOBCARD" "$WORKCARD"

# Point path_To_Input at the real database. Every shipped card carries the
# authors' own '~/GiBUU/buuinput', which does not exist here, and GiBUU then
# fails while reading its database rather than saying the path is wrong.
# `set -e` aborts the whole script the moment this python exits nonzero, so the
# status must be captured INSIDE the condition. Written as `rc=$?` on the next
# line it was dead code: the card with no path_To_Input made run_gibuu.sh exit
# 2 silently, with the message below never printed.
if ! python3 - "$WORKCARD" "$INPUT" <<'PY'
import re, sys
path, inp = sys.argv[1], sys.argv[2]
text = open(path).read()
new, n = re.subn(r'(?im)^(\s*path_To_Input\s*=\s*)([\'"]).*?\2', lambda m: m.group(1) + "'" + inp + "'", text)
if n == 0:
    sys.exit(2)          # no path_To_Input at all: caller is told below
open(path, 'w').write(new)
PY
then
  die "the job card has no 'path_To_Input' entry, so GiBUU cannot be pointed at the input database"
fi

# Apply the seed. GiBUU accepts either spelling of the namelist entry.
if [ -n "$SEED" ]; then
  python3 - "$WORKCARD" "$SEED" <<'PY'
import re, sys
path, seed = sys.argv[1], sys.argv[2]
text = open(path).read()
new, n = re.subn(r'(?im)^(\s*SEED\s*=\s*)[-+]?\d+', lambda m: m.group(1) + seed, text)
if n == 0:
    # No initRandom block in this card: append one.
    new = text.rstrip('\n') + "\n\n&initRandom\n      SEED = %s\n/\n" % seed
open(path, 'w').write(new)
PY
fi

# Judge the seed that will ACTUALLY be used, read back from the card as it now
# stands. Zero means "draw from the clock", so it is refused like an absent one.
EFFECTIVE_SEED="$(grep -iE '^[[:space:]]*SEED[[:space:]]*=' "$WORKCARD" | head -1 \
  | sed -E 's/.*[Ss][Ee][Ee][Dd][[:space:]]*=[[:space:]]*//; s/[[:space:]]*!.*$//; s/[[:space:]]*$//' | tr -d '\r' || true)"
if [ "$ALLOW_RANDOM" = "0" ]; then
  if [ -z "$EFFECTIVE_SEED" ]; then
    die "the job card sets no initRandom Seed, so GiBUU would draw one from the system clock and the run would be irreproducible. Pass --seed <non-zero>, or --allow-random-seed."
  fi
  if ! is_int "$EFFECTIVE_SEED"; then
    die "the job card's Seed is '$EFFECTIVE_SEED', which is not an integer; pin it with --seed"
  fi
  if [ "$EFFECTIVE_SEED" -eq 0 ]; then
    die "the job card's Seed is 0, and GiBUU reads 0 as 'draw one from SYSTEM_CLOCK()', so the run would be irreproducible. Pass --seed <non-zero>, or --allow-random-seed."
  fi
fi

log "running GiBUU.x with seed ${EFFECTIVE_SEED:-<clock>} into $OUTDIR"
set +e
( cd "$OUTDIR" && LD_LIBRARY_PATH="${LIBPATH:+$LIBPATH:}${LD_LIBRARY_PATH:-}" \
  "$BIN" < "$WORKCARD" > "$OUTDIR/out.log" 2> "$OUTDIR/err.log" )
STATUS=$?
set -e

if [ "$STATUS" -ne 0 ]; then
  log "GiBUU exited with status $STATUS"
  tail -15 "$OUTDIR/err.log" >&2 2>/dev/null
  tail -10 "$OUTDIR/out.log" >&2 2>/dev/null
  exit 1
fi

# A zero exit is not enough: GiBUU prints its own completion banner, and a run
# stopped early by a namelist error can still leave status 0 behind.
grep -q "BUU simulation: finished" "$OUTDIR/out.log" \
  || { log "the run did not report 'BUU simulation: finished'; it stopped early"
       tail -10 "$OUTDIR/out.log" >&2; exit 1; }

# GiBUU reports namelist trouble in words rather than in the exit status, and a
# job card whose namelist name is misspelled is simply IGNORED, so the run
# succeeds with default physics. That is the quiet failure worth catching.
if grep -qiE "^ *(ERROR|FATAL)|severe error|namelist.*not (found|read)" "$OUTDIR/out.log" "$OUTDIR/err.log" 2>/dev/null; then
  log "the run logged an error:"
  grep -inE "^ *(ERROR|FATAL)|severe error|namelist.*not (found|read)" "$OUTDIR/out.log" "$OUTDIR/err.log" 2>/dev/null | head -5 >&2
  exit 1
fi

NDAT="$(find "$OUTDIR" -maxdepth 1 -name '*.dat' -size +0c 2>/dev/null | wc -l | tr -d ' ')"
[ "${NDAT:-0}" -gt 0 ] || die "the run produced no non-empty .dat output"

# Non-finite values must never reach a result file. Word-bounded, because the
# headers are prose: a bare search for "inf" matches ordinary words.
if grep -qiE "(^|[^a-z])(nan|infinity)([^a-z]|$)" "$OUTDIR"/*.dat 2>/dev/null; then
  log "the output contains NaN or Infinity:"
  grep -liE "(^|[^a-z])(nan|infinity)([^a-z]|$)" "$OUTDIR"/*.dat 2>/dev/null | head -3 >&2
  exit 1
fi

log "run complete: $NDAT output files"
echo "RESULT_DIR=$OUTDIR"

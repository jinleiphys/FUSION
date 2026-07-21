#!/bin/bash
# run_azure2.sh <file.azr> [menu-choice] [workdir]
#
# Build AZURE2 if needed, run one .azr, and report honestly.
#
# menu-choice defaults to 3 (calculate without data, uses <segmentsTest>).
#   1 = calculate using data      2 = fit          3 = calculate without data
# Anything else is refused rather than guessed at: 4 (MINOS) and 5 (reaction
# rate) ask further questions this wrapper does not answer.
#
# WHY THIS IS NOT `AZURE2 file.azr`:
#
#  1. AZURE2 IS INTERACTIVE. It prints a menu and blocks on stdin, then asks for
#     an external parameter file and possibly an external capture amplitude
#     file. Unanswered, it hangs forever rather than failing.
#  2. IT WILL NOT CREATE ITS OWN OUTPUT DIRECTORIES. The paths in <config> must
#     already exist; otherwise it stops with "Could not find output directory".
#  3. IT READS param.par BACK IF PRESENT. A stale parameter file from an earlier
#     run silently overrides the widths in the .azr, so the deck you are looking
#     at is not the calculation you get. This is the quietest trap in the code
#     and it is why this script clears the file unless asked not to.
#  4. DATA FILE PATHS RESOLVE AGAINST THE PROCESS CWD, not the .azr location
#     (the GUI chdirs, the console does not). This script runs with the .azr
#     directory as cwd so relative data paths in <segmentsData> behave the way
#     the file looks like it means.
#  5. CONTENT, NOT STATUS, IS THE VERDICT. Following the rule this repo has now
#     had to learn from six codes, success is asserted from non-empty output
#     carrying finite numbers, never from $? alone.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

AZR_IN="${1:?usage: run_azure2.sh <file.azr> [menu-choice] [workdir]}"
CHOICE="${2:-3}"
case "$CHOICE" in
  1|2|3) : ;;
  *) echo "run_azure2: menu choice '$CHOICE' not supported (use 1, 2 or 3)." >&2
     echo "  4 (MINOS) and 5 (reaction rate) need extra answers this script" >&2
     echo "  does not supply; run those by hand." >&2
     exit 2 ;;
esac

[ -f "$AZR_IN" ] || { echo "run_azure2: no such file: $AZR_IN" >&2; exit 1; }
AZR_DIR="$(cd "$(dirname "$AZR_IN")" && pwd)"
AZR="$(basename "$AZR_IN")"

BIN="${AZURE2_BIN:-}"
if [ -z "$BIN" ]; then
  BIN="$(bash "$HERE/install_azure2.sh" | sed -n 's/^AZURE2=//p')"
fi
[ -x "$BIN" ] || { echo "run_azure2: no usable AZURE2 binary" >&2; exit 1; }

cd "$AZR_DIR"

# The <config> section names the output and checks directories, on its 2nd and
# 3rd lines. Read them out of the file rather than assuming "output/", because a
# wrong guess here produces the confusing "Could not find output directory".
OUTDIR="$(awk '/^<config>/{f=1;n=0;next} f&&NF{n++; if(n==2){sub(/[ \t]*#.*/,""); gsub(/[ \t]+$/,""); print; exit}}' "$AZR")"
CHKDIR="$(awk '/^<config>/{f=1;n=0;next} f&&NF{n++; if(n==3){sub(/[ \t]*#.*/,""); gsub(/[ \t]+$/,""); print; exit}}' "$AZR")"
: "${OUTDIR:=output/}"
: "${CHKDIR:=checks/}"
mkdir -p "$OUTDIR" "$CHKDIR"

# Trap 3. Keep it opt-out so a deliberate restart-from-parameters run is still
# possible, but make the default the safe one.
if [ -z "${AZURE2_KEEP_PARAMS:-}" ]; then
  rm -f "$OUTDIR/param.par" "$OUTDIR/parameters.out"
fi

# CONCURRENCY. "files newer than my stamp" attributes another process's output
# to this run: an adversarial pass started a stub that wrote nothing, then a real
# AZURE2 in the same directory 0.08 s later, and the stub reported OK for the
# other process's files. An exclusive lock on the output directory removes the
# race rather than trying to disambiguate afterwards.
LOCK="$OUTDIR/.run_azure2.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "run_azure2: $OUTDIR is locked by another run (stale? remove $LOCK)." >&2
  exit 1
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

STAMP="$(mktemp)"; touch "$STAMP"

LOG="$OUTDIR/run.log"; ERR="$OUTDIR/run.err"
set +e
printf '%s\n\n\n6\n' "$CHOICE" | "$BIN" --no-gui "$AZR" > "$LOG" 2> "$ERR"
RC=$?
set -e

if grep -q "Could not find" "$LOG" 2>/dev/null; then
  echo "run_azure2: AZURE2 could not find a directory named in <config>:" >&2
  grep "Could not find" "$LOG" >&2
  rm -f "$STAMP"; exit 1
fi

# A DROPPED SEGMENT IS A FAILURE, not a warning. If a data file is missing or
# unreadable AZURE2 prints "Could Not Fill Segment #N from file." and carries on
# with the rest, so chiSquared.out is computed over a DIFFERENT deck than the one
# requested. Silently accepting that is how a benchmark quietly stops testing
# what it claims to test.
if grep -qi "Could Not Fill Segment" "$LOG" 2>/dev/null; then
  echo "run_azure2: AZURE2 dropped one or more segments; the deck did not run as written:" >&2
  grep -i "Could Not Fill Segment" "$LOG" >&2
  echo "  (usually a missing or unreadable data file; paths resolve against $AZR_DIR)" >&2
  rm -f "$STAMP"; exit 1
fi

# Positive assertion 1: files that THIS run wrote. NUL-delimited throughout, so
# output directories containing spaces do not get word-split into fake paths.
NEWLIST="$(mktemp)"
# Only the AZUREOut_* tables are numeric result files. Deliberately excluded:
# intEC.extrap (complex amplitudes written as "(re,im)", a legitimate format
# that is not a column table) and parameters.out (a human-readable report).
# Validating those as numeric tables makes a healthy run look broken.
find "$OUTDIR" -type f -newer "$STAMP" -name 'AZUREOut_*' \
     \( -name '*.extrap' -o -name '*.out' -o -name '*.acoeff' \) \
     -print0 2>/dev/null > "$NEWLIST" || true
rm -f "$STAMP"
if [ ! -s "$NEWLIST" ]; then
  echo "run_azure2: AZURE2 exited $RC but wrote no result file into $OUTDIR." >&2
  echo "  Last lines of $LOG:" >&2; tail -15 "$LOG" >&2
  [ -s "$ERR" ] && { echo "  stderr:" >&2; tail -10 "$ERR" >&2; }
  rm -f "$NEWLIST"; exit 1
fi

# Positive assertion 2: every result file is a well-formed numeric table with
# finite values. check_output.py enforces column consistency, float parsing,
# finiteness and a terminating newline; a nan/inf grep catches none of the
# truncated-line, 1e9999 or non-numeric-token cases.
if ! xargs -0 python3 "$HERE/check_output.py" < "$NEWLIST" ; then
  echo "run_azure2: result file(s) failed structural validation." >&2
  rm -f "$NEWLIST"; exit 1
fi

if [ "$RC" -ne 0 ]; then
  echo "run_azure2: WARNING, AZURE2 exited $RC although output looks well formed." >&2
  tail -5 "$LOG" >&2
fi

grep -E "^WARNING" "$LOG" 2>/dev/null | sort -u | sed 's/^/run_azure2: /' >&2 || true

NFILES="$(tr -cd '\0' < "$NEWLIST" | wc -c | tr -d ' ')"
echo "run_azure2: OK, $NFILES result file(s) in $OUTDIR"
tr '\0' '\n' < "$NEWLIST" | sed 's/^/  /'
rm -f "$NEWLIST"

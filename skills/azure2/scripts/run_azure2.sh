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

# Record what existed before, so "did this run produce it" is answerable rather
# than assumed. A pre-existing output file from an earlier run is exactly how
# the CCFULL skill once reported a stale reference as a fresh success.
BEFORE="$(mktemp)"; trap 'rm -f "$BEFORE"' EXIT
find "$OUTDIR" -type f -newermt "@0" 2>/dev/null | sort > "$BEFORE" || true
STAMP="$(mktemp)"; touch "$STAMP"

LOG="$OUTDIR/run.log"; ERR="$OUTDIR/run.err"
set +e
printf '%s\n\n\n6\n' "$CHOICE" | "$BIN" --no-gui "$AZR" > "$LOG" 2> "$ERR"
RC=$?
set -e

if grep -q "Could not find" "$LOG" 2>/dev/null; then
  echo "run_azure2: AZURE2 could not find a directory named in <config>:" >&2
  grep "Could not find" "$LOG" >&2
  exit 1
fi

# Positive assertion 1: files that this run actually wrote.
NEW="$(find "$OUTDIR" -type f -newer "$STAMP" \
        \( -name '*.extrap' -o -name '*.out' -o -name '*.acoeff' \) \
        ! -name 'run.log' ! -name 'run.err' 2>/dev/null | sort)"
rm -f "$STAMP"
if [ -z "$NEW" ]; then
  echo "run_azure2: AZURE2 exited $RC but wrote no result file into $OUTDIR." >&2
  echo "  Last lines of $LOG:" >&2; tail -15 "$LOG" >&2
  [ -s "$ERR" ] && { echo "  stderr:" >&2; tail -10 "$ERR" >&2; }
  exit 1
fi

# Positive assertion 2: non-empty, and every number finite. A diverging R-matrix
# solve writes nan/inf rather than failing, and a comparator that only checks
# for the file's existence would call that a success.
BAD=0
for f in $NEW; do
  if [ ! -s "$f" ]; then
    echo "run_azure2: $f was created but is EMPTY." >&2; BAD=1; continue
  fi
  if grep -qiE 'nan|inf' "$f"; then
    echo "run_azure2: $f contains non-finite values (nan/inf):" >&2
    grep -inE 'nan|inf' "$f" | head -3 >&2; BAD=1
  fi
done
[ "$BAD" -eq 0 ] || exit 1

if [ "$RC" -ne 0 ]; then
  echo "run_azure2: WARNING, AZURE2 exited $RC although output looks well formed." >&2
  tail -5 "$LOG" >&2
fi

# Surface the warnings AZURE2 prints but does not treat as errors. The
# A-matrix one is expected whenever external capture is on, and is not a fault.
grep -E "^WARNING" "$LOG" 2>/dev/null | sort -u | sed 's/^/run_azure2: /' >&2 || true

echo "run_azure2: OK, $(echo "$NEW" | wc -l | tr -d ' ') result file(s) in $OUTDIR"
for f in $NEW; do echo "  $f"; done

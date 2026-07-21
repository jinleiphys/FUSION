#!/bin/bash
# run_pikoe.sh <deck.cnt> [workdir]
#
# Build pikoe if needed, run one control file, and report honestly.
#
# THE CRITICAL POINT: pikoe's exit status is not a verdict. The physics record,
# including whether the calculation finished, goes to the outlist file named by
# the kibout field of input line L16 (unit 6 in every shipped deck, which is why
# the record lands in a .outlist file rather than on the terminal). A run that
# dies early can still leave a plausible-looking table behind. This script
# asserts three positive facts instead of trusting $?:
#
#   1. the calculation-completed banner is present (in the outlist or stdout),
#   2. at least one NON-EMPTY data table was produced. Emptiness is the point:
#      pikoe opens every output unit at startup, so all of LG_/PX_/TR_/TL_ exist
#      at zero bytes from the first second of a run. Presence proves nothing.
#   3. stderr contains nothing beyond the benign "STOP 0" that pikoe always
#      writes on a normal exit.
#
# LAYOUT: the shipped decks reference the data tables by RELATIVE path
# (../elem/nnampFL.dat, ../pot/EDAD1p12C_e.dat), because upstream expects the
# binary and the deck to sit in a sampleN/ subdirectory of the unpacked tree.
# This script reproduces that layout without copying 50 MB of tables: it makes
# <workdir>/elem and <workdir>/pot symlinks into the install, and runs the deck
# in <workdir>/case. The decks are therefore used verbatim, never rewritten.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

SRC="${1:?usage: run_pikoe.sh <deck.cnt> [workdir]}"
WORK="${2:-$(pwd)/pikoe-run}"

[ -f "$SRC" ] || { echo "no such deck: $SRC" >&2; exit 1; }

BIN_LINE="$(bash "$HERE/install_pikoe.sh")"
BIN="${BIN_LINE#PIKOE=}"
[ -x "$BIN" ] || { echo "no pikoe binary" >&2; exit 1; }
SRCDIR="$(cd "$(dirname "$BIN")" && pwd)"

abspath () { ( cd "$1" 2>/dev/null && pwd ) || echo "$1"; }

CASE="$WORK/case"

# Refuse to destroy anything we were not asked to own. The earlier version of
# this guard compared against $CASE while the rm below deleted $WORK, so a deck
# sitting in the workdir, or a workdir pointed at the install tree, was wiped.
# Guard the directory that is actually removed, and check both the deck and the
# install tree against it.
WORK_ABS="$(abspath "$WORK")"
inside () {
  # inside <path> <dir>: true if <path> is <dir> or lies beneath it
  case "$1" in
    "$2") return 0 ;;
    "$2"/*) return 0 ;;
    *) return 1 ;;
  esac
}
if inside "$(abspath "$(dirname "$SRC")")/$(basename "$SRC")" "$WORK_ABS"; then
  echo "run_pikoe: the deck lives inside the workdir ($WORK); refusing to wipe it" >&2
  exit 1
fi
if inside "$SRCDIR" "$WORK_ABS"; then
  echo "run_pikoe: the workdir ($WORK) contains the pikoe install ($SRCDIR); refusing to wipe it" >&2
  exit 1
fi

# Own and reset only $CASE. $WORK may legitimately be a directory the caller
# already uses for other things, so it is created but never removed.
mkdir -p "$WORK"
rm -rf "$CASE"
mkdir -p "$CASE"
ln -sfn "$SRCDIR/elem" "$WORK/elem"
ln -sfn "$SRCDIR/pot"  "$WORK/pot"

DECK="$(basename "$SRC")"
cp "$SRC" "$CASE/$DECK" || { echo "run_pikoe: failed to stage deck $SRC" >&2; exit 1; }
[ -s "$CASE/$DECK" ] || { echo "run_pikoe: staged deck is empty: $CASE/$DECK" >&2; exit 1; }

cd "$CASE"
# The upstream readme recommends an unlimited stack. macOS caps the hard limit
# well below unlimited, so ask for the hard limit and carry on if refused: the
# distributed sample cases run inside the default stack.
ulimit -s hard 2>/dev/null || true

set +e
"$BIN" < "$DECK" > run.stdout 2> run.stderr
rc=$?
set -e

banner_file=""
for f in *.outlist run.stdout; do
  [ -f "$f" ] || continue
  if grep -q "calculation completed" "$f"; then banner_file="$f"; break; fi
done

if [ -z "$banner_file" ]; then
  echo "PIKOE FAILED: no calculation-completed banner (it exited $rc)" >&2
  echo "== stdout ==" >&2; tail -20 run.stdout >&2
  [ -s run.stderr ] && { echo "== stderr ==" >&2; tail -20 run.stderr >&2; }
  for f in *.outlist; do
    [ -f "$f" ] && { echo "== $f ==" >&2; tail -20 "$f" >&2; }
  done
  exit 1
fi

# Count NON-EMPTY tables. `ls *.dat | wc -l` was wrong twice over: under
# `set -euo pipefail` a glob matching nothing aborts the script before the
# diagnostic below can print, and a zero-byte table counted as a result.
nonempty=""
for f in *.dat; do
  [ -f "$f" ] || continue
  [ -s "$f" ] || continue
  nonempty="$nonempty $f"
done
if [ -z "$nonempty" ]; then
  echo "PIKOE FAILED: banner present but no non-empty data table was written" >&2
  ls -l >&2
  exit 1
fi

if [ "$rc" -ne 0 ]; then
  echo "run_pikoe: WARNING pikoe exited $rc despite completing; treat as suspect" >&2
fi

# pikoe writes "STOP 0" to stderr on every normal exit. Warning about that on
# every successful run would train the reader to ignore stderr, which defeats
# the point, so only report anything else.
if [ -s run.stderr ]; then
  if grep -qv '^STOP 0$' run.stderr; then
    echo "== stderr (unexpected content, inspect it) ==" >&2
    grep -v '^STOP 0$' run.stderr | head -10 >&2
  fi
fi

echo "== $CASE =="
echo "tables:$nonempty"
echo "record: $CASE/$(ls *.outlist 2>/dev/null | head -1)"
grep -E "integrated value|calculation completed" ./*.outlist run.stdout 2>/dev/null | sed 's/^/  /' || true

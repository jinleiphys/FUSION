#!/bin/bash
# run_nlat.sh <deck.in> [workdir]
#
# Build NLAT if needed, run one input deck in a clean workdir, report honestly.
#
# THE CRITICAL POINT: the deck names its own output DIRECTORY, and in the
# distributed samples that name is the sample directory itself (LOCAL_SAMPLE,
# NONLOCAL_SAMPLE). Running a shipped deck from inside the unpacked tree
# therefore writes the results on top of the distributed reference output, and
# any later comparison silently compares the run against itself. That is the
# CCFULL false positive in a new costume. This script always runs in a fresh
# workdir, so the references in the install tree are never touched.
#
# NLAT creates the output directory itself, by shelling out `mkdir <name>`
# (SOURCE/main.f90). Two consequences: the deck is used verbatim, nothing needs
# rewriting; and the directory name reaches a shell unquoted, so a name with
# spaces or shell metacharacters will misbehave. Keep the names plain.
#
# Success is asserted positively, never from the exit status: the output
# directory must exist and must contain at least one NON-EMPTY .txt file.
# Emptiness matters because NLAT creates every enabled output file whether or
# not the corresponding calculation ran: a local-only run still leaves
# NonlocalBoundWF.txt and the Nonlocal*Integral/Smatrix files at zero bytes.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

SRC="${1:?usage: run_nlat.sh <deck.in> [workdir]}"
WORK="${2:-$(pwd)/nlat-run}"

[ -f "$SRC" ] || { echo "no such deck: $SRC" >&2; exit 1; }

BIN_LINE="$(bash "$HERE/install_nlat.sh")"
BIN="${BIN_LINE#NLAT=}"
[ -x "$BIN" ] || { echo "no NLAT binary" >&2; exit 1; }
SRCDIR="$(cd "$(dirname "$BIN")" && pwd)"

# Resolve symlinks. `pwd -P` is the point: a deck reached through a symlink
# whose target lives inside the workdir would otherwise pass the guard below and
# then be destroyed along with the workdir.
abspath () { ( cd "$1" 2>/dev/null && pwd -P ) || echo "$1"; }
realfile () {
  local d b
  d="$(abspath "$(dirname "$1")")"
  b="$(basename "$1")"
  # Follow a symlinked deck to its real location before judging where it lives.
  while [ -L "$d/$b" ]; do
    local t
    t="$(readlink "$d/$b")"
    case "$t" in
      /*) d="$(abspath "$(dirname "$t")")"; b="$(basename "$t")" ;;
      *)  d="$(abspath "$(dirname "$d/$t")")"; b="$(basename "$t")" ;;
    esac
  done
  echo "$d/$b"
}
inside () { case "$1" in "$2") return 0 ;; "$2"/*) return 0 ;; *) return 1 ;; esac; }

WORK_ABS="$(abspath "$WORK")"
SRC_REAL="$(realfile "$SRC")"

# Guard the directory that is actually removed. BOTH directions matter and the
# dangerous one is easy to get backwards: the previous version tested only
# whether the install contained the workdir, while the destructive case is the
# workdir living INSIDE the install (for example pointing it at LOCAL_SAMPLE or
# at SOURCE/). That is the same defect the pikoe wrapper shipped with, so it is
# spelled out here rather than left to a one-line test.
if inside "$SRC_REAL" "$WORK_ABS"; then
  echo "run_nlat: the deck lives inside the workdir ($WORK); refusing to wipe it" >&2
  exit 1
fi
if inside "$WORK_ABS" "$SRCDIR"; then
  echo "run_nlat: the workdir ($WORK) is inside the NLAT install ($SRCDIR); refusing to wipe it" >&2
  echo "  Running there would destroy the distributed reference output." >&2
  exit 1
fi
if inside "$SRCDIR" "$WORK_ABS"; then
  echo "run_nlat: the workdir ($WORK) contains the NLAT install ($SRCDIR); refusing to wipe it" >&2
  exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK"
DECK="$(basename "$SRC_REAL")"
cp "$SRC_REAL" "$WORK/$DECK" || { echo "run_nlat: failed to stage deck $SRC" >&2; exit 1; }
[ -s "$WORK/$DECK" ] || { echo "run_nlat: staged deck is empty: $WORK/$DECK" >&2; exit 1; }

cd "$WORK"
set +e
"$BIN" < "$DECK" > run.out 2> run.err
rc=$?
set -e

# NLAT creates exactly one directory, the one the deck named. Find it rather
# than parsing the deck: the output-directory line carries no marker, and the
# two shipped decks do not even format the following line the same way.
outdir=""
for d in */; do
  [ -d "$d" ] || continue
  outdir="${d%/}"
  break
done

if [ -z "$outdir" ]; then
  echo "NLAT FAILED: no output directory was created (it exited $rc)" >&2
  echo "== stdout ==" >&2; tail -20 run.out >&2
  [ -s run.err ] && { echo "== stderr ==" >&2; tail -20 run.err >&2; }
  exit 1
fi

nonempty=""
for f in "$outdir"/*.txt; do
  [ -f "$f" ] || continue
  [ -s "$f" ] || continue
  nonempty="$nonempty $(basename "$f")"
done
if [ -z "$nonempty" ]; then
  echo "NLAT FAILED: output directory $outdir holds no non-empty result file" >&2
  ls -l "$outdir" >&2
  exit 1
fi

if [ "$rc" -ne 0 ]; then
  echo "run_nlat: WARNING NLAT exited $rc despite producing output; treat as suspect" >&2
fi

# The only benign stderr is the mkdir complaint that appears when the output
# directory already exists, since NLAT calls mkdir unconditionally.
if [ -s run.err ]; then
  if grep -qv "mkdir:.*File exists" run.err; then
    echo "== stderr (unexpected content, inspect it) ==" >&2
    grep -v "mkdir:.*File exists" run.err | head -10 >&2
  fi
fi

echo "== $WORK/$outdir =="
echo "non-empty results:$nonempty"
echo "log: $WORK/run.out"

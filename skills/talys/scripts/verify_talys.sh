#!/bin/bash
# verify_talys.sh <sample-name> [workdir]
#
# Run one of TALYS's own sample cases in a clean workdir and compare every
# output file against the distributed reference in that sample's org/ directory.
#
#   verify_talys.sh n-Nb093-14MeV-full
#   verify_talys.sh n-Sn120-omp-KD03
#
# With no argument, lists the available sample names.
#
# Comparison notes:
#   - The org/ reference and a fresh run differ in the "date:" and "user:"
#     header lines and in the reported execution time. Those are excluded.
#   - Everything else is compared byte for byte first. TALYS is deterministic
#     and most files reproduce exactly; files that do not are then compared
#     numerically, split by magnitude, because near-zero populations differ by
#     float32 round-off in a way that makes relative differences meaningless.
#   - Upstream's own harness is talys/samples/verify, which runs the whole set
#     in about an hour. This script does one case, in a clean directory.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

BIN_LINE="$(bash "$HERE/install_talys.sh")"
BIN="${BIN_LINE#TALYS=}"
ROOT="$(cd "$(dirname "$BIN")/.." && pwd)"
SAMPLES="$ROOT/samples"

if [ $# -lt 1 ]; then
  # A sample case is a directory holding org/ and new/. Selecting on that is
  # portable; a name-based grep filter is not (BSD grep does not honour the
  # GNU '\|' alternation without -E, so README and verify leaked into the list).
  echo "available sample cases in $SAMPLES:" >&2
  find "$SAMPLES" -mindepth 1 -maxdepth 1 -type d \
       -exec test -d '{}/org' -a -d '{}/new' \; -print \
    | xargs -n1 basename | sort | column -c 100 2>/dev/null \
    || find "$SAMPLES" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
  exit 2
fi

CASE="$1"
WORK="${2:-$(pwd)/talys-verify-$CASE}"
SDIR="$SAMPLES/$CASE"
[ -d "$SDIR/new" ] && [ -d "$SDIR/org" ] || { echo "no such sample case: $CASE" >&2; exit 2; }

rm -rf "$WORK"; mkdir -p "$WORK"
# Copy the whole new/ dir: some cases ship an auxiliary `energies` grid file.
cp "$SDIR/new"/* "$WORK"/
# The reference lives in org/ and is never copied into the run directory, so a
# failed run cannot be mistaken for a reproduction.

echo "running sample $CASE ..." >&2
# Do not swallow a failed run: comparing the output of a run that never happened
# is exactly the false positive this skill exists to prevent.
if ! bash "$HERE/run_talys.sh" "$WORK" "$WORK" >/dev/null; then
  echo "the sample run FAILED; not comparing (see $WORK/talys.out)" >&2
  exit 1
fi

python3 - "$SDIR/org" "$WORK" <<'PY'
import os,re,sys,math,glob
ORG,W=sys.argv[1],sys.argv[2]
skip=re.compile(r'date:|user:|Execution time|Date:')
num=re.compile(r'[-+]?\d+\.\d+E[-+]\d+')

def lines(p):
    return [l for l in open(p,errors='replace') if not skip.search(l)]

exact=0; differ=[]; missing=[]
refs=[f for f in sorted(glob.glob(os.path.join(ORG,"*"))) if os.path.isfile(f)]
for p1 in refs:
    b=os.path.basename(p1); p2=os.path.join(W,b)
    if not os.path.exists(p2): missing.append(b); continue
    if lines(p1)==lines(p2): exact+=1
    else: differ.append(b)

print("reference files: %d" % len(refs))
print("reproduced exactly (ignoring date/user/timing): %d" % exact)
print("missing from our run: %d" % len(missing))
print("differing: %d" % len(differ))
for b in missing[:10]: print("   MISSING", b)

if differ:
    pairs=[]
    for b in differ:
        if b=="talys.out": continue
        for l1,l2 in zip(lines(os.path.join(ORG,b)), lines(os.path.join(W,b))):
            if l1==l2: continue
            n1,n2=num.findall(l1),num.findall(l2)
            if len(n1)!=len(n2): continue
            pairs += list(zip(map(float,n1),map(float,n2)))
    print("\nfiles differing: %s%s" % (", ".join(differ[:8]), " ..." if len(differ)>8 else ""))
    if pairs:
        print("numbers on differing lines: %d" % len(pairs))
        for floor,label in [(1e-8,"all above 1e-8"),(1e-2,"physical observables (>1e-2)")]:
            w=[(abs(x-y)/max(abs(x),abs(y)),x,y) for x,y in pairs
               if max(abs(x),abs(y))>floor]
            if not w: print("  %s: none" % label); continue
            w.sort(reverse=True)
            figs=16 if w[0][0]==0 else -math.log10(w[0][0])
            print("  %s: %d numbers, max rel %.2e -> ~%.1f significant figures"
                  % (label,len(w),w[0][0],figs))
            print("     worst: ref %g   ours %g" % (w[0][1],w[0][2]))
        print("\nDifferences below ~1e-4 are numerically-zero populations where one")
        print("platform gives exact 0 and the other a float32 residue; judge the run")
        print("on the physical-observables line.")
PY

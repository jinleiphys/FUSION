#!/bin/bash
# compare_gsm.sh <reference.out> <produced.out>
#
# Numerically compare two GSM outputs.  A plain diff is the wrong tool here:
# the shipped reference outputs were produced by GSM-1.0, whose print format
# differs cosmetically from GSM-2.0 ("k:(...)" vs "k : (...)"), and last-digit
# rounding legitimately varies between compilers and architectures.
#
# This extracts every number from both files and reports relative differences,
# split by magnitude so that convergence residuals (|Jost|, overlaps, numerical
# -zero widths, all ~1e-8 and below) do not drown out the actual observables.
set -euo pipefail
REF="${1:?usage: compare_gsm.sh <reference.out> <produced.out>}"
OUR="${2:?usage: compare_gsm.sh <reference.out> <produced.out>}"

python3 - "$REF" "$OUR" <<'PY'
import re, sys, math
num = re.compile(r'[-+]?\d+\.?\d*(?:[eE][-+]?\d+)?')
# Lines that legitimately differ between machines: timings, and the storage
# directory (an absolute path, whose digits would otherwise be read as data).
skip = re.compile(r'time:|STORAGE_DIR|workspace|^\s*/', re.I)

def nums(p):
    out = []
    for line in open(p, errors='replace'):
        if skip.search(line):
            continue
        out += [float(m) for m in num.findall(line)]
    return out

a, b = nums(sys.argv[1]), nums(sys.argv[2])
print("numbers extracted   reference: %d   produced: %d" % (len(a), len(b)))
if len(a) != len(b):
    print("COUNT MISMATCH: the runs did not produce the same quantities.")
    print("Usual causes: an iterative solver converged in a different number of")
    print("steps, or the run stopped early. Diff the two files structurally with")
    print("  diff <(sed 's/[0-9][0-9.eE+-]*/N/g' REF) <(sed 's/[0-9][0-9.eE+-]*/N/g' OURS)")
    sys.exit(1)

def report(label, floor):
    w = []
    for x, y in zip(a, b):
        scale = max(abs(x), abs(y))
        if scale < floor or scale == 0.0:
            continue
        w.append((abs(x - y) / scale, x, y))
    if not w:
        print("\n%s: nothing above %g" % (label, floor)); return
    w.sort(reverse=True)
    worst = w[0][0]
    figs = 16 if worst == 0 else -math.log10(worst)
    print("\n%s  (|value| > %g):  %d numbers" % (label, floor, len(w)))
    print("  max relative difference: %.3e  ->  ~%.0f significant figures" % (worst, figs))
    for d, x, y in w[:4]:
        print("    rel %.2e   ref %.15g   ours %.15g" % (d, x, y))

report("ALL NUMBERS",            0.0)
report("OBSERVABLES", 1e-2)
print("\nObservables are energies (MeV), widths (keV), momenta (fm^-1), norms.")
print("Numbers below 1e-2 are mostly convergence residuals; judge the run on the")
print("observables line, and state agreement as significant figures, not 'identical'.")
PY

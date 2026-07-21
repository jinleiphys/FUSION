#!/usr/bin/env python3
"""compare_nlat.py <reference-dir> <output-dir> [--tol REL] [--prefix-ok NAME:REFN:RUNN]

Compare an NLAT run against the distributed reference output, numerically.

Why not `diff`: NLAT writes full double precision, so a different compiler or
architecture changes the last digit or two of essentially every number while the
physics is identical. A plain diff reports thousands of meaningless differences
and hides the one that matters. This compares token by token and reports the
worst RELATIVE difference per file.

Two guards against a false pass, both learned the hard way in this project:

  * A zero-byte reference is reported as SKIPPED, never as a match. Several
    distributed reference files are empty by construction (a local-only run
    still creates NonlocalBoundWF.txt and the Nonlocal*Integral/Smatrix files),
    and "empty equals empty" is not evidence of anything.
  * If nothing was actually compared, the result is FAILURE, not success. A
    comparison that silently checked zero files is the single most flattering
    way to be wrong.

`--prefix-ok NAME:REFN:RUNN` declares ONE known length deviation: file NAME is
allowed to have exactly REFN numbers in the reference and exactly RUNN in the
run, with RUNN < REFN, in which case the overlapping RUNN values are compared and
the extra reference values are reported as unmatched. The counts are pinned on
purpose: this is a narrow, evidence-backed exception for a specific packaging
fault upstream, not a general licence to ignore length mismatches. Any other
count, in either file, is still a hard failure.

Exit status 0 only if at least one file was compared and every compared file is
within tolerance.
"""
import math
import os
import sys

DEFAULT_TOL = 1e-6


def tokens(path):
    """Yield floats in file order, ignoring anything unparseable."""
    out = []
    with open(path, errors="replace") as fh:
        for line in fh:
            for tok in line.split():
                try:
                    out.append(float(tok.replace("D", "E").replace("d", "e")))
                except ValueError:
                    pass
    return out


def compare_file(ref, got, tol, prefix_ok=None):
    a, b = tokens(ref), tokens(got)
    if len(a) != len(b):
        if (prefix_ok is not None
                and len(a) == prefix_ok[0] and len(b) == prefix_ok[1]
                and prefix_ok[1] < prefix_ok[0]):
            a = a[:len(b)]  # compare the overlap only; the caller declared this
        else:
            return None, "token count differs: reference %d, run %d" % (len(a), len(b))
    worst = 0.0
    worst_pair = None
    over = 0
    for i, (x, y) in enumerate(zip(a, b)):
        # NaN and Inf must be caught explicitly. Every comparison against NaN is
        # False, so an all-NaN output file would otherwise sail through with
        # worst == 0.0 and be reported as a perfect match. NaN is exactly what a
        # diverging iterative nonlocal solve produces, which is what this code
        # does for a living, so this is the failure mode most worth catching.
        if not math.isfinite(x):
            return None, "non-finite value in REFERENCE at token %d: %r" % (i + 1, x)
        if not math.isfinite(y):
            return None, "non-finite value in RUN OUTPUT at token %d: %r" % (i + 1, y)
        if x == y:
            continue
        scale = max(abs(x), abs(y))
        if scale == 0.0:
            continue
        d = abs(x - y) / scale
        if d > worst:
            worst, worst_pair = d, (x, y)
        if d > tol:
            over += 1
    return (len(a), worst, worst_pair, over), None


def main():
    argv = sys.argv[1:]
    args = []
    tol = DEFAULT_TOL
    prefix_specs = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--tol":
            # Support the spaced form the docstring advertises, not only --tol=X.
            if i + 1 >= len(argv):
                print("--tol needs a value", file=sys.stderr)
                return 2
            tol = float(argv[i + 1])
            i += 2
            continue
        if a == "--prefix-ok":
            if i + 1 >= len(argv):
                print("--prefix-ok needs NAME:REFN:RUNN", file=sys.stderr)
                return 2
            prefix_specs.append(argv[i + 1])
            i += 2
            continue
        if a.startswith("--prefix-ok="):
            prefix_specs.append(a.split("=", 1)[1])
            i += 1
            continue
        if a.startswith("--tol="):
            tol = float(a.split("=", 1)[1])
            i += 1
            continue
        if a.startswith("--"):
            print("unknown option: %s" % a, file=sys.stderr)
            return 2
        args.append(a)
        i += 1
    if len(args) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    refdir, outdir = args

    # NAME -> (reference count, run count)
    prefix_ok = {}
    for spec in prefix_specs:
        parts = spec.split(":")
        if len(parts) != 3:
            print("bad --prefix-ok spec %r, want NAME:REFN:RUNN" % spec, file=sys.stderr)
            return 2
        try:
            prefix_ok[parts[0]] = (int(parts[1]), int(parts[2]))
        except ValueError:
            print("bad counts in --prefix-ok spec %r" % spec, file=sys.stderr)
            return 2

    if not os.path.isdir(refdir):
        print("no reference directory: %s" % refdir, file=sys.stderr)
        return 2
    if not os.path.isdir(outdir):
        print("no output directory: %s" % outdir, file=sys.stderr)
        return 2

    refs = sorted(f for f in os.listdir(refdir) if f.endswith(".txt"))
    if not refs:
        print("no .txt reference files in %s" % refdir, file=sys.stderr)
        return 2

    compared = skipped = failed = 0
    print("  %-30s %9s %12s %8s" % ("file", "numbers", "worst rel", "verdict"))
    for f in refs:
        ref, got = os.path.join(refdir, f), os.path.join(outdir, f)
        if os.path.getsize(ref) == 0:
            print("  %-30s %9s %12s %8s" % (f, "-", "-", "SKIP(ref empty)"))
            skipped += 1
            continue
        if not os.path.exists(got):
            print("  %-30s %9s %12s %8s" % (f, "-", "-", "MISSING"))
            failed += 1
            continue
        if os.path.getsize(got) == 0:
            print("  %-30s %9s %12s %8s" % (f, "-", "-", "EMPTY OUTPUT"))
            failed += 1
            continue
        res, err = compare_file(ref, got, tol, prefix_ok.get(f))
        if err:
            print("  %-30s %9s %12s %8s  %s" % (f, "-", "-", "FAIL", err))
            failed += 1
            continue
        n, worst, pair, over = res
        ok = worst <= tol
        note = ""
        if f in prefix_ok:
            refn, runn = prefix_ok[f]
            note = "  [declared prefix: %d of %d reference values matched, %d unmatched]" % (
                runn, refn, refn - runn)
        print("  %-30s %9d %12.3e %8s%s" % (f, n, worst, "ok" if ok else "FAIL", note))
        compared += 1
        if not ok:
            print("        worst pair: reference %.17g, run %.17g (%d values over %g)"
                  % (pair[0], pair[1], over, tol))
            failed += 1

    print("  compared %d, skipped %d (empty reference), failed %d"
          % (compared, skipped, failed))
    if compared == 0 and failed == 0:
        print("  NOTHING WAS COMPARED: treating as failure")
        return 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

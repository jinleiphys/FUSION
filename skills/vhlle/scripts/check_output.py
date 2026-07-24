#!/usr/bin/env python3
"""
check_output.py: validate a vHLLE profile table (outx/outy/outz/outdiag.dat).

Checks: at least one data row, a consistent column count, every field a finite
number (no NaN/Inf from a diverged run), and optional minimum row/column counts.

    check_output.py FILE [--min-rows N] [--min-cols N]

Exit 0 on success, non-zero on any failure.
"""
import sys
import math
import argparse


def main(argv):
    p = argparse.ArgumentParser()
    p.add_argument("file")
    p.add_argument("--min-rows", type=int, default=1)
    p.add_argument("--min-cols", type=int, default=1)
    a = p.parse_args(argv)
    if a.min_rows < 0 or a.min_cols < 0:
        p.error("--min-rows/--min-cols must be non-negative")

    rows = 0
    ncols = None
    nonfinite = 0
    with open(a.file) as f:
        for lineno, line in enumerate(f, 1):
            s = line.split()
            if not s:
                continue
            try:
                vals = [float(x) for x in s]
            except ValueError:
                # a non-numeric line in a profile table is unexpected
                print("FAIL: non-numeric token on line %d of %s" % (lineno, a.file))
                return 1
            if ncols is None:
                ncols = len(vals)
            elif len(vals) != ncols:
                print("FAIL: ragged table, line %d has %d cols, expected %d"
                      % (lineno, len(vals), ncols))
                return 1
            for v in vals:
                if not math.isfinite(v):
                    nonfinite += 1
            rows += 1

    if rows == 0:
        print("FAIL: no data rows in %s" % a.file)
        return 1
    if nonfinite > 0:
        print("FAIL: %d non-finite (NaN/Inf) values in %s" % (nonfinite, a.file))
        return 1
    if rows < a.min_rows:
        print("FAIL: %d rows < required %d in %s" % (rows, a.min_rows, a.file))
        return 1
    if ncols < a.min_cols:
        print("FAIL: %d cols < required %d in %s" % (ncols, a.min_cols, a.file))
        return 1

    print("check_output: OK (%s: %d rows, %d cols, all finite)" % (a.file, rows, ncols))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

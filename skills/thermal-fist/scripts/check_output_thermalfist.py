#!/usr/bin/env python3
"""Validate a Thermal-FIST output table, and optionally compare it to a reference.

Thermal-FIST's cpc/EoS example programs write whitespace-delimited tables whose
FIRST line is a header naming the columns (e.g. `T[MeV] p/T^4 e/T^4 ...`) and
whose remaining lines are numeric rows. This checker enforces the shape that a
usable output must have, independent of the build:

  * the file is non-empty and its first line is a header (starts with a
    non-numeric token, or a leading '#');
  * every data row parses as all-numeric with a CONSISTENT column count;
  * no value is NaN or +-Inf;
  * at least --min-rows data rows are present.

With --reference it also reproduces the semantics of the code's own comparator
(test/test_CompareOutputs.cpp): skip the header line of both files, then compare
every numeric column with an ABSOLUTE tolerance, and require the same number of
columns and rows. This is used for the fast physics anchor, where a single known
row is checked; the full tier-1 evidence is the shipped ctest suite, not this.

Usage:
  check_output_thermalfist.py <table> [--min-rows N] [--min-cols N]
  check_output_thermalfist.py <table> --reference <ref> [--accuracy A]
  check_output_thermalfist.py <table> --row-at COL VAL --expect C1 V1 [C2 V2 ...] [--accuracy A]

Exit 0 on success, 1 on any failure.
"""
import argparse
import math
import sys


def is_number(tok):
    try:
        float(tok)
        return True
    except ValueError:
        return False


def load_table(path):
    """Return (header_line, list_of_numeric_rows, ncols).

    Each row is the list of its NUMERIC columns. Some Thermal-FIST tables carry
    leading LABEL columns (cpc3 writes a `Dataset` name like `NA49-30GeV-4pi`
    first, then nine numbers); those leading non-numeric tokens are stripped and
    the count of them must be consistent across rows. Everything AFTER the first
    numeric token must itself be numeric and finite, or the row is malformed (a
    label appearing mid-row is a real defect, not a label column).

    Raises ValueError with a specific message on the first malformed row.
    """
    with open(path) as fh:
        lines = [ln.rstrip('\n') for ln in fh]
    if not lines:
        raise ValueError("file is empty")
    # Header: the first line. It may or may not start with '#'. Either way it is
    # not a data row (the code writes a named-column header first).
    header = lines[0]
    rows = []
    ncols = None
    nlabels = None
    for i, ln in enumerate(lines[1:], start=2):
        s = ln.strip()
        if not s:
            continue
        if s.startswith('#'):
            # Comment lines inside the body are tolerated but not counted.
            continue
        toks = s.split()
        # Count the leading label (non-numeric) tokens.
        lbl = 0
        while lbl < len(toks) and not is_number(toks[lbl]):
            lbl += 1
        nums = toks[lbl:]
        if not nums:
            raise ValueError(f"line {i} has no numeric column: {s[:80]!r}")
        if not all(is_number(t) for t in nums):
            raise ValueError(f"line {i} has a non-numeric token after a number "
                             f"(a label column must be leading): {s[:80]!r}")
        vals = [float(t) for t in nums]
        for v in vals:
            if not math.isfinite(v):
                raise ValueError(f"line {i} contains a non-finite value: {s[:80]!r}")
        if ncols is None:
            ncols, nlabels = len(vals), lbl
        else:
            if len(vals) != ncols:
                raise ValueError(f"line {i} has {len(vals)} numeric columns, expected {ncols}")
            if lbl != nlabels:
                raise ValueError(f"line {i} has {lbl} label columns, expected {nlabels}")
        rows.append(vals)
    return header, rows, (ncols or 0)


def cmp_reference(path, ref, accuracy):
    """Reproduce test_CompareOutputs.cpp: skip headers, abs-compare all numbers."""
    _, a, na = load_table(path)
    _, b, nb = load_table(ref)
    if len(a) != len(b):
        print(f"FAIL: {path} has {len(a)} rows, reference {ref} has {len(b)}")
        return 1
    if na != nb:
        print(f"FAIL: {path} has {na} columns, reference {ref} has {nb}")
        return 1
    worst = 0.0
    for r, (ra, rb) in enumerate(zip(a, b), start=1):
        for c, (x, y) in enumerate(zip(ra, rb)):
            d = abs(x - y)
            if d > worst:
                worst = d
            if d > accuracy:
                print(f"FAIL: row {r} col {c}: {x} vs {y}, |diff|={d:.3e} > {accuracy:.3e}")
                return 1
    print(f"reference match: {len(a)} rows x {na} cols, worst |diff| = {worst:.3e} <= {accuracy:.3e}")
    return 0


def check_row_at(path, col_idx, col_val, expects, accuracy):
    """Find the data row whose column col_idx equals col_val, check other columns."""
    _, rows, ncols = load_table(path)
    if col_idx >= ncols:
        print(f"FAIL: --row-at column {col_idx} out of range (table has {ncols} columns)")
        return 1
    match = None
    for row in rows:
        if abs(row[col_idx] - col_val) <= 1e-6:
            match = row
            break
    if match is None:
        print(f"FAIL: no row with column {col_idx} == {col_val}")
        return 1
    ok = True
    for ci, ev in expects:
        if ci >= ncols:
            print(f"FAIL: expected column {ci} out of range (table has {ncols} columns)")
            return 1
        d = abs(match[ci] - ev)
        rel = d / abs(ev) if ev != 0 else d
        status = "ok" if d <= accuracy else "MISMATCH"
        print(f"  col {ci}: got {match[ci]:.6g}, expected {ev:.6g}, |diff|={d:.3e} ({status})")
        if d > accuracy:
            ok = False
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('table')
    ap.add_argument('--min-rows', type=int, default=1)
    ap.add_argument('--min-cols', type=int, default=1)
    ap.add_argument('--reference')
    ap.add_argument('--accuracy', type=float, default=1e-6)
    ap.add_argument('--row-at', nargs=2, metavar=('COL', 'VAL'),
                    help='column index and value identifying one row')
    ap.add_argument('--expect', nargs='+', metavar='COL VAL',
                    help='pairs of column-index expected-value to check in that row')
    args = ap.parse_args()

    if args.min_rows < 0 or args.min_cols < 0:
        print("FAIL: --min-rows and --min-cols must be non-negative")
        return 1
    if args.accuracy <= 0:
        print("FAIL: --accuracy must be positive")
        return 1

    # Structural validation always runs first.
    try:
        header, rows, ncols = load_table(args.table)
    except (OSError, ValueError) as exc:
        print(f"FAIL: {args.table}: {exc}")
        return 1
    if len(rows) < args.min_rows:
        print(f"FAIL: {args.table} has {len(rows)} data rows, expected at least {args.min_rows}")
        return 1
    if ncols < args.min_cols:
        print(f"FAIL: {args.table} has {ncols} columns, expected at least {args.min_cols}")
        return 1
    print(f"table OK: {len(rows)} data rows, {ncols} columns")

    if args.reference:
        try:
            return cmp_reference(args.table, args.reference, args.accuracy)
        except (OSError, ValueError) as exc:
            print(f"FAIL: comparing to {args.reference}: {exc}")
            return 1

    if args.row_at:
        try:
            col_idx = int(args.row_at[0])
            col_val = float(args.row_at[1])
        except ValueError:
            print(f"FAIL: --row-at needs an integer column and a numeric value, got {args.row_at}")
            return 1
        if not args.expect or len(args.expect) % 2 != 0:
            print("FAIL: --expect needs an even number of COL VAL arguments")
            return 1
        expects = []
        for i in range(0, len(args.expect), 2):
            try:
                expects.append((int(args.expect[i]), float(args.expect[i + 1])))
            except ValueError:
                print(f"FAIL: --expect pair {args.expect[i]} {args.expect[i+1]} is not COL(int) VAL(num)")
                return 1
        return check_row_at(args.table, col_idx, col_val, expects, args.accuracy)

    return 0


if __name__ == '__main__':
    sys.exit(main())

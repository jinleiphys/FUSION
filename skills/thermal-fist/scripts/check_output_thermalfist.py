#!/usr/bin/env python3
"""Validate a Thermal-FIST output table, and optionally compare it to a reference.

Thermal-FIST's cpc/EoS example programs write whitespace-delimited tables whose
FIRST line is a NAMED header (e.g. `T[MeV] p/T^4 e/T^4 ...`) and whose remaining
lines are data. This checker enforces the shape a usable output must have,
independent of the build:

  * the file is non-empty and its first line is a real header (it carries at
    least one non-numeric token, so a headerless or truncated dump is rejected);
  * every data row parses with a CONSISTENT count of numeric columns, and a
    CONSISTENT count of leading LABEL columns (cpc3 writes a `Dataset` name like
    `NA49-30GeV-4pi` first, then numbers). A non-numeric token AFTER a number is a
    real defect, not a label column;
  * no numeric value is NaN or +-Inf;
  * at least --min-rows data rows and --min-cols numeric columns are present.

With --reference it reproduces the semantics of the code's own comparator
(test/test_CompareOutputs.cpp), but STRICTER: it also requires the leading label
tokens to match, so a fit result cannot be silently associated with the wrong
dataset. Skip the header of both files, then compare every numeric column with an
ABSOLUTE tolerance and require the same label text, column count and row count.

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
    """Return (header_line, rows, ncols, nlabels, labels).

    rows[i]   = list of the NUMERIC columns of data row i (floats).
    labels[i] = list of the leading LABEL tokens of data row i (strings).
    ncols     = numeric column count (consistent across rows).
    nlabels   = label column count (consistent across rows).

    Raises ValueError with a specific message on the first malformed line.
    """
    with open(path) as fh:
        lines = [ln.rstrip('\n') for ln in fh]
    if not lines:
        raise ValueError("file is empty")
    header = lines[0]
    # A real Thermal-FIST table opens with a NAMED header. If the first line is
    # all-numeric it is not a header, which means the file is headerless or the
    # run was truncated before the header was written.
    htoks = header.strip().lstrip('#').split()
    if not htoks or all(is_number(t) for t in htoks):
        raise ValueError(f"first line is not a named header: {header.strip()[:80]!r}")

    rows, labels = [], []
    ncols = None
    nlabels = None
    for i, ln in enumerate(lines[1:], start=2):
        s = ln.strip()
        if not s or s.startswith('#'):
            continue
        toks = s.split()
        lbl = 0
        while lbl < len(toks) and not is_number(toks[lbl]):
            lbl += 1
        lbltoks = toks[:lbl]
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
        labels.append(lbltoks)
    return header, rows, (ncols or 0), (nlabels or 0), labels


def cmp_reference(path, ref, accuracy):
    """Stricter than test_CompareOutputs: header, numbers AND label text match."""
    ha, a, na, la, alab = load_table(path)
    hb, b, nb, lb, blab = load_table(ref)
    # The header names the columns; a run that produced a DIFFERENT header (wrong
    # columns) with the same numbers must not match. Compare it tokenized so pure
    # whitespace differences are ignored.
    if ha.split() != hb.split():
        print(f"FAIL: header {ha.strip()[:80]!r} != reference header {hb.strip()[:80]!r}")
        return 1
    if len(a) != len(b):
        print(f"FAIL: {path} has {len(a)} rows, reference {ref} has {len(b)}")
        return 1
    if na != nb:
        print(f"FAIL: {path} has {na} numeric columns, reference {ref} has {nb}")
        return 1
    if la != lb:
        print(f"FAIL: {path} has {la} label columns, reference {ref} has {lb}")
        return 1
    worst = 0.0
    for r, (ra, rb, lra, lrb) in enumerate(zip(a, b, alab, blab), start=1):
        if lra != lrb:
            print(f"FAIL: row {r} label {lra} != reference label {lrb}")
            return 1
        for c, (x, y) in enumerate(zip(ra, rb)):
            d = abs(x - y)
            if d > worst:
                worst = d
            if d > accuracy:
                print(f"FAIL: row {r} col {c}: {x} vs {y}, |diff|={d:.3e} > {accuracy:.3e}")
                return 1
    print(f"reference match: {len(a)} rows x {na} cols ({la} label col), worst |diff| = {worst:.3e} <= {accuracy:.3e}")
    return 0


def check_row_at(path, col_idx, col_val, expects, accuracy):
    """Find the data row whose numeric column col_idx equals col_val, check others."""
    _, rows, ncols, _, _ = load_table(path)
    if col_idx >= ncols:
        print(f"FAIL: --row-at column {col_idx} out of range (table has {ncols} numeric columns)")
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
            print(f"FAIL: expected column {ci} out of range (table has {ncols} numeric columns)")
            return 1
        d = abs(match[ci] - ev)
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
                    help='numeric column index and value identifying one row')
    ap.add_argument('--expect', nargs='+', metavar='COL VAL',
                    help='pairs of numeric-column-index expected-value to check in that row')
    args = ap.parse_args()

    if args.min_rows < 0 or args.min_cols < 0:
        print("FAIL: --min-rows and --min-cols must be non-negative")
        return 1
    # An accuracy that is NaN or non-positive makes every |diff| comparison
    # vacuously pass (d > nan and d <= nan are both false), so a broken run would
    # certify. Require a finite, positive tolerance.
    if not math.isfinite(args.accuracy) or args.accuracy <= 0:
        print(f"FAIL: --accuracy must be a finite positive number, got {args.accuracy}")
        return 1

    try:
        _header, rows, ncols, _nlabels, _labels = load_table(args.table)
    except (OSError, ValueError) as exc:
        print(f"FAIL: {args.table}: {exc}")
        return 1
    if len(rows) < args.min_rows:
        print(f"FAIL: {args.table} has {len(rows)} data rows, expected at least {args.min_rows}")
        return 1
    if ncols < args.min_cols:
        print(f"FAIL: {args.table} has {ncols} numeric columns, expected at least {args.min_cols}")
        return 1
    print(f"table OK: {len(rows)} data rows, {ncols} numeric columns")

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
        if col_idx < 0:
            print(f"FAIL: --row-at column must be non-negative, got {col_idx}")
            return 1
        if not math.isfinite(col_val):
            print(f"FAIL: --row-at value must be finite, got {col_val}")
            return 1
        if not args.expect or len(args.expect) % 2 != 0:
            print("FAIL: --expect needs an even number of COL VAL arguments")
            return 1
        expects = []
        for i in range(0, len(args.expect), 2):
            try:
                ci, ev = int(args.expect[i]), float(args.expect[i + 1])
            except ValueError:
                print(f"FAIL: --expect pair {args.expect[i]} {args.expect[i+1]} is not COL(int) VAL(num)")
                return 1
            if ci < 0:
                print(f"FAIL: --expect column must be non-negative, got {ci}")
                return 1
            if not math.isfinite(ev):
                print(f"FAIL: --expect value must be finite, got {ev}")
                return 1
            expects.append((ci, ev))
        return check_row_at(args.table, col_idx, col_val, expects, args.accuracy)

    return 0


if __name__ == '__main__':
    sys.exit(main())

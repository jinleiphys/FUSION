#!/usr/bin/env python3
"""Parse and check GiBUU's pion-induced cross-section table.

This is the single place that knows the column layout of
`pionInduced_xSections.dat`, so run_gibuu.sh and verify_gibuu.sh do not each
re-derive it in shell and then disagree.

THE COLUMN LAYOUT IS NOT THE ONE THE HEADER SUGGESTS AT FIRST READING, and
getting it wrong is easy because the file's own header is written by a
different branch than the row. From code/analysis/LoPionAnalysis.f90 the row
that this parser reads is the `write(140,'(20G12.4)')` at line 358:

    1  elab                    getEKin()
    2  Sigma piMinus           sigma_QE(-1)
    3  Sigma piNull            sigma_QE(0)
    4  Sigma piPlus            sigma_QE(+1)
    5  Sigma_QElastic          sum(sigma_QE)
    6  absorption_xSection     absorption_xSection
    7  sigma Total             sigTot = sum(sigma_QE) + absorption_xSection
    8  sigma Total(check)      sigmaTotalSave
    9  absorption Events       absEvents            (integer)
    10 number of runs          numberRuns           (integer)
    11-13 error of quasiElastic(-1:1)
    14 error of absorption_xSection
    15 error of sigma Total

WHAT COLUMNS 7 AND 8 ARE WORTH. They are two routes to the same total, and it
is tempting to read their agreement as an independent physics identity in the
way SIDES uses the optical theorem. It is not. Tracing the source:

    sigma_Absorption = totalPerweight - (perweight of ALL escaping pions)
    sigmaTotal       = totalPerweight - (perweight of NON-INTERACTING pions)
    sigTot           = sum(sigma_QE) + absorption

and since the quasi-elastic set is exactly "escaped after interacting", the two
are set complements of each other and agree BY CONSTRUCTION. The identity
therefore catches a lost or double-counted event and nothing else. It would
hold with the physics completely wrong. It is checked because a bookkeeping
check is worth having, and it is labelled honestly because pretending it is a
physics validation is how a skill ends up overclaiming.

A related trap, worth knowing before quoting any single column: with modest
statistics `absorption_xSection` comes out NEGATIVE (measured: -8153 mb at one
run, -8530 at five). That is not a bug, it follows from the definition above,
and it means the individual columns are meaningful only in combination. Do not
quote column 6 as a cross section.
"""
import argparse
import math
import sys

N_COLUMNS = 15
I_ELAB, I_PIM, I_PI0, I_PIP, I_QESUM, I_ABS, I_TOTAL, I_CHECK = 0, 1, 2, 3, 4, 5, 6, 7
# A total below this (in mb) is numerically zero, not a small cross section. The
# pion-absorption card produces totals like -3.7e-11, and an identity check on
# two numerically-zero routes is vacuous. Measured cross sections in this file
# are hundreds to thousands of mb, so the floor cannot reject a real result.
ZERO_FLOOR = 1e-6


def read_rows(path):
    """Return ALL data rows as lists of floats, or (None, message).

    The earlier version read only the last row, so a corrupted earlier row (a
    different energy point, or a truncated line) was never seen. GiBUU appends
    one row per energy, and every one must be well formed.
    """
    try:
        with open(path) as fh:
            lines = [ln for ln in fh if ln.strip() and not ln.lstrip().startswith('#')]
    except OSError as exc:
        return None, f"cannot read {path}: {exc}"
    if not lines:
        return None, f"{path} has a header but no data row"
    rows = []
    for ln in lines:
        fields = ln.split()
        if len(fields) != N_COLUMNS:
            return None, (f"{path} has a row with {len(fields)} columns, expected {N_COLUMNS}; "
                          f"the output format changed and this parser would silently "
                          f"read the wrong quantities: {ln.strip()[:90]!r}")
        try:
            row = [float(f) for f in fields]
        except ValueError:
            return None, f"{path} has a non-numeric field in a data row: {ln.strip()[:90]!r}"
        for i, v in enumerate(row):
            if not math.isfinite(v):
                return None, f"{path} column {i + 1} is not finite: {v}"
        rows.append(row)
    return rows, None


def close(a, b, tol):
    scale = max(abs(a), abs(b), 1e-30)
    return abs(a - b) / scale <= tol


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('datfile')
    ap.add_argument('--expect-elab', type=float)
    ap.add_argument('--expect-qe', type=float)
    ap.add_argument('--expect-total', type=float)
    ap.add_argument('--tolerance', type=float, default=1e-3,
                    help='relative tolerance. The file is written with G12.4, so about four '
                         'significant digits survive; a tolerance far below 1e-4 would be '
                         'testing the print format rather than the result.')
    ap.add_argument('--identity-only', action='store_true',
                    help='check only the column 7 / column 8 bookkeeping identity')
    args = ap.parse_args()

    if args.tolerance <= 0:
        print("FAIL: --tolerance must be positive")
        return 1

    rows, err = read_rows(args.datfile)
    if rows is None:
        print(f"FAIL: {err}")
        return 1

    ok = True
    # Structural checks apply to EVERY row; the pinned-value checks only to the
    # last one (single-energy cards write exactly one row, and for a multi-energy
    # card the caller pins a specific expectation, not all of them).
    for r, row in enumerate(rows):
        total, check = row[I_TOTAL], row[I_CHECK]
        label = "" if len(rows) == 1 else f" (row {r + 1})"

        # Vacuity: two numerically-zero totals make the identity meaningless, so
        # it must not pass on them. A hard exact-zero test missed -3.7e-11.
        if max(abs(total), abs(check)) < ZERO_FLOOR:
            print(f"FAIL: both total columns are ~0{label} ({total:g}, {check:g}), so the "
                  f"identity check would be vacuous")
            ok = False
            continue

        if close(total, check, args.tolerance):
            if not args.identity_only or r == len(rows) - 1:
                print(f"  bookkeeping identity holds{label}: sigma Total = {total:g}, "
                      f"sigma Total(check) = {check:g} (agree to {args.tolerance:g} relative)")
        else:
            print(f"FAIL: the two totals disagree{label}: {total:g} vs {check:g}; "
                  f"events are being lost or double counted")
            ok = False

        # Two sum rules the row is built from, both cheap, both catching a
        # column shift the identity above would survive. Column 5 is the sum of
        # the three pion channels, and column 7 is column 5 plus column 6.
        if not close(row[I_PIM] + row[I_PI0] + row[I_PIP], row[I_QESUM], args.tolerance):
            print(f"FAIL: columns 2+3+4 = {row[I_PIM] + row[I_PI0] + row[I_PIP]:g} does not "
                  f"equal Sigma_QElastic (column 5) = {row[I_QESUM]:g}{label}; the columns are "
                  f"not the ones this parser expects")
            ok = False
        if not close(row[I_QESUM] + row[I_ABS], total, args.tolerance):
            print(f"FAIL: column 5 + column 6 = {row[I_QESUM] + row[I_ABS]:g} does not equal "
                  f"column 7 = {total:g}{label}; the columns are not the ones this parser expects")
            ok = False

    if ok:
        print("    NB the identity is true by construction, see the module docstring; it catches a "
              "lost or double-counted event, not wrong physics")

    if not args.identity_only:
        last = rows[-1]
        for name, idx, want in (('elab', I_ELAB, args.expect_elab),
                                ('Sigma_QElastic', I_QESUM, args.expect_qe),
                                ('sigma Total', I_TOTAL, args.expect_total)):
            if want is None:
                continue
            if close(last[idx], want, args.tolerance):
                print(f"  {name}: {last[idx]:g} matches the pinned {want:g}")
            else:
                print(f"FAIL: {name} is {last[idx]:g}, pinned value is {want:g} "
                      f"(relative tolerance {args.tolerance:g})")
                ok = False

    if ok:
        print("OUTPUT OK")
        return 0
    print("OUTPUT FAILED")
    return 1


if __name__ == '__main__':
    sys.exit(main())

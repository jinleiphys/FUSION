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
I_ELAB, I_QESUM, I_ABS, I_TOTAL, I_CHECK = 0, 4, 5, 6, 7


def read_row(path):
    """Return the single data row as floats, or (None, message)."""
    try:
        with open(path) as fh:
            lines = [ln for ln in fh if ln.strip() and not ln.lstrip().startswith('#')]
    except OSError as exc:
        return None, f"cannot read {path}: {exc}"
    if not lines:
        return None, f"{path} has a header but no data row"
    fields = lines[-1].split()
    if len(fields) != N_COLUMNS:
        return None, (f"{path} has {len(fields)} columns, expected {N_COLUMNS}; "
                      f"the output format changed and this parser would silently "
                      f"read the wrong quantities")
    try:
        row = [float(f) for f in fields]
    except ValueError:
        return None, f"{path} has a non-numeric field in its data row: {lines[-1].strip()[:90]!r}"
    for i, v in enumerate(row):
        if not math.isfinite(v):
            return None, f"{path} column {i + 1} is not finite: {v}"
    return row, None


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

    row, err = read_row(args.datfile)
    if row is None:
        print(f"FAIL: {err}")
        return 1

    ok = True
    total, check = row[I_TOTAL], row[I_CHECK]
    # Guard the guard: if BOTH routes are zero the comparison below is vacuous.
    if total == 0.0 and check == 0.0:
        print("FAIL: both total columns are zero, so the identity check would pass vacuously")
        return 1
    if close(total, check, args.tolerance):
        print(f"  bookkeeping identity holds: sigma Total = {total:g}, "
              f"sigma Total(check) = {check:g} (agree to {args.tolerance:g} relative)")
        print("    NB this is true by construction, see the module docstring; it catches a "
              "lost or double-counted event, not wrong physics")
    else:
        print(f"FAIL: the two totals disagree: {total:g} vs {check:g}; "
              f"events are being lost or double counted")
        ok = False

    if not args.identity_only:
        # The sum rule the row is built from. Cheap, and it catches a column
        # shift that the identity above would survive.
        if not close(row[I_QESUM] + row[I_ABS], total, args.tolerance):
            print(f"FAIL: column 5 + column 6 = {row[I_QESUM] + row[I_ABS]:g} does not equal "
                  f"column 7 = {total:g}; the columns are not the ones this parser expects")
            ok = False
        for name, idx, want in (('elab', I_ELAB, args.expect_elab),
                                ('Sigma_QElastic', I_QESUM, args.expect_qe),
                                ('sigma Total', I_TOTAL, args.expect_total)):
            if want is None:
                continue
            if close(row[idx], want, args.tolerance):
                print(f"  {name}: {row[idx]:g} matches the pinned {want:g}")
            else:
                print(f"FAIL: {name} is {row[idx]:g}, pinned value is {want:g} "
                      f"(relative tolerance {args.tolerance:g})")
                ok = False

    if ok:
        print("OUTPUT OK")
        return 0
    print("OUTPUT FAILED")
    return 1


if __name__ == '__main__':
    sys.exit(main())

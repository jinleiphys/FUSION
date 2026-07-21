#!/usr/bin/env python3
"""check_pikoe.py <case> <case-dir>

Extract the anchor quantities from one pikoe run and compare them against the
pinned values recorded in references/verification.md.

The pins are NOT distributed reference output: pikoe ships none (see
failure-modes.md item 7). They are values established in a clean-room run and
cross-checked against the published figures of the CPC paper, so this script is
a regression check plus a coarse physics check, and it says so rather than
implying a reference comparison it cannot make.

Exit status 0 if every anchor is within tolerance, 1 otherwise.
"""
import glob
import os
import re
import sys

# case -> (glob for the table, list of anchors)
# Each anchor: (label, extractor, expected, relative tolerance)
RTOL = 0.01

# Sentinel: the case ran and was parsed, but no pin exists to compare against.
SKIPPED = "SKIPPED"


NCOL = 13  # t1l th1l ph1l t2l th2l ph2l pbl thbl phbl pr isol obs Ay


class TableError(Exception):
    pass


def read_table(path, ncol=NCOL, infer_ncol=False):
    """Parse a pikoe TDX/QDX table strictly.

    Strictness is the point. An earlier version skipped any line it could not
    parse, so a table full of Fortran '***' overflow markers, or a run truncated
    mid-write, still passed every anchor. A malformed row is now a failure.
    """
    rows = []
    with open(path) as fh:
        header = fh.readline()
        if not header.strip():
            raise TableError("%s: empty file" % path)
        for lineno, line in enumerate(fh, start=2):
            parts = line.split()
            if not parts:
                continue
            if infer_ncol and ncol is None:
                ncol = len(parts)
            if len(parts) != ncol:
                raise TableError("%s line %d: %d fields, expected %d"
                                 % (path, lineno, len(parts), ncol))
            try:
                vals = [float(p) for p in parts]
            except ValueError:
                raise TableError("%s line %d: unparseable value in %r"
                                 % (path, lineno, line.strip()))
            for v in vals:
                if v != v or v in (float("inf"), float("-inf")):
                    raise TableError("%s line %d: non-finite value" % (path, lineno))
            rows.append(vals)
    if not rows:
        raise TableError("%s: header only, no data rows" % path)
    return rows


def outlist_value(case_dir, pattern):
    for path in glob.glob(os.path.join(case_dir, "*.outlist")):
        with open(path) as fh:
            text = fh.read()
        m = re.search(pattern, text)
        if m:
            return float(m.group(1))
    return None


def _window(rows, xcol, lo, hi, sel):
    sub = rows
    if sel is not None:
        sub = [r for r in sub if sel(r)]
    if lo is not None:
        sub = [r for r in sub if r[xcol] >= lo]
    if hi is not None:
        sub = [r for r in sub if r[xcol] <= hi]
    return sorted(sub, key=lambda r: r[xcol])


def _extremum(rows, xcol, ycol, lo, hi, sel, want_max, interior):
    """Return (x, y) of the window extremum.

    `interior` demands a genuine local extremum: the point must not sit on the
    window edge. Without it these helpers report the endpoint of a monotone
    stretch while the label still says "peak" or "dip", which is a label that
    lies whenever the physics changes.
    """
    sub = _window(rows, xcol, lo, hi, sel)
    if not sub:
        return None
    pick = max if want_max else min
    best = pick(sub, key=lambda r: r[ycol])
    if interior and len(sub) > 2 and best in (sub[0], sub[-1]):
        return None
    return best[xcol], best[ycol]


def peak(rows, xcol, ycol, lo=None, hi=None, sel=None, interior=False):
    return _extremum(rows, xcol, ycol, lo, hi, sel, True, interior)


def trough(rows, xcol, ycol, lo, hi, interior=False):
    return _extremum(rows, xcol, ycol, lo, hi, None, False, interior)


def check(case, case_dir):
    # Column indices of the TDX/QDX table, zero-based:
    # 0 t1l 1 th1l 2 ph1l 3 t2l 4 th2l 5 ph2l 6 pbl 7 thbl 8 phbl 9 pr
    # 10 isol 11 tdx-or-qdx 12 Ay
    TH2, T2, ISOL, OBS = 4, 3, 10, 11
    results = []

    if case == "TDXnorm":
        tbl = glob.glob(os.path.join(case_dir, "tbl_*TDXnorm.dat"))
        if not tbl:
            return [("table present", "missing", "tbl_*TDXnorm.dat", False)]
        rows = read_table(tbl[0])
        depth = outlist_value(case_dir, r"central potential depth\s*:\s*([-\d.]+)")
        # Anchor to the heading. A bare "([\d.]+) ub" matched the first such
        # text anywhere in the file and could not span an exponent, so an
        # output written as 1.234E+02 ub would have been read as 1.234.
        integ = outlist_value(
            case_dir,
            r"integrated value of the calculated TDX\s*--\s*([-\d.eEdD+]+)\s*(?:ub|mb)")
        p1 = peak(rows, TH2, OBS, 20, 52, interior=True)
        dip = trough(rows, TH2, OBS, 45, 60, interior=True)
        p2 = peak(rows, TH2, OBS, 52, 80, interior=True)
        results = [
            ("s.p. central depth [MeV]", depth, 54.34231, RTOL),
            ("integrated TDX [ub]", integ, 23.44, RTOL),
            ("first peak theta2 [deg]", p1[0] if p1 else None, 40.5, RTOL),
            ("first peak TDX", p1[1] if p1 else None, 127.03, RTOL),
            ("dip theta2 [deg]", dip[0] if dip else None, 50.5, RTOL),
            ("dip TDX", dip[1] if dip else None, 8.0529, RTOL),
            ("second peak theta2 [deg]", p2[0] if p2 else None, 61.0, RTOL),
            ("second peak TDX", p2[1] if p2 else None, 128.32, RTOL),
        ]

    elif case == "TDXinv":
        tbl = glob.glob(os.path.join(case_dir, "tbl_*TDXinv.dat"))
        if not tbl:
            return [("table present", "missing", "tbl_*TDXinv.dat", False)]
        rows = read_table(tbl[0])
        b1 = peak(rows, TH2, OBS, sel=lambda r: int(r[ISOL]) == 1)
        b2 = peak(rows, TH2, OBS, sel=lambda r: int(r[ISOL]) == 2)
        results = [
            ("isol=1 max theta2 [deg]", b1[0] if b1 else None, 31.50, RTOL),
            ("isol=1 max TDX", b1[1] if b1 else None, 1049.2, RTOL),
            ("isol=2 max theta2 [deg]", b2[0] if b2 else None, 32.25, RTOL),
            ("isol=2 max TDX", b2[1] if b2 else None, 1421.6, RTOL),
        ]

    elif case == "QDXinv":
        tbl = glob.glob(os.path.join(case_dir, "tbl_*QDXinv.dat"))
        if not tbl:
            return [("table present", "missing", "tbl_*QDXinv.dat", False)]
        rows = read_table(tbl[0])
        # The split at 250 MeV must not be inclusive on both sides, or a
        # maximum sitting exactly at the boundary is reported as both peaks.
        lo = peak(rows, T2, OBS, hi=250, interior=True)
        hi = peak(rows, T2, OBS, lo=250.0001, interior=True)
        results = [
            ("low-T2 peak T2 [MeV]", lo[0] if lo else None, 185.0, RTOL),
            ("low-T2 peak QDX", lo[1] if lo else None, 0.18147, RTOL),
            ("high-T2 peak T2 [MeV]", hi[0] if hi else None, 325.0, RTOL),
            ("high-T2 peak QDX", hi[1] if hi else None, 0.17408, RTOL),
        ]

    elif case in ("MD", "MD100"):
        tag = "MD100" if case == "MD100" else "MD"
        lg = [p for p in glob.glob(os.path.join(case_dir, "LG_*.dat"))
              if (tag == "MD100") == ("100" in os.path.basename(p))]
        if not lg:
            return [("LG file present", "missing", "LG_*.dat", False)]
        rows = read_table(lg[0], ncol=None, infer_ncol=True)
        # LG file: column 0 is the longitudinal momentum, column 1 the
        # distribution. The peak POSITION is a poor anchor here because the
        # distribution has a flat top (three grid points sit within 1 percent of
        # the maximum at 100A MeV), so the argmax can hop between them under a
        # different compiler. Pin the peak value and the centroid, which is
        # stable and also carries the physics point of these figures: the low
        # incident-energy distribution is asymmetric.
        p = peak(rows, 0, 1)
        total = sum(r[1] for r in rows)
        centroid = sum(r[0] * r[1] for r in rows) / total if total else None
        if case not in MD_PINS:
            # No pin recorded yet. Report the measurement and signal SKIPPED,
            # rather than inventing an expected value (a pin read off a printed
            # figure by eye is not a verification anchor) and rather than
            # returning success, which would let `verify_pikoe.sh MD` print
            # VERIFY OK having checked nothing at all.
            print("  %s: LG peak %s (no pin recorded)" % (case, p))
            return SKIPPED
        expected = MD_PINS[case]
        results = [
            ("LG peak value", p[1] if p else None, expected[0], RTOL),
            ("LG centroid [MeV/c]", centroid, expected[1], 0.02),
            ("LG sum over grid", total, expected[2], RTOL),
        ]

    else:
        print("unknown case: %s" % case, file=sys.stderr)
        return None

    return results


# Pins for the momentum-distribution cases, as
# (LG peak value, LG centroid in MeV/c, sum of the LG distribution over the grid).
# An entry here must come from a measured run, never from reading the paper's
# figures. Both were measured to completion in a clean room.
MD_PINS = {
    "MD": (39.316, -24.0854, 908.544),
    "MD100": (36.724, -63.9691, 905.855),
}


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    case, case_dir = sys.argv[1], sys.argv[2]
    try:
        results = check(case, case_dir)
    except TableError as exc:
        print("  MALFORMED OUTPUT: %s" % exc)
        return 1
    except (IndexError, OSError) as exc:
        print("  CHECK FAILED: %s" % exc)
        return 1
    if results is None:
        return 2
    if results is SKIPPED:
        return 3

    ok = True
    print("  %-28s %14s %14s %9s" % ("anchor", "got", "pinned", "reldiff"))
    for label, got, expected, tol in results:
        if not isinstance(got, float):
            print("  %-28s %14s %14s   FAIL" % (label, got, expected))
            ok = False
            continue
        if expected == 0:
            rel = abs(got)
        else:
            rel = abs(got - expected) / abs(expected)
        flag = "ok" if rel <= tol else "FAIL"
        if flag == "FAIL":
            ok = False
        print("  %-28s %14.5g %14.5g %8.2f%% %s"
              % (label, got, expected, 100 * rel, flag))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

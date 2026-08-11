#!/usr/bin/env python3
"""fitreport.py <run.log> [--dat PREFIX]

Summarize an SFRESCO run: chi2 before and after, fitted parameters with their
MINUIT errors, the error-matrix status, the correlation matrix, and warnings
about the two things that silently invalidate a fit (approximate error matrix,
near-degenerate parameters).

With --dat PREFIX and a search.plot file, also split the plot file into plain
columns for plotting: PREFIX-<n>-data.dat (x, y, dy) and PREFIX-<n>-theory.dat
(x, y) per dataset. Feed those to the nature-figure skill; do not plot here.

Standard library only.
"""

import argparse
import re
import sys

CORR_WARN = 0.95
# FRESCO interleaves its own progress lines into MINUIT's output, so a block
# ends at the first line that is clearly not part of the table.
STOP = r"minuit>|AMM:|\*\*\*|^\s*$"


def tail_block(lines, header_re, stop_re=STOP):
    """Return the last block starting at header_re and ending before stop_re."""
    start = None
    for i, ln in enumerate(lines):
        if re.search(header_re, ln):
            start = i
    if start is None:
        return []
    out = [lines[start]]
    for ln in lines[start + 1:]:
        if re.search(stop_re, ln):
            break
        out.append(ln)
    return out


def report(path):
    lines = open(path, errors="replace").read().splitlines()

    deck = next((ln.split("=", 1)[1].strip() for ln in lines
                 if "Fresco input file" in ln), "?")
    search = next((ln.split("=", 1)[1].strip() for ln in lines
                   if "search file" in ln.lower() and "=" in ln), "?")
    npts = [int(m.group(1)) for ln in lines
            if (m := re.search(r"(\d+)\s+data points", ln))]

    chis = [float(m.group(1)) for ln in lines
            if (m := re.search(r"ChiSq/N\s*=\s*([-\d.Ee+]+)", ln))]

    print(f"search file : {search}")
    print(f"fresco deck : {deck}")
    if npts:
        print(f"data points : {sum(npts)}  ({' + '.join(map(str, npts))})"
              "   [chi2/N is per point, not per degree of freedom]")
    if chis:
        print(f"chi2/N      : {chis[0]:.4f} (start)  ->  {chis[-1]:.4f} (last in log;"
              " end the session with `show` or `plot` so this is the fitted value)")

    # Final parameter values as SFRESCO itself reports them (the Q command).
    qblock = []
    for ln in lines:
        if re.search(r"Var\s+\d+=", ln):
            if qblock and re.search(r"Var\s+1=", ln):
                qblock = []
            qblock.append(re.sub(r"^\s*sfresco>\s*", "", ln).rstrip())
    if qblock:
        print("\nparameters at the last Q command"
              " (put `q` AFTER `end`, or these are the starting values):")
        for ln in qblock:
            print("  " + ln.strip())

    # MINUIT's own final table, verbatim (includes MINOS errors when run).
    ext = tail_block(lines, r"EXT PARAMETER")
    if ext:
        print("\nMINUIT final table:")
        for ln in ext:
            print("  " + ln.rstrip())

    # MINUIT's verdict on the covariance: ACCURATE, APPROXIMATE, NOT POS-DEF,
    # FORCED POS-DEF, or NO ERROR MATRIX when nothing computed one. Skip the
    # "EXTERNAL ERROR MATRIX. NDIM=" table header.
    status = [ln.strip() for ln in lines
              if re.search(r"(ERR|ERROR) MATRIX +(ACCURATE|APPROXIMATE"
                           r"|NOT POS-DEF|UNCERTAINTY)|MATRIX FORCED POS-DEF"
                           r"|NO ERROR MATRIX", ln)]
    advice = ("  WARNING: errors are not trustworthy. In MINUIT run"
              " `set strategy 2`, `migrad`, then `hesse`"
              " (and `minos` for asymmetric errors).")
    if status:
        print(f"\nerror matrix: {status[-1]}")
        if "ACCURATE" not in status[-1].upper():
            print(advice)
    else:
        print("\nerror matrix: none reported (no MIGRAD or HESSE in this session)")
        print(advice)

    corr = tail_block(lines, r"CORRELATION COEFFICIENTS")
    if corr:
        print("\ncorrelations:")
        worst = 0.0
        for ln in corr:
            print("  " + ln.rstrip())
            # Matrix rows look like: "  1  0.94939  1.000-0.921 0.055-0.198".
            # First number is the row index, second the global correlation, then
            # the row itself; entry k of row i is the diagonal when k == i.
            row = re.match(r"\s*(\d+)\s+(-?\d\.\d+)((?:\s*-?\d\.\d+)+)\s*$", ln)
            if not row:
                continue
            i = int(row.group(1))
            entries = re.findall(r"-?\d\.\d+", row.group(3))
            for k, v in enumerate(entries, start=1):
                if k != i:                      # skip the diagonal, not |rho|=1
                    worst = max(worst, abs(float(v)))
        if worst >= CORR_WARN:
            print(f"  WARNING: |correlation| up to {worst:.3f}. Those parameters"
                  " are not independently determined by this data set;"
                  " quote the combination, or fix one and refit.")

    fails = sorted({ln.strip() for ln in lines
                    if re.search(r"FAIL|ABEND|NOT CONVERG|CALL LIMIT", ln.upper())})
    if fails:
        print("\nwarnings in the log (MINUIT messages are about the search,"
              " FRESCO messages about the calculation):")
        for ln in fails[:4]:
            print("  " + ln)


NUMERIC = re.compile(r"[-+]?[\d.]+([eEdD][-+]?\d+)?$")


def split_plot(path, prefix):
    """Split a search.plot into per-dataset data/theory column files."""
    blocks, cur, kind = [], [], None
    for ln in open(path, errors="replace"):
        s = ln.strip()
        if s.startswith("@TYPE"):
            if cur:
                blocks.append((kind, cur))
            kind = "data" if "xydy" in s else "theory"
            cur = []
        elif s == "&":
            if cur:
                blocks.append((kind, cur))
            cur, kind = [], None
        elif s and not s.startswith(("@", "#")) and kind:
            # Skip SFRESCO's own separators, e.g. the "NEW energy" marker that
            # divides the energies of a type=1 dataset.
            if NUMERIC.match(s.split()[0]):
                cur.append(s)
    if cur:
        blocks.append((kind, cur))

    # A PLOT file alternates data and theory per dataset, a LINE file has theory
    # only, so each kind carries its own counter.
    counts, written = {"data": 0, "theory": 0}, []
    for kind, rows in blocks:
        counts[kind] += 1
        n = counts[kind]
        name = f"{prefix}-{n}-{kind}.dat"
        with open(name, "w") as f:
            f.write(f"# from {path}: dataset {n} {kind}\n")
            f.write("\n".join(rows) + "\n")
        written.append(f"{name} ({len(rows)} rows)")
    for w in written:
        print("wrote " + w)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("file", help="sfresco run log, or a search.plot with --dat")
    ap.add_argument("--dat", metavar="PREFIX",
                    help="treat the file as a search.plot and split it into columns")
    args = ap.parse_args()
    try:
        if args.dat:
            split_plot(args.file, args.dat)
        else:
            report(args.file)
    except FileNotFoundError:
        sys.exit(f"no such file: {args.file}")


if __name__ == "__main__":
    main()

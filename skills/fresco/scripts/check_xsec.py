#!/usr/bin/env python3
"""check_xsec.py <output> [--ref <refoutput>] [--sigfig N]

Parse the integrated cross sections from a FRESCO output (the CUMULATIVE block of
the last energy) and, if a reference output is given, report agreement to N
significant figures. This enforces the rule: never report a FRESCO number without
comparing it to a reference and stating the agreement to N digits.

Parsed quantities (last occurrence in the file = last energy):
  reaction     CUMULATIVE REACTION cross section
  absorption   Cumulative ABSORBTION by Imaginary Potentials
  outgoing     CUMULATIVE OUTGOING cross section
"""
import argparse
import re
import sys

PATTERNS = {
    "reaction":   re.compile(r"CUMULATIVE REACTION cross section\s*=\s*([-\d.Ee+]+)", re.I),
    "absorption": re.compile(r"Cumulative ABSORBTION by Imaginary Potentials\s*=\s*([-\d.Ee+]+)", re.I),
    "outgoing":   re.compile(r"CUMULATIVE OUTGOING cross section\s*=\s*([-\d.Ee+]+)", re.I),
}


def parse(path):
    vals = {}
    with open(path, errors="replace") as fh:
        text = fh.read()
    for key, pat in PATTERNS.items():
        hits = pat.findall(text)
        if hits:
            vals[key] = float(hits[-1])  # last energy
    return vals


def agree_sigfigs(a, b):
    """Number of leading significant figures that match between a and b."""
    if a == b:
        return float("inf")
    if a == 0 or b == 0:
        return 0
    import math
    rel = abs(a - b) / max(abs(a), abs(b))
    if rel <= 0:
        return float("inf")
    return -math.log10(rel)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("output")
    ap.add_argument("--ref", help="reference FRESCO output to compare against")
    ap.add_argument("--sigfig", type=int, default=6,
                    help="required significant figures of agreement (default 6)")
    args = ap.parse_args()

    got = parse(args.output)
    if not got:
        print(f"ERROR: no CUMULATIVE cross-section block found in {args.output}",
              file=sys.stderr)
        print("       (run likely failed; inspect the output file)", file=sys.stderr)
        sys.exit(2)

    if not args.ref:
        print(f"# {args.output}")
        for k, v in got.items():
            print(f"  {k:11s} = {v:.5f} mb")
        return

    ref = parse(args.ref)
    print(f"# compare  {args.output}")
    print(f"# against  {args.ref}")
    print(f"# required agreement: {args.sigfig} sig figs\n")
    print(f"  {'quantity':11s} {'this':>16s} {'reference':>16s} {'sigfigs':>9s}  ok")
    ok_all = True
    for k in PATTERNS:
        if k in got and k in ref:
            sf = agree_sigfigs(got[k], ref[k])
            ok = sf >= args.sigfig
            ok_all = ok_all and ok
            sfs = "exact" if sf == float("inf") else f"{sf:.1f}"
            print(f"  {k:11s} {got[k]:16.5f} {ref[k]:16.5f} {sfs:>9s}  {'PASS' if ok else 'FAIL'}")
        elif k in got:
            print(f"  {k:11s} {got[k]:16.5f} {'(absent in ref)':>16s}")
    sys.exit(0 if ok_all else 1)


if __name__ == "__main__":
    main()

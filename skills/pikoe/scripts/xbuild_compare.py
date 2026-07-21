#!/usr/bin/env python3
"""Compare pikoe .dat output across build variants.

Reports worst relative difference and the implied number of agreeing significant
figures. Rejects non-finite values explicitly: NaN comparisons are all false, so
a naive `d > worst` loop silently reports an all-NaN file as a perfect match.
That exact bug shipped in the NLAT comparator and was caught only by an
adversarial pass, so it is guarded here rather than assumed away.
"""
import sys, math, pathlib

def read(p):
    vals = []
    for ln, line in enumerate(p.read_text(errors="replace").splitlines(), 1):
        for tok in line.split():
            try:
                v = float(tok)
            except ValueError:
                continue
            if not math.isfinite(v):
                raise ValueError(f"{p}: non-finite value {tok!r} at line {ln}")
            vals.append(v)
    return vals

def cmp(a, b):
    va, vb = read(a), read(b)
    if len(va) != len(vb):
        return None, f"token count differs: {len(va)} vs {len(vb)}"
    if not va:
        return None, "no numbers parsed"
    worst, scale = 0.0, max(abs(x) for x in va) or 1.0
    for x, y in zip(va, vb):
        d = abs(x - y) / max(abs(x), abs(y), 1e-30 * scale)
        worst = max(worst, d)
    return worst, f"{len(va)} numbers"

def sigfigs(w):
    if w == 0:
        return "exact (bit-identical)"
    return f"{-math.log10(w):.1f} significant figures"

def main():
    base, others = pathlib.Path(sys.argv[1]), [pathlib.Path(p) for p in sys.argv[2:]]
    rc = 0
    for other in others:
        print(f"\n=== {base.name} vs {other.name} ===")
        worst_all = 0.0
        for f in sorted(base.rglob("*.dat")):
            rel = f.relative_to(base)
            g = other / rel
            if not g.exists():
                print(f"  {str(rel):45} MISSING in {other.name}"); rc = 1; continue
            try:
                w, note = cmp(f, g)
            except ValueError as e:
                print(f"  {str(rel):45} REJECTED: {e}"); rc = 1; continue
            if w is None:
                print(f"  {str(rel):45} MISMATCH: {note}"); rc = 1; continue
            worst_all = max(worst_all, w)
            print(f"  {str(rel):45} {note:>16}  worst rel {w:.3e}")
        print(f"  --> worst overall {worst_all:.3e}  = {sigfigs(worst_all)}")
    return rc

sys.exit(main())

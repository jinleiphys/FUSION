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
    worst_scaled = 0.0
    for x, y in zip(va, vb):
        d = abs(x - y) / max(abs(x), abs(y), 1e-30 * scale)
        worst = max(worst, d)
        worst_scaled = max(worst_scaled, abs(x - y) / scale)
    cmp.worst_scaled = worst_scaled
    return worst, f"{len(va)} numbers"

def sigfigs(w):
    if w == 0:
        return "exact (bit-identical)"
    return f"{-math.log10(w):.1f} significant figures"

def main():
    # Optional: --glob PATTERN (default *.dat) selects the files compared.
    # The second column, "vs file max", is |a-b| over the file's largest |value|;
    # it keeps a 1e-17-versus-0 entry from reading as a 100% difference.
    args = sys.argv[1:]
    pattern = "*.dat"
    if len(args) >= 2 and args[0] == "--glob":
        pattern, args = args[1], args[2:]
    base, others = pathlib.Path(args[0]), [pathlib.Path(p) for p in args[1:]]
    rc = 0
    for other in others:
        print(f"\n=== {base.name} vs {other.name} ===")
        worst_all = 0.0
        for f in sorted(base.rglob(pattern)):
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
            print(f"  {str(rel):45} {note:>16}  worst rel {w:.3e}  vs file max {cmp.worst_scaled:.3e}")
        print(f"  --> worst overall {worst_all:.3e}  = {sigfigs(worst_all)}")
    return rc

sys.exit(main())

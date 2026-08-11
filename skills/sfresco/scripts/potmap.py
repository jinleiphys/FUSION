#!/usr/bin/env python3
"""potmap.py <deck.in> [--kp N] [--emit PLINE.COL ...] [--fort3 FILE]

Map a FRESCO deck's potentials onto the (kp, pline, col) triple that an SFRESCO
`&variable kind=1` needs, and print ready-to-paste `&variable` lines.

Why this exists: `pline` is NOT the line number in your input file. It is the
order of the *expanded* &potl records for that kp, and one alias-style &pot
namelist (v=, w=, wd=, vso= ...) expands into several records. Counting by eye
is the single most common way to fit the wrong parameter, and the fit still
runs and still converges, just on something you did not mean.

Two modes:
  default        parse the deck and emulate FRESCO's expansion (frxx0.f)
  --fort3 FILE   read the expanded &potl records FRESCO itself wrote (fort.3
                 in the run directory). Ground truth. Use it to cross-check.

Standard library only.
"""

import argparse
import re
import sys

EPS = 1e-10          # frxx0.f:128, the same tolerance FRESCO uses


class _Null:
    """Fortran null value in a namelist array: leaves that element untouched."""

    def __repr__(self):
        return "NULL"


NULL = _Null()

# Column labels by potential TYPE. Index 0 of each tuple is col=1.
# Source: frxx0.f alias expansion (p1=at, p2=ap, p3=rc, p4=ac for TYPE=0) and
# the FRESCO manual section 3.3.
TYPE_LABELS = {
    0:  ("at", "ap", "rc", "ac", "", "", ""),
    1:  ("V", "rV", "aV", "W", "rW", "aW", ""),
    2:  ("Vd", "rVd", "aVd", "Wd", "rWd", "aWd", ""),
    3:  ("Vso", "rso", "aso", "Wso", "rsoi", "asoi", ""),
    4:  ("Vso_t", "rso_t", "aso_t", "Wso_t", "rsoi_t", "asoi_t", ""),
    8:  ("Vss", "rss", "ass", "Wss", "rwss", "awss", ""),
    9:  ("Vem", "rem", "aem", "Wem", "rwem", "awem", ""),
}
DEF_LABELS = tuple(f"def{k}" for k in range(1, 8))  # TYPE 10-17: deformations
STEP_TYPE = -99                                     # internal marker for &step rows
STEP_LABELS = ("ib", "ia", "k", "str", "", "", "")

TYPE_NAME = {
    0: "Coulomb / radius convention",
    1: "central volume",
    2: "central surface (derivative)",
    3: "spin-orbit, projectile",
    4: "spin-orbit, target",
    5: "tensor, projectile",
    6: "tensor, target",
    7: "tensor L.(p+t)",
    8: "spin-spin",
    9: "effective-mass reduction",
    10: "deformed projectile",
    11: "deformed target",
    12: "projectile, matrix elements read in",
    13: "target, matrix elements read in",
}

# Alias groups equivalenced in frxx0.f: (r0,vr0,rv), (a,av), (wr0,r0w,rw),
# (aw,wa), (rso,rso0), (awd,wda), (wdr,wdr0).
ALIASES = {
    "vr0": "rv", "r0": "rv",
    "a": "av",
    "wr0": "rw", "r0w": "rw",
    "wa": "aw",
    "rso0": "rso",
    "wda": "awd",
    "wdr0": "wdr",
}


def strip_comments(text):
    """Drop Fortran-style trailing comments, respecting single quotes."""
    out = []
    for line in text.splitlines():
        keep, inq = [], False
        for ch in line:
            if ch == "'":
                inq = not inq
            if ch == "!" and not inq:
                break
            keep.append(ch)
        out.append("".join(keep))
    return "\n".join(out)


def find_namelists(text, *names):
    """Yield (group, body) for every `&name ... /` block, in file order."""
    pat = re.compile(r"&(" + "|".join(names) + r")\b(.*?)(?<![\"'])/",
                     re.IGNORECASE | re.DOTALL)
    for m in pat.finditer(text):
        yield m.group(1).lower(), m.group(2)


def parse_assignments(body):
    """Parse `key=v1 v2 ...` and `p(1:3)=...` into {key: [floats]} plus p[0..8]."""
    vals, parr = {}, [0.0] * 9
    # Split on assignments: capture key (optionally with an index/range) and the
    # value list that follows, up to the next key= or end of body.
    pat = re.compile(
        r"([A-Za-z_]\w*)\s*(?:\(\s*(\d+)\s*(?::\s*(\d+)\s*)?\))?\s*=\s*"
        r"([^=]*?)(?=(?:[,\s]+[A-Za-z_]\w*\s*(?:\(\s*\d+[^)]*\))?\s*=)|$)",
        re.DOTALL,
    )
    for m in pat.finditer(body):
        key = m.group(1).lower()
        i0 = int(m.group(2)) if m.group(2) else None
        # Split on commas first: an empty field is a Fortran null value, which
        # leaves that array element untouched and shifts every later one, e.g.
        # `p(1:3)=50,,0.65` puts 0.65 in p(3), not p(2). NULL marks such a slot.
        nums = []
        for field in m.group(4).split(","):
            toks = field.split()
            if not toks:
                nums.append(NULL)
                continue
            for tok in toks:
                if tok.startswith("'"):
                    continue
                tok = re.sub(r"[dD]([-+]?\d)", r"e\1", tok)  # Fortran D exponents
                if tok.upper() in ("T", "F", ".TRUE.", ".FALSE."):
                    continue
                rep = 1
                m3 = re.fullmatch(r"(\d+)\*(.*)", tok)       # Fortran `4*0.0`
                if m3:
                    rep, tok = int(m3.group(1)), m3.group(2)
                    if not tok:                              # `4*` = 4 nulls
                        nums.extend([NULL] * rep)
                        continue
                try:
                    nums.extend([float(tok)] * rep)
                except ValueError:
                    pass
        while nums and nums[-1] is NULL:                     # trailing separator
            nums.pop()
        if not nums or all(v is NULL for v in nums):
            continue
        if key in ("p", "def", "defp", "deft", "mnep", "mnet"):
            # These are all declared p(0:8) in frxx0.f, so a bare `p=` fills
            # from p(0), NOT p(1). Only `p(1:3)=` starts at p(1).
            start = i0 if i0 is not None else 0
            target = parr if key in ("p", "def") else vals.setdefault(key, [0.0] * 9)
            for k, v in enumerate(nums):
                if v is not NULL and 0 <= start + k <= 8:
                    target[start + k] = v
            continue
        m2 = re.fullmatch(r"p([0-7])", key)
        if m2:
            if nums[0] is not NULL:
                parr[int(m2.group(1))] = nums[0]
            continue
        nums = [v for v in nums if v is not NULL]
        if nums:
            vals[ALIASES.get(key, key)] = nums
    return vals, parr


def g(vals, key):
    v = vals.get(key)
    return v[0] if v else 0.0


def expand(vals, parr):
    """Emulate frxx0.f: one &pot -> one or more expanded &potl records.

    Ordinary input (any p(k) or def(k) nonzero) is 1:1. Otherwise the alias
    keywords expand in the fixed order of the `loop` counter in frxx0.f.
    """
    # frxx0.f:815 tests `maxval(abs(p))+maxval(abs(def)) > 0`, strictly, over the
    # whole p(0:8). Any nonzero element at all, however small, means ordinary input.
    ordinary = any(x != 0.0 for x in parr)
    typ = int(g(vals, "type"))
    shape = int(g(vals, "shape"))
    if ordinary:
        return [(typ, shape, parr[1:8])]

    at, ap, rc, ac = (g(vals, k) for k in ("at", "ap", "rc", "ac"))
    if abs(at) + abs(ap) < EPS:
        at = 1.0
    recs = []
    if abs(rc) > EPS:                                     # loop 0
        recs.append((0, shape, [at, ap, rc, ac, 0, 0, 0]))
    for key, t in (("mnep", 10), ("mnet", 11)):           # loops 1, 2
        arr = vals.get(key)                               # `sum(abs(p))` over p(0:8)
        if arr and sum(abs(x) for x in arr) > EPS:
            recs.append((t, shape, arr[1:8]))
    vol = [g(vals, k) for k in ("v", "rv", "av", "w", "rw", "aw")] + [0.0]
    if abs(vol[0]) + abs(vol[3]) > EPS:                   # loop 3
        recs.append((1, shape, vol))
    srf = [g(vals, k) for k in ("vd", "vdr", "vda", "wd", "wdr", "awd")] + [0.0]
    if abs(srf[0]) + abs(srf[3]) > EPS:                   # loop 4
        recs.append((2, shape, srf))
    for key, t in (("defp", 10), ("deft", 11)):           # loops 5, 6
        arr = vals.get(key)                               # `sum(abs(p))` over p(0:8)
        if arr and sum(abs(x) for x in arr) > EPS:
            recs.append((t, shape, arr[1:8]))
    so = [g(vals, k) for k in ("vso", "rso", "aso", "vsoi", "rsoi", "asoi")] + [0.0]
    if abs(so[0]) + abs(so[3]) > EPS:                     # loop 7
        recs.append((3, shape, so))
    return recs


def scan(path, expanded=False):
    """-> list of (kp, pline, type, shape, p[1..7]) in `pline` order.

    `pline` counts expanded &potl records per kp AND the &step records that
    follow a TYPE 12-17 record (frxx2.f increments the same counter for both),
    so a searchable `&step str` gets its own pline. Step rows are marked with
    type STEP_TYPE and carry (ib, ia, k, str) in the value slots.
    """
    text = strip_comments(open(path).read())
    rows, count, kp = [], {}, 0
    for group, body in find_namelists(text, "potl" if expanded else "pot", "step"):
        vals, parr = parse_assignments(body)
        if group == "step":
            ib = int(g(vals, "ib"))
            if ib == 0 or kp == 0:     # empty `&step /` terminates, no count
                continue
            count[kp] = count.get(kp, 0) + 1
            rows.append((kp, count[kp], STEP_TYPE, 0,
                         [ib, g(vals, "ia"), g(vals, "k"), g(vals, "str"),
                          0.0, 0.0, 0.0]))
            continue
        kp = int(g(vals, "kpi" if expanded else "kp"))
        if kp == 0:                    # empty `&pot /` ends the potential block
            break
        kp = abs(kp)                   # frxx0.f: KP = ABS(KPI), so -4 and 4 share
                                       # one potential and one pline sequence
        if expanded:
            recs = [(int(g(vals, "typei")), int(g(vals, "shapei")), parr[1:8])]
        else:
            recs = expand(vals, parr)
        for typ, shape, p in recs:
            count[kp] = count.get(kp, 0) + 1
            rows.append((kp, count[kp], typ, shape, list(p)))
    return rows


def read_deck(path):
    return scan(path, expanded=False)


def read_fort3(path):
    return scan(path, expanded=True)


def labels_for(typ):
    if typ == STEP_TYPE:
        return STEP_LABELS
    typ = abs(typ)              # negative TYPE adds into the previous potential
    if 10 <= typ <= 17:
        return DEF_LABELS
    return TYPE_LABELS.get(typ, tuple(f"p{k}" for k in range(1, 8)))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("deck", help="FRESCO input deck (or fort.3 with --fort3)")
    ap.add_argument("--fort3", action="store_true",
                    help="the file is an expanded fort.3 written by a FRESCO run")
    ap.add_argument("--kp", type=int, help="show only this potential index")
    ap.add_argument("--emit", nargs="+", metavar="[KP.]PLINE.COL",
                    help="emit &variable lines for these entries, e.g. --emit 2.1 3.4;"
                         " prefix the kp (1.2.1) when the deck has several potentials")
    ap.add_argument("--step", type=float, default=None,
                    help="step for emitted &variable lines (default: 1%% of the value)")
    args = ap.parse_args()

    rows = read_fort3(args.deck) if args.fort3 else read_deck(args.deck)
    if not rows:
        sys.exit(f"no &pot namelists found in {args.deck}")
    if args.kp:
        rows = [r for r in rows if r[0] == args.kp]
        if not rows:
            sys.exit(f"no potential with kp={args.kp}")

    if not args.emit:
        print(f"# {args.deck}: potential map for SFRESCO &variable kind=1")
        print("# pline counts EXPANDED &potl records per kp, not input lines.")
        for kp, pline, typ, shape, p in rows:
            if typ == STEP_TYPE:
                print(f"\nkp={kp}  pline={pline}   &step coupling"
                      f" (ib={int(p[0])}, ia={int(p[1])}, k={int(p[2])})")
                print(f"    col ignored  str    = {p[3]:12.6f}")
                continue
            name = TYPE_NAME.get(abs(typ), f"type {typ}")
            if typ < 0:
                name += ", added into the previous potential"
            sh = f", shape={shape}" if shape else ""
            print(f"\nkp={kp}  pline={pline}   type={typ} ({name}{sh})")
            labs = labels_for(typ)
            for c in range(1, 8):
                lab = labs[c - 1] if c - 1 < len(labs) else ""
                if not lab or p[c - 1] == 0.0:
                    continue
                print(f"    col={c}  {lab:<6s} = {p[c-1]:12.6g}")
        print("\n# emit variables with:  potmap.py <deck> --emit <pline>.<col> ...")
        return

    index = {(r[0], r[1], c): (r[2], r[4][c - 1])
             for r in rows for c in range(1, 8)}
    kps = sorted({r[0] for r in rows})
    for spec in args.emit:
        parts = spec.split(".")
        try:
            if len(parts) == 3:
                kp, pl, col = (int(x) for x in parts)
            elif len(parts) == 2:
                pl, col = (int(x) for x in parts)
                if len(kps) > 1:
                    sys.exit(f"{args.deck} defines potentials kp={kps}; write the spec"
                             f" as KP.PLINE.COL (or pass --kp)")
                kp = kps[0]
            else:
                raise ValueError
        except ValueError:
            sys.exit(f"bad --emit spec {spec!r}, want [KP.]PLINE.COL such as 2.1")
        if (kp, pl, col) not in index:
            sys.exit(f"no kp={kp} pline={pl} col={col} in {args.deck}")
        typ, val = index[(kp, pl, col)]
        if typ == STEP_TYPE:           # a &step varies `str`; col is ignored
            _, val = index[(kp, pl, 4)]
            step = args.step if args.step is not None else max(abs(val) * 0.01, 1e-3)
            print(f" &variable kind=1 name='str{pl}' kp={kp} pline={pl} col=1"
                  f" potential={val:.6g} step={step:.4g} /   ! &step strength")
            continue
        labs = labels_for(typ)
        name = labs[col - 1] if col - 1 < len(labs) and labs[col - 1] else f"p{col}"
        step = args.step if args.step is not None else max(abs(val) * 0.01, 1e-3)
        print(f" &variable kind=1 name='{name}' kp={kp} pline={pl} col={col}"
              f" potential={val:.6g} step={step:.4g} /")


if __name__ == "__main__":
    main()

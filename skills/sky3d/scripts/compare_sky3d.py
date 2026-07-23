#!/usr/bin/env python3
"""Compare a Sky3D for006 against a reference for006, physics by physics.

A plain `diff` is the WRONG comparator for Sky3D and will report thousands of
differences on a run that is physically identical. Two classes of printed number
are not reproducible even between two runs of the same binary, and neither is a
defect:

  1. The orbital and spin components (Lx, Ly, Lz, Sx, Sy, Sz) of DEGENERATE
     single-particle states. 16O with SV-bas and no pairing is spherical, so the
     p3/2 and p1/2 levels come out as degenerate multiplets. Which orthogonal
     basis the diagonalizer returns inside a degenerate subspace is arbitrary:
     any unitary mixing of degenerate states is an equally valid eigenbasis.
     The energies of those states are identical; only the orientation is not.

  2. Quantities that vanish by symmetry, printed as numerical noise. For a
     spherical nucleus q20 falls to around 1e-9 AT CONVERGENCE, having passed
     through roughly 1e-3 to 1e-2 in the transient while the initial Gaussian
     relaxes, and the centre-of-mass <x>, <y>, <z> sit around 1e-16 to 1e-11
     throughout. Their relative difference between two runs is order unity and
     means nothing. The dimensionless test below is what makes this precise: it
     is |q20| / (N * rms^2) that stays tiny, not |q20| itself.

So this comparator checks what is physically determined, and says plainly what
it excludes. The energy functional, the single-particle ENERGIES, and the
determined moments (particle number, rms radius, <x2>, <y2>, <z2>) are required
to match EXACTLY at printed precision. q20 is handled adaptively: it is treated
as a symmetry residue only when both runs are spherical by its own magnitude
relative to N*rms^2, and is compared as a real observable otherwise, so a
deformed case is not silently excused.

Non-finite values are always a failure, on either side.

Usage:  compare_sky3d.py <candidate for006> <reference for006> [--rtol 1e-6]
Exit 0 on agreement, 1 on any failure.
"""
import argparse
import math
import re
import sys

# " Total: -1.166577E+02 MeV. t0 part: ... " and its continuation " t3 part: ..."
ENERGY_LINE = re.compile(r'^\s*(Total:|t3 part)')
SCI = re.compile(r'[-+]?\d+\.\d+E[-+]\d+')
# s.p. table row: index, parity, v**2, var_h1, var_h2, Norm, Ekin, Energy, then
# the six Lx..Sz columns which we deliberately stop before.
SP_ROW = re.compile(
    r'^\s*(\d+)\s+(-?1)\.\s+([\d.]+)\s+([\d.E+-]+)\s+([\d.E+-]+)\s+'
    r'([\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s')
# moments table row: "    Total:      16.0000      2.6884  1.4983E-09 ..."
MOM_ROW = re.compile(r'^\s*(Total|Neutron|Proton):\s+([\d.]+)\s+([\d.]+)\s+([-\d.E+]+)\s+'
                     r'([-\d.E+]+)\s+([-\d.E+]+)\s+([-\d.E+]+)')


# Sky3D decorates headers as " ***** Force definition *****", so the field
# overflow test must skip that symmetric form or it fires on every healthy run.
HEADER = re.compile(r'^\s*\*{3,}.*\*{3,}\s*$')
NONFINITE = re.compile(r'(?i)\b(nan|infinity)\b|\*{4,}')

# Physical bounds on the columns the COMPARISON excludes. Excluding a column from
# the comparison is not a reason to stop looking at it: a run with residuals of
# 1e5 is not converged and a spin component of 999 is not a spin-1/2 orbital,
# and both used to pass.
MAX_RESIDUAL = 1.0e3    # var_h1/var_h2 in MeV^2; the benchmark reaches < 1e-5
MAX_SPIN = 0.5001       # |S_i| for a spin-1/2 orbital, with printing slack
MAX_CENTROID = 1.0e3    # |<x>| in fm; any real box is far smaller

# Full s.p. row including the six Lx..Sz columns, used for bounds checking only.
SP_FULL = re.compile(
    r'^\s*(\d+)\s+(-?1)\.\s+([\d.]+)\s+([\d.E+-]+)\s+([\d.E+-]+)\s+'
    r'([\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)'
    r'\s+(-?[\d.E+-]+)\s+(-?[\d.E+-]+)\s+(-?[\d.E+-]+)'
    r'\s+(-?[\d.E+-]+)\s+(-?[\d.E+-]+)\s+(-?[\d.E+-]+)\s*$')
# Moments row extended to the three centroid columns.
MOM_CENTROID = re.compile(
    r'^\s*(Total|Neutron|Proton):\s+([\d.]+)\s+([\d.]+)\s+([-\d.E+]+)\s+'
    r'([-\d.E+]+)\s+([-\d.E+]+)\s+([-\d.E+]+)\s+'
    r'([-\d.E+]+)\s+([-\d.E+]+)\s+([-\d.E+]+)')
# A "Total:" line carries 4 values and its "t3 part" continuation carries 3.
# Anything else means the line was corrupted (a value replaced by NaN or by a
# field overflow drops silently out of the SCI regex, which is how a 265-value
# candidate once compared EXACT against a 266-value reference).
ENERGY_WIDTH = {'Total:': 4, 't3 part': 3}


def parse(path):
    """Return (energy_rows, sp_rows, moment_rows). Raises ValueError on corruption."""
    energy, sp, mom = [], [], []
    with open(path, errors='replace') as fh:
        for lineno, line in enumerate(fh, 1):
            # Detect non-finite and overflowed fields TEXTUALLY, before any
            # numeric regex gets the chance to skip over them.
            if HEADER.match(line):
                continue
            if NONFINITE.search(line):
                raise ValueError(f"{path}:{lineno}: non-finite value or field overflow: {line.strip()[:90]!r}")
            if ENERGY_LINE.match(line) and 'MeV' in line:
                key = 'Total:' if line.lstrip().startswith('Total:') else 't3 part'
                vals = SCI.findall(line)
                want = ENERGY_WIDTH[key]
                if len(vals) != want:
                    raise ValueError(f"{path}:{lineno}: energy line has {len(vals)} values, expected {want}: "
                                     f"{line.strip()[:90]!r}")
                energy.append(tuple(float(v) for v in vals))
                continue
            m = SP_FULL.match(line)
            if m:
                # The excluded columns are excluded from the COMPARISON, not from
                # inspection: an unconverged or unphysical run must not slip
                # through just because its differing columns are not compared.
                v_h1, v_h2 = float(m.group(4)), float(m.group(5))
                if max(abs(v_h1), abs(v_h2)) > MAX_RESIDUAL:
                    raise ValueError(f"{path}:{lineno}: single-particle residual var_h1/var_h2 = "
                                     f"{v_h1:g}/{v_h2:g} exceeds {MAX_RESIDUAL:g}; the run is not converged")
                spins = [float(m.group(i)) for i in (12, 13, 14)]
                if max(abs(x) for x in spins) > MAX_SPIN:
                    raise ValueError(f"{path}:{lineno}: spin component {max(spins, key=abs):g} exceeds "
                                     f"{MAX_SPIN:g}, impossible for a spin-1/2 orbital")
            m = SP_ROW.match(line)
            if m:
                # v**2, Norm, Ekin, Energy. var_h1 and var_h2 are convergence
                # residuals of the individual state and are kept out on purpose:
                # they are what the iteration drives to zero, so near convergence
                # they are noise-dominated in exactly the way q20 is.
                sp.append((float(m.group(3)), float(m.group(6)),
                           float(m.group(7)), float(m.group(8))))
                continue
            m = MOM_ROW.match(line)
            if m:
                mom.append(tuple(float(m.group(i)) for i in range(2, 8)))
                c = MOM_CENTROID.match(line)
                if c:
                    cen = [float(c.group(i)) for i in (7, 8, 9)]
                    if max(abs(x) for x in cen) > MAX_CENTROID:
                        raise ValueError(f"{path}:{lineno}: centre-of-mass coordinate "
                                         f"{max(cen, key=abs):g} fm is outside any sane box")
    if not energy or not sp or not mom:
        raise ValueError(f"{path}: parsed {len(energy)} energy, {len(sp)} single-particle and "
                         f"{len(mom)} moment rows; at least one block is missing")
    return energy, sp, mom


def check_finite(name, rows, path):
    for row in rows:
        for v in row:
            if not math.isfinite(v):
                print(f"FAIL: non-finite value in {name} of {path}: {v}")
                return False
    return True


def compare_exact(name, a, b):
    if len(a) != len(b):
        print(f"FAIL: {name} count differs: {len(a)} vs {len(b)}")
        return False
    bad = 0
    worst = (0.0, None)
    for i, (ra, rb) in enumerate(zip(a, b)):
        for x, y in zip(ra, rb):
            if x != y:
                bad += 1
                d = abs(x - y) / max(abs(x), abs(y)) if max(abs(x), abs(y)) > 0 else 0.0
                if d > worst[0]:
                    worst = (d, (i, x, y))
    n = sum(len(r) for r in a)
    if bad:
        print(f"FAIL: {name}: {bad} of {n} values differ at printed precision; "
              f"worst relative {worst[0]:.3e} (row {worst[1][0]}: {worst[1][1]} vs {worst[1][2]})")
        return False
    print(f"  {name}: {n} values, EXACT at printed precision")
    return True


def compare_moments(a, b, rtol, sphere_tol):
    """Moments row is (Part.Num., rms, q20, <x2>, <y2>, <z2>).

    Part.Num., rms and the three <x_i^2> are determined observables and are
    required to be exact at printed precision. q20 is handled adaptively,
    because whether it is an observable depends on the case:

      * If the run is spherical, meaning |q20| / (N * rms^2) stays below
        sphere_tol on BOTH sides for every row, then q20 is the symmetry-breaking
        residue of the initial condition, not an observable, and comparing it
        between two runs is meaningless. It is then only asserted to be small.
      * Otherwise the nucleus is genuinely deformed, q20 IS an observable, and it
        is compared with the relative tolerance like anything else.

    This is what keeps the comparator honest for a deformed case instead of
    hard-coding "q20 is noise", which is true for the 16O benchmark only.
    """
    if len(a) != len(b):
        print(f"FAIL: moments count differs: {len(a)} vs {len(b)}")
        return False
    labels = ('Part.Num.', 'rms radius', 'q20', '<x2>', '<y2>', '<z2>')
    determined = (0, 1, 3, 4, 5)
    ok = True

    bad = 0
    worst = (0.0, None)
    for i, (ra, rb) in enumerate(zip(a, b)):
        for k in determined:
            if ra[k] != rb[k]:
                bad += 1
                d = abs(ra[k] - rb[k]) / max(abs(ra[k]), abs(rb[k]), 1e-300)
                if d > worst[0]:
                    worst = (d, (i, labels[k], ra[k], rb[k]))
    if bad:
        print(f"FAIL: moments (Part.Num., rms, <x2>, <y2>, <z2>): {bad} values differ; worst "
              f"relative {worst[0]:.3e} (row {worst[1][0]} {worst[1][1]}: {worst[1][2]} vs {worst[1][3]})")
        ok = False
    else:
        print(f"  moments (Part.Num., rms radius, <x2>, <y2>, <z2>): "
              f"{len(a) * len(determined)} values, EXACT at printed precision")

    def sphericity(rows):
        return max(abs(r[2]) / (r[0] * r[1] ** 2) for r in rows if r[0] > 0 and r[1] > 0)

    sa, sb = sphericity(a), sphericity(b)
    if sa < sphere_tol and sb < sphere_tol:
        print(f"  q20: NOT compared, both runs are spherical to {max(sa, sb):.2e} of N*rms^2 "
              f"(threshold {sphere_tol:.0e}), so q20 is a symmetry residue, not an observable")
    else:
        worst = (0.0, None)
        for i, (ra, rb) in enumerate(zip(a, b)):
            m = max(abs(ra[2]), abs(rb[2]))
            if m == 0:
                continue
            d = abs(ra[2] - rb[2]) / m
            if d > worst[0]:
                worst = (d, (i, ra[2], rb[2]))
        if worst[0] > rtol:
            print(f"FAIL: q20 (deformed case, so it IS an observable): worst relative "
                  f"{worst[0]:.3e} exceeds rtol {rtol:.1e} "
                  f"(row {worst[1][0]}: {worst[1][1]} vs {worst[1][2]})")
            ok = False
        else:
            print(f"  q20 (deformed case, compared as an observable): worst relative "
                  f"{worst[0]:.3e} <= rtol {rtol:.1e}")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('candidate')
    ap.add_argument('reference')
    ap.add_argument('--rtol', type=float, default=1e-6,
                    help='relative tolerance for the moments table (default 1e-6)')
    ap.add_argument('--sphere-tol', type=float, default=1e-3,
                    help='|q20|/(N*rms^2) below this on BOTH sides means the case is spherical '
                         'and q20 is a symmetry residue rather than an observable')
    args = ap.parse_args()

    # A threshold of nan or inf makes every comparison below pass. Reject any
    # non-finite, negative or absurd tolerance rather than letting it disable
    # the check it is supposed to parameterize.
    for name, val, upper in (('--rtol', args.rtol, 1.0),
                             ('--sphere-tol', args.sphere_tol, 1.0)):
        if not math.isfinite(val) or val < 0.0 or val > upper:
            print(f"FAIL: {name}={val!r} is not a finite tolerance in [0, {upper}]")
            return 1

    try:
        ca = parse(args.candidate)
        rb = parse(args.reference)
    except ValueError as exc:
        print(f"FAIL: {exc}")
        return 1

    for label, idx in (('energy functional', 0), ('single-particle table', 1), ('moments', 2)):
        if not check_finite(label, ca[idx], args.candidate):
            return 1
        if not check_finite(label, rb[idx], args.reference):
            return 1

    print(f"comparing {args.candidate}")
    print(f"     with {args.reference}")
    ok = True
    ok &= compare_exact('energy functional (Total, t0, t1, t2, t3, t4, Coulomb, every printed step)',
                        ca[0], rb[0])
    ok &= compare_exact('single-particle (v**2, Norm, Ekin, Energy)', ca[1], rb[1])
    ok &= compare_moments(ca[2], rb[2], args.rtol, args.sphere_tol)
    print("  EXCLUDED by design: Lx, Ly, Lz, Sx, Sy, Sz of degenerate states (arbitrary basis")
    print("  inside a degenerate subspace), var_h1/var_h2 (per-state convergence residuals),")
    print("  and <x>, <y>, <z> (centre-of-mass drift, ~1e-16 to 1e-11, zero by symmetry)")
    if ok:
        print("COMPARE OK")
        return 0
    print("COMPARE FAILED")
    return 1


if __name__ == '__main__':
    sys.exit(main())

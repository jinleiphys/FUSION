#!/usr/bin/env python3
"""
check_gubser.py: validate a vHLLE Gubser (icModel 4) outx.dat against the
analytic ideal-conformal Gubser solution.

The analytic solution (Gubser 2010; q = 1 fm^-1, reference proper time tau0 = 1),
in Milne coordinates along the x-axis (y = 0, so r = |x|):

    v_r(tau, r) = 2 tau r / (1 + tau^2 + r^2)
    eps(tau, r) = 4^(4/3) / ( tau^(4/3) * D^(4/3) ),
                  D = 1 + 2(tau^2 + r^2) + (tau^2 - r^2)^2

This is a CODE-INDEPENDENT reference: at tau = 1 it equals what icGubser.cpp
sets as the initial condition, and vHLLE must reproduce its time evolution.

Usage:
    check_gubser.py OUTX_DAT --tau TAU [--xcut XCUT]
                    [--max-eps-reldiff R] [--max-vx-absdiff V]
                    [--center-eps VALUE --center-tol TOL]

Exit 0 if every requested check passes, non-zero otherwise. Prints a summary.
"""
import sys
import math
import argparse


def eps_ana(tau, r):
    D = 1.0 + 2.0 * (tau * tau + r * r) + (tau * tau - r * r) ** 2
    return (4.0 ** (4.0 / 3.0)) / (tau ** (4.0 / 3.0) * D ** (4.0 / 3.0))


def vr_ana(tau, r):
    return 2.0 * tau * r / (1.0 + tau * tau + r * r)


def parse_args(argv):
    p = argparse.ArgumentParser(description="validate vHLLE Gubser output vs analytic")
    p.add_argument("outx")
    p.add_argument("--tau", type=float, required=True)
    p.add_argument("--xcut", type=float, default=5.0)
    p.add_argument("--max-eps-reldiff", type=float, default=None)
    p.add_argument("--max-vx-absdiff", type=float, default=None)
    p.add_argument("--center-eps", type=float, default=None)
    p.add_argument("--center-tol", type=float, default=None)
    a = p.parse_args(argv)
    if not math.isfinite(a.tau) or a.tau <= 0.0:
        p.error("--tau must be a positive finite number")
    if not math.isfinite(a.xcut) or a.xcut <= 0.0:
        p.error("--xcut must be a positive finite number")
    if (a.center_eps is None) != (a.center_tol is None):
        p.error("--center-eps and --center-tol must be given together")
    return a


def main(argv):
    a = parse_args(argv)

    rows = []
    with open(a.outx) as f:
        for line in f:
            parts = line.split()
            if len(parts) < 7:
                continue
            try:
                vals = [float(x) for x in parts[:7]]
            except ValueError:
                continue
            t, x, vx, vy, e, nb, T = vals
            if abs(t - a.tau) < 1e-6:
                rows.append((x, vx, e, T))

    if not rows:
        print("FAIL: no rows found at tau=%g in %s" % (a.tau, a.outx))
        return 1

    # reject any non-finite value outright (a diverged run)
    for (x, vx, e, T) in rows:
        for v in (x, vx, e, T):
            if not math.isfinite(v):
                print("FAIL: non-finite value in output at tau=%g" % a.tau)
                return 1

    max_de = rms_de = max_dv = rms_dv = 0.0
    n = 0
    center = None
    # symmetry: eps(+x) must equal eps(-x) for a symmetric IC; record worst asymmetry
    by_absx = {}
    for (x, vx, e, T) in rows:
        if abs(x) <= a.xcut:
            ea = eps_ana(a.tau, abs(x))
            va = vr_ana(a.tau, abs(x)) * (1.0 if x >= 0 else -1.0)
            rde = abs(e - ea) / ea if ea > 0 else 0.0
            dv = abs(vx - va)
            max_de = max(max_de, rde)
            rms_de += rde * rde
            max_dv = max(max_dv, dv)
            rms_dv += dv * dv
            n += 1
        key = round(abs(x), 6)
        by_absx.setdefault(key, []).append(e)
        if abs(x) < 1e-9:
            center = e

    if n == 0:
        print("FAIL: no cells within |x|<=%g at tau=%g" % (a.xcut, a.tau))
        return 1
    rms_de = math.sqrt(rms_de / n)
    rms_dv = math.sqrt(rms_dv / n)

    max_asym = 0.0
    for key, es in by_absx.items():
        if len(es) >= 2:
            lo, hi = min(es), max(es)
            if hi > 0:
                max_asym = max(max_asym, (hi - lo) / hi)

    print("check_gubser: tau=%g  |x|<=%g  N=%d" % (a.tau, a.xcut, n))
    print("  eps vs analytic : max reldiff=%.4f  rms=%.4f" % (max_de, rms_de))
    print("  vx  vs analytic : max absdiff=%.5f  rms=%.5f" % (max_dv, rms_dv))
    print("  eps left-right symmetry: max reldiff=%.2e" % max_asym)
    if center is not None:
        print("  center eps(tau=%g, x=0) = %.6e" % (a.tau, center))

    ok = True
    if a.max_eps_reldiff is not None and max_de > a.max_eps_reldiff:
        print("FAIL: eps max reldiff %.4f > %.4f" % (max_de, a.max_eps_reldiff))
        ok = False
    if a.max_vx_absdiff is not None and max_dv > a.max_vx_absdiff:
        print("FAIL: vx max absdiff %.5f > %.5f" % (max_dv, a.max_vx_absdiff))
        ok = False
    # symmetry is a hard structural invariant: a symmetric IC must stay symmetric
    if max_asym > 1e-6:
        print("FAIL: left-right asymmetry %.2e exceeds 1e-6 (broken symmetry)" % max_asym)
        ok = False
    if a.center_eps is not None:
        if center is None:
            print("FAIL: no x=0 cell to check center-eps")
            ok = False
        else:
            rel = abs(center - a.center_eps) / a.center_eps
            if rel > a.center_tol:
                print("FAIL: center eps %.6e vs pinned %.6e, reldiff %.3e > %.3e"
                      % (center, a.center_eps, rel, a.center_tol))
                ok = False

    # make it explicit when no physics threshold was requested: only the symmetry
    # invariant was enforced, so a bare "PASS" would overstate what was checked
    enforced = (a.max_eps_reldiff is not None or a.max_vx_absdiff is not None
                or a.center_eps is not None)
    if not ok:
        print("check_gubser: FAIL")
    elif enforced:
        print("check_gubser: PASS")
    else:
        print("check_gubser: PASS (symmetry only; no eps/vx/center threshold given, informational)")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

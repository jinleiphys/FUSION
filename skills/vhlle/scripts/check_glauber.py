#!/usr/bin/env python3
"""
check_glauber.py: validate a vHLLE optical-Glauber outx.dat against pinned
production anchors: the last timestep must be the expected tau, and the central
cell energy density and temperature must match pinned values within tolerance.
All values must be finite.

    check_glauber.py OUTX --last-tau T --center-eps E --center-T Tval --tol R

Exit 0 on pass, non-zero on any failure.
"""
import sys
import math
import argparse


def main(argv):
    p = argparse.ArgumentParser()
    p.add_argument("outx")
    p.add_argument("--last-tau", type=float, required=True)
    p.add_argument("--center-eps", type=float, required=True)
    p.add_argument("--center-T", type=float, required=True)
    p.add_argument("--tol", type=float, required=True)
    a = p.parse_args(argv)
    if a.tol <= 0 or not math.isfinite(a.tol):
        p.error("--tol must be a positive finite number")

    rows = []
    with open(a.outx) as f:
        for line in f:
            s = line.split()
            if len(s) < 7:
                continue
            try:
                rows.append((float(s[0]), float(s[1]), float(s[4]), float(s[6])))
            except ValueError:
                continue
    if not rows:
        print("FAIL: no data rows in %s" % a.outx)
        return 1

    lastt = max(r[0] for r in rows)
    if abs(lastt - a.last_tau) > 1e-6:
        print("FAIL: last tau %.4f != expected %.4f" % (lastt, a.last_tau))
        return 1
    center = [r for r in rows if abs(r[0] - lastt) < 1e-6 and abs(r[1]) < 0.1]
    if not center:
        print("FAIL: no central cell at last tau")
        return 1
    eps, T = center[0][2], center[0][3]
    if not (math.isfinite(eps) and math.isfinite(T)):
        print("FAIL: non-finite central eps/T")
        return 1
    reps = abs(eps - a.center_eps) / a.center_eps
    rT = abs(T - a.center_T) / a.center_T
    print("check_glauber: last tau=%.4f  center eps=%.6e (pin %.6e, rel %.2e)  T=%.6e (pin %.6e, rel %.2e)"
          % (lastt, eps, a.center_eps, reps, T, a.center_T, rT))
    ok = True
    if reps > a.tol:
        print("FAIL: central eps reldiff %.3e > %.3e" % (reps, a.tol)); ok = False
    if rT > a.tol:
        print("FAIL: central T reldiff %.3e > %.3e" % (rT, a.tol)); ok = False
    print("check_glauber:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

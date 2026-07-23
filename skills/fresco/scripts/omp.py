#!/usr/bin/env python3
"""
omp.py - global nucleon optical model potentials, emitted as ready-to-paste
FRESCO &POT blocks.

Supported parameterizations:
    kd02   Koning and Delaroche, Nucl. Phys. A713 (2003) 231
    ch89   Varner et al. (Chapel Hill 89), Phys. Rep. 201 (1991) 57

Both are transcribed from production Fortran (Koning's own kd02.f, and the
TWOFNR-derived ch89.f) and pinned against it by --selftest, so this file is a
checked copy of a working implementation, not a formula typed from memory.
The reference numbers are baked into REF below, so --selftest needs no Fortran.

Why this script exists: the parameter formulas are the easy part. What actually
breaks a calculation is the handoff into FRESCO, and there are three traps:

  1. FRESCO builds radii as R = r0 * (Ap^1/3 + At^1/3), while both KD02 and CH89
     are defined on R = r0 * At^1/3. Emitting `ap=0` is what makes those agree.
     Get this wrong and every radius is ~20% too large, the deck still runs, and
     the cross section still looks entirely reasonable.
  2. The surface term is imaginary: W_d belongs in p4 of a `type=2` line, not p1.
     Putting it in p1 makes a real surface well and silently kills the absorption.
  3. A `type=0` line must exist even for neutrons, because it is what defines the
     radius convention. rc is then unused but still has to be present.

Usage:
    omp.py --code kd02 --proj n --target 90Zr --energy 50
    omp.py --code ch89 --proj p --target 208Pb --energy 30 --format table
    omp.py --code kd02 --proj n --target Zr-90 --energy 50 --format json
    omp.py --selftest

No third-party dependencies.
"""

import argparse
import json
import math
import re
import sys

A_MAX = 350          # past the heaviest known nuclide; keeps exp() in range

SYMBOLS = (
    "n H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co "
    "Ni Cu Zn Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te "
    "I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf Ta W Re Os Ir "
    "Pt Au Hg Tl Pb Bi Po At Rn Fr Ra Ac Th Pa U Np Pu Am Cm Bk Cf Es Fm Md No "
    "Lr Rf Db Sg Bh Hs Mt Ds Rg Cn Nh Fl Mc Lv Ts Og"
).split()


def _check_nuclide(z, a, src):
    """Reject nuclides that cannot exist.

    The numeric form is Z,A, and writing it A,Z instead is an easy slip that would
    otherwise pass silently: '90,40' would be read as Z=90 A=40 and quietly return
    a full set of parameters for an impossible nucleus, which is exactly the class
    of error this script exists to prevent.
    """
    if a < 1:
        raise SystemExit(f"target '{src}': mass number A={a} must be at least 1")
    if z < 1:
        raise SystemExit(f"target '{src}': charge Z={z} must be at least 1")
    if z > a:
        raise SystemExit(
            f"target '{src}': Z={z} exceeds A={a}, which is not a nucleus. "
            f"The numeric form is Z,A, so for A={z} Z={a} write '{a},{z}'.")
    if z >= len(SYMBOLS):
        raise SystemExit(f"target '{src}': Z={z} is beyond the element table")
    if a > A_MAX:
        # Not cosmetic: KD02's d2 term contains exp((A-156)/8), which overflows for
        # large A and would otherwise surface as a bare OverflowError traceback.
        raise SystemExit(
            f"target '{src}': A={a} exceeds {A_MAX}, beyond any known nuclide")


def warn(msg):
    """Advisories go to stderr so they never contaminate a piped &POT block."""
    print(f"warning: {msg}", file=sys.stderr)


def parse_target(s):
    """'90Zr' / 'Zr90' / 'Zr-90' / '40,90' -> (Z, A, label)."""
    s = s.strip()
    m = re.fullmatch(r"\s*(\d+)\s*[,:]\s*(\d+)\s*", s)
    if m:
        z, a = int(m.group(1)), int(m.group(2))
        _check_nuclide(z, a, s)
        return z, a, f"{a}{SYMBOLS[z]}"
    m = (re.fullmatch(r"(\d+)[- ]?([A-Za-z]{1,2})", s)
         or re.fullmatch(r"([A-Za-z]{1,2})[- ]?(\d+)", s))
    if not m:
        raise SystemExit(f"cannot parse target '{s}'. Try 90Zr, Zr-90, or 40,90 (Z,A).")
    g1, g2 = m.group(1), m.group(2)
    sym, a = (g2, int(g1)) if g1.isdigit() else (g1, int(g2))
    sym = sym.capitalize()
    if sym not in SYMBOLS:
        raise SystemExit(f"unknown element '{sym}'")
    z = SYMBOLS.index(sym)
    _check_nuclide(z, a, s)
    return z, a, f"{a}{sym}"


# --------------------------------------------------------------------------
# KD02: Koning and Delaroche, NPA 713 (2003) 231
# transcribed from the reference kd02.f (Koning)
# --------------------------------------------------------------------------
def kd02(k0, Z, A, E):
    """k0 = 1 neutron, 2 proton. Z, A of the target; E lab energy in MeV."""
    N = A - Z
    p = {}
    rv = 1.3039 - 0.4054 * A ** (-1 / 3)
    av = 0.6778 - 1.487e-4 * A
    v4 = 7.0e-9
    w2 = 73.55 + 0.0795 * A
    rvd = 1.3424 - 0.01585 * A ** (1 / 3)
    d2 = 0.0180 + 3.802e-3 / (1.0 + math.exp((A - 156.0) / 8.0))
    d3 = 11.5
    vso1 = 5.922 + 0.0030 * A
    vso2 = 0.0040
    rvso = 1.1854 - 0.647 * A ** (-1 / 3)
    avso = 0.59
    wso1, wso2 = -3.1, 160.0

    if k0 == 1:
        ef = -11.2814 + 0.02646 * A
        v1 = 59.30 - 21.0 * (N - Z) / A - 0.024 * A
        v2 = 7.228e-3 - 1.48e-6 * A
        v3 = 1.994e-5 - 2.0e-8 * A
        w1 = 12.195 + 0.0167 * A
        d1 = 16.0 - 16.0 * (N - Z) / A
        avd = 0.5446 - 1.656e-4 * A
        rc = 0.0
    elif k0 == 2:
        ef = -8.4075 + 0.01378 * A
        v1 = 59.30 + 21.0 * (N - Z) / A - 0.024 * A
        v2 = 7.067e-3 + 4.23e-6 * A
        v3 = 1.729e-5 + 1.136e-8 * A
        w1 = 14.667 + 0.009629 * A
        avd = 0.5187 + 5.205e-4 * A
        d1 = 16.0 + 16.0 * (N - Z) / A
        rc = 1.198 + 0.697 * A ** (-2 / 3) + 12.994 * A ** (-5 / 3)
    else:
        raise SystemExit("kd02: k0 must be 1 (neutron) or 2 (proton)")

    f = E - ef
    if k0 == 1:
        vcoul = 0.0
    else:
        Vc = 1.73 / rc * Z / A ** (1 / 3)
        vcoul = Vc * v1 * (v2 - 2.0 * v3 * f + 3.0 * v4 * f * f)

    p["V"] = v1 * (1.0 - v2 * f + v3 * f ** 2 - v4 * f ** 3) + vcoul
    p["rv"], p["av"] = rv, av
    p["W"] = w1 * f ** 2 / (f ** 2 + w2 ** 2)
    p["rw"], p["aw"] = rv, av
    p["Wd"] = d1 * f ** 2 * math.exp(-d2 * f) / (f ** 2 + d3 ** 2)
    p["rwd"], p["awd"] = rvd, avd
    p["Vso"] = vso1 * math.exp(-vso2 * f)
    p["rso"], p["aso"] = rvso, avso
    p["Wso"] = wso1 * f ** 2 / (f ** 2 + wso2 ** 2)
    p["rwso"], p["awso"] = rvso, avso
    p["rc"] = rc
    p["Ef"] = ef
    return p


# --------------------------------------------------------------------------
# CH89: Varner et al., Phys. Rep. 201 (1991) 57
# transcribed from the reference ch89.f (TWOFNR lineage)
#
# Two deliberate differences from that Fortran, both documented in SKILL.md:
#   - it computes Vso/rso/aso internally but never returns them (and pot.f has
#     the spin-orbit lines commented out). Elastic scattering needs them, so
#     they are returned here. --no-spin-orbit reproduces that reference behaviour.
#   - pot.f hardcodes rc = 1.24 rather than the Varner form. The Varner value is
#     used here.
# --------------------------------------------------------------------------
def ch89(zp, Z, A, E):
    """zp = 0 neutron, 1 proton. Z, A of the target; E lab energy in MeV."""
    if zp not in (0, 1):
        raise SystemExit("ch89 is defined for nucleons only (zp = 0 or 1)")
    N = A - Z
    asym = (N - Z) / A
    a13 = A ** (1 / 3)

    v0, vt, ve = 52.9, 13.1, -0.299
    r0, r00, a0 = 1.25, -0.225, 0.69
    rc_, rc0 = 1.24, 0.12
    wv0, wve0, wvew = 7.8, 35.0, 16.0
    ws0, wst, wse0, wsew = 10.0, 18.0, 36.0, 37.0
    rw_, rw0, aw_ = 1.33, -0.42, 0.69

    rrc = rc_ * a13 + rc0
    rcn = rrc / a13
    ecpp = 1.73 * Z / rrc

    # Coulomb-corrected bombarding energy, and the isospin sign flip
    erp = E - ecpp if zp == 1 else E
    sgn = +1.0 if zp == 1 else -1.0

    p = {}
    p["V"] = v0 + sgn * vt * asym + erp * ve
    p["rv"] = (r0 * a13 + r00) / a13
    p["av"] = a0

    wvp = wv0 / (1.0 + math.exp((wve0 - erp) / wvew))
    p["W"] = max(wvp, 0.0)
    p["rw"] = (rw_ * a13 + rw0) / a13
    p["aw"] = aw_

    wsp = (ws0 + sgn * wst * asym) / (1.0 + math.exp((erp - wse0) / wsew))
    p["Wd"] = max(wsp, 0.0)
    p["rwd"], p["awd"] = p["rw"], p["aw"]

    p["Vso"] = 5.9
    p["rso"] = (1.34 * a13 - 1.20) / a13
    p["aso"] = 0.63
    p["Wso"] = 0.0
    p["rwso"], p["awso"] = p["rso"], p["aso"]
    p["rc"] = rcn
    p["Ecoul"] = ecpp
    return p


CODES = {"kd02": kd02, "ch89": ch89}


# Mass and energy ranges the published fits actually cover. Outside them the formulas
# still evaluate, but the result is extrapolation and should not be quoted as "KD02"
# or "CH89" without saying so.
FIT_RANGE = {"kd02": ((24, 209), (0.001, 200.0)),
             "ch89": ((40, 209), (10.0, 65.0))}


def evaluate(code, proj, Z, A, E, quiet=False):
    (amin, amax), (emin, emax) = FIT_RANGE[code]
    if not quiet:
        if not amin <= A <= amax:
            warn(f"A={A:g} is outside the {code.upper()} fitted mass range "
                 f"{amin}-{amax}; this is extrapolation.")
        if not emin <= E <= emax:
            warn(f"E={E:g} MeV is outside the {code.upper()} fitted energy range "
                 f"{emin}-{emax} MeV; this is extrapolation.")
    if code == "kd02":
        return kd02(1 if proj == "n" else 2, Z, A, E)
    return ch89(0 if proj == "n" else 1, Z, A, E)


# --------------------------------------------------------------------------
# output
# --------------------------------------------------------------------------
def fmt_fresco(p, code, proj, Z, A, label, E, kp=1, spin_orbit=True):
    f = lambda x: f"{x:.6f}"
    zp = 0 if proj == "n" else 1
    lines = [
        f"! {code.upper()} global OMP, {proj} + {label}, E_lab = {E} MeV",
        f"! target Z={Z} A={A};  ap=0 forces R = r0*At^(1/3), the convention"
        f" both {code.upper()} and this script use.",
    ]
    if zp == 0:
        lines.append("! neutron projectile: rc is unused but the type=0 line"
                     " must still be present.")
    lines += [
        f" &POT kp={kp} type=0 ap=0.000 at={A:.3f} rc={f(p['rc'] if p['rc'] else 1.200)} /",
        f" &POT kp={kp} type=1 p1={f(p['V'])} p2={f(p['rv'])} p3={f(p['av'])}"
        f" p4={f(p['W'])} p5={f(p['rw'])} p6={f(p['aw'])} /",
        f" &POT kp={kp} type=2 p4={f(p['Wd'])} p5={f(p['rwd'])} p6={f(p['awd'])} /",
    ]
    if spin_orbit:
        lines.append(
            f" &POT kp={kp} type=3 p1={f(p['Vso'])} p2={f(p['rso'])} p3={f(p['aso'])}"
            f" p4={f(p['Wso'])} p5={f(p['rwso'])} p6={f(p['awso'])} /")
    lines.append(" &pot /")
    return "\n".join(lines)


def fmt_table(p, code, proj, label, E):
    out = [f"{code.upper()}  {proj} + {label}  E_lab = {E} MeV",
           f"{'term':<14}{'depth':>12}{'r':>10}{'a':>10}"]
    rows = [("real volume", "V", "rv", "av"),
            ("imag volume", "W", "rw", "aw"),
            ("imag surface", "Wd", "rwd", "awd"),
            ("real spin-orbit", "Vso", "rso", "aso"),
            ("imag spin-orbit", "Wso", "rwso", "awso")]
    for name, d, r, a in rows:
        out.append(f"{name:<14}{p[d]:>12.5f}{p[r]:>10.5f}{p[a]:>10.5f}")
    out.append(f"{'Coulomb rc':<14}{'':>12}{p['rc']:>10.5f}")
    for extra in ("Ef", "Ecoul"):
        if extra in p:
            out.append(f"# {extra} = {p[extra]:.5f} MeV")
    out.append("# radii are reduced: R = r * A_target^(1/3)")
    return "\n".join(out)


# --------------------------------------------------------------------------
# selftest: values pinned against the reference Fortran
# --------------------------------------------------------------------------
REF = [
    # code, proj, Z, A, E, {term: value}
    ("kd02", "n", 40, 90, 50.0, dict(V=3.52745232840509e1, rv=1.21343729971235,
     av=6.64416999963578e-1, W=4.76045094564224, Wd=3.79359457368308,
     rwd=1.27136968601378, awd=5.29696010373300e-1, Vso=4.89227835015655,
     rso=1.04102563940947, Wso=-3.69963635034609e-1, rc=0.0)),
    ("kd02", "n", 6, 12, 100.0, dict(V=2.55477975284590e1, W=8.54376405860909,
     Wd=1.40870504651899, Vso=3.82240307783717, Wso=-1.00678559902166)),
    ("kd02", "p", 40, 90, 50.0, dict(V=4.16495727992617e1, W=5.18999382890647,
     Wd=4.91344329353643, awd=5.65545004094020e-1, Vso=4.92630351911307,
     rc=1.23989500249849)),
    ("kd02", "p", 82, 208, 25.0, dict(V=5.33598902967944e1, W=1.71846316737771,
     Wd=9.79598258672243, rc=1.21963389857862)),
    ("kd02", "p", 20, 40, 65.0, dict(V=3.51067049083420e1, W=7.13654881513690,
     Wd=3.18854959228917, rc=1.28536690319541)),
    ("ch89", "n", 40, 90, 50.0, dict(V=3.64944444444444e1, rv=1.19979252874384,
     av=0.69, W=5.60503626205268, rw=1.23627938698850, Wd=3.25214457555584)),
    ("ch89", "n", 40, 90, 30.0, dict(V=4.24744444444444e1, W=3.29553615155067,
     Wd=4.32361547028612)),
]


# Tolerance is 2e-7 rather than machine epsilon for a specific, understood reason:
# the reference kd02.f is single precision wherever Fortran lets it be. The declared
# variables are real*8, but that does not make the arithmetic double: the literals are
# truncated (59.30 enters as 59.2999992370605), and some subexpressions are evaluated
# in single precision before ever meeting a real*8, because 1./3. is a single-precision
# divide and real(N-Z) carries no kind argument so it drops to real(4). Together these
# put a relative ~1e-8 error on essentially every KD02 quantity. ch89.f suffixes every
# constant with d0, which is why CH89 reproduces to machine precision here.
#
# Verified rather than assumed: neutron V involves no cube root at all (it is built
# only from ef, v1..v4) yet still deviates, so the cube-root literal is one instance
# and not the mechanism. Recompiling kd02.f with -fdefault-real-8, which promotes
# those literals to double, reproduces this module to 16 digits.
#
# So the reference values below are what the production Fortran actually returns,
# and this module is the more accurate of the two. At the three or four physically
# meaningful digits of a global optical potential the difference is irrelevant.
# Anything above this floor is a real bug, not the literal-precision artifact.
TOL = 2e-7


def selftest(verbose=True):
    worst, worst_at, nfail, nchk = 0.0, "", 0, 0
    for code, proj, Z, A, E, ref in REF:
        p = evaluate(code, proj, Z, A, E, quiet=True)
        for key, want in ref.items():
            nchk += 1
            got = p[key]
            rel = (abs(got - want) / abs(want)) if abs(want) > 1e-12 else abs(got - want)
            if rel > worst:
                worst, worst_at = rel, f"{code} {proj}+{A} @ {E} MeV, {key}"
            if rel > TOL:
                nfail += 1
                print(f"FAIL {code} {proj}+{A}(Z={Z}) {E} MeV  {key}: "
                      f"got {got!r} want {want!r} (rel {rel:.3e})")
    if verbose:
        print(f"selftest: {nchk} values checked against the reference Fortran, "
              f"{nchk - nfail} passed (tolerance {TOL:g})")
        print(f"worst relative deviation {worst:.3e} at {worst_at}")
        print("  KD02 differs from the reference Fortran at the 1e-8 level: that "
              "kd02.f is single precision wherever Fortran allows, in unsuffixed "
              "literals and in subexpressions such as real(N-Z), which drops to "
              "real(4). ch89.f suffixes every constant with d0 and matches exactly.")
    return nfail == 0


def main():
    ap = argparse.ArgumentParser(
        description="Global nucleon optical potentials as FRESCO &POT blocks.")
    ap.add_argument("--code", choices=sorted(CODES), help="parameterization")
    ap.add_argument("--proj", choices=["n", "p"], help="projectile")
    ap.add_argument("--target", help="e.g. 90Zr, Zr-90, or '40,90' as Z,A")
    ap.add_argument("--energy", type=float, help="laboratory energy in MeV")
    ap.add_argument("--format", choices=["fresco", "table", "json"],
                    default="fresco")
    ap.add_argument("--kp", type=int, default=1, help="FRESCO potential index")
    ap.add_argument("--no-spin-orbit", action="store_true",
                    help="omit the type=3 term (matches the reference ch89.f behaviour)")
    ap.add_argument("--selftest", action="store_true",
                    help="verify against values pinned from the Fortran")
    a = ap.parse_args()

    if a.selftest:
        sys.exit(0 if selftest() else 1)
    missing = [f for f in ("code", "proj", "target", "energy")
               if getattr(a, f) is None]
    if missing:
        ap.error("missing required argument(s): " + ", ".join("--" + m for m in missing))

    Z, A, label = parse_target(a.target)
    if a.energy <= 0:
        raise SystemExit("energy must be positive")
    p = evaluate(a.code, a.proj, Z, A, a.energy)

    if a.format == "json":
        print(json.dumps({"code": a.code, "projectile": a.proj, "Z": Z, "A": A,
                          "target": label, "E_lab": a.energy,
                          "radius_convention": "R = r * A_target^(1/3)",
                          "parameters": p}, indent=2))
    elif a.format == "table":
        print(fmt_table(p, a.code, a.proj, label, a.energy))
    else:
        print(fmt_fresco(p, a.code, a.proj, Z, A, label, a.energy,
                         kp=a.kp, spin_orbit=not a.no_spin_orbit))


if __name__ == "__main__":
    main()

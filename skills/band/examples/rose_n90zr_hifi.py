"""rose high-fidelity solver on the n+90Zr KD02 50 MeV case that FUSION's FRESCO and COLOSS
skills already pin (skills/coloss/references/verification.md, section 1):

    FRESCO  sigma_R = 1299.19061 mb   (Numerov, real axis)
    COLOSS  sigma_R = 1299.1905  mb   (complex scaling, Lagrange-Laguerre)

Same potential, number for number (skills/fresco/examples/n90Zr-kd02-50MeV.in, radii r0*At^(1/3)),
same integer masses (1.0 and 90.0). A third solver agreeing to 1e-6 relative says rose integrates
the same equation, including the spin-orbit convention, and is converged. It says nothing about
whether KD02 is right.

Usage: python rose_n90zr_hifi.py [l_max] [r_max_fm]     (defaults 40, 30)
"""
import sys
import numpy as np
import rose

A13 = 90.0 ** (1 / 3)
# rose KD_simple order: Vv Rv av  Wv Rwv awv  Wd Rd ad  Vso Rso aso  Wso Rwso awso
alpha = np.array([35.274524, 1.213437 * A13, 0.664417,
                  4.760451, 1.213437 * A13, 0.664417,
                  3.793594, 1.271370 * A13, 0.529696,
                  4.892278, 1.041026 * A13, 0.590000,
                  -0.369964, 1.041026 * A13, 0.590000])
mu = 90.0 / 91.0 * rose.constants.AMU       # integer masses, as in the FRESCO/COLOSS case
Ecm = 50.0 * 90.0 / 91.0
lmax = int(sys.argv[1]) if len(sys.argv) > 1 else 40
rmax = float(sys.argv[2]) if len(sys.argv) > 2 else 30.0

k = np.sqrt(2 * mu * Ecm) / rose.constants.HBARC
space = rose.InteractionSpace(coordinate_space_potential=rose.koning_delaroche.KD_simple,
                              spin_orbit_term=rose.koning_delaroche.KD_simple_so, n_theta=15,
                              mu=mu, energy=Ecm, is_complex=True, l_max=lmax)
solver = rose.SchroedingerEquation.make_base_solver(domain=np.array([1e-6, k * rmax]), s_0=k * rmax - 0.5)
sae = rose.ScatteringAmplitudeEmulator.HIFI_solver(space, base_solver=solver, l_max=lmax,
                                                    s_mesh=np.linspace(1e-6, k * rmax - 0.5, 4000), verbose=False)
xs = sae.exact_xs(alpha)

FRESCO, COLOSS = 1299.19061, 1299.1905
d = abs(xs.rxn - FRESCO) / FRESCO
print(f"rose sigma_R = {xs.rxn:.5f} mb (l_max={lmax}, r_max={rmax} fm); FRESCO {FRESCO}, COLOSS {COLOSS}; "
      f"relative difference to FRESCO {d:.1e}")
ok = d < 1e-6
print("ROSE N90ZR", "OK" if ok else "FAIL")
sys.exit(0 if ok else 1)

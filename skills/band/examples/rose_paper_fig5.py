"""Reproduce the (15,15) point of Fig. 5 of the ROSE paper: Odell et al., Phys. Rev. C 109, 044612
(2024), arXiv:2312.12426.

Paper setup (Sec. III.1): n+40Ca at 14 MeV c.m., l_max = 10, 200 training and 100 test parameter
sets by Latin hypercube in +-30% of the Table 1 prior means, emulator (n_phi, n_U) = (15, 15),
high-fidelity reference at Runge-Kutta tolerance 1e-9. Claim (Sec. III.2): "in the worst case an
error of 1%".

Which error: Eq. (30) and the Fig. 5 caption define accuracy as the MAXIMUM relative error over
1..179 deg. That is the metric gated here, on the median test point, which is what the centre of
the Fig. 5 cloud shows. The worst case does NOT reproduce on that metric: the worst of 100 test
points is set by one deep cross-section minimum and came out 0.7% to 5% across seeds, against the
paper's "in the worst case an error of 1%". The current rose.training.CAT_plot draws the MEDIAN
over angles instead, on which the worst case is about 0.13%; whether the published figure used
that metric cannot be established from the paper, so it is printed for reference only.

Built exactly as the paper's tutorial does (rose.training.build_sae, EIM trained over the box,
scale=True, use_svd=True). A bare from_train with default options gave ~6% median error on the
same sets: the training options matter more than the basis size.

Usage: python rose_paper_fig5.py [seed]      (about 2-3 minutes)
"""
import sys
import numpy as np
from numba import njit
import rose
from rose.koning_delaroche import woods_saxon_safe, woods_saxon_prime_safe, thomas_safe
from rose.constants import MASS_PION
from rose.training import sample_params_LHC, build_sae, CATPerformance

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 13
# Table 1 prior means, in the paper's Eq. (4) order: Vv Wv Wd Vso Rv Rd Rso av ad aso
prior = np.array([45, 2, 5, 5, 4, 4, 4, 0.5, 0.5, 0.5], float)


@njit
def pot(r, w):  # Eq. (5) without the spin-orbit term
    Vv = w[0]; Wv = w[1]; Wd = w[2]; Rv = w[4]; Rd = w[5]; av = w[7]; ad = w[8]
    return (-(Vv + 1j * Wv) * woods_saxon_safe(r, Rv, av)
            - 1j * (-4 * ad) * Wd * woods_saxon_prime_safe(r, Rd, ad))


@njit
def so(r, w, lds):  # Eq. (5) spin-orbit term, (hbar/m_pi c)^2 = 2 fm^2
    return lds * w[3] / MASS_PION**2 * thomas_safe(r, w[6], w[9])


train = sample_params_LHC(200, prior, scale=0.3, seed=seed)
test = sample_params_LHC(100, prior, scale=0.3, seed=seed + 1)
bounds = np.array([prior * 0.7, prior * 1.3]).T
mu, E = 40.0 / 41.0 * rose.constants.AMU, 14.0
angles = np.radians(np.linspace(1, 179, 179))
base = rose.InteractionEIMSpace(coordinate_space_potential=pot, n_theta=10, mu=mu, energy=E,
                                is_complex=True, spin_orbit_term=so, training_info=bounds, l_max=10)
solver = rose.SchroedingerEquation.make_base_solver(s_0=6 * np.pi, rk_tols=[1e-9, 1e-9],
                                                   domain=np.array([1e-8, 8 * np.pi]))
_, sae = build_sae((15, 15), base, train, bounds, angles=angles, base_solver=solver,
                   scale=True, use_svd=True, l_max=10)
hf = np.array([sae.exact_dsdo(a) for a in test])
cat = CATPerformance(sae.emulate_dsdo, list(test), hf, n_timing=3)
med, mx = cat.median_rel_err, cat.rel_err.max(axis=1)
print(f"seed {seed}, 100 test points")
print(f"  median-over-angle metric (current CAT_plot):           median {np.median(med):.2e}, worst {med.max():.2e}")
print(f"  Eq. (30) metric (max over angles; the paper's, gated): median {np.median(mx):.2e}, worst {mx.max():.2e}")
print(f"  emulator {1e3 * np.mean(cat.times):.2f} ms per call (paper: 1-3 ms)")
ok = np.median(mx) <= 0.01      # paper's own metric, typical test point: at or below 1%
print(f"  worst case on the paper's metric: {mx.max():.1%} (paper: about 1%; not reproduced, see header)")
print("ROSE FIG5", "OK" if ok else "FAIL")
sys.exit(0 if ok else 1)

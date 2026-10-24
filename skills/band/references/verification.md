# BAND skill: verification record

Environment: `install_band.sh`, surmise 1.0.0, Taweret 1.3.0, nuclear-rose 1.1.8, jitr 2.3,
numpy 2.3.5. macOS 26.6 ARM64 (uv, Python 3.12.11), 2026-10-23; Linux x86-64 (conda-forge
route, Python 3.12) in section 8. Every number below is
printed by a script in `examples/` and gated by `scripts/verify_band.sh`.

## 1. rose high-fidelity solver against FRESCO and COLOSS (cross-code)

FUSION already pins n+90Zr elastic with KD02 at Elab = 50 MeV, integer masses, as a matched
FRESCO/COLOSS case (`skills/coloss/references/verification.md`, section 1). rose was given the
same potential number for number (`skills/fresco/examples/n90Zr-kd02-50MeV.in`), radii converted to
absolute r0·90^(1/3), mu = (90/91)·amu, E_cm = 50·90/91 MeV.

| solver | method | sigma_R (mb) |
|---|---|---|
| FRESCO | Numerov, real axis | 1299.19061 |
| COLOSS | complex scaling, Lagrange-Laguerre | 1299.1905 |
| rose 1.1.8 | Runge-Kutta (scipy solve_ivp, tol 1e-9) | **1299.19050** |

Relative difference to FRESCO 8.8e-8. Convergence: l_max 30, 40, 50 give 1299.19050; r_max 22,
30, 40 fm give 1299.19049-1299.19050; l_max 25 gives 1299.19026; **rose's default l_max 15 gives
1294.37952** (0.37% low, silently). Three solvers built on different methods agreeing to seven
figures confirms rose's spin-orbit convention equals FRESCO's (Thomson-Nunes,
(hbar/m_pi c)^2 = 2 fm^2) and that it is converged. Numerics, not physics: KD02 itself carries
three or four meaningful digits.

## 2. rose emulator: the ROSE paper's Fig. 5 claim

Odell et al., PRC 109, 044612 (2024), Sec. III.1-2, setup read from the LaTeX source: n+40Ca at
14 MeV c.m., l_max 10, 200 training / 100 test LHS sets in ±30% of Table 1 prior means,
(n_phi, n_U) = (15,15), reference at RK tolerance 1e-9. Claim: "in the worst case an error of 1%".

The paper's Eq. (30) and the Fig. 5 caption define accuracy as the MAXIMUM relative error over
1-179 deg. The current `rose.training.CAT_plot` draws `CATPerformance.median_rel_err`, the MEDIAN
over angles; whether the published figure was made that way cannot be established from the paper.

| seed | max-over-angle (paper's): median / worst | median-over-angle: median / worst | emulator time |
|---|---|---|---|
| 13 | 9.5e-4 / 4.2e-2 to 4.9e-2 | 1.5e-4 / 1.2e-3 | 0.46-0.48 ms |
| 101 | 1.1e-3 / 6.7e-3 | 1.7e-4 / 1.4e-3 | 0.45 ms |

What reproduces: the typical accuracy (median test point 0.1% on the paper's own metric, the
centre of the Fig. 5 cloud) and the 1-3 ms per call. What does not: "in the worst case an error
of 1%" on the paper's metric; the worst of 100 test points is one deep minimum and reaches 0.7%
to 5% depending on the seed. It holds only on the median-over-angle metric (worst 0.13%), which
an earlier version of this skill gated on; the Codex pass rejected that as substituting a weaker
metric, and it was right. Gate now: median test point <= 1% on the paper's metric.

How the first attempt failed, kept because it is the likely user error: built with a bare
`ScatteringAmplitudeEmulator.from_train` (no `scale`/`use_svd`, EIM on the training points, solver
defaults), the same sets gave a median max-over-angle error of 6.1% and a worst of 21%. Rebuilding
exactly as the paper's tutorial does (`rose.training.build_sae`, EIM over the box,
`scale=True, use_svd=True`, `s_0 = 6 pi`) fixed it. Training is not bit-reproducible between runs
(the third figure of the errors moves for a fixed seed).

## 3. surmise: exact Gaussian posterior (analytic)

Linear model f = th0 + th1·x on 15 points in [0,1], th_true = (0.3, 0.8), noise sigma = 0.05,
prior N(0.5, 0.5^2) on each. PCGP emulator on 80 prior draws (error at the posterior 4e-5, far
below sigma), directbayes, Metropolis-Hastings 40,000 + 5,000 burn-in, step 2.4/sqrt(2) times
the exact posterior widths. Gate (a regression bar, not a proof): batch-means ESS > 500,
|mean - exact| < 3 batch-means MC standard errors, width within 10%, posterior correlation
(exact -0.850) within 0.05.

| seed | ESS (batch means) | mean offset (MC std errors) | width ratio | correlation |
|---|---|---|---|---|
| 7 | 2403, 2582 | 0.90, 0.59 | 1.010, 1.002 | -0.850 |
| 11 | 1969, 2176 | 0.07, 0.41 | 1.020, 1.008 | -0.851 |
| 23 | 2581, 2606 | 0.01, 0.02 | 0.986, 0.997 | -0.845 |

The first version estimated ESS by an autocorrelation sum cut at 0.05 and checked only the
marginals; Codex showed a chain with correct marginals and correlation 0.003 passed it, and that
the cutoff overstates ESS for a slowly mixing component (12,000 against an asymptotic 293).

With surmise's default `stepParam=None` (proposal width = prior spread, 0.5) the same case gave
ESS 44-115 from 40,000 samples and, for seed 11, a mean off by 0.3 posterior widths and widths
16% low: a sampler-tuning failure, not an emulator or calibration one.

## 4. Taweret: the SAMBA toy against the paper's equations (analytic)

Semposki, Furnstahl, Phillips, PRC 106, 044002 (2022), arXiv:2206.04116, equations taken from
the source. 40 points 0.05 <= g <= 1, N_s = N_l = 3.

| quantity | compared with | max relative difference |
|---|---|---|
| exact F(g) | Bessel closed form (Eq. 1) vs our quadrature | 1.1e-14 |
| Taweret `TrueModel` | Bessel closed form | 2.9e-13 |
| `Loworder(3)` mean | Eq. 3 series | 0 |
| `Highorder(3)` mean | Eq. 4 series | 6.1e-15 |
| `Multivariate` mixed mean, width | precision weighting from the two models' means and variances | 0, 0 |
| model widths, g-dependence | informative error models, sigma_s = 256 g^4 cbar, sigma_l = (4g)^-4.5 dbar/2 | spread 3.6e-16; cbar = 0.332, dbar = 2.439 (order one, as the paper requires) |
| model widths, size | SAMBA's own arrays (rows 2-3 of the reference file shipped with Taweret's tests) | 2.0e-16, 0 |

The first version checked the mixing algebra with Taweret's own widths, so widths scaled by 100
still passed (Codex); the widths are now pinned by the paper's equations and by SAMBA.

Physics, now gated: for 0.15 < g < 0.5 the worst error of the mixed curve (0.28) must be under
half that of either series (1.24 weak, 2.20 strong).

## 5. Shipped suites (`verify_band.sh --full`)

- `pytest --pyargs surmise.tests`: **303 passed**. From a source checkout the same tests show 92
  failed and 20 errors, all `ModuleNotFoundError: surmise.emulationsupport.matern_covmat`,
  because pytest imports the uncompiled tree; the suite must run against the installed package.
- `pytest --pyargs Taweret.tests`: **28 passed**, including comparison with arrays from SAMBA,
  the paper's companion code.

## 6. Guards shown to fire

Each disabled or provoked once, confirming exactly that check flips:
- rose at l_max 15: `ROSE N90ZR FAIL`, exit 1.
- an example printing its OK line but exiting 1: reported FAIL, `VERIFY FAILED`.
- a suite expecting 304 passed instead of 303 (edit confirmed applied): FAIL, `VERIFY FAILED`.

After the Codex pass, each new guard provoked the same way:
- Taweret widths scaled by 100 (monkeypatched `evaluate`): cbar 33, dbar 244, SAMBA mismatch 99,
  `TAWERET SAMBA FAIL`, exit 1.
- surmise chain with one column permuted (marginals kept, correlation 0.003): FAIL, exit 1.
- `BAND_ROOT_DIR=$HOME/.` and a symlink to $HOME: refused after canonicalisation. A pre-existing
  `venv/` without the installer's marker: `--force` refuses to delete it.
- a module the examples import removed from the environment: no longer "already installed".

## 8. Second platform: Linux x86-64 (heliumx, Ubuntu 24.04, 2026-10-24)

`verify_band.sh --full` from an empty root: **VERIFY OK**. Same numbers where deterministic
(rose 1299.19050 mb, Taweret exact), statistically equivalent where not (surmise correlation
-0.854; Fig. 5 median test point 0.1%, worst on the paper's metric 4.5%). Suites 303 and 28.

Getting there exposed four install defects, all fixed in `install_band.sh` / `run_band.sh`:
1. `python3 -m venv` fails on Ubuntu without `python3.12-venv` (needs sudo); the script died
   without saying why, and the half-made venv then blocked every rerun. Now: a clear message,
   cleanup of anything this run created, and fall-through to the next route.
2. `uv` sat in `~/.local/bin`, off PATH for a non-interactive ssh shell; now looked for there.
3. **openbt** (Taweret dependency, source-only on PyPI) needs an MPI wrapper (`mpic++`) and
   Eigen; the server had neither and could not reach Meson's WrapDB to fetch Eigen. The conda
   route (conda-forge `python=3.12 eigen pkg-config openmpi cxx-compiler`) builds it.
4. The conda-built `openbtcli` then failed under `mpirun` with exit 127, `libmpi.so.40` not
   found: no rpath. Built now with `-Wl,-rpath,<env>/lib`; `run_band.sh` also puts the
   environment's `bin/` (where `mpirun` lives) first on PATH. Without these, Taweret's tree
   mixing fails although every import succeeds.

## 7. Codex adversarial pass (2026-10-23)

Verdict "do not ship unchanged", nine findings, all applied: the Fig. 5 metric substitution
(section 2), the spin-orbit prose (rose passes 2l·s, not l·s; the code was right, the text would
have halved the term), pytest exit status ignored by the suite check, a `$HOME/.` bypass of the
deletion guard, `pins_ok` accepting `.post1` versions and missing modules, the surmise and Taweret
gates (sections 3-4), the `stepParam=None` description, and Smooth Emulator's licence (GPL v3 in
its LICENSE.md). Confirmed by the same pass: the n+90Zr mapping (ap=0 radii, +4ia Wd f', masses,
E_cm), the exact posterior, the SAMBA transcriptions, the np.trapz and PUQ claims, the APIs and
licences, and jitr 2.3's vanishing spin-flip Clebsch-Gordan factors.

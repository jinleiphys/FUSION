---
name: band
description: >-
  Bayesian uncertainty quantification for nuclear physics with the BAND framework (Bayesian Analysis of Nuclear Dynamics, bandframework v1.0.0): calibrate a model's parameters against data with surmise, build a fast reduced-basis emulator of nucleon-nucleus elastic scattering with rose, and combine several models' predictions with Bayesian model mixing in Taweret; also routes to the other BAND tools (jitr, Bfrescox, OpenBT, parMOO, PUQ, pybmc, LCGP, mooGP, Smooth Emulator). Use for Bayesian calibration, 贝叶斯校准, 参数后验, posterior, MCMC, emulator, 仿真器, surrogate model, Gaussian process emulator, reduced basis, reduced-order model, ROSE, optical potential calibration, 光学势不确定度, uncertainty quantification, UQ, 不确定度量化, model mixing, 模型混合, Bayesian model averaging, BMM, Taweret, surmise, BAND framework, experimental design. For running FRESCO itself use the `fresco` skill; for fitting a FRESCO deck by chi-squared use `sfresco`.
---

# BAND framework: calibration, emulation and model mixing

BAND (Phillips et al., J. Phys. G 48, 072001 (2021)) is a collection of separately
maintained tools, not one program. This skill installs the three core Python tools in an
isolated pinned environment and carries a verified recipe for each; the rest are routed in
`references/tools.md`.

| Tool | Job | Version here | Paper / citation | Licence |
|---|---|---|---|---|
| **rose** (`nuclear-rose`) | reduced-basis emulator for nucleon-nucleus elastic scattering with a local optical potential (also its own Runge-Kutta solver) | 1.1.8 | Odell et al., Phys. Rev. C 109, 044612 (2024) | GPL-3.0 |
| **surmise** | emulators (PCGP family) and Bayesian calibration (directbayes + MCMC samplers) | 1.0.0 | surmise 1.0.0 Users Manual (Plumlee, Sürer, Wild, Chan, O'Neal, 2026); no journal paper of its own | MIT |
| **Taweret** | Bayesian model mixing: bivariate linear, multivariate (precision-weighted / GP), BART trees | 1.3.0 | Ingles et al., J. Open Source Softw. 9, 6175 (2024) | MIT |

Citations verified on INSPIRE 2026-10-23. Cite the BAND framework too (its README gives the
BibTeX for the v1.0.0 technical report).

## Prime rules (do not skip)

1. **Work inside the BAND environment.** `scripts/run_band.sh script.py` installs it on first use
   (`~/.cache/fusion/band/venv`) and runs your script there. Never `pip install` these into the
   user's own Python: rose pins `jitr<2.4`, numpy must stay below 2.4 (see 3), and Taweret
   drags in bilby and OpenBT. Routes, first that works: `uv` (about a minute), a Python
   3.10-3.13 `venv`, then **conda/mamba from conda-forge** (`BAND_USE_CONDA=1` forces it).
   The hard part is **openbt**, a Taweret dependency that PyPI ships as source only: it needs an
   MPI compiler wrapper (`mpic++`) and Eigen (or network access to Meson's WrapDB to fetch it).
   A Mac with Homebrew `open-mpi` builds it directly; a lab server without MPI, or one that
   cannot reach WrapDB, needs the conda route, which supplies Eigen, OpenMPI and a compiler.
2. **Verified number before physics.** Run `scripts/verify_band.sh` once on a new machine
   (20 s; `--paper` adds the ROSE paper reproduction, `--full` both shipped test suites).
3. **numpy below 2.4.** rose 1.1.8 calls `np.trapz`, removed in numpy 2.4, while its
   requirements allow numpy < 2.5; an unpinned install crashes in the scaled-basis training
   that the ROSE tutorials use. The install script pins it.
4. **An emulator error is not a physics error.** Every emulator here is checked against its own
   high-fidelity solver. Whether the optical potential, the error model or the prior is right is
   a separate question, and no number in this skill answers it.

## rose: emulating elastic scattering

Workflow, as in the paper and its tutorials (full working script: `examples/rose_paper_fig5.py`):

1. Write the potential as numba-compiled functions `V(r, alpha)` and `V_so(r, alpha, lds)`
   (`@njit` is required; a plain Python function fails with "Cannot determine Numba type").
   `rose.koning_delaroche.KD_simple` / `KD_simple_so` take a 15-vector
   `Vv Rv av Wv Rwv awv Wd Rd ad Vso Rso aso Wso Rwso awso` with **absolute radii in fm**
   (r0·A^(1/3) already applied). **The third argument `lds` is 2l·s, not l·s**:
   rose passes `j(j+1) - l(l+1) - 3/4`, which is `l` or `-(l+1)`, whatever its docstrings say.
   `KD_simple_so` returns `lds · Vso · (hbar/m_pi c)^2 · (1/r) df/dr` with
   `(hbar/m_pi c)^2 = 2 fm^2`, i.e. the ROSE paper's Eq. (5) and FRESCO's convention: the same
   numbers give the same cross section (below). A hand-written spin-orbit term that treats
   `lds` as l·s and multiplies by 2 itself doubles the interaction.
2. `rose.InteractionEIMSpace(..., mu=, energy=E_cm, training_info=bounds, l_max=)`; train with
   `rose.training.build_sae((n_phi, n_U), base, theta_train, bounds, base_solver=...,
   scale=True, use_svd=True)` on Latin-hypercube samples (`rose.training.sample_params_LHC`).
3. `sae.emulate_xs(alpha)` / `emulate_dsdo(alpha)`; check against `sae.exact_*` on held-out
   points with `rose.training.CATPerformance` before using it.

Traps:
- **`l_max` defaults to 15 and nothing warns.** For n+90Zr at 50 MeV that gives
  sigma_R = 1294.38 mb against the converged 1299.19, 0.37% low. Converge `l_max` (here 30+).
- **`energy` is centre-of-mass, `mu` is the reduced mass in MeV.** Choose masses on purpose:
  integer versus physical masses moves the n+90Zr sigma_R by 2.45 mb (1.9e-3).
- **Training options matter more than basis size.** The same (15,15) emulator built with a bare
  `from_train` and default options had about 6% median error; with the tutorial's
  `build_sae(..., scale=True, use_svd=True)` and EIM trained over the box, 0.015%.
- **Quote which accuracy metric.** The paper's Eq. (30) and Fig. 5 caption define accuracy as
  the maximum relative error over 1-179 deg; the current `rose.training.CAT_plot` draws the
  median over angles. For the paper's (15,15) setup the typical test point is about 0.1% on
  the maximum metric, but the worst of 100 is set by one deep minimum and ranges 0.7% to 5%
  between seeds, above the paper's "worst case 1%". On the median metric the worst is 0.13%.
- Training is not bit-deterministic run to run (third significant figure of the error moves);
  fix seeds for the parameter samples and quote errors to one figure.
- rose is for elastic nucleon-nucleus scattering with a local potential. Its dependency **jitr**
  is a separate R-matrix solver; it has been found to drop the spin-flip term of the (p,n)
  charge-exchange cross section (confirmed independently with FRESCO), so check any jitr (p,n)
  observable against another code before use.

## surmise: calibration

Pattern (full working script: `examples/surmise_linear_posterior.py`):

```python
from surmise import set_RNG; from surmise.emulation import emulator; from surmise.calibration import calibrator
set_RNG(np.random.default_rng(seed))            # surmise 1.0 refuses to run without it
emu = emulator(x=x, theta=theta_train, f=f, method='PCGP')     # f has shape (n_x, n_theta)
cal = calibrator(emu=emu, y=y, x=x, thetaprior=Prior, method='directbayes', yvar=sigma**2 * ones,
                 args={'sampler': 'metropolis_hastings', 'nSamples': 40000, 'nBurnSamples': 5000,
                       'theta0': None, 'stepType': 'Normal', 'stepParam': step, 'verbose': False})
chain = cal.info['thetarnd']
```

`Prior` is a class with static `lpdf(theta) -> (n,1)` and `rnd(n) -> (n, d)`. directbayes
requires every Metropolis-Hastings field above, even the ones that may be `None`.

Traps:
- **`stepParam=None` sets the proposal width to the spread of `draw_func` samples**, which in
  directbayes are prior draws (plus emulator training points or earlier posterior samples when
  present). In a fresh calibration that is roughly the prior's spread; when the data constrain a
  parameter well, it is many times the posterior width and the chain barely moves. In the
  worked example, 40,000 samples gave an effective sample size of 44-115 and a 0.3-sigma error
  in the posterior mean.
  Run a short pilot, set `stepParam` to about 2.4/sqrt(d) times the pilot's posterior widths,
  and **always report the effective sample size**, not the chain length.
- Check the emulator where the posterior lives (`emu.predict` at the posterior mean versus the
  model) before trusting a calibration; a good emulator over the prior box can still be poor
  in a small posterior region.
- surmise also offers `method='nuclear-ROSE'`, the hook the ROSE paper uses to calibrate with a
  rose emulator.
- **Run its tests as `pytest --pyargs surmise.tests`.** Run from a source checkout, pytest
  imports the uncompiled tree and reports 92 failures and 20 errors that are not real.

## Taweret: model mixing

Use when two or more models are each trustworthy in different regions (a weak- and a
strong-coupling expansion, two EOS models, low- and high-energy theories). Methods:
`Taweret.mix.gaussian.Multivariate` (precision-weighted: f = Z^-1 sum f_k/v_k, var = Z^-1,
local in the input, needs each model's own uncertainty), `bivariate_linear` (a parametric
weight function, sampled with bilby), `gp_bmm` (a Gaussian process added as a third model,
as in SAMBA) and `trees` (Bayesian additive regression trees through OpenBT). The models implement
`Taweret.core.base_model.BaseModel` (`evaluate`, `log_likelihood_elementwise`, `set_prior`).

Worked case: `examples/taweret_samba_mixing.py`, the zero-dimensional phi^4 partition function
of Semposki, Furnstahl and Phillips, Phys. Rev. C 106, 044002 (2022) (SAMBA), re-derived from
the paper's equations. Traps:
- Precision weighting is only as good as the error models: an underestimated variance in one
  model takes over the mixture where it should not. In the gap between expansions the mixed
  curve is better than either series but still off by about 0.3 in F(g) at N=3.
- `TrueModel().evaluate(g)` returns `(value, error)`, not the value alone.

## Benchmark

`scripts/verify_band.sh` (details and numbers in `references/verification.md`):

| Check | Anchor | Result |
|---|---|---|
| rose high-fidelity solver, n+90Zr KD02 50 MeV, integer masses | FRESCO 1299.19061, COLOSS 1299.1905 mb (FUSION's own matched case) | 1299.19050 mb, 8.8e-8 relative; flat for l_max 30-50, r_max 22-40 fm |
| rose emulator, PRC 109 044612 Fig. 5 (15,15) | Eq. (30) accuracy, "worst case about 1%" | median test point 0.09-0.11% (reproduced), worst 0.7-5% (**not** reproduced; 0.13% on the median-over-angle metric), 0.46 ms/call, two seeds |
| surmise PCGP + directbayes | exact Gaussian posterior | means within 0.9 MC errors, widths within 2%, three seeds |
| Taweret SAMBA toy | paper's Eqs. 1, 3, 4, 18-20 | F(g) to 3e-13, series and mixing exact |
| shipped suites (`--full`) | surmise 303, Taweret 28 (vs SAMBA arrays) | all pass |

Tier: **tier 1 for rose's high-fidelity solver** (an independent cross-code number to 1e-7) and
**partial for its emulator** (the paper's typical accuracy reproduces, its worst-case claim does
not on its own metric); **tier 2 for surmise and Taweret**, pinned by closed-form results and their shipped
suites (Taweret's compares against the SAMBA companion code), since neither paper prints a
reproducible number of its own. Verified on macOS 26 ARM64 (uv route) and Linux x86-64 Ubuntu 24.04 (conda route), Python 3.12;
Codex adversarial pass applied (`references/verification.md`, sections 7-8).

## Other BAND tools

`references/tools.md`: what each of the remaining tools is for, where it installs from, and
its traps (notably: `pip install PUQ` installs an unrelated package; jitr 3.x conflicts with
rose's `jitr<2.4`, so give it its own environment).

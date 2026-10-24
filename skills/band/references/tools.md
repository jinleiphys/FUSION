# The rest of the BAND framework

BAND framework v1.0.0 (github.com/bandframework/bandframework, BSD-2-Clause) pins each tool
below to a release; the versions are those pins. Licences and PyPI status checked 2026-10-23
against GitHub and PyPI. None of these is installed by `install_band.sh`; install one on request,
into its own environment unless stated, and say which version you installed.

## Software tools

| Tool | What it does | Get it | Licence | Notes |
|---|---|---|---|---|
| **Bfrescox** v0.0.2-alpha | Python wrapper for Frescox (FRESCO with modern Fortran I/O): writes decks, runs, parses | github.com/bandframework/Bfrescox (not on PyPI) | BSD-2-Clause | alpha. For FRESCO itself and its conventions use the `fresco` skill; the BAND use case pairs it with surmise (breakup-calibration-demo, below) |
| **jitr** v3.0.1 | JIT-compiled Lagrange-mesh R-matrix solver for parametric reaction-model calibration | `pip install jitr` | BSD-3-Clause | rose 1.1.8 needs `jitr<2.4`, so jitr 3 goes in a separate environment. Its (p,n) charge-exchange cross section has been found to drop the spin-flip term (confirmed with FRESCO): cross-check any (p,n) result |
| **surmise** v1.0.0 | emulation + calibration | installed here | MIT | see SKILL.md |
| **Taweret** v1.3.0 | Bayesian model mixing | installed here | MIT | see SKILL.md |
| **OpenBT** v1.2.0 | Bayesian additive regression trees (C++ with Python and R front ends): regression, model mixing, sensitivity, multiobjective optimisation | `pip install openbt` (already present as a Taweret dependency) | MIT | the engine behind `Taweret.mix.trees` |
| **LCGP** v1.1.1 | latent-component Gaussian process emulator for stochastic simulators | `pip install lcgp` | MIT | |
| **mooGP** v1.0.0 | multi-output orthogonal GP emulator for vector-valued outputs | `pip install moogp` | GPL-3.0 | |
| **parMOO** v0.5.1 | parallel multiobjective simulation optimisation | `pip install parmoo` | BSD-3-Clause | |
| **PUQ** v0.1.1 | experimental designs tailored to UQ, parallel | **github.com/parallelUQ/PUQ only** | MIT | **`pip install PUQ` installs an unrelated package** (c-PRIMED/puq 2.6.1). Install from the GitHub release |
| **pybmc** v0.4.1 | Bayesian model combination of several predictive models | `pip install pybmc` | MIT | |
| **Smooth Emulator** v1.0.0-beta | simplex sampler, emulator trainer and MCMC explorer (C++) | github.com/bandframework/SmoothEmulator | GPL-3.0, declared in its `LICENSE.md` (GitHub's detector reports NOASSERTION because the file is prose) | beta; builds from source |

## Examples and uses in the framework

Stand-alone analyses, useful as templates rather than as tools:

- **breakup-calibration-demo** (BANDsoftware_uses): Bfrescox + surmise, Bayesian inference of the
  <8B|7Be+p> ANC from CDCC 8B breakup. The closest worked example to reaction-theory practice.
- **BRICK**: Bayesian R-matrix Inference Code Kit, R-matrix parameters from data (AZURE2-based;
  see the `azure2` skill for the code itself).
- **rose** (also listed as an example), **SaMBA** (the model-mixing sandbox Taweret grew from),
  **neutron-rich-bmm** (GP mixing for the neutron-star EOS), **nuclear_saturation** (Bayesian
  mixture model for the empirical saturation point), **ModelDiscrepancy**, **QGP_Bayes**
  (JETSCAPE parameter inference tutorial), **BMEX** (web app for nuclear-mass model predictions).

Clone the framework with `git clone --recursive https://github.com/bandframework/bandframework`
(submodules need git >= 2.38), or one submodule with `git submodule update --init <path>`.

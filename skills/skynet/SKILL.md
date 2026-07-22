---
name: skynet
description: >-
  Drive SkyNet, the modular nuclear reaction network library of J. Lippuner and L. F. Roberts (ApJS 233, 18 (2017); arXiv:1706.06198; BSD 3-Clause; bitbucket.org/jlippuner/skynet). Evolve nuclide abundances under a full reaction network with a self-heating Helmholtz equation of state, Coulomb screening, and weak/neutrino reactions: r-process nucleosynthesis, rp-process (X-ray bursts), alpha networks, and nuclear statistical equilibrium (NSE). Uses JINA REACLIB rate libraries and webnucleo nuclear data shipped with the code. Use for 跑SkyNet, SkyNet input, reaction network, 反应网络, nucleosynthesis, 核合成, r-process, rp-process, r过程, X-ray burst, NSE, nuclear statistical equilibrium, Saha equation, abundance evolution, network calculation, alpha network, REACLIB, weak rates, neutron star merger, ejecta abundances, self-heating, Coulomb screening, final abundances, isotope yields.
---

# Driving SkyNet

SkyNet integrates the coupled abundance equations of a nuclear reaction network:
given a set of nuclides, a rate library (JINA REACLIB, weak rates, neutrino
reactions), a thermodynamic trajectory or a self-heating equation of state, and
an initial composition, it returns the time evolution and final abundances. It
covers the standard astrophysical networks: the r-process in neutron-star-merger
and supernova ejecta, the rp-process on accreting neutron stars (X-ray bursts),
alpha networks, and nuclear statistical equilibrium (the high-temperature Saha
limit) with Coulomb screening.

Upstream: `bitbucket.org/jlippuner/skynet`, BSD 3-Clause (Caltech), C++11 + a
little Fortran, built with CMake against HDF5 (C++), GSL, and Boost. The methods
paper is Lippuner and Roberts, ApJS 233, 18 (2017), arXiv:1706.06198.

## Prime rules (do not skip)

1. **Content is the verdict, never the exit status.** A network executable can
   exit 0 having printed nothing, or print `nan`/`inf` abundances. `run_skynet.sh`
   parses the abundance and `max error` lines and rejects a run with no finite
   result or any non-finite value; `verify_skynet.sh` pins actual numbers.
2. **This is a TIER 1 skill with a documented macOS caveat.** SkyNet ships a
   CTest suite that self-compares against the authors' own reference values.
   This build reproduces them **19/19 on Linux**. On **macOS it is 17/19**: the
   two exceptions are `StopWatch` (a wall-clock timing self-test, environment
   flaky) and the third `NSE` block (full-network Saha at T9=3, abundances over
   ~200 decades), which is libm-limited (Apple `exp`/`log` give ~7e-3 vs a
   glibc-calibrated 3.5e-5 gate). The identical patched source passes 19/19 on
   Linux, so this is a platform numerical difference, not a build fault. Full
   evidence in `references/verification.md`. Do not "fix" it by loosening the
   Linux gate or by matching a hand-picked number.
3. **The build needs five portability patches on Apple clang.** They are applied
   automatically from `scripts/skynet_macos_portability.patch` and are
   portability only (a `constexpr` literal for `pow`, a glibc guard on FPE
   trapping, a Boost component drop, a dylib link line, one test include), each
   proven behaviour-preserving by the Linux pass. Never edit SkyNet's physics.
   The rationale for each is in `references/failure-modes.md`.
4. **Run each case from its build directory.** CMake copies every case's input
   files (trajectories, initial compositions, reference tables) into
   `$SKYNET_BUILD/tests/<Case>/`, and the nuclear data is found through the
   install prefix baked into the binary. `run_skynet.sh` handles this.
5. **The matrix solver is dense LAPACK.** Accelerate on macOS, system LAPACK on
   Linux, so no Pardiso/MKL/Trilinos/Armadillo license or extra dependency is
   needed. Do not switch solvers to chase performance for a benchmark.
6. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_skynet.sh` clones the repo at a pinned commit, applies the
portability patch, configures with CMake (dense LAPACK, Python bindings and
movie maker OFF), builds, installs, runs an AlphaNetwork probe, and prints four
lines:

```
SKYNET_SRC=<patched source tree>
SKYNET_BUILD=<cmake build dir, holds the case executables>
SKYNET_INSTALL=<install prefix, holds data/ and examples/>
SKYNET_DATA=<install prefix>/data
```

`run_skynet.sh` and `verify_skynet.sh` parse those (or take `SKYNET_BUILD` from
the environment). Requires `git`, `cmake`, `gfortran`, `python3`, and HDF5/GSL/
Boost: `brew install hdf5 gsl boost` on macOS (LAPACK comes from Accelerate);
`apt install libhdf5-dev libgsl-dev libboost-all-dev liblapack-dev` or a conda
env on Linux. A cold build is a few minutes; the fast path re-probes an existing
build in about a second.

## Command line

```bash
bash scripts/install_skynet.sh          # provision and print the SKYNET_* vars
bash scripts/run_skynet.sh [case]       # run one network calculation (default: alpha)
bash scripts/verify_skynet.sh           # tier-1 benchmark (CTest + pinned anchors)
bash scripts/selftest_skynet.sh         # harness guards (14 cases, no real build needed)
```

Cases for `run_skynet.sh`:

| case | calculation |
|---|---|
| `alpha` | alpha-chain network to NSE, analytic check (~1 s) |
| `nse` | NSE (Saha) at fixed T, rho, Ye, three reference blocks |
| `nse-screening` | NSE across a T-rho-Ye grid with Coulomb screening |
| `xrayburst` | full rp-process on an X-ray-burst trajectory (~1-2 min) |
| `neutrino` | network including neutrino reactions |
| `trivial` / `small` | trivial / small hand-checkable networks |
| `inverse` | detailed-balance inverse-rate reconstruction |

## Authoring a custom network

SkyNet is a library, and its native interface is Python (`from SkyNet import *`),
shown by the shipped `examples/r-process.py`: construct a `NuclideLibrary`, a set
of `REACLIBReactionLibrary` rate sets, a `HelmholtzEOS` and `SkyNetScreening`,
then a `ReactionNetwork` and call `Evolve`. The Python bindings need SWIG and are
OFF in this build (they are a portability liability on a very new Python and are
not needed for the benchmark); turn them on with `-DUSE_SWIG=ON` after
`brew install swig`. The field-by-field construction reference, including the C++
driver alternative, is in `references/input-format.md`. Output formats (HDF5
history, abundance and thermodynamic columns) are in `references/output-format.md`.

## Benchmark

The verification, its tier, the cross-build evidence, and exactly what is and is
not claimed are in `references/verification.md`. Headline: X(ni56) from the
analytic alpha network is 1.7794E-02 to five figures on both macOS and Linux, the
NSE Saha block reproduces to < 1e-10 on both, and the full CTest suite is 19/19
on Linux and 17/19 on macOS with the two documented libm/timing exceptions.

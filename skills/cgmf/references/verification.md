# CGMF verification

**Status: TIER 1.** The distribution ships byte-exact reference history files and
this build reproduces them exactly. This is the strongest benchmark in the FUSION
per-code series to date for a Monte Carlo code, and it is possible only because
CGMF is integer-deterministic (event `i` is seeded from `i`).

Source: Talou, Stetcu, Jaffke, Rising, Lovell, Kawano, *Fission fragment decay
simulations with the CGMF code*, Comput. Phys. Commun. **269**, 108087 (2021),
DOI 10.1016/j.cpc.2021.108087, verified live against CrossRef.

## L1: exact reproduction of the distributed reference output

`utils/cgmf/tests/` ships `.reference` history files that the repo's own CTest
compares byte-for-byte. `verify_cgmf.sh` reconstructs the serial reference by
concatenating the two MPI-rank files in order (exactly as the CTest does) and
runs the same arguments.

| case | args | result |
|---|---|---|
| 252Cf(sf) | `-n 40 -e 0.0 -i 98252` | **bit-exact**, 0 differing lines |
| n(thermal)+235U | `-n 40 -e 2.53e-8 -i 92235` | **bit-exact**, 0 differing lines |

Measured on **macOS / Apple Silicon** against LANL's shipped reference. What is
established, and what is not, stated precisely because an earlier draft overclaimed:

- **Established:** this build reproduces the shipped reference byte-for-byte, and
  a **separate Release-vs-Debug build on the same machine also reproduces it**
  (checked in an adversarial pass). So the match is stable across at least two
  build configurations, not a single lucky binary.
- **Not established:** the shipped reference files carry no compiler or platform
  metadata, and their local timestamps are just clone times, so it is **not**
  proven that LANL generated them on a different platform. The honest claim is
  "the LANL-shipped reference is reproduced bit-for-bit on this macOS/ARM build",
  not "cross-platform reproduction for free".

**The caveat that remains:** byte-exactness holds on a matching toolchain. A
different compiler or optimisation level could perturb the last floating-point
digits of a trajectory and break the match. If a future build stops matching,
suspect the toolchain, and confirm the physics with an observable (nu-bar) rather
than a byte diff.

## L2: physics, average total prompt-neutron multiplicity of 252Cf(sf)

The CGMF manual quotes nu-bar_tot for 252Cf(sf) from its own runs:

- **3.82** at 1,000,000 events (`doc/rtd/start.rst`, the worked example).
- **3.817616** at 500,000 events (`doc/rtd/nb_neutrons.ipynb`, via
  `Histories.nubartot()`).

Because this build reproduces the shipped reference bit-for-bit, it **is** the
same deterministic code that produced those numbers, so 3.82 is this build's
converged value by construction, not merely a value to aim at.

At the event counts a per-run check can afford, nu-bar is deterministic but
Monte-Carlo-noisy, scattering around 3.82:

| events | nu-bar_tot | standard error ~ 1.25/sqrt(N) |
|---|---|---|
| 40 | 3.80 | 0.20 |
| 500 | 3.78 | 0.056 |
| 3000 | 3.72 | 0.023 |

`verify_cgmf.sh` pins the deterministic n=500 value (3.78) as a regression check
and separately asserts it is within Monte Carlo distance of the manual's 3.82.
The evaluated experimental value for 252Cf(sf) is 3.7676; CGMF's 3.82 is a model
value, and the small difference from experiment is physics, not a porting error.

Note the two decimals: cgmf.x prints `<nu>_tot` to two places, which is enough
for both the regression pin and the sanity window. Full-precision nu-bar comes
from CGMFtk's `nubartot()` on the history file.

## Reproducing

```bash
bash ../../scripts/install_cgmf.sh
bash ../../scripts/verify_cgmf.sh       # L1 (bit-exact) + L2 (nu-bar)
bash ../../scripts/selftest_cgmf.sh     # the harness guards
```

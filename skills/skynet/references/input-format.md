# SkyNet input authoring

SkyNet is a **library**, not a text-input program: a calculation is a short
driver that constructs the network objects and calls `Evolve`. The native
interface is Python (SWIG bindings); a C++ driver builds the same objects with
the same names. This skill's benchmark and `run_skynet.sh` cases use the shipped
compiled drivers (`tests/*`, real network calculations); to author a **new**
calculation, follow the pattern below. It mirrors `examples/r-process.py` in the
distribution.

## The construction pattern

```python
from SkyNet import *
import numpy as np

# 1. Nuclide set: which isotopes are in the network.
nuclib = NuclideLibrary.CreateFromWebnucleoXML(SkyNetRoot
    + "/data/webnucleo_nuc_v2.0.xml")

# 2. Global options.
opts = NetworkOptions()
opts.ConvergenceCriterion   = NetworkConvergenceCriterion.Mass
opts.MassDeviationThreshold = 1.0E-10
opts.IsSelfHeating          = True   # evolve temperature from nuclear energy release
opts.EnableScreening        = True   # Coulomb screening of reaction rates

# 3. Equation of state and screening.
helm   = HelmholtzEOS(SkyNetRoot + "/data/helm_table.dat")
screen = SkyNetScreening(nuclib)

# 4. Rate libraries. Each REACLIBReactionLibrary selects a ReactionType
#    (Strong / Weak) from a REACLIB-format file. Fission and neutrino sets are
#    separate libraries. The trailing bool is "do screening".
strong = REACLIBReactionLibrary(SkyNetRoot + "/data/reaclib",
    ReactionType.Strong, True, LeptonMode.TreatAllAsDecayExceptLabelEC,
    "Strong reactions", nuclib, opts, True)
weak   = REACLIBReactionLibrary(SkyNetRoot + "/data/reaclib",
    ReactionType.Weak, False, LeptonMode.TreatAllAsDecayExceptLabelEC,
    "Weak reactions", nuclib, opts, True)

# 5. Assemble the network.
net = ReactionNetwork(nuclib, [weak, strong], helm, screen, opts)
```

## Initial composition and trajectory

Two common ways to start and drive the network:

**Self-heating from an initial thermodynamic point** (r-process ejecta): pick
temperature, Ye and entropy, use NSE to get the initial density and composition,
give a density profile, and let SkyNet evolve the temperature:

```python
T0, Ye, s, tau = 6.0, 0.01, 10.0, 7.1        # GK, -, kB/baryon, ms
nse = NSE(net.GetNuclideLibrary(), helm, screen)
ini = nse.CalcFromTemperatureAndEntropy(T0, s, Ye)
rho_profile = ExpTMinus3(ini.Rho(), tau / 1000.0)   # rho ~ t^-3 expansion
output = net.EvolveSelfHeatingWithInitialTemperature(
    ini.Y(), 0.0, 1.0E9, T0, rho_profile, "my_run")   # y0, t0, tEnd, T0, rho(t), basename
```

**Prescribed temperature-density history** (X-ray burst, post-processing a
hydro trajectory): read a `TemperatureDensityHistory` from a two-column-plus
time-temperature-density file and evolve along it (see `tests/XRayBurst`):

```python
hist   = TemperatureDensityHistory.CreateFromFile("temp_rho_vs_time")
output = net.Evolve(Y0, hist.GetTime()[0], hist.GetTime()[-1], hist, "my_run")
```

## Key objects and where their inputs come from

| object | input | shipped file |
|---|---|---|
| `NuclideLibrary` | webnucleo XML nuclide database | `data/webnucleo_nuc_v2.0.xml` |
| `HelmholtzEOS` | Timmes Helmholtz EOS table | `data/helm_table.dat` |
| `REACLIBReactionLibrary` | JINA REACLIB rate file | `data/reaclib` (and fission `data/netsu_*`) |
| `NeutrinoReactionLibrary` | neutrino cross sections | `data/neutrino_reactions.dat` |
| `FFNReactionLibrary` | FFN/MESA weak rates | `data/FFN_*` |

`NuclideLibrary.CreateRestrictedLibrary(full, names)` builds a sub-network for a
named list of isotopes (how the NSE and X-ray-burst tests restrict the space).

## Options that change the physics vs the run

- Change the **result**: the nuclide set, the rate libraries included,
  `IsSelfHeating`, `EnableScreening`, the initial `Y`/`T`/`Ye`/entropy, and the
  trajectory.
- Change only **cost/robustness**: `MassDeviationThreshold`,
  `ConvergenceCriterion`, integrator tolerances. The dense LAPACK matrix solver
  is fixed at build time (see `failure-modes.md`); it does not change results.

## C++ driver alternative

The same classes exist in C++ (`ReactionNetwork`, `NuclideLibrary`,
`REACLIBReactionLibrary`, `HelmholtzEOS`, `NSE`, ...); the compiled `tests/*`
drivers are exactly such programs. Link against `libSkyNet` (or the static
`libSkyNet_static.a` the tests use) and include from the source tree. This is the
route used when the Python bindings are off (this build's default).

## Enabling the Python bindings

The Python interface needs SWIG and is OFF by default here (a portability
liability on a very new Python, and not needed for the benchmark). To turn it on:
`brew install swig`, then configure with `-DUSE_SWIG=ON -DENABLE_SWIG=ON` and a
Python whose headers are found by CMake. The generated `SkyNet.py` and `_SkyNet`
module install into the prefix's `lib/`; add it to `PYTHONPATH` and
`from SkyNet import *` works as above.

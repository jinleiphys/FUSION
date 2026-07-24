# Thermal-FIST input reference

Thermal-FIST is primarily a C++ LIBRARY. There is no single monolithic input
file the way FRESCO or SMASH have one. A calculation is defined either in C++
(construct a `ThermalParticleSystem` from a particle list, pick a model class,
set the thermal parameters, call `CalculateDensities()`) or through the Qt GUI,
or, for the cases this skill drives, through the compiled example programs whose
inputs are their command-line arguments plus a particle list read from disk.

This file documents the three inputs that actually decide a result: the particle
list, the model variant, and the thermal parameters. All facts are from the v1.6.1
source (`src/examples/`, `include/HRGBase/`) and `docs/quickstart.md`.

## 1. The particle list

Read from `input/list/<set>/list.dat` (hadrons only) or `list-withnuclei.dat`
(hadrons plus light nuclei). The compiled-in base path is `ThermalFIST_INPUT_FOLDER`,
so the example binaries find their list wherever they are run from. The shipped
sets under `input/list/`:

| set | what |
|---|---|
| `PDG2014` | the default; light and strange hadrons per the 2014 PDG |
| `PDG2020`, `PDG2020_modular`, `PDG2025` | newer PDG compilations |
| `thermus23`, `thermus23mod`, `thermus30` | lists extracted from THERMUS 2.3 / 3.0, for cross-checking against that package |
| `SMASH-1.8` | the SMASH hadron list |
| `electroweak` | adds electroweak particles |

The cpc examples deliberately use `thermus23/list.dat` so their numbers can be
compared against THERMUS. Each list file is one particle per line: PDG code,
name, mass, degeneracy, statistics, quark content, and quantum numbers. A
`decays.dat` in the same folder carries the decay channels used for feed-down.

## 2. The model variant (the `<config>` argument)

The physics content is chosen by the model CLASS, and the cpc example programs
select it with a single integer argument:

| class | `cpc1HRGTDep <config>` | meaning |
|---|---|---|
| `ThermalModelIdeal` | 0 | ideal (non-interacting) hadron resonance gas |
| `ThermalModelEVDiagonal` | 1 | excluded-volume HRG, constant hard-core radius r = 0.3 fm (reproduces arXiv:1412.5478) |
| `ThermalModelVDWFull` | 2 | van der Waals HRG with attraction + repulsion for baryons, fixed to nuclear ground state (reproduces arXiv:1609.03975) |

`cpc2chi2 <config>` (0..3) selects Id / EV-two-component / EV-bag-model / QvdW
for the ALICE 2.76 TeV thermal fit; `cpc3chi2NEQ <config>` (0..1) selects the
equilibrium vs chemically-frozen (gamma_S free) fit. `run_thermalfist.sh` rejects
any config outside the closed set a given example accepts.

## 3. Thermal parameters

The state of an HRG is fixed by temperature and the chemical potentials, plus the
volume and any excluded-volume/vdW parameters:

- `T` temperature (GeV internally, MeV in the cpc output tables);
- `muB`, `muQ`, `muS` (and `muC` for charm) baryon, charge, strangeness chemical
  potentials, often constrained by conservation (Q/B fixed, S = 0, C = 0);
- `V` or `R` the (correlation) volume, entering extensive quantities;
- `gammaq`, `gammaS`, `gammaC` optional quark fugacities for chemical
  non-equilibrium;
- excluded-volume radius `r` (EV) or vdW `a`, `b` (QvdW).

The two GUI/library example programs the ctest suite also runs take these as
positional arguments, e.g.
`example-ThermodynamicsBQS <a> <b> <QvdW-flag> <paramrange.in> <outfile>` scans a
range of (muB, muQ, muS) given in the `.in` file. `run_thermalfist.sh` does not
wrap those; they are exercised by `verify_thermalfist.sh` through the shipped
ctest suite.

## Reproducing the CPC paper

The four `cpc*` programs correspond one-to-one to the figures of Vovchenko &
Stoecker, CPC 244, 295 (2019): cpc1 is the temperature dependence of HRG
thermodynamics at mu = 0 (Fig. of Sec. 4), cpc2 and cpc3 are the ALICE thermal
fits, cpc4 is the Monte Carlo event sampler. This is why the shipped
`test/ReferenceOutput/` doubles as both a regression fixture and a published-value
benchmark.

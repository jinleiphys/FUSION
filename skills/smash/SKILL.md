---
name: smash
description: >-
  Drive SMASH (Simulating Many Accelerated Strongly-interacting Hadrons), the hadronic transport approach of J. Weil et al. (Phys. Rev. C 94, 054905 (2016)), release SMASH-3.3. Solve the relativistic Boltzmann equation for a hadron gas: heavy-ion collisions from a few hundred MeV to collider energies, thermal boxes for equilibration and detailed-balance studies, expanding spheres, and replay of externally supplied particle lists. Produces per-particle OSCAR/binary output for multiplicities, spectra, flow, dilepton and photon rates, with optional mean-field potentials and string fragmentation through Pythia. Use for 跑SMASH, 强子输运, hadronic transport, heavy-ion collision, 重离子碰撞, Boltzmann transport, cascade, Au+Au, particle multiplicity, flow, freeze-out, OSCAR2013, afterburner, dilepton, box equilibration, kinetic theory.
---

# Driving SMASH

SMASH solves the relativistic Boltzmann equation for hadrons: it propagates
particles, samples their collisions and decays, and writes the resulting particle
lists. It is used both as a standalone transport model at low and intermediate
beam energies and as the hadronic afterburner behind a hydrodynamic stage at
collider energies.

C++17, CMake. Needs GSL, Eigen 3.x, and Pythia exactly 8.316.

## Prime rules (do not skip)

1. **Pin the random seed for anything you intend to check.** Every shipped
   configuration carries `Randomseed: -1`, which draws a fresh seed and makes the
   run unreproducible. `scripts/run_smash.sh` refuses `-1` unless you pass
   `--allow-random-seed`. With a pinned seed the output is byte-identical between
   two runs of the same build.
2. **Do not compare multiplicities across machines.** SMASH is Monte Carlo, and
   transport amplifies floating-point differences into different collision
   histories. Anchor on baryon number and electric charge, which are integers
   fixed by the initial nuclei and identical on every platform and every seed:
   `scripts/check_conservation_smash.py`.
3. **This is a TIER 1 skill: it reproduces SMASH's own 104-case test suite.**
   Two of those cases are non-deterministic by upstream construction
   (`potentials.cc` and `random.cc` seed themselves from `std::random_device`
   and then assert statistical quantities), so `verify_smash.sh` retries exactly
   those two by name, once, and treats every other failure as fatal. Do not
   widen that into "allow one failure".
4. **The dependencies fail with messages that point away from the cause.** The
   Pythia URL in SMASH's own INSTALL.md 404s and the 404 page gets saved as a
   `.tgz`; Eigen 5 makes SMASH report "at least version 3.0 is required" when the
   problem is that your Eigen is too NEW. Read `references/failure-modes.md`
   before debugging a build by hand.
5. **`WARN Fpe : Failed to setup trap on pole error.` is harmless** and appears
   on every macOS run. Never grep logs case-insensitively for "error"; match
   SMASH's severity field.
6. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_smash.sh` fetches and builds everything, then prints:

```
SMASH=<executable>
SMASH_ROOT=<repository root>
SMASH_BUILD=<build dir, where ctest runs>
SMASH_EIGEN3_ROOT=<Eigen 3.4 prefix>
SMASH_GSL_PREFIX=<GSL prefix>
SMASH_PYTHIA_PREFIX=<Pythia prefix>
```

The last three matter beyond the build: the `usage_of_SMASH_as_library` test
spawns a fresh cmake that inherits no cache variables, so those prefixes must
reach it through the environment. `verify_smash.sh` does that for you.

First run takes roughly 20 minutes, almost all of it compiling Pythia and SMASH,
and is cached afterwards. Needs `git`, `cmake` 3.16+, a C++17 compiler, `curl`
and `python3`. Overrides: `SMASH_ROOT_DIR`, `SMASH_PIN`, `SMASH_JOBS`,
`SMASH_GSL_PREFIX`, `SMASH_PYTHIA_URL`, `SMASH_EIGEN_VERSION`.

## Running

```bash
scripts/run_smash.sh --config <config.yaml> --outdir /tmp/run1 \
  --seed 20260723 --nevents 2 --end-time 20.0
```

Prints `RESULT_DIR=` and `RESULT_OSCAR=`. It copies the configuration it actually
used into the output directory, then asserts a zero exit, a non-empty particle
list, no NaN, no `ERROR`-severity log line, and that the number of completed
events matches `Nevents` (a run can stop early and still exit 0).

## Verifying

```bash
scripts/verify_smash.sh              # test suite + seeded anchor, about 8 min
scripts/verify_smash.sh --tests-only
scripts/selftest_smash.sh            # harness only, seconds, no build needed
```

## Writing an input

Field reference taken from the source: `references/input-format.md`. The shape:

```yaml
General:
    Modus:      Collider      # or Box, Sphere, List, ListBox
    Delta_Time: 0.1
    End_Time:   200.0
    Randomseed: 20260723      # PIN THIS
    Nevents:    1
Output:
    Particles:
        Format: ["Oscar2013"]
Modi:
    Collider:
        Projectile: {Particles: {2212: 79, 2112: 118}}   # Au197
        Target:     {Particles: {2212: 79, 2112: 118}}
        E_Kin: 1.23                                       # GeV per nucleon
```

Nuclei are given as PDG-code counts, so the expected baryon number and charge of
the whole run follow directly from them, which is what makes the conservation
anchor possible.

## Reading the output

`references/output-format.md`. `particle_lists.oscar` has twelve columns named on
its first line (parse that line, it changes with the requested content), events
delimited by `# event N out` and `# event N end`.

## Benchmark

| stage | what | result |
|---|---|---|
| test suite | SMASH's own 104 ctest cases | reproduced, with the two self-seeded cases retried once |
| anchor | seeded Au+Au, 2 events, E_kin 1.23 GeV/nucleon, 20 fm/c | baryon number 788 and charge 316, both EXACT |

The anchor's multiplicities (450 n, 336 p, 76 pi-, 65 pi0, 57 pi+, plus eta, K0,
Lambda, Sigma-) are recorded in `references/verification.md` as a same-build
reproducibility check only, never as a cross-platform reference.

## Failure modes

`references/failure-modes.md`, nine of them, starting with the dead Pythia URL
and the Eigen 5 message that says the opposite of the truth.

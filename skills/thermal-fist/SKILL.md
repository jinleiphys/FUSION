---
name: thermal-fist
description: >-
  Drive Thermal-FIST, the hadron-resonance-gas package of V. Vovchenko and H. Stoecker (Comput. Phys. Commun. 244, 295 (2019)), release v1.6.1. Compute the thermodynamics and conserved-charge susceptibilities of a hadron resonance gas (ideal, excluded-volume, or van der Waals), fit chemical freeze-out parameters to measured particle yields, and evaluate the hadronic equation of state for heavy-ion and neutron-star applications. Build from source, run the shipped cpc example programs, and reproduce the package's own ctest self-comparison suite. Use for 跑Thermal-FIST, 强子共振气体, hadron resonance gas, HRG model, thermal model, chemical freeze-out, 化学冻结, thermal fit, particle yields, statistical hadronization, conserved-charge susceptibilities, equation of state, EoS, van der Waals HRG, excluded volume, QCD crossover, lattice comparison, ALICE thermal fit, chi2 freeze-out.
---

# Driving Thermal-FIST

Thermal-FIST computes the properties of a hadron resonance gas: given a particle
list, a model (ideal, excluded-volume, or van der Waals), and thermal parameters
(T, muB, muQ, muS, volume), it returns densities, thermodynamics (p, e, s),
fluctuations and conserved-charge susceptibilities, and it fits chemical
freeze-out parameters to measured yields. It is used both as a thermal-model
analysis tool for heavy-ion data and as a hadronic equation of state, including
for neutron-star matter.

C++, CMake. Eigen 3.4 and Minuit2 are BUNDLED, so the core has no external
dependency; only the test build fetches GoogleTest. Qt is optional (GUI only).

## Prime rules (do not skip)

1. **Run the ctest suite SERIALLY.** `ctest -j` fails 21 of the 26 comparison
   cases on a perfectly good build: the `Run<X>` and `Compare<X>` tests share an
   output file with no declared dependency, so under parallelism a Compare reads
   the file before the matching Run has written it. `verify_thermalfist.sh`
   forces `-j1` and clears `CTEST_PARALLEL_LEVEL`. Run serially, all 93 pass.
2. **This is a TIER 1 skill reproducing the shipped `test/ReferenceOutput`, with
   a MIXED comparator.** The suite compares cpc2 and cpc4's `analyt.dat`
   BYTE-EXACT (`cmake -E compare_files`) and cpc1, Thermodynamics, Susceptibilities
   and NeutronStar with an absolute 1e-6 tolerance (`test_CompareOutputs`); cpc4's
   Monte Carlo output is not compared at all. Both platforms pass all of it. Do
   not describe the whole suite as bit-identical (cpc1 is not) nor as uniformly
   1e-6 (cpc2/cpc4 are byte-exact).
3. **cpc3 output has a leading LABEL column** (`NA49-30GeV-4pi`, then numbers).
   A parser that treats every token as a float breaks on it, and the shipped
   comparator silently compares NOTHING on those rows. Handle it as a labelled
   table; `check_output_thermalfist.py` does.
4. **cpc4 is Monte Carlo.** Its `cpc4.montecarlo.dat` is not reproducible without
   pinning the event count and RNG, so `run_thermalfist.sh` does not expose it and
   no benchmark rests on it.
5. **Examples write to the current directory, not to a `-o` path.** Run each in a
   fresh directory or the outputs collide.
6. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_thermalfist.sh` clones, pins, builds, and prints:

```
TFIST=<cpc1HRGTDep, a representative example binary>
TFIST_ROOT=<repository root>
TFIST_BUILD=<build dir, where ctest runs>
TFIST_EXAMPLES=<dir holding the example binaries>
```

First build takes a few minutes and is cached afterwards. Needs `git`, `cmake`
3.21+, a C++17 compiler, and network ONCE (the test build fetches GoogleTest via
FetchContent). Pinned to release v1.6.1, commit `fe5c61af00cf`. Overrides:
`TFIST_ROOT_DIR`, `TFIST_PIN`, `TFIST_JOBS`, `TFIST_EXPECTED_TESTS`.

## Running

```bash
scripts/run_thermalfist.sh --example cpc1 --config 0 --outdir /tmp/run1
```

`--example` is `cpc1` (temperature dependence of HRG thermodynamics at mu=0),
`cpc2` (ALICE 2.76 TeV thermal-fit chi^2 vs T), or `cpc3` (equilibrium vs
chemically-frozen fit). `--config` selects the model variant within the closed
set each example accepts (cpc1: 0 Ideal, 1 EV, 2 QvdW). It runs in an isolated
directory, asserts a zero exit, then validates every `.out`/`.dat` table it
produced (header, numeric rows with consistent columns, no NaN/Inf, leading label
columns tolerated). Prints `RESULT_DIR=` and `RESULT_FILES=`.

## Verifying

```bash
scripts/verify_thermalfist.sh              # anchor + ctest suite + cpc3, about 5 min
scripts/verify_thermalfist.sh --anchor-only  # full cpc1 output vs the shipped reference
scripts/verify_thermalfist.sh --tests-only   # the 93-case ctest suite + cpc3 stage
scripts/selftest_thermalfist.sh            # harness only, 50 cases (46 without a clone), seconds
```

The anchor compares the FULL cpc1 output against the shipped reference (not just
one row), the ctest stage runs the 93 cases serially and rejects skipped cases,
and a third stage covers cpc3 (which upstream leaves out of the suite).

A clean run ends in `VERIFY OK`. If the expected test count was overridden with
`TFIST_EXPECTED_TESTS`, it ends in `VERIFY PASSED-NOT-CERTIFIED` instead (not a
superstring of `VERIFY OK`): the run passed but did not certify the pinned v1.6.1
at tier 1. Evidence and what the adversarial pass found: `references/verification.md`.

## Writing an input

Thermal-FIST is a library; there is no monolithic input file. A calculation is a
particle list plus a model plus thermal parameters, all covered in
`references/input-format.md`. The cpc example programs take a single integer
`<config>` selecting the model. They do NOT all read the same particle list:
cpc1 and cpc2 read `input/list/thermus23/list.dat`, while cpc3 and cpc4 read
`input/list/PDG2014/list.dat`. The list is part of the physics, so reproducing a
cpc3 fit with the thermus23 list would change the result.

## Reading the output

`references/output-format.md`. The example programs write whitespace-delimited
tables whose first line names the columns. cpc1 is `T[MeV] p/T^4 e/T^4 s/T^3
chi2B chi4B chi2B-chi4B`, 181 temperature rows; cpc3 prepends a dataset label
column.

## Benchmark

| stage | what | result |
|---|---|---|
| anchor | `cpc1HRGTDep 0`, full Ideal-HRG output vs shipped reference + T=150 MeV row | 181 rows / 7 cols reproduced within 1e-6; p/T^4=0.647513, e/T^4=3.846843, s/T^3=4.494356 |
| test suite | Thermal-FIST's own 93 ctest cases, SERIAL | 93/93 on macOS/Apple clang 21 and Linux/gcc 13.3, within the code's 1e-6 comparator |
| cpc3 | both cpc3 configs (not in the 93) | EQ fit reproduces the reference within 1e-6 both platforms; NEQ fit is under-constrained, validated structurally only |

Tier 1: reproduces the shipped `test/ReferenceOutput` on two platforms through the
code's own tolerance comparator. The first hadron-resonance-gas / equation-of-state
code in FUSION, and the third of the heavy-ion row after SMASH and GiBUU; it also
covers the hadron-resonance-gas branch of the equation-of-state row.

## Failure modes

`references/failure-modes.md`, nine of them, starting with the parallel-ctest
false failures and the tolerance-not-byte-match framing.

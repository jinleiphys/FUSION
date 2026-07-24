# Thermal-FIST verification

## What was verified, and where

Thermal-FIST v1.6.1 (commit `fe5c61af00cf`), GPL-3.0, Vovchenko & Stoecker,
Comput. Phys. Commun. 244, 295-310 (2019), DOI 10.1016/j.cpc.2019.06.024
(CrossRef-verified live 2026-07-24). Built with `-DINCLUDE_TESTS=ON` and NO
source patches on both platforms:

| platform | compiler | ctest (serial) | anchor |
|---|---|---|---|
| macOS 26.5, Apple Silicon | Apple clang 21.0.0 | 93 / 93 | exact |
| Linux (heliumx), x86-64 | gcc 13.3.0 | 93 / 93 | exact |

**Tier 1, with an honest qualifier: the benchmark is a TOLERANCE, not a byte
match.** The 93 cases are Thermal-FIST's own ctest suite, which runs each cpc/EoS
example and compares its output against `test/ReferenceOutput/` using the code's
own `test_CompareOutputs` (absolute 1e-6 per column). Upstream itself declares
cpc1 possibly non-deterministic across compilers (its `INCLUDE_ALL_TESTS` option
switches cpc1 to exact `compare_files` and its comment names those cases
"non-deterministic among compilers/hardware"), which is exactly why the shipped
default is the tolerance comparator. So the claim is "reproduces the shipped
reference within the code's own 1e-6 comparator, on two platforms and two
compilers", never bit-identical.

Zero external dependencies at build time except a one-time GoogleTest fetch:
Eigen 3.4.0 and Minuit2 are bundled under `thirdparty/`, and with no `ROOTSYS`
the build uses the bundled standalone Minuit2. No `-DCMAKE_POLICY_VERSION_MINIMUM`
flag is needed under CMake 4.2 (GoogleTest's old `cmake_minimum_required` only
warns).

## The fast anchor

`cpc1HRGTDep 0` (ideal HRG at mu = 0), row T = 150 MeV of `cpc1.Id-HRG.TDep.out`:

```
p/T^4 = 0.647513,  e/T^4 = 3.846843,  s/T^3 = 4.494356
```

Reproduced to `|diff| = 0` on macOS and within the 1e-6 ctest tolerance on Linux.
`p/T^4 ~ 0.65` at 150 MeV is the expected order for an ideal hadron gas just below
the QCD crossover. `verify_thermalfist.sh --anchor-only` pins it in seconds with no
network.

## The decisive trap: the ctest suite must run serially

Under `ctest -j` (or with `CTEST_PARALLEL_LEVEL` set), 21 of the 26 `Compare<X>`
cases FAIL on a correct build:

```
21 tests failed out of 93  (parallel)
 0 tests failed out of 93  (serial)
```

The suite pairs a `Run<X>` test that writes an output file with a `Compare<X>`
test that reads it, and declares no dependency between them, so under parallelism
a Compare runs before its Run has finished writing. This is an upstream
test-suite defect, harmless once known: `verify_thermalfist.sh` forces `-j1` and
clears `CTEST_PARALLEL_LEVEL`. A student who runs `ctest -j8` by hand and sees 21
red comparisons has a working build, not a broken one.

## A comparator limitation found while building this

`cpc3.{EQ,NEQ}.chi2.out` begins each row with a dataset LABEL
(`NA49-30GeV-4pi`), then nine numbers. The shipped `test_CompareOutputs` reads
each line with `istringstream >> double`, which fails on the label token, so it
reads ZERO numbers from a cpc3 row and compares nothing. So the shipped cpc3
comparison verifies only that the row counts match, not the values. The tier-1
evidence therefore rests on the cpc1/cpc2/Thermodynamics/Susceptibilities tables,
which are fully numeric and fully compared. `check_output_thermalfist.py` handles
the label column correctly (strips consistent leading labels, requires everything
after the first number to be numeric).

## Harness self-test

`scripts/selftest_thermalfist.sh` needs no build and covers 35 cases:
structural validation of `check_output_thermalfist.py` (clean numeric table,
leading-label table, empty file, header-only, mid-row label, NaN, Inf,
inconsistent numeric-column and label-column counts, min-rows/min-cols, bad
accuracy), reference comparison (match, mismatch caught, loose-tolerance pass,
row/column count mismatch), the `--row-at` anchor (match, missing value,
out-of-range column, odd `--expect`, wrong value), `run_thermalfist.sh` argument
validation (missing/unknown example, non-integer and out-of-range config, unknown
flag, non-empty outdir, empty producer, nonzero exit), and `verify_thermalfist.sh`
argument and identity guards. Each negative case is built to fail ONLY the guard
under test; two selftest bugs found during construction were of exactly the shape
the FUSION devlog warns about (a test input tripping a different guard first, and
a `grep` needle beginning with `--` being read as an option), both fixed.

## What the adversarial pass found

(to be filled in after the Codex pass)

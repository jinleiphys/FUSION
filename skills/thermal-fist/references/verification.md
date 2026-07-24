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

## cpc3 is not in the 93, and is covered separately

`cpc3.{EQ,NEQ}.chi2.out` begins each row with a dataset LABEL
(`NA49-30GeV-4pi`), then nine numbers. cpc3 is NOT one of the 93 ctest cases: its
`RunCPC3` / `CompareCPC3` entries are commented out in `test/CMakeLists.txt`, and
even the shipped `test_CompareOutputs` could not check it (its `>> double` fails
on the label token, so it reads zero numbers from a cpc3 row). So the 93 tier-1
cases rest on the cpc1/cpc2/Thermodynamics/Susceptibilities tables, which are
fully numeric and fully compared. `verify_thermalfist.sh` adds a THIRD stage that
covers cpc3, but honestly split by fit type:

- **cpc3 config 0, the EQUILIBRIUM fit** (gammaq = gammaS = 1 fixed, only T, muB,
  R free) is well-constrained and reproduces the shipped reference within 1e-6 on
  BOTH macOS and Linux, so it is compared strictly.
- **cpc3 config 1, the chemically-frozen NEQ fit** (gammaq and gammaS also free)
  is under-constrained: the extra freedom flattens a chi2 direction, so the
  minimiser lands on a DIFFERENT minimum per build. Measured: the ALICE muB comes
  out 2.42 MeV on this build against 4.96 MeV in the reference, a 2.5 MeV gap, not
  a last-digit drift, and both macOS and Linux disagree with the reference the
  same way. This is almost certainly why upstream commented cpc3 out of its ctest
  suite. So the NEQ output is validated STRUCTURALLY only (runs, 5 rows, 9 numeric
  columns, finite), never compared numerically, and the skill says so plainly
  rather than reporting a false match.

`check_output_thermalfist.py` handles the label column (strips consistent leading
labels, requires everything after the first number to be numeric, and compares
the label text in reference mode).

## Harness self-test

`scripts/selftest_thermalfist.sh` covers 48 cases and needs no build for 45 of
them: structural validation of `check_output_thermalfist.py` (clean numeric
table, leading-label table, empty file, header-only, mid-row label, NaN, Inf,
inconsistent numeric-column and label-column counts, min-rows/min-cols, bad
accuracy, a numeric-only first line rejected as a non-header, NaN accuracy and NaN
expected values, negative column indices), reference comparison (match, mismatch,
loose-tolerance pass, row/column count mismatch, label-text mismatch), the
`--row-at` anchor, `run_thermalfist.sh` argument validation (missing/unknown
example, non-integer and out-of-range config for cpc1/cpc2/cpc3, unknown flag,
non-empty outdir, empty producer, wrong output filename, nonzero exit), and
`verify_thermalfist.sh` argument, PIN-format and identity guards. The three
identity sub-guards that are only reachable when the source HEAD equals the pin
(cache binding present, `INCLUDE_TESTS=ON`, non-symlinked binary) run when the
pinned clone is present and are skipped with a note otherwise. Each negative case
is built to fail ONLY the guard under test.

## What the adversarial pass found

One Codex adversarial pass (`codex exec`, allowed to build and run the code)
returned 13 findings, 5 blockers and 8 major, ALL fixed:

Blockers: (1) a symlinked `src` or `build` under a user-set `TFIST_ROOT_DIR` let
`git` and the `rm -rf CMakeFiles` step operate OUTSIDE the cache root; install now
refuses a symlinked or escaping src/build. (2) 93 SKIPPED ctest cases were
reported as 93 passes, because ctest counts skips as non-failures; verify now
counts the actual `Passed` lines, requires exactly 93, and rejects any
Skipped/Not-Run/Disabled/Timeout. (3) an empty `CMakeCache.txt` passed the
source-build identity check because the binding was skipped when the cache
variable was empty; verify now requires BOTH source-dir variables present and
equal to the canonical source, plus `INCLUDE_TESTS:BOOL=ON`, and rejects a
symlinked binary. (4) `--anchor-only` accepted a one-row truncated output; the
anchor now compares the FULL cpc1 output (181 rows, 7 columns) against the
shipped reference at 1e-6. (5) `run_thermalfist.sh` accepted any nonzero-exit
table; it now requires the EXACT config-specific filename and shape and compares
to the shipped reference.

Major: NaN `--accuracy`/`--expect` made every comparison vacuously pass (now
require finite positive); `TFIST_PIN` could certify a non-pinned build and
`TFIST_PIN=--detach` was an option injection (now a 40-hex format check, and a
non-canonical pin forces `VERIFY PASSED-NOT-CERTIFIED`); the installer blessed a
swapped binary on a digest change instead of rebuilding (now rebuilds, and the
probe validates full shape + anchor); cpc3 was documented as tested but is not in
the 93 (now stated, and covered by the new stage 3); the `eval` install pattern
was a path-injection vector (README now extracts variables with `sed`); the
checker discarded header and label identity (now validates a named header and
compares label text); the selftest coverage was incomplete (now 48 cases with the
new guards); and the docs said all cpc examples read `thermus23` while cpc3/cpc4
read `PDG2014` (corrected per program). Codex could NOT falsify the 93 serial-test
count, the config ranges, the citation, the GPL-3.0 license, or the `-j1` +
`CTEST_PARALLEL_LEVEL=1` serial enforcement, and found no bash-4 or GNU-only
dependency.

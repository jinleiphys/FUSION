# Thermal-FIST failure modes

Ordered by how likely each is to waste your time, and each one produces a
confident-looking wrong result rather than an obvious crash.

## 1. Parallel ctest fails 21 of 26 comparisons, and the build is fine

`ctest -j` (or `CTEST_PARALLEL_LEVEL` set in the environment) makes 21 of the 26
`Compare<X>` cases fail. The build is NOT broken. The suite pairs a `Run<X>` test
that writes an output file with a `Compare<X>` test that reads it, and declares NO
dependency between them, so under parallelism a Compare runs before its Run has
finished writing and reads a missing or half-written file. Run SERIALLY and all 93
pass. `verify_thermalfist.sh` forces `-j1` and clears `CTEST_PARALLEL_LEVEL`; if you
run ctest by hand, do the same. This is the single most important fact about the
suite.

## 2. The benchmark is a tolerance, not a byte match, on purpose

Upstream itself flags cpc1 as possibly non-deterministic across compilers: the
`INCLUDE_ALL_TESTS=ON` option switches cpc1 to an exact `compare_files` and its own
comment calls those cases "`non-deterministic` among compilers/hardware". The
default suite therefore compares with `test_CompareOutputs`, an absolute 1e-6
per-column tolerance. So the honest claim is "reproduces the shipped reference
within the code's own 1e-6 comparator", verified on macOS/Apple clang and
Linux/gcc. Do not upgrade this to "bit-identical"; the authors deliberately did
not.

## 3. cpc3's label column breaks all-numeric parsers

`cpc3.{EQ,NEQ}.chi2.out` begins each data row with a dataset NAME
(`NA49-30GeV-4pi`), then nine numbers. A validator that does `float(token)` on the
first column throws. Worse, the shipped `test_CompareOutputs` silently reads ZERO
numbers from such a row (its `>> double` fails on the label and the rest is never
reached), so its cpc3 comparison checks only the row count, not the values. Treat
cpc3 as a row-labelled table; `check_output_thermalfist.py` does.

## 4. cpc4 is Monte Carlo and is not a reproducible run

`cpc4mcHRG` samples events; `cpc4.montecarlo.dat` changes run to run unless the
event count and RNG are pinned. `run_thermalfist.sh` deliberately does NOT expose
cpc4, and the tier-1 evidence never rests on it. Its ctest case `CompareCPC4a`
passes because the shipped reference was generated with the same fixed internal
setup, but do not treat a cpc4 run through the wrapper as a benchmark.

## 5. GoogleTest is fetched at configure time; no network means no tests

`-DINCLUDE_TESTS=ON` pulls GoogleTest release-1.12.1 through CMake `FetchContent`,
so the FIRST configure needs network. Offline, configure fails naming googletest or
a download. The core library, the GUI and the examples build with no network; only
the test suite needs it, once, then it is cached under `build/_deps/`.

## 6. Qt6, if installed, silently builds an unused GUI; if absent, that is fine

The GUI subdirectory is always added on a native build, but the `QtThermalFIST`
target is only created when `find_package(Qt6)` (or Qt5) succeeds. So on a box with
Qt (this one had Qt 6) an extra, unneeded GUI compiles and lengthens the build; on a
box without Qt the library, examples and tests build normally and the GUI is simply
skipped. Qt is an OPTIONAL dependency. Its absence is never a build error, and this
skill needs only the examples and tests.

## 7. Examples write to CWD, not to an output path

There is no `-o` flag. `cpc1HRGTDep 0` writes `cpc1.Id-HRG.TDep.out` into whatever
directory it runs in. Run each example in a fresh directory or its outputs collide
and you compare the wrong file. `run_thermalfist.sh` uses an isolated `mktemp -d`.

## 8. CMake 4 prints GoogleTest deprecation warnings; ignore them

With CMake 4.x, GoogleTest 1.12.1's `cmake_minimum_required(VERSION < 3.10)` prints
"Compatibility with CMake < 3.10 will be removed" warnings. They are warnings, not
errors: Thermal-FIST configures and builds cleanly and needs NO
`-DCMAKE_POLICY_VERSION_MINIMUM` flag (unlike some older bundled-CMake codes). Do not
add one reflexively.

## 9. The default macOS bash is 3.2

Anything you script around this skill must avoid bash 4 builtins. `run_thermalfist.sh`
uses a plain glob loop rather than `mapfile` for exactly this reason; a `mapfile` in a
helper will die with "command not found" on a stock macOS shell only, passing on Linux.

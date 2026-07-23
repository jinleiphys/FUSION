# SMASH failure modes

Ordered by how much time each one costs before you work out what happened. The
first three are all dependency problems whose error message points away from the
cause, which is why `install_smash.sh` exists at all.

## 1. SMASH's own INSTALL.md gives a Pythia URL that 404s

`INSTALL.md` still says

```
wget https://pythia.org/download/pythia83/pythia8316.tgz
```

Pythia moved everything under `/releases/`, so that path now returns 404. The
damage is that the 404 body is a 3.7 KB HTML page, and `curl -o pythia8316.tgz`
writes it happily, so the first thing you actually see is

```
tar: Error opening archive: Unrecognized archive format
```

which suggests a corrupt download rather than a wrong address. The working URL
is `https://pythia.org/releases/pythia83/pythia8316.tgz`.
`install_smash.sh` checks the gzip magic bytes before unpacking and says so
explicitly, rather than letting `tar` produce that misleading message.

Pythia must be **exactly 8.316**; SMASH's `FindPythia.cmake` requires the exact
version, not a minimum.

## 2. Eigen 5 cannot be parsed by SMASH 3.3, and the message says the opposite

Homebrew now ships Eigen **5.0.1**, which renamed `EIGEN_WORLD_VERSION`. SMASH
3.3's bundled `cmake/FindEigen3.cmake` reads that macro out of
`Eigen/src/Core/util/Macros.h`, gets nothing, and reports

```
-- Eigen3 version .. found in /opt/homebrew/include/eigen3, but at least version 3.0 is required
CMake Error: Could NOT find Eigen3 (missing: EIGEN3_VERSION_OK)
```

That reads as "your Eigen is too old". It is too NEW. The fix is to give SMASH
an Eigen 3.4, not to patch SMASH: `install_smash.sh` downloads the 3.4.0 headers
(header-only, no build) and points `EIGEN3_INCLUDE_DIR` at them, and refuses to
proceed if the headers it finds are not a 3.x.

Related trap: **`brew --prefix eigen` prints a path even when Eigen is not
installed**, so "the prefix exists" is not evidence that the library does.

## 3. The library-example test needs THREE hints through the environment

`ctest` case `usage_of_SMASH_as_library` spawns a **fresh cmake** for the example
project. That child process inherits none of the main build's `-D` cache
variables, so it re-runs `find_package` for everything, and it fails on whatever
the machine happens to lack. Three distinct failures were observed, in this
order, each hidden behind the previous one:

| symptom | cause | hint that fixes it |
|---|---|---|
| `Could NOT find Eigen3 (missing: EIGEN3_VERSION_OK)` | picks up the system Eigen 5 | `EIGEN3_ROOT` |
| `Could NOT find GSL (Required is at least version 2.0)` | GSL only inside a conda prefix | `GSL_ROOT_DIR`, `PKG_CONFIG_PATH`, `CMAKE_PREFIX_PATH` |
| `Failed to run SMASH library example` | the example builds, then cannot load `libpythia8` from the custom prefix | `LD_LIBRARY_PATH` (`DYLD_LIBRARY_PATH` on macOS) |

`verify_smash.sh` sets all of them in one place. Note the third one is a
*runtime* failure after a successful build, so fixing only the configure-time
hints moves the error rather than removing it.

## 4. The default configurations are irreproducible on purpose

Every shipped config carries `Randomseed: -1`, meaning "draw a fresh seed". A run
made with it cannot be compared with a reference, with another machine, or with
itself. `run_smash.sh` refuses `-1` unless `--allow-random-seed` is given. With a
pinned seed the output is byte-identical between two runs of the same build.

## 5. Four test files seed themselves; two of them are observed flakes

`src/tests/potentials.cc` and `src/tests/random.cc` open with

```cpp
TEST(set_random_seed) { std::random_device rd; random::set_seed(rd()); }
```

and then assert statistical quantities against fixed tolerances, so they fail
occasionally on a correct build. Measured: `potentials` passed 4 of 5
consecutive standalone runs on macOS.

**Those two are the observed flakes, not the complete list of self-seeded
tests.** `src/tests/scatteraction.cc` (three call sites) and
`src/tests/dynamic_fluidization.cc` (one) also seed themselves, through
`random::generate_63bit_seed()`, which draws from `std::random_device` as well.
Neither has been seen to fail, so they are not on the retry list, but the claim
"the other 102 are deterministic" is false and is not made. Audit this set before
extending the retry policy.

`verify_smash.sh` therefore retries **only those two by name, once**, and treats
any other failure as fatal. Do not relax this into "allow one failure": that is
exactly how a real regression gets through.

## 6. `WARN Fpe : Failed to setup trap on pole error` is harmless

On macOS/ARM, SMASH cannot install floating-point traps and says so twice at
startup. It is a warning, not an error, and every run prints it. Beware when
writing log checks: a case-insensitive search for "error" matches this line, so
match SMASH's severity FIELD (`^[time] ERROR`) instead. `run_smash.sh` does.

## 7. A run can exit 0 having written fewer events than requested

Count the `# event N ensemble E end` markers rather than trusting the exit
status. Three traps, all of which this skill fell into once:

- The comparison is against **`Nevents` x `Ensembles`**, not `Nevents`. Each
  parallel ensemble is an independent system with its own end marker, so
  `Nevents: 1, Ensembles: 20` must produce 20 of them.
- The `ensemble` field is not optional: a pattern written as `# event N end`
  matches nothing in real SMASH-3.3 output.
- **Do NOT require the `out` and `end` markers to pair one-to-one.** That holds
  only for `Only_Final: Yes`. Under `Only_Final: No` one event contains an `in`
  block and several `out` blocks, and under `IfNotEmpty` an empty event has no
  block at all. Requiring the pairing rejected every legitimate `Only_Final: No`
  run. `run_smash.sh` now delegates the whole grammar to
  `check_conservation_smash.py --structure-only`; see
  `references/output-format.md` for the three block shapes.

## 8. Comparing multiplicities across machines is not a test

SMASH is Monte Carlo, and a transport code amplifies any floating-point
difference into different collision histories. The seeded output is bit-identical
within one build and should NOT be expected to match another build. Anchor on
baryon number and electric charge, which are integers fixed by the initial
nuclei and identical on every platform, for every seed. See
`scripts/check_conservation_smash.py`.

Be honest about what that buys, though. B and Q are a **limited invariant**, not
a general broken-build detector: most cross-section, collision-ordering, spectra,
flow and timing regressions preserve both. They catch a build that has lost
particles or corrupted its bookkeeping, and the test suite catches the rest. Do
not present a passing conservation check as evidence that the physics is right.

## 9. Licensing

GPL-3.0-or-later, confirmed twice: `LICENSE.md` in the repository and the
`rightsList` of the Zenodo record for SMASH-3.3. GitHub's detector reports
NOASSERTION only because `LICENSE.md` additionally reproduces the BSD-3, CC0 and
Unlicense terms covering bundled third-party code. Unlike Sky3D, nothing here is
restricted to non-profit use.

## 10. The library test relinks the binary, so a digest stamp goes stale

`usage_of_SMASH_as_library` reruns cmake and `make install` for its example
project, which **relinks `build/smash`**. Any check that compares the binary
against a digest recorded at install time therefore fails on the second run,
after the first full verify has "invalidated" a build that is perfectly sound.
Measured: two consecutive relinks of an unchanged tree produced three different
SHA-256 values, because the link is not byte-reproducible on macOS.

Bind a build to its source through `CMakeCache.txt` (`CMAKE_HOME_DIRECTORY` and
`CMAKE_CACHEFILE_DIR`) and through properties that survive a relink, not through
the binary's bytes. A digest stamp sitting in the same writable directory as the
binary it vouches for was never a defence anyway.

## 11. `file` calls a shell script "executable"

`file -b` describes a bash script as `Bourne-Again shell script text
executable`, so a guard written as `case ... in *executable*)` accepts exactly
the stub it was meant to reject. Match the object format positively:
`Mach-O*|ELF*`.

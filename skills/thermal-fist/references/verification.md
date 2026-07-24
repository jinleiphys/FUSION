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

**Tier 1, reproducing the shipped `test/ReferenceOutput` with a MIXED comparator.**
The 93 cases are Thermal-FIST's own ctest suite. It does NOT use one comparator:
cpc2 (4 cases) and cpc4's `analyt.dat` (1 case) are compared BYTE-EXACT with
`cmake -E compare_files`, while cpc1 (3 cases), Thermodynamics (6),
Susceptibilities (6) and NeutronStar (1) use `test_CompareOutputs` with an
absolute 1e-6 tolerance. cpc4's Monte Carlo output (`cpc4.montecarlo.dat`) is not
compared at all. Both platforms (macOS/Apple clang 21, Linux/gcc 13.3) pass every
case. So the honest claim is "reproduces the shipped reference, byte-exact where
upstream compares byte-exact and within 1e-6 where upstream uses its tolerance
comparator, on two platforms", never a blanket bit-identical (cpc1 is not) nor a
blanket 1e-6 (cpc2/cpc4 are byte-exact). Upstream flags cpc1 as possibly
non-deterministic across compilers (its `INCLUDE_ALL_TESTS` option would switch
cpc1 to `compare_files`), which is why cpc1 stays on the tolerance comparator.

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

`scripts/selftest_thermalfist.sh` covers 50 cases (46 without a pinned clone, plus
4 identity sub-guards when the clone is present) and needs no build: structural
validation of `check_output_thermalfist.py` (clean numeric
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

## What the adversarial passes found

FIVE Codex adversarial passes (`codex exec`, allowed to build and run the code)
ran. Round 1 returned 13 findings, round 2 found 4, round 3 found 7, round 4 found
4, round 5 found the certification-trust theme once more and confirmed NO new
false rejection and no functional regression; ALL fixed. selftest grew 35 -> 48
-> 50.

Round 5: the round-4 fixes held (no new row-count false reject, the
`.gitignore`-aware pristine filter caught the injection while passing `.DS_Store`),
but the from-source certification was still spoofable at the cache layer: install's
fast-path trusts the build stamp, which a local attacker with write access to the
cache could forge alongside reference-copying stubs and a hand-written CTest graph.
Closed concretely: the certifying path now forces a CLEAN REBUILD
(`TFIST_FORCE_BUILD=1`) from the SHA-pinned, pristine source, so the certified
binaries and CTest graph are produced by cmake in that run and cannot be forged
(short of breaking git's SHA integrity or having write access to the repo/scripts,
which is out of scope for every skill). This is the stopping point: the remaining
threat model is a local attacker who controls the filesystem, which no FUSION skill
defends against and which the clean rebuild now largely closes anyway.

Round 4: (1, BLOCKER, systemic) build identity was still spoofable: an external
build dir with a cache bound to the pinned source, 93 `/usr/bin/true` CTest
entries and reference-copying cpc stubs passed `VERIFY OK`. Being a regular file
inside the build does not prove cmake produced it. Fixed by design: a tier-1
certification (`VERIFY OK`) now requires verify to BUILD from the pinned source
itself via install; a caller-supplied build (`TFIST_*` preset) yields
`VERIFY PASSED-NOT-CERTIFIED`. This is a pattern shared by the whole skill family
(they all accepted a preset build); Thermal-FIST is the first to make the preset
path explicitly non-certifying. (2, MAJOR, FALSE REJECT) the run wrapper required
151 rows for every cpc2 config, but only config 0 has 151 (1 and 3 have 76, 2 has
61); the row count is now per-config. (3, MAJOR, FALSE REJECT) `git ls-files
--others` lists git-IGNORED files too, so a macOS `.DS_Store` (covered by the
repo's own `.gitignore`) false-rejected a legitimate clone; the predicate now uses
`--exclude-per-directory=.gitignore`, which honours every tracked `.gitignore` but
still not `.git/info/exclude`, so the injection attack stays caught while
`.DS_Store` does not. (4, MINOR) the `--help` header still described a uniform
1e-6 comparator; corrected to the mixed policy.

Round 3: (1, BLOCKER) `verify_thermalfist.sh` had been committed non-executable
(mode 100644), so the documented command returned permission denied; fixed to
100755. (2, MAJOR) `git status --porcelain` and `git diff --quiet HEAD` both skip
GIT-IGNORED untracked files, so a source injected under a CMake glob and listed in
`.git/info/exclude` passed the clean-tree check while the build compiled it; the
predicate now also requires `git ls-files --others` (no --exclude-standard) empty,
in install, verify and the selftest gate. (3, MAJOR) verify ran cpc3 from the
caller-supplied `TFIST_EXAMPLES`, which is not identity-checked, so an external
cpc3 stub was accepted; the example binaries are now derived from the
identity-checked `TFIST_BUILD` and required to be non-symlinked files inside it.
(4, MAJOR) the wrapper and the cpc3-NEQ structural check used lower-bound
row/column counts, so an 8-column, 182-row spoof with the right filename passed
when no reference was available; `check_output_thermalfist.py` gained `--rows`
and `--cols` EXACT options, now used by both. (5-7, MINOR) the selftest
reachability gate used the weaker predicate; the docs said 48 selftests (now 50)
and described the suite as uniformly 1e-6 (it is MIXED: byte-exact for cpc2/cpc4,
1e-6 for cpc1/EoS).

Round 2 (the round-1 fixes introduced their own defects, the recurring FUSION
pattern): (1, BLOCKER) the ctest stage counted `Passed` lines but no longer failed
directly on a nonzero reported-failure count, so a ctest printing 93 `Passed`
lines while reporting 1 failure and exiting nonzero would have passed; verify now
fails on any nonzero exit OR nonzero `NFAIL`, independently of the Passed count.
(2, MAJOR) `git diff --quiet HEAD` ignores UNTRACKED files, so an injected extra
source could sit in the pinned tree and be compiled by a glob build while the tree
looked clean; install and verify now use `git status --porcelain`. (3, MAJOR) the
install probe used lower-bound `--min-rows/--min-cols`, so a swapped binary
emitting an 8-column, 182-row table with a spoofed anchor row passed; the probe
now compares the full output to the shipped reference. (4, MAJOR) reference
comparison ignored the HEADER line; `cmp_reference` now compares the tokenized
header too. Each fix has an isolated selftest case, including a fake `ctest` that
prints 93 `Passed` lines then reports a failure.

Round 1 returned 13 findings, 5 blockers and 8 major, ALL fixed:

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
compares label text); the selftest coverage was incomplete (grown with the
new guards); and the docs said all cpc examples read `thermus23` while cpc3/cpc4
read `PDG2014` (corrected per program). Codex could NOT falsify the 93 serial-test
count, the config ranges, the citation, the GPL-3.0 license, or the `-j1` +
`CTEST_PARALLEL_LEVEL=1` serial enforcement, and found no bash-4 or GNU-only
dependency.

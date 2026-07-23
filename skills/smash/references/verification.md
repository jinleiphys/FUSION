# SMASH verification

**Tier 1: this reproduces SMASH's own test suite.** Measured 2026-07-23 at
upstream commit `d1a1c6cf0a0002ee064eec1b929b9a7c14b3d5bc` (SMASH-3.3, released
2025-12-03), with **no source patches on either platform**.

## Identity

| | |
|---|---|
| paper | Weil et al., Phys. Rev. C **94**, 054905 (2016), `10.1103/physrevc.94.054905` (CrossRef-verified) |
| software | SMASH-3.3, `10.5281/zenodo.3484711` (DataCite-verified, 2025-12-03) |
| licence | GPL-3.0-or-later, confirmed twice: `LICENSE.md` and the Zenodo `rightsList` |

GitHub reports NOASSERTION for this repository only because `LICENSE.md` also
reproduces the BSD-3, CC0 and Unlicense terms of bundled third-party code. This
is the KSHELL lesson applied: read the licence text, not the detector's verdict.

## Builds compared

| | macOS | Linux |
|---|---|---|
| machine | Apple Silicon | heliumx, x86-64 |
| compiler | Apple clang (C++17) | g++ 13.3.0 |
| GSL | Homebrew 2.8 | conda-forge, inside a conda prefix |
| Eigen | 3.4.0 headers fetched by the installer | same |
| Pythia | 8.316, built from source | same |

Neither platform needed a patch. The differences are entirely in where the
dependencies live, which is what the installer's detection logic exists for.

## Stage 1: the shipped test suite

SMASH ships **104 ctest cases**. Both platforms run them; `verify_smash.sh`
requires the count to be exactly 104, never "at least", so a suite that silently
skipped cases cannot certify the build.

Two of the 104 are **non-deterministic by upstream construction**, not by
platform. `src/tests/potentials.cc` and `src/tests/random.cc` both open with

```cpp
TEST(set_random_seed) {
  std::random_device rd;
  int64_t seed = rd();
  random::set_seed(seed);
}
```

and then assert statistical quantities against fixed tolerances, for example
`COMPARE_ABSOLUTE_ERROR(P2[0].front().momentum().velocity().x1(), 0.6, 0.003)`.
A fresh seed on every run therefore produces an occasional failure on a
perfectly good build.

**Two more test files seed themselves and are not on the retry list.**
`scatteraction.cc` calls `random::generate_63bit_seed()` at three sites and
`dynamic_fluidization.cc` at one; that helper also draws from
`std::random_device`. Neither has been observed to fail, so neither is retried,
but this skill does NOT claim that the other 102 cases are deterministic. Four
files self-seed; two of them have been seen to flake.

Measured flake rate on macOS: **`potentials` passed 4 of 5 consecutive
standalone runs**. Across two full-suite runs it failed once and passed once.
On Linux the suite passed **104 of 104 on the first attempt**, which is what a
statistical failure looks like: present on one machine's run and absent on
another's, with no platform meaning to it at all.

The policy this justifies is deliberately narrow: every other case must pass
on the **first** attempt, and only those two names may be retried, **once**. A
statistical fluke passes with a fresh seed; a broken build fails twice. Widening
this to "allow one failure" would let a real regression through, which is the
hole an earlier skill's `Total >= N` check had.

## Stage 2: a seeded physics anchor

The shipped collider configuration, Au+Au at E_kin = 1.23 GeV per nucleon
(the HADES energy), shortened to 2 events and 20 fm/c, with `Randomseed` pinned
to 20260723. About 25 s.

**Reproducibility within one build is exact.** Two runs of the same seeded
configuration produced a byte-identical `particle_lists.oscar` (997 lines).

**The anchor itself is a conservation check, not a multiplicity comparison:**

| quantity | measured | expected | |
|---|---|---|---|
| baryon number | 788 | 2 events x 2 nuclei x 197 | EXACT |
| electric charge | 316 e | 2 events x 2 nuclei x 79 | EXACT |

Those are integers fixed by the initial nuclei, so they are identical on every
platform and for every seed. They are checked **per event**, not only on the
total, because equal and opposite violations in two events would otherwise
cancel into a clean-looking sum. Their scope is limited and stated as such: they
catch lost particles and corrupted bookkeeping, not a wrong cross section, and
the test suite is what covers the rest. Contrast the multiplicities from the same run:

```
n 450, p 336, pi- 76, pi0 65, pi+ 57, eta 2, K0 2, Lambda 1, Sigma- 1
```

Those are recorded **only** as a same-build reproducibility check. They are a
2-event Monte Carlo sample; they are not a reference, they carry no quoted
uncertainty, and comparing them against another build would prove nothing.

That is not an argument, it is a measurement. The identical seeded configuration
on Linux gave a DIFFERENT sample:

| | macOS | Linux |
|---|---|---|
| particle records | 990 | 978 |
| n / p | 450 / 336 | 442 / 344 |
| pi- / pi0 / pi+ | 76 / 65 / 57 | 70 / 71 / 43 |
| **baryon number** | **788** | **788** |
| **electric charge** | **316** | **316** |

Same seed, same configuration, same source, and the multiplicities move by up to
25 per cent while the two conservation laws are identical integers. Anchoring a
Monte Carlo transport code on multiplicities would therefore have produced a
skill that fails on every machine but the one it was built on. This is the whole
reason the anchor is a conservation law.

## The library test needs three environment hints, each found the hard way

`usage_of_SMASH_as_library` spawns a fresh cmake for the example project, and
that child inherits none of the main build's `-D` cache variables. It therefore
re-runs `find_package` for everything and fails on whatever the machine lacks.
Three failures appeared in sequence, each hidden behind the previous:

1. macOS: `Could NOT find Eigen3 (missing: EIGEN3_VERSION_OK)`, because it found
   the system Eigen 5.0.1 whose renamed macros SMASH 3.3 cannot parse. Fixed by
   exporting `EIGEN3_ROOT`.
2. Linux: `Could NOT find GSL (Required is at least version 2.0)`, because GSL
   lives only inside a conda prefix. Fixed by `GSL_ROOT_DIR`, `PKG_CONFIG_PATH`
   and `CMAKE_PREFIX_PATH`.
3. Linux again: `Failed to run SMASH library example`. The example now BUILT and
   then failed to load `libpythia8` from the custom prefix. Fixed by
   `LD_LIBRARY_PATH` (`DYLD_LIBRARY_PATH` on macOS).

Worth stating because the first fix moved the error rather than removing it, and
a skill that stopped after step 1 would have shipped a suite that fails 103/104
on any cluster.

## What the adversarial pass found

The first version of this skill FAILED its adversarial pass with 19 defects, 7
of them blockers, and every one was reproduced before being accepted. Two are
worth carrying forward because both looked like the skill's strong points:

1. **`--seed -2` did not pin anything.** SMASH treats ANY negative seed as
   "draw a fresh one", not only the `-1` in the shipped configs. Two runs with
   `--seed -2` used seeds 8409242248972502135 and 4845130125537222390 and
   produced different output, while `config_used.yaml` still read `-2` and
   looked pinned. The guard now judges the effective seed numerically.
2. **The baryon-number rule was still wrong after being "fixed" once.** Adding
   nuclear codes did not repair the underlying error, which was treating "four
   digits" as the definition of a baryon. Every excited state SMASH propagates
   breaks it: N(1440) is 12112, Lambda(1405) is 13122. It now transcribes
   `PdgCode::baryon_number()` from the source (a non-nuclear hadron whose n_q1
   digit is nonzero), checked against 24 cases including anti-resonances and
   hypertriton. The Au+Au anchor happens to be taken after the resonances have
   decayed, which is exactly why the error survived the first fix.

Both share a shape: a rule that held for the sample in front of me, generalized
without checking it against the code's own definition.

Other blockers were false-success paths: verify discarded ctest's exit status; a
mixed `(Failed)` plus `(Timeout)` slipped through a regex that matched only the
first; a retry that selected NO tests exited 0 and counted as a pass; pre-set
`SMASH`/`SMASH_BUILD` bypassed every identity check; `run_smash.sh` accepted a
forged OSCAR file; and shipped examples ran against the DEFAULT particle tables
because `-p/-d` were never passed, succeeding while computing the wrong thing.

Two factual corrections came out of it too: `potentials.cc` and `random.cc` are
not the only self-seeded tests, and the event grammar carries an `ensemble`
field this document originally omitted.

## Harness

`scripts/selftest_smash.sh`, 49 cases, no SMASH build required (the run tests use
a stub executable). Every guard has a negative case that fails only that guard,
and each asserts WHICH guard fired. The one that most needed it: SMASH prints
`WARN Fpe : Failed to setup trap on pole error.` on every macOS run, so a
case-insensitive search for "error" flags a healthy run. The passing control is
asserted to actually contain that warning line, so the error-guard test cannot
pass vacuously.

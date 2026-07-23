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

## What the SECOND adversarial pass found, and why it matters more

Round 2 confirmed 11 of the 19 as fixed and found **two new blockers, both
caused by round 1's own fixes.** They are recorded here in full because the
shape repeats:

1. **The identity check rejected a legitimate build.** Round 1 added a
   binary-digest comparison against the installer's stamp. But SMASH's own
   `usage_of_SMASH_as_library` case reruns cmake and `make install`, which
   **relinks `build/smash`**, so the stamp goes stale during the very run that
   is supposed to certify the build, and the next `verify` died at the identity
   check before testing anything. Measured: two consecutive relinks of an
   unchanged source tree gave `51e39a9e...`, `a8b05efc...` and `c0031eeb...`,
   three different digests, because the link is not reproducible on macOS. The
   digest was also never a real defence, since the stamp file sits in the same
   writable directory as the binary it vouches for.
2. **Real `Only_Final: No` output was rejected outright.** Round 1 added "the
   `out` and `end` markers must pair one-to-one", which is true only of the
   shipped `Only_Final: Yes` collider configuration. A real run writes one `in`
   block and one `out` block per output interval inside a single event.
   Measured on a live Au+Au run: 10 block-start markers against 2 end markers,
   so `run_smash.sh` refused it, and `check_conservation_smash.py` failed with
   "event 0/0 starts while 0/0 is still open".

Both guards had been validated against exactly one configuration. **A guard that
has met only one input has not been tested, it has been demonstrated.**

The fixes, and the evidence for each:

| | fix | evidence |
|---|---|---|
| identity | bind the build to the source through `CMakeCache.txt` (`CMAKE_HOME_DIRECTORY` and `CMAKE_CACHEFILE_DIR`), require a native Mach-O/ELF binary inside that build tree reporting the pinned `git describe`, and gate the stamp's build-identity LINE (stable across a relink) instead of the digest | a relinked binary now certifies; six negative cases each reject on their own guard |
| grammar | one parser for the OSCAR2013 block grammar, transcribed from `src/oscaroutput.cc`, covering all three `Only_Final` shapes; `run_smash.sh` calls it with `--structure-only` instead of re-parsing in shell | a live `Only_Final: No` run: 4824 records in **12** blocks across 2 events, baryon number 394 and charge 158 **in every one of the 12**, including the intermediate blocks that still contain Delta resonances |

That second measurement is also the strongest live test of the round-1 baryon
rule: the intermediate blocks balance only because `2224` and friends are
counted as baryons, and the particle count grows from 394 to 439 as resonances
decay while both conserved integers do not move.

Two smaller results from the same pass, both measured rather than argued:

- **Parallel ensembles are separate systems.** `Nevents: 1, Ensembles: 3`
  completes THREE `(event, ensemble)` pairs, labelled `event 0 ensemble 0..2`,
  each with its own 394 baryons. The old check compared against `Nevents` alone
  and rejected the run.
- **A relative `--particles` path resolved twice.** It was validated against the
  caller's directory and then handed to SMASH, which runs from the config's
  directory, so the file checked was not always the file used. Paths are now
  made absolute at the point of validation.

### Both platforms re-verified after the round-2 fixes

The fixes are harness code, so they were re-run end to end on both platforms
rather than only where they were written:

| | macOS/ARM | Linux/x86-64 (heliumx) |
|---|---|---|
| `selftest_smash.sh` | 84/84, no block skipped | 84/84, no block skipped |
| ctest | **104/104 on the first attempt** | **104/104 on the first attempt** |
| anchor B / Q | 788 / 316 exact | 788 / 316 exact |
| verdict | `VERIFY OK` | `VERIFY OK` |

The Linux anchor reproduced the multiplicities this document already recorded
for that platform (978 records, n/p 442/344, pi 70/71/43), which is a useful
consistency check that the rebuilt Linux binary is the same code, and another
reminder that those numbers differ from macOS by up to 25 per cent while the
two conserved integers do not move at all.

Taking the harness to Linux was not a formality. It exposed that the identity
and ctest selftest blocks were **fabricating their fixture**: they synthesized a
stamp with `head -1` of the real build's stamp, and the Linux build predated the
stamp, so that file did not exist, `head -1` contributed nothing, and the
synthetic stamp collapsed to a single line holding the digest, which the
identity check dutifully reported as a bad build-identity line. Eight cases
failed against an input the fixture had invented. The blocks now require a real
stamp as a precondition and say plainly when they are skipped. **On macOS the
bug was invisible, because there the file exists.**

## What the THIRD adversarial pass found

Round 3 was run against the round-2 fixes. Part A: **8 FIXED, 4 PARTIAL, 0 NOT
FIXED**, so both blockers and the previously unfixed item are closed. Part B
found six residuals, and the instructive thing is that **four of them were
created by the round-2 fixes themselves**, which is the third time in this
skill's history that a fix has introduced a defect of the same shape as the one
it repaired.

| finding | what actually happened | fix |
|---|---|---|
| the non-OSCAR branch skipped the log scan | the branch added for Binary/Root configs exited BEFORE the `ERROR`-severity check, so a Binary-only run that logged a genuine error returned success | the log scan moved above every branch that can exit |
| `config.yaml` counted as output | SMASH always copies its configuration into the output directory, so "produced at least one non-empty file" was satisfied by a run that produced nothing | that one filename excluded from the count |
| an inline YAML comment disabled the event count | `Nevents: 2 # comment` is valid YAML; the value read back was `2 # comment`, `is_uint` rejected it, no `--events` expectation was passed, and a run that wrote one of two events passed | `read_key` strips the comment, and the seed is read through it too |
| an oversized seed bypassed the negative-seed guard | `--seed 9223372036854775808` matched the unbounded integer regex, then bash could not compare it, printed "integer expression expected", and the run went ahead | the integer patterns are bounded to 18 digits |
| the marker grammar was too loose | `COUNT` was optional and the `end` tail was unconstrained, so `# event 0 ensemble 0 out` and `# event 0 ensemble 0 end nonsense tokens` both passed | both patterns anchored to the full line, `COUNT` mandatory, and a marker-shaped line that does not match is REPORTED rather than skipped |
| the shipped `List` example could not be run | `run_smash.sh` runs from the config's directory, but `input/list/config.yaml` sets `File_Directory: "../input/list"`, which resolves only from the build directory. Measured: `FATAL List: example_list0 does not exist!` | a `--workdir` override, documented with the exact command |

**A validation that a comment can disable is not a validation**, and neither is
one that a large number can step around. Both are the same failure as the
original blockers: a rule that held for the inputs in front of me.

### On the remaining identity finding

Round 3 demonstrated, rather than argued, that identity can be satisfied by a
constructed build tree: a native stub, a fabricated `CMakeCache.txt` and stamp,
and a fake `ctest` earlier on `PATH` produced `VERIFY OK`. That is correct and
was already stated in the code: everything the check inspects is metadata the
caller can write, so no amount of further metadata checking closes it.

What DOES distinguish the two cases is who produced the build. On the default
path this script runs `install_smash.sh`, which clones the pinned commit and
builds it here; when `SMASH`/`SMASH_BUILD`/`SMASH_ROOT` are pre-set the build
arrives from outside and its provenance is asserted rather than established.
So that path now still runs and still catches mistakes, but it **cannot print
the tier-1 verdict**: it ends in `VERIFY PASSED-NOT-CERTIFIED`. Certification
is reserved for the route where this harness produced the build itself.

## The FOURTH pass, and what four rounds of this actually measured

Round 4 was aimed squarely at the round-3 fixes, on the reasoning that the
interesting question was no longer "were the findings fixed" but "did the fixes
break something new". Part A: **all six round-3 findings confirmed FIXED**,
each against real output. Part B found **two new defects, both introduced by
round 3, both in the same two lines of input validation**:

1. **The 18-digit cap rejected a legitimate seed.** SMASH's `Randomseed` is an
   `int64_t`, and `9223372036854775807` is exactly its maximum; raw SMASH runs
   with it. The round-3 fix had replaced an unbounded regex (which let an
   uncomparable value bypass the negative-seed guard) with a DIGIT COUNT, and a
   digit count is not a range. It now asks python for the real int64 bound, so
   the maximum is accepted and one past it is still refused.
2. **Quoted YAML numerics.** `Randomseed: "123"` and `Nevents: "2"` are valid
   YAML that SMASH accepts. The quoted seed was rejected outright, and the
   quoted `Nevents` did something worse: `is_uint` failed, no `--events`
   expectation was passed, and **the event-count check silently switched off**
   while the run still reported success having written one event of two.

The second is the one worth keeping, because the quoting was only the trigger.
The defect was that an unparseable value took the FAIL-OPEN branch. Stripping
quotes fixes the reported case; what fixes the class is that a key which is
present but unreadable is now an ERROR:

```
the configuration's Nevents is 'two', which this wrapper cannot read as a count,
so the number of events written could not be checked. Fix the value, or pass --nevents.
```

Four rounds in, the honest summary is that **every round has introduced defects
of the same shape as the ones it repaired**: rounds 2, 3 and 4 each found that
the previous round's fix had a new false-pass or false-reject in it. The
countermeasures that actually caught things were never careful reading. They
were, in order of yield: running the harness on a second machine, the flip test,
and an adversarial reader with permission to run the real code. Nothing here was
found by inspection.

Round 4 also confirmed, by running them, that the tightened marker grammar
rejects nothing legitimate: `Only_Final` Yes / No / IfNotEmpty (empty and
non-empty), `Ensembles: 2`, `OSCAR2013Extended`, and the Collider, Box, Sphere,
List and ListBox modi all parse. The hardcoded `end 0 impact <x>
scattering_projectile_target yes|no` tail matches every real particle-list
event; `SMASH_IC` writes a bare `end`, and that content is correctly refused as
not `particle_lists` rather than mis-parsed.

## The guard-flip discipline, applied

Per the project rule, no new guard is counted as tested until it is shown to
flip. Each was disabled in turn and the suite rerun; every one failed **exactly
one** case, the case written for it, and nothing else:

| guard disabled | case that flipped |
|---|---|
| log scan before the output branch | a Binary-only run that logged an ERROR |
| `config.yaml` excluded from the output count | a run that wrote only its own config |
| `read_key` comment stripping | an inline YAML comment disabling the event count |
| 18-digit bound on integers | two oversized seeds |
| mandatory `out COUNT` | an `out` marker with no count |
| preset-path certification downgrade | a supplied build printing the tier-1 verdict |
| int64 range check (vs the 18-digit cap) | the int64 maximum seed being accepted |
| quote stripping in `read_key` | a quoted Randomseed, and a quoted Nevents enforcing the count |
| fail-closed on an unreadable Nevents/Ensembles | both unreadable-value cases |
| Mach-O/ELF check | a shell script named `smash` is rejected |
| `particle_lists` content check | a `full_event_history` file is refused |
| `CMAKE_HOME_DIRECTORY` binding | a build configured from another source tree |
| `CMAKE_CACHEFILE_DIR` binding | a `CMakeCache.txt` copied from another build |
| stamp build-identity check | a stamp recording another commit |
| `CMakeCache.txt` existence | a build directory that is not a cmake tree |

That exercise immediately caught a defect in a guard I had just written: the
file-type check was `case ... in *executable*)`, and `file` describes a shell
script as "Bourne-Again shell script text **executable**", so the stub sailed
through the check meant to exclude it. It now matches `Mach-O*|ELF*`
positively. Writing the guard is not the work; proving it fires is.

Three of the negative cases were themselves wrong when first written, and the
flip discipline is what exposed them: the missing-`CMakeCache` case pointed at a
binary that did not exist and so tripped the "no usable executable" check first;
the fewer-events case deleted an event's two marker lines but left its three
records behind, so it failed on the stray-record guard rather than the
event-count guard it was written for; and the `Only_Final: No` fixture I wrote by
hand did not actually conserve baryon number (p + n going to Delta++ + pi-),
so a correct parser rightly rejected it.

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

`scripts/selftest_smash.sh`, **100 cases** (49, then 84, then 94 after the
second, third and fourth adversarial passes), a few seconds, 100/100 on BOTH
platforms. The run and ctest tests use stub executables, so no SMASH
build is required; the identity and ctest-parsing cases additionally use the
local clone when there is one, because the git pin is the one thing that cannot
be synthesized, and they announce themselves as skipped when there is not.

Every guard has a negative case that fails only that guard, and each asserts
WHICH guard fired. The one that most needed it: SMASH prints
`WARN Fpe : Failed to setup trap on pole error.` on every macOS run, so a
case-insensitive search for "error" flags a healthy run. The passing control is
asserted to actually contain that warning line, so the error-guard test cannot
pass vacuously.

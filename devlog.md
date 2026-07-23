# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.
Full-length versions of consolidated entries live in `devlog-archive.md` (not auto-imported).

## 2026-07-23: SMASH round 3, where four of six new defects came from round 2's fixes

**Why we tried it:** cross-AI validation is mandatory before a per-code skill
ships, so the round-2 fixes went straight into a third adversarial pass.

**Verdict:** Part A 8 FIXED, 4 PARTIAL, 0 NOT FIXED. Both blockers and the
previously unfixed item are closed. Part B found six residuals, and **four of
them were introduced by the round-2 fixes themselves**, the third time in this
skill that a repair has shipped a defect shaped like the one it repaired.

**The four self-inflicted ones, all false passes:**

- The non-OSCAR branch added for Binary/Root configs exited BEFORE the
  `ERROR`-severity log scan, so a Binary-only run that logged a real error
  returned success. Checks that apply to every run must precede every branch
  that can exit.
- `config.yaml` counted as produced output. SMASH always copies its
  configuration into the output directory, so "produced at least one non-empty
  file" was satisfied by a run that produced nothing.
- `Nevents: 2 # comment` is valid YAML, and `read_key` did not strip the
  comment, so `is_uint` rejected `2 # comment`, no `--events` expectation was
  passed, and the event-count check silently did nothing.
- `--seed 9223372036854775808` matched an unbounded integer regex, bash could
  not compare it, printed "integer expression expected", and the run proceeded,
  bypassing the negative-seed guard entirely.

**Two that were merely too loose:** the marker grammar left `COUNT` optional and
the `end` tail unconstrained, so a truncated `out` and an `end nonsense tokens`
both passed; and the shipped `List` example could not be run at all, because
`run_smash.sh` runs from the config's directory while
`input/list/config.yaml` sets `File_Directory: "../input/list"`, which resolves
only from the build directory (measured: `FATAL List: example_list0 does not
exist!`). Fixed with a documented `--workdir`.

**The identity finding was accepted rather than patched.** Round 3 demonstrated
that a constructed build tree (native stub, fabricated CMakeCache and stamp,
fake ctest on PATH) yields `VERIFY OK`. That is true and unfixable by more
metadata checking, because the metadata is what is being forged. What changed is
the claim, not the check: a build supplied through `SMASH`/`SMASH_BUILD`/
`SMASH_ROOT` now ends in `VERIFY PASSED-NOT-CERTIFIED`, and the tier-1 verdict
is reserved for the path where this harness built the code itself.

**Lesson:** "a validation that a comment can disable is not a validation", and
neither is one a large number steps around. Every one of these is the original
blocker's shape: a rule written for the inputs in front of me. The practical
countermeasure that keeps working is not more care while writing, it is the flip
test plus running the harness somewhere else, which is what exposed the
fabricated-fixture bug that macOS could not see.

**Status:** all six addressed, selftest 84 to 94 cases, every fix flip-tested,
94/94 on macOS/ARM and Linux/x86-64.

## 2026-07-23: SMASH round-2 blockers, or: a guard is only as good as its worst input

**Why we tried it:** the two round-2 blockers had to be cleared before SMASH
could ship, and both were regressions introduced by round 1's own fixes. That
made them worth more than their fix cost, because the same mistake produced
both.

**What failed, reproduced before touching anything:**

- The identity check rejected a legitimate build. SMASH's own
  `usage_of_SMASH_as_library` ctest case reruns cmake and `make install` and
  **relinks `build/smash`**, so the digest the installer stamped goes stale
  during the very run meant to certify the build. Measured: three consecutive
  relinks of an unchanged tree gave three different SHA-256 values, so the link
  is not byte-reproducible on macOS and a digest was never a stable identity.
  It was not a security boundary either: the stamp file sits in the same
  writable directory as the binary it vouches for.
- Real `Only_Final: No` output was rejected outright. A live Au+Au run wrote 10
  block-start markers against 2 end markers, and the "out and end must pair"
  rule refused it; the conservation checker failed alongside with "event 0/0
  starts while 0/0 is still open".

**Root cause, identical in both:** each guard was written against the one
configuration in front of me, the shipped `Only_Final: Yes` collider run, and
never confronted with the output it would actually meet. The SMASH source
answers both questions directly, in `oscaroutput.cc` and in what the library
test's CMake actually does.

**The fixes.** Identity now binds the build to the source through
`CMakeCache.txt` (`CMAKE_HOME_DIRECTORY` and `CMAKE_CACHEFILE_DIR`), requires a
native Mach-O/ELF binary inside that tree reporting the pinned `git describe`,
and gates the stamp's build-identity LINE, which survives a relink, instead of
the digest. The OSCAR grammar now lives in ONE place: it was transcribed from
`oscaroutput.cc` into `check_conservation_smash.py`, covers all three
`Only_Final` shapes, and `run_smash.sh` calls it with `--structure-only` rather
than re-parsing in shell. Conservation is checked per BLOCK, not per event.

**Evidence:** a live `Only_Final: No` run gives 4824 records in 12 blocks over 2
events, with baryon number 394 and charge 158 in every one of the 12, including
the intermediate blocks that still hold Delta resonances while the particle
count climbs 394 to 439. That is simultaneously the strongest live test of the
round-1 baryon-number rule.

**The part worth keeping.** Applying the flip discipline immediately caught a
defect in a guard written minutes earlier: the "must be a native executable"
check was `case ... in *executable*)`, and `file` calls a bash script
"Bourne-Again shell script text **executable**", so it accepted exactly the stub
it existed to reject. Three of the negative CASES were also wrong when first
written, each failing on a different guard than the one it claimed to test, and
one hand-written OSCAR fixture did not conserve baryon number at all, so a
correct parser rightly rejected it.

**Lesson:** when a guard encodes a rule, find the code that already defines it
and transcribe it; when a guard is written from a sample, assume the sample is
unrepresentative until a second one says otherwise. And run the flip check on
the guard you just wrote, not only on the old ones, because that is when the
rule is least tested.

**Status:** both blockers fixed, plus all 10 remaining round-2 items including
the one previously NOT FIXED (`run_smash.sh` hard-requiring
`particle_lists.oscar`, so Binary/Root/HepMC-only configs always failed).
Selftest 49 to 83 cases.

## 2026-07-23: SMASH, and a rule that was wrong twice in the same way

**Why we tried it:** SMASH was the first code of the newly opened heavy-ion row.
Building it was routine; the interesting failures were again all in the harness,
and one of them repeated a mistake I had already made and thought I had fixed.

**What failed:** the skill failed its adversarial pass with 19 defects, 7 of them
blockers. The one worth keeping is the baryon-number rule. I first wrote "a
four-digit PDG code is a baryon". Told that light nuclei break it, I added the
ten-digit nuclear codes and considered it fixed. It was still wrong: N(1440) is
`12112` and Lambda(1405) is `13122`, and resonances are the BULK of a transport
run's intermediate state, so the "exact conservation" anchor would have been
silently wrong on any output taken before they decay.

**Root cause:** both versions generalized from the sample in front of me instead
of reading the code's own definition. SMASH answers the question directly in
`PdgCode::baryon_number()`: a non-nuclear hadron whose `n_q1` digit is nonzero.
Once transcribed, protons, resonances, anti-resonances and hypernuclei all fall
out of one rule. The 2-event Au+Au anchor is taken at 20 fm/c, after the
resonances have decayed, which is exactly why the first fix looked sufficient:
the test case could not see the error.

**Lesson:** when a code ships the predicate you are reimplementing, transcribe
it rather than inferring it from examples, and cite the file and function in a
comment so the next person can check. And when a fix is prompted by one
counterexample, ask whether the counterexample is the only thing wrong with the
rule, or just the first thing noticed.

**Second lesson, from a different blocker:** `--seed -2` pinned nothing, because
SMASH treats ANY negative seed as random while `config_used.yaml` still recorded
`-2` and looked pinned. A guard written against the literal default (`-1`) rather
than against the code's actual behaviour is a guard that certifies exactly the
thing it was meant to prevent.

**Third lesson, from round 2, and the one that actually cost the most:** the two
NEW blockers were caused by my own round-1 fixes. The build-identity check I
added to close a bypass rejects a LEGITIMATE build, because SMASH's own library
test reruns `make install` and relinks the binary after the installer stamped
it; and the structural OSCAR check I added rejects real `Only_Final: No` output,
which has one `in` block and several `out` blocks per event. Both guards were
validated against exactly one configuration, the default collider run with final
output only. A guard that has only met one input has not been tested, it has
been demonstrated.

**Status:** IN PROGRESS, not shipped. Round 1's 19 defects are fixed; round 2
left 2 blockers, 7 partials and 1 unfixed item, all listed in TODO.md.

## 2026-07-23: Sky3D, and a guard that only the expensive path could falsify

**Why we tried it:** Sky3D (TDHF) was the first skill of the newly opened
heavy-ion row. The static 16O case reproduces the shipped reference exactly, so
the physics side was settled early; the interesting failures were all in the
harness.

**What failed:** the skill failed its adversarial pass with 21 defects, and then
its RE-verification pass with 8 more, one a blocker. The blocker is the one
worth keeping. The numeric-overflow guard excluded Sky3D's symmetric
`***** X *****` headers, but a real collision log also carries one-sided ones
(`***** Data for fragment # 1 from file ...`, `******* Fragment # 0`), so every
legitimate collision run was rejected, and `verify --with-collision` would have
failed AFTER completing a 45-minute run. Second worst: `compare_sky3d.py`
silently dropped a `NaN` from an energy line, because the numeric regex does not
match "NaN", and then reported 265 values EXACT against a 266-value reference.

**Root cause:** both are the same mistake in two costumes. A guard was written
against the output I happened to have in front of me (a static run, a well-formed
number) and never confronted with the output it would actually meet. I had never
put a real collision `for006` through the validator, and never put a genuinely
malformed value through the comparator; my own NaN test "passed" only through
column misalignment, so it proved nothing.

**Lesson:** a guard must be exercised against REAL output from every path it
gates, not only the path that is cheap to run. If a path takes 45 minutes,
extract one real output file from it once and keep that as a fixture, so the
guard is tested in seconds forever after. Corollary that paid twice here: make
every negative case assert WHICH guard fired. That mechanism caught two silent
diversions in this session, including five pre-existing cases that a newly added
requirement had rerouted onto the wrong guard.

**Also measured, and left open:** an intermittent SIGBUS at startup on macOS,
1 failure in 25 consecutive static runs (plus one during verification, so about
4 per cent), against 0 in 25 on Linux. It dies before the first iteration with an
empty for006. **Stack exhaustion is refuted**: a deliberately reduced 2 MB stack
gave 0 failures in 6 runs, where a stack-limited crash would have got worse, not
better. Do not retry `ulimit`. Cause unknown. It is a loud failure, so the
harness rejects it instead of accepting a truncated run, and the skill ships as
tier-1-with-a-stability-caveat rather than a bare tier 1.

**Status:** Fixed, selftest 33 to 69 cases. Every landed attack is now a
permanent regression test with a real-output fixture. The SIGBUS is documented,
not solved.

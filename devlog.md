# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.
Full-length versions of consolidated entries live in `devlog-archive.md` (not auto-imported).

## 2026-07-23: SMASH shipped after five adversarial rounds, and what actually found the defects

**Why it matters beyond SMASH:** four of the five rounds found that the PREVIOUS
round's fixes had introduced a new defect of the same shape as the one they
repaired. That is a base rate, not bad luck, and it is the reason this entry
exists. Full round-by-round detail in devlog-archive.md.

**Severity decayed monotonically**, which is what finally justified stopping:
round 2 gave two blockers (a legitimate build rejected, real `Only_Final: No`
output rejected), round 3 four silent false passes, round 4 two input-validation
boundary defects, round 5 one false reject. The stopping condition was never a
round count; it was a round that comes back without a new defect of that shape.

**What found the defects, in order of yield:**

1. **Running the harness on a second machine.** This exposed selftest fixtures
   that were FABRICATING their own input: they built a stamp with `head -1` of a
   file that does not exist on Linux, so eight cases failed against an invented
   fixture. On macOS the file exists and it all passed cleanly.
2. **The flip test** (disable the guard, confirm exactly its own case fails, and
   nothing else). This caught a guard written minutes earlier: `case ... in
   *executable*)` accepted a bash script, because `file` calls one
   "Bourne-Again shell script text executable".
3. **An adversarial reader allowed to RUN the real code**, not just read it.

**Nothing in five rounds was found by inspection**, including my own inspection
immediately after writing the code. Plan for that rather than intending to be
more careful.

**The one fix that retired a whole class instead of one case:** replacing a
fail-open branch with a fail-closed one. `Nevents: "2"` (valid YAML) made a
parse fail, which SKIPPED the event-count check, so a run that wrote one event
of two reported success. Stripping quotes fixes the reported case; making an
unreadable-but-present key an ERROR fixes the class. **Any validation whose
"I could not read this" path is `skip` is one unexpected spelling away from not
existing.**

**Two SMASH-specific facts worth keeping:** its own `usage_of_SMASH_as_library`
ctest reruns cmake and `make install`, relinking `build/smash`, so any identity
check based on a binary digest goes stale during the very run meant to certify
it (three relinks of an unchanged tree gave three different SHA-256s). And a
digit count is not a range: capping a seed at 18 digits rejected
`9223372036854775807`, which is exactly the `int64_t` maximum SMASH accepts.

**Status:** SHIPPED, tier 1, seventeenth per-code skill. selftest 103/103 and
ctest 104/104 first attempt on macOS/ARM and Linux/x86-64.

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

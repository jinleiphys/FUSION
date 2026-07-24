# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.
Full-length versions of consolidated entries live in `devlog-archive.md` (not auto-imported).

## 2026-07-24: GiBUU adversarial pass, one blocker, all in the seed/parse edges

**Why we tried it:** first Codex pass on the GiBUU skill (18th per-code skill,
tier 2). Nine findings, one blocker, all fixed and re-verified on both platforms.

**The blocker, same shape as everything SMASH kept hitting.** The effective-seed
readback grepped the first `SEED=` line ANYWHERE in the job card, but GiBUU reads
the first `&initRandom` NAMELIST. An empty first `&initRandom` with a seeded
second block, or a stray `SEED=` outside any block, made the wrapper report a
seeded run while GiBUU fell back to the clock. Both injection and readback now
operate strictly on the first `&initRandom` block; verified against the real
binary. It is the SMASH lesson restated: a rule ("the seed is the first SEED=
line") that held for my sample and not for what the code accepts.

**Two that only Linux could show, both about following symlinks / env:**
- the `-lbz2` conditional retry (added blind for Linux, never exercised on
  macOS) fired correctly on the first Linux run;
- the new native-exe fast-path guard rejected the REAL Linux build, because
  GiBUU.x is a symlink and GNU `file` does not follow symlinks by default while
  macOS `file` does. Fixed with `file -bL`. This is a fresh instance of "a guard
  validated on one platform," and it was caught only by running on the second.

**Other fixes:** Inf slipped past a guard matching only `infinity`; GiBUU's own
`!!!!! ERROR ... STOPPING !!` fatal line was missed by an anchored `^ERROR`
regex; the seed range was int64 but GiBUU's Seed is a 32-bit integer that aborts
above 2^31-1; the checker read only the last row and one sum rule (now every row
and both `col2+3+4=col5` and `col5+6=col7`); the vacuity guard was exact-zero
only (the pion-absorption card gives -3.7e-11).

**A number claim retracted.** "343,039 numbers bit-identical" was false
precision: the per-number count is tokenizer-dependent (three methods, three
answers, because Fortran line-wraps records). Replaced with the exact,
reproducible unit: 5 of 8 output files are seed-driven, 3 are lookup tables, and
all 8 are bit-identical across platforms at a fixed seed.

**Lesson:** first-pass discipline (dual-platform + flip + fixture self-assert)
caught two defects during construction, but the seed blocker and the symlink
guard were caught only by an adversary running the real binary on both
platforms. Construction-time testing against your own model of a Fortran
namelist reader has a floor; the real binary is the only authority.

**Status:** all nine fixed, selftest 37 to 50 cases, every new guard flipped,
VERIFY OK on macOS/ARM and Linux/x86-64.

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

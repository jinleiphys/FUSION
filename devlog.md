# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.
Full-length versions of consolidated entries live in `devlog-archive.md` (not auto-imported).

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

**Status:** Fixed. selftest 29 to 49 cases, every landed attack a regression
test. SMASH ships tier 1.

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

## 2026-07-23: fresco skill unified across FUSION and the global copy; exfor-data is the first research skill

**Direction change (user ruling):** the 2026-07-14 decision that the auto-install
variant lives only in FUSION is **withdrawn**. The global skill and the FUSION copy
are now kept byte-identical and `diff -r` between them must be empty. Both check the
bin dir, then PATH, and build from upstream only if neither has a binary, so a deck
authored in one place runs unchanged in the other. CLAUDE.md line amended in place
rather than appended to, because a stale rule there actively misleads a later session.

**New in the fresco skill: `scripts/omp.py`.** Emits KD02 and CH89 global nucleon
optical potentials as ready-to-paste `&POT` blocks. Pure Python, standard library,
so it needs no Fortran toolchain even though it is a transcription of Fortran.

Why a generator rather than letting the model write the parameters: the formulas are
the easy part, the handoff into FRESCO is not. Three failure modes are silent, meaning
the deck runs and prints a plausible cross section that is wrong. FRESCO builds radii
as `R = r0*(Ap^1/3 + At^1/3)` while KD02 and CH89 are defined on `R = r0*At^1/3`, so
without `ap=0` every radius is ~22% too large. `W_d` must land in `p4` of the `type=2`
line, since `p1` makes it a real surface well and the absorption quietly drops. And a
`type=0` line is required even for neutrons because it is what declares the convention.

**Precision finding worth keeping.** `--selftest` pins 39 values against the reference
Fortran and passes at 2e-7, not machine epsilon. First diagnosis (single-precision cube
root) was wrong and Codex caught it: **every unsuffixed real literal in that kd02.f is
single precision**, so `59.30` enters as `59.2999992370605`. Proof that the cube root is
not the mechanism: neutron `V` contains no cube root at all yet still deviates, and
recompiling with `-fdefault-real-8` matches the Python to 16 digits. The reference
`ch89.f` suffixes everything with `d0` and reproduces exactly. So the Python is the more
accurate of the two and the residual belongs to the Fortran. End to end the generated
deck gives sigma_R = 1301.64017 mb for n+90Zr at 50 MeV, identical to a hand-built deck.

**First research skill embedded: `skills/exfor-data/`.** Drives no code, so the per-code
bar does not apply; see skills-catalog.md for the EXFOR-specific traps (unscriptable
search servlet, fixed-width blank-preserving records, `DATA-ERR` sometimes in per cent,
`COMMON` and `DATA` counting their header lines differently).

**Codex adversarial pass on both:** 3 defects, all confirmed and fixed. (1) the precision
diagnosis above; (2) `omp.py` accepted impossible nuclides, so `--target 90,40` silently
returned parameters for Z=90 A=40 when the user meant 90Zr, now rejected with a message
naming the correct spelling; (3) `exfor.py` documented a header-count consistency check
that the code never actually performed, so a truncated wrapped record vanished silently.
Fixing (3) then exposed that EXFOR counts `COMMON` and `DATA` header lines differently,
which caused 33 false warnings on real entries before both readings were accepted.

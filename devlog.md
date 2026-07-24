# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.
Full-length versions of consolidated entries live in `devlog-archive.md` (not auto-imported).

## 2026-07-24: direction change, skill-building paused, pivot to the paper

**The standard for "a skill passes" was wrong, and the fix reframes the whole
queue.** A skill does not pass by building from a pinned source and clearing an
anti-spoof rebuild (the `VERIFY OK` vs `PASSED-NOT-CERTIFIED` machinery I added on
Thermal-FIST and vHLLE). It passes by REPRODUCING THE PUBLISHED WORK, the specific
figure/table/number in the code's paper. That is exactly the fusion-paper
benchmark's L2 (reproduce the author reference case) and L3 (unseen system vs
published values), and the measurement lives in that repo's harness, not in the
platform verify scripts. So: the TODO item to retrofit certification across the
family is DROPPED, and the published-work audit belongs with the paper.

**Skill-building is over-extended for the paper and is now PAUSED.** The paper's
coverage gate closed 2026-07-23; the platform has 20 per-code skills; the paper
keeps a final 12-13. So new skills add pruning and disclosure burden, not paper
progress. The heavy-ion row is the proof: SMASH + GiBUU + Thermal-FIST + vHLLE are
four skills for what the paper treats as ONE row, i.e. the last several builds
(vHLLE included) were already past the point of paper-usefulness. FUSION stays a
long-term maintained platform, so the rest of the code list resumes a few at a
time after submission, never as a race to cover the field.

**Critical path is now fusion-paper**, not FUSION: Phase B harness, the 2026-08-31
axis + cell-list freeze, L3 published-anchor pre-registration, then the Sep-Oct
matrix. Next platform-side task when it resumes: map each shipped skill's
benchmark to the published result it reproduces (or flag it as code-self-test-only
and needing an anchor), which is the L2/L3 pre-registration draft. Full statement
in CLAUDE.md Key decisions 2026-07-24.

## 2026-07-24: vHLLE, the first analytic-solution benchmark in the series

**What it is:** the 20th per-code skill (relativistic viscous hydrodynamics,
fourth of the heavy-ion row), tier 2, pinned vhlle main `c3480d62` + companion
data repo vhlle_params `ae2ba98`. VERIFY OK on macOS/clang 21 and Linux/gcc 13.3,
selftest 39/39, one Codex pass (6 fixed).

**The benchmark is a CODE-INDEPENDENT analytic solution, not a shipped
reference.** vHLLE ships no reference output, so tier 2, but the anchor is
stronger than a build check: its Gubser-flow run is compared cell by cell to the
closed-form ideal-conformal Gubser solution (eps within 2.5% at tau=1.5, exact
left-right symmetry, and the error grows monotonically with time exactly as
numerical viscosity predicts). This is the first skill whose physics is pinned by
an analytic reference I computed independently rather than by the code's own
numbers. Worth reaching for whenever a code has a known analytic limit.

**Three build/physics traps, all of which produce a plausible wrong result:**
1. **A Gubser run stops after ONE step on a thin eta grid.** The main-branch loop
   breaks when the freeze-out surface finder returns zero elements, and a
   boost-invariant blob on a thin nz grid produces no surface. `nz 15` with a real
   eta extent fixes it; no e_crit value helps. Two silent timesteps look like a
   converged short run.
2. **The analytic Gubser test needs the conformal (SIMPLE) EoS.** Under the
   default TABLE (Laine lattice) build the same deck runs fine and gives sensible
   output that simply does NOT match the analytic solution, because the lattice
   EoS is not conformal. So the skill builds TWO binaries from one pinned source
   via the code's own documented `#define TABLE/SIMPLE` toggle.
3. **eos/eosHadronLog.dat is read unconditionally**, even by a pure-hydro run that
   never particlizes, so the companion data repo is mandatory. And on Linux the
   binary needs an rpath to a conda GSL or it dies at runtime on libgsl.

**Cross-platform bit-identity, unusual for a PDE solver.** The SIMPLE Gubser path
is pure double arithmetic (no GSL spline), and with no FMA contraction the KT
scheme gives identical IEEE results on ARM and x86-64: every physical column
(tau, x, vx, eps, T) is bit-identical, only the numerically-zero vy differs at
~4e-16. The TABLE/Glauber path (which does use the GSL spline) also reproduced its
central anchor identically.

**What the Codex pass found (its report was truncated by the provider's safety
filter, again, but its experiments named the findings):** two mattered. (1) verify
certified with a non-canonical `VHLLE_PARAMS_PIN`: certification checked only the
code pin, not the EoS-data pin, though the EoS is physics. Now BOTH pins gate
certification. This is a fresh instance of the Thermal-FIST round-5 lesson (pin
every physics input, not just the obvious one). (2) run_vhlle passed on STALE
output: a no-op binary plus a leftover outx.dat validated clean; it now clears the
output dir first. The mutation testing also caught that the vx-threshold and
Glauber-anchor guards were not flip-tested, so the Glauber anchor moved out of a
verify heredoc into `check_glauber.py` and selftest now flips all of them.

**GitHub from heliumx is intermittent** (one 134 s connect timeout mid-run wiped
the cache the force-reclone had just deleted). Added `VHLLE_URL`/`VHLLE_PARAMS_URL`
overrides and certified on Linux against a local `file://` mirror at the same
pins. A useful pattern for any China-network or firewalled host.

## 2026-07-24: Thermal-FIST, the first HRG/EoS code, and five adversarial rounds

**What it is:** the 19th per-code skill (first hadron-resonance-gas / equation-of-
state code, third of the heavy-ion row after SMASH and GiBUU), tier 1, pinned
v1.6.1. CERTIFIED VERIFY OK on macOS/Apple clang 21 and Linux/gcc 13.3, 93/93
serial ctest, selftest 50/50 both platforms.

**Two traps worth keeping, both physics/build, not harness:**
1. **Parallel ctest gives 21 of 26 false Compare failures.** The Run/Compare pairs
   share an output file with no declared ctest dependency, so `-j` lets a Compare
   read before its Run writes. The suite MUST run `-j1`. A student who runs
   `ctest -j8` sees red on a working build.
2. **cpc3's chemically-frozen NEQ fit is not reproducible across builds.** Its
   ALICE muB comes out 2.42 MeV here vs 4.96 in the shipped reference, the same
   disagreement on both platforms, not a last-digit drift. The fit is
   under-constrained (gammaq and gammaS free flatten a chi2 direction), so the
   minimiser lands elsewhere. This is almost certainly why upstream commented cpc3
   out of its own suite. The EQ fit (3 params) reproduces at 1e-6; the NEQ fit is
   validated structurally only. A fit result you did not converge yourself is not
   a benchmark.

**The comparator was MIXED, not uniform**, and I claimed uniform 1e-6 for three
rounds before Codex read the CMakeLists per test: cpc2 and cpc4.analyt.dat are
byte-exact `compare_files`, the rest are 1e-6 tolerance, cpc4's Monte Carlo output
is uncompared. Read the test definitions; do not infer one comparator from one
example.

**Why five rounds, and the transferable lesson of each:** the SMASH pattern held
exactly, each round's fixes created the next round's defects.
- R2: replacing a fail condition with a richer one and dropping the original. The
  ctest check was rewritten to count Passed lines and lost the direct "fail on any
  reported failure", so a ctest printing 93 Passed lines while reporting a failure
  passed. A guard that failed on signal X must still fail on X after you add Y.
- R3: `git status --porcelain` and `git diff --quiet HEAD` both skip git-IGNORED
  files, so a source injected via `.git/info/exclude` under a CMake glob passed the
  clean-tree check. `git ls-files --others --exclude-per-directory=.gitignore` is
  the predicate that catches it while still ignoring in-tree-ignored files.
- R4: the hardening's OWN false-rejects. Requiring 151 rows for every cpc2 config
  (only config 0 has 151; 1/3 have 76, 2 has 61), and `ls-files --others` flagging
  a macOS `.DS_Store`. A guard tightened against an attack rejected a normal user.
- R5: the certification itself. verify trusting any caller-supplied or cached build
  is spoofable (a build dir with a source-bound cache, `true` ctest entries and
  reference-copying stubs passes). Closed by making a preset build
  NON-CERTIFIED and the certifying path force a CLEAN REBUILD from the SHA-pinned,
  pristine source, so cmake produces the certified binaries in-run. This pattern
  is shared by all 18 prior skills; Thermal-FIST is the first to close it. Worth
  retrofitting across the family.

**Process cost worth noting:** Codex's provider truncated the round-2 and round-5
reports at a safety filter, but the temp FIXTURES it left behind (a fake ctest, a
hand-written CTestTestfile, header/label spoofs) named the findings precisely, so
a truncated report is still actionable. And a self-inflicted scare: my cleanup
`rm -f` deleted a TRACKED `src/library/.DS_Store` that upstream had committed,
dirtying the clone and silently dropping 4 selftest cases to 46; `git checkout`
restored it. Check whether a file you plant for a test was already tracked.

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

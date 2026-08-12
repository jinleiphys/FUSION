# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.
Full-length versions of consolidated entries live in `devlog-archive.md` (not auto-imported).

## 2026-08-13: re-typing done, and two thirds of all contrasts labels were wrong

**The headline number: of 17,408 edges labeled `contrasts`, only 6,000
survived a second pass that asked one narrow question** (does the citing text
dispute the cited paper's own claims?); 6,433 became `uses`, 2,631 `compares`,
2,344 `background`. A dispute label users would reach for in "who challenged
X" queries was wrong two times out of three. The general lesson for every
LLM-typed layer in this project: when one label carries the sharp semantics
(disagreement), measure its precision with a dedicated verification pass
before anyone queries it; the first-pass prompt already carried carefully
worded rules for exactly this case and overfired anyway, because a rule
inside a six-way classification prompt is weaker than a single-question pass.

**Phase 1 facts:** the 4,559 re-opened papers averaged 32 edges each (the
no-context tail is the INSPIRE-backfill-heavy cohort), so throughput was a
tenth of the July full run and the original cost estimate tripled mid-flight
before landing at roughly $6 (13.0M in / 2.3M out); the recheck itself was
light (7.5M in / 0.9M out, minutes at 40 workers). relations.tsv and
citations.tsv are 1:1 again, 703,430 rows.

**One real bug shipped in the recheck and cost a wasted phase-2 launch:**
kb_relations.py has no module-level `threading` import (cmd_full imports it
function-locally), so cmd_recheck_contrasts died at its first `Lock()` with a
NameError, and the sequential runner chain went on to apply an empty sidecar.
The count-only smoke test returns before the Lock, which is why testing
missed it. Two lessons: a smoke test must penetrate to the code path that
does the work, and a multi-step runner should chain with `&&` so a dead step
stops the chain.

## 2026-08-12 (rebuild): collision guard live, the blocker edge is now a success story

**The full KINGSTON rebuild took 11 minutes, not hours** (61,059 papers, zero
missing tex dirs), so a citegraph rebuild is now a cheap operation, worth
knowing before the next data defect gets triaged as "expensive". Guard
calibration passed in the build output: `\cite{Jin15}` in 1511.03214 resolves
to the authors' true preceding paper 1510.02602 through the self-citation
corroboration, and the soliton edge is gone, so the guard REPAIRED the edge
rather than merely deleting it. The Leidemann `Lei15` edges died on their own
under the several-person-no-corroboration rule; `edge-blacklist.tsv` stays as
belt and braces. Pipeline: rebuild, INSPIRE re-merge (376,503 edges, zero
overlap with the tex layer by construction, since backfill targeted papers
with no tex edges), page-set + blacklist filter. Final graph 703,430 edges
(the guard costs about 16k Tier-B edges against the old arbitrary tie-break,
the price of not guessing); whole-wiki link audit: 1,538,412 links, 0 missing.

**Relations re-opened for tonight's off-peak window:** the 3,181 no-context
papers (recovered as the tail of relations.tsv by first appearance, matching
the stuck count in the July run log exactly) plus 1,648 papers whose edge set
the rebuild changed, 4,796 papers total, 4,559 with surviving edges;
646,778 typed rows kept. `run_relations_repair.sh` is armed: phase 1 re-types
those papers with context, phase 2 runs the focused contrasts recheck over
all 15,797 contrasts rows, then one injection. Follow-up when it prints ALL
DONE: refresh kb-search counts, commit the re-typed data.

## 2026-08-12 (repair): the mechanical half of the graph defects fixed, and two pipeline bugs found under them

**What was repaired, zero tokens, all verified converged:** the 4,093 dangling
edges are gone from both TSVs (723,748 edges remain, type counts restated in
the skill), the `[TARGET]` evidence placeholder reads `[the cited paper]`, and
every page's citation and related-work section was rebuilt corpus-wide.
Left open, because they need KINGSTON hours or paid re-typing: the Tier-B
collision guard + rebuild, the ~3,181 no-context papers, the contrasts
overfire. Cost quote for the paid half: contrasts-only is ~2.5% of one $109
full pass.

**The repair found the bug Codex only grazed.** The broken slash links it
reported were a symptom of `inject_citations.py` using `md_path.stem` as the
arXiv id and `f"{id}.md"` as the path, neither mapped through the underscore
convention. Consequence, worse than the symptom: **all 17,570 old-style pages
carried "None detected within the corpus" while having edges in the TSV**
(nucl-th/0703083 has 24), and old-style entries in new-style pages rendered as
`(0000)` with the id for a title. One id-mapping function fixed both.

**A second trap nearly caused a real mess: `kb_relations.py`'s DEFAULT tsv
path was the 221 KB pilot `relations-sample.tsv`, not the real file.** A bare
`scripts/kb_relations.py inject` therefore rebuilt pages from the sample, and
combined with a revisit patch it overwrote ~44k Related-work sections with the
literal text "No typed semantic relations in sample.", which is the sentence
that gave it away. Nothing was committed; re-running with the full file
restored everything (482,710 related-work links, 0 missing targets). The
default now points at `relations.tsv`. Lesson: when a pipeline script has a
`--path` flag that every documented invocation passes explicitly, the default
is dead code aimed at your foot; align it or remove it.

**Third find: the citation injector was nondeterministic.** It sorted edge
lists by date only, over a Python set, so equal-date ordering followed the
hash seed and consecutive runs kept "updating" thousands of pages. Tie-break
by id added; convergence proven by two consecutive zero-update runs plus one
under `PYTHONHASHSEED=random`, for both injectors.

## 2026-08-12 (later still): Codex pass on kb-search, FAIL, and the failure was in the DATA claims, not the commands

**Verdict FAIL: 1 blocker + 8 major + 3 minor, and not one recipe failed to
run.** Every defect that mattered was the skill VOUCHING for data quality it
had not measured: "citation edges are mechanical, trustable as-is" was the
central false sentence. Codex went to the raw .tex on KINGSTON and produced
counterexamples: the blocker is that 1511.03214's ONLY `cites` edge resolves
`\cite{Jin15}` to an unrelated Polyakov quark-meson soliton paper
(author-year collision in kb_citegraph's Tier-B fallback), on the user's own
IAV paper of all places; same shape for `Lei15` = Leidemann 2015 typed
`extends high`; a `contrasts` edge whose own evidence sentence ("can also be
described") is not a disagreement; 4,093 edges whose cited end has no page;
253,032 evidence cells with a literal `[TARGET]` placeholder; ~3,181 backfill
papers typed from titles+abstracts only. Plus honest-wording items: frontmatter
key is `arxiv` not `id` and `concepts` covers 43,489 of 61,059 pages; topic
lists are newest-first (the citation ranking lives in the Landscape synthesis,
not the list); 727,841 edges not 727,842 (header line); newest page 2026-06-16
so "through June" overstated; the "about one second" grep is 3-9 s cold.

**All four load-bearing findings independently re-verified before fixing**
(per the standing rule that a lint's finding is a hypothesis): soliton title,
4,093 dangling, 253,032 placeholders, 43,489 concepts, all reproduced. The fix
is disclosure, not deletion: the skill now states the error modes and uses the
blocker itself as the in-text example of why an edge is a lead, not a fact.
The data defects are logged as a TODO for a future kb refresh (collision guard
in kb_citegraph.py is the real repair).

**Two lessons for the family:** a research skill's adversarial pass must aim
at the DATA CLAIMS, not the command syntax; commands that run are the easy
part. And giving Codex the raw-source escape hatch (KINGSTON .tex, outside the
shipped base) is what produced the blocker; a pass confined to the shipped
directory would have called the graph internally consistent and missed it.

## 2026-08-12 (later): literature-wiki + research-profile embedded from the public repo

**The user's original question ("我们那个Wiki的skill是不是没复制过来") had a second,
better answer.** kb-search covers the SHIPPED knowledge base; the personal-wiki
skills (literature-wiki, research-profile) were also missing, and for those a
clean public version already existed: github.com/jinleiphys/research_LLM_wiki
(v2.1, sanitized for release in May 2026, cross-harness SKILL.md + AGENTS.md,
templates included, configurable wiki path). Copied in byte-identical with
`cp -RL` at c336c55; that repo stays the source of truth and re-syncs must
leave `diff -r` empty, the same bidirectional-sync discipline as the fresco
pair.

**One tooling fact worth keeping:** these are the first skills in the family
with HAND-WRITTEN AGENTS.md (the generator's marker comment is absent), and
`build_agents_md.py` handles that correctly: "wrote 0 AGENTS.md, left 2
hand-written alone". So the generated-pointer convention and the hand-written
convention can coexist; do not "fix" a hand-written AGENTS.md by regenerating
it.

**Boundary check, so nobody reopens it:** these skills ship the method (schema,
controlled vocabulary, lint, templates) and define the mount point; the user's
actual wikis at ~/research-wiki and ~/research-wiki-personal remain private,
exactly as the hard rule requires. Skill count 24 to 26 in both READMEs and
fusion-setup. Their SKILL.md text references companion skills FUSION does not
yet ship (pdf-extract, literature-search); left as-is, both because the copies
must stay identical to the public repo and because the references are soft
delegations, but it is a real reason to port those two next.

## 2026-08-12: kb-search shipped, closing the gap between shipping the KB and shipping a way to use it

**The gap:** the README promised "the agent reads it with plain grep", but no
skill told the agent HOW: the page anatomy, the underscore filename convention
for old-style arXiv ids, the TSV schemas, or the trust boundaries. The personal
`literature-corpus` skill could not be copied in, because it is bound to the
full-text `corpus.db` (forbidden to ship), a hardcoded Anaconda python, and an
external drive. So `skills/kb-search/` is a NEW skill covering only what ships:
grep recipes over `papers/` and `topics/`, awk filters over `citations.tsv`
and `relations.tsv`, and the three standard jobs (survey, missing-citation
scan, who-disputes-X).

**Verified before written:** every recipe was run against the shipped base
(61,059 pages, full-tree grep ~1 s; 727,842 edges in both TSVs; relation type
counts background 486k / uses 188k / compares 21k / contrasts 18k / extends
11k / applies 5k; coverage through 2606 = June 2026). One real trap documented:
filenames use `nucl-th_0703083.md` while the TSVs and in-page links keep the
slash form, so ids must be mapped, and some in-page relative links are broken
as file paths.

**Carried the usual honesty rules into the skill:** hits must come from a grep
run in-task with the arXiv id attached; cite the paper never the page (digests
are machine-generated); a miss is not proof (nucl-th only, lexical, snapshot),
escalate to INSPIRE/arXiv online. Skill count 23 to 24 updated in both READMEs
and fusion-setup; the two cold-machine "verified" claims were reworded
count-free rather than bumped, because the verification ran when there were 23.
NOT yet done: a Codex adversarial pass on the skill text (single-source so far).

## 2026-08-11: install-script audit, 20 scripts, 2 real defects

**Why:** the FRESCO auto-install hole found on 2026-07-30 (detection tested one
artifact while the install produced two) was almost certainly not unique. Audited
every `install_*.sh` on one question: does the fast path require EVERY artifact
the skill later needs, or only the first one?

**Two hits, both confirmed by running the script, not by reading it.**

1. **TALYS, the same shape with a worse failure mode.** The fast path was
   `[ -x "$BIN" ]` and exited 0. The structure-database check sat 20 lines BELOW
   it, so it was unreachable whenever the binary existed, and its own comment says
   exactly what that costs: "if the structure database is missing the run will
   fail later in a way that looks like a physics problem". Reproduced with a stub
   binary and no `structure/`: "talys already built", exit 0. It matters more than
   FRESCO's because the database is 8.6 GB of the 11 GB install, i.e. precisely
   what a user deletes to reclaim disk (and what TODO wants to make an opt-in
   extra), and because a PARTIALLY missing database does not abort, it falls back
   to Duflo-Zuker masses and still prints "successful calculation".
2. **Thermal-FIST, one binary certifying four.** `fast_path_ok` checked
   `cpc1HRGTDep`, while run and verify dispatch to `cpc2chi2`, `cpc3chi2NEQ` and
   `cpc4mcHRG` as well. Lower severity, because the run wrapper does check its own
   binary and dies with a clear message, so this is a misleading green install
   rather than a wrong number.

**The 18 clean ones show the pattern that works, and it is not "check harder".**
Two designs made the question moot. (i) **Provision dependencies BEFORE the fast
path**: GiBUU unpacks its input database and SMASH resolves Eigen/Pythia/GSL above
the fast-path branch, so the check cannot be skipped. (ii) **Make the fast path
probe rather than stat**: CGMF, KSHELL, SIDES, SWANLOP, SkyNet, CNOK and vHLLE run
a real calculation, which touches every artifact at once, so no enumeration can
fall behind. Enumerating artifacts by hand (the fix applied here) is the weakest of
the three and drifts as soon as a skill grows a new output.

**Third fix, same day (user asked for it after the first report): AZURE2 was the
last skill whose fast path was a bare file-exists, no probe and no stamp.** Not the
multi-artifact bug (Minuit2 is linked statically, so the lone binary really is the
whole runtime install, and there is no second artifact to corroborate it with),
but it was the one place a half-written cached binary was waved through. The
post-build probe it already had (two assertions, bare invocation for the syntax
banner and `--help` for `--no-gui`) is now a function called from both paths, so
a failed probe falls through to a rebuild instead of being handed back.

**And the flip test for it lied the first time, in the way this project keeps
meeting.** The assertion was "must not hand back a path", but after a failed probe
the CORRECT behaviour is to rebuild and then hand back a path, which is exactly
what happened; the run also regenerated the `.app` bundle and took the backup
binary inside it with it. Rewritten against a throwaway `AZURE2_ROOT` with the
real discriminator (did the probe fire, and did it reach the rebuild rather than
short-circuit), which passes both ways. Two lessons, both old: assert on the
mechanism you are testing, not on a symptom that a correct run also produces; and
do not flip-test a guard against the user's live cache when the env var for a
scratch root is right there. Cache confirmed intact afterwards: verify VERIFY OK
with both anchors unmoved (S(90 keV) = 7.6080 keV b, S_6.79(0) = 1.2572 keV b),
selftest 25/25.

**Guard discipline held:** both fixes flip-tested (hide exactly one artifact,
confirm exactly that guard fires, restore), plus a no-false-reject case on a
complete tree, plus Thermal-FIST selftest 50/50 unchanged. `timeout` does not
exist on macOS; `perl -e 'alarm N; exec @ARGV'` is the portable substitute for
bounding a script that would otherwise rebuild.

## 2026-07-30: SFRESCO added as a companion skill, and the auto-provision hole it exposed

**This is not a new per-code row, and it does not reopen the treadmill.** SFRESCO
ships inside the FRESCO distribution and its binary contains FRESCO, so
`skills/sfresco/` extends the existing FRESCO row from forward calculation to
parameter *estimation* (chi-squared fitting of potential parameters, spectroscopic
amplitudes, R-matrix widths, dataset normalisations). Authored in
`~/Desktop/claude_skills/skills/sfresco` and copied in; the two live in sync.

**It meets the 2026-07-24 pass criterion the easy way, because the answer is in
print.** Boxes 7 and 8 of *FRESCO: getting started* section 4 give a complete
worked fit AND its result, so `examples/p-cd-manual.*` reproduces a published
result end to end:
starting from r0 = 1.0 it returns V = 52.5280, r0 = 1.17958, W = 3.46041,
W_d = 7.42937, chi2/N = 2.1910 against the manual's 52.53, 1.179, 3.46, 7.43,
2.19. Every printed digit. Worth noting: **a code whose own
documentation publishes a worked example with numbers is the cheapest possible
published anchor**, and the FRESCO family is unusual in having one. Codes that ship only a
test suite (Thermal-FIST's ctest, SkyNet's self-comparison) are expensive for
exactly the opposite reason.

**The real find was in the platform, not the skill.** `install_fresco.sh` checked
only for `fresco` before declaring success, while its install step copies `fresco`
and `sfresco` together. So any machine with a hand-built or older `fresco` (this
laptop, for one) would get "already installed" and no `sfresco` at all, with no way
to trigger a build short of `--force`. Detection now requires both binaries.
Auto-provision was then tested for the first time end to end from an empty bin dir:
clone, build, and the closure fit passes. Two facts fell out of that run: a fresh
build is **FRES 3.5**, not the 3.4 in `~/bin`, and 3.5 accepts `type=9` (ANC) data
that 3.4 rejects outright. **Lesson for the family: an auto-install path that has
never actually run on a machine lacking the binary is not a feature, it is an
untested claim.** Worth auditing the other install scripts for the same
"check one artifact, install several" shape.

**Cross-validation moved two documented facts.** Three bounded Codex passes over
the FRESCO sources corrected `pline` (it also counts `&step` records for TYPE
12-17, so a deck with matrix-element couplings numbers differently than the
potential lines suggest) and the failure penalty (the CC-iteration 10000 is
unconditional; only the bound-state and R-matrix ones are gated by
`number_calls>5`, and within the first five calls those are fatal instead), plus 14
script bugs. A fourth, unbounded pass hung for 28 minutes with no output and was
killed: **the same bounded-prompt lesson as the opticalfisher appeal audit, now
observed twice.**

## 2026-07-24, amended 2026-08-11: what "a skill passes" means, and the treadmill stopping

**The standard was wrong, and the fix reframes the whole queue.** A skill does not
pass by building from a pinned source and clearing an anti-spoof rebuild (the
`VERIFY OK` vs `PASSED-NOT-CERTIFIED` machinery added on Thermal-FIST and vHLLE).
It passes by REPRODUCING THE PUBLISHED WORK, the specific figure, table or number
in the code's paper, because that is what makes the skill trustworthy to someone
who did not build it. So the TODO item to retrofit certification across the family
is DROPPED.

**Skill-building is PAUSED, as long-term maintenance rather than a queue to burn
down.** Twenty-one skills is already broad coverage and the heavy-ion row alone
holds four (SMASH, GiBUU, Thermal-FIST, vHLLE), so another row is worth less than
depth on a code someone actually reaches for. The rest of the list resumes a few at
a time, when a specific code is wanted, never as a race to cover the field.

**What replaced it as the critical path (2026-08-11): getting the platform into
other people's hands.** Phase 4, which has had zero work done. The standing
platform-side task when skills resume is unchanged: map each shipped skill's
benchmark to the published result it reproduces, or flag it as code-self-test-only
and needing an anchor. Full statement in CLAUDE.md Key decisions 2026-07-24 and
2026-08-11.

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

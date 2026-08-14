# FUSION devlog archive

Older entries moved out of devlog.md to keep the auto-loaded portion under ~5 KB. NOT auto-imported.

## 2026-08-13 (TALYS packaging): the disk question answered itself, and hid the real defect

**The long-open "should TALYS be an opt-in extra" decision was never a real
decision.** Provisioning is lazy (`run_talys.sh` calls `install_talys.sh` at
run time), so nobody who does not ask for a statistical-model calculation ever
downloads a byte: TALYS is opt-in by construction. Adding a flag would have
created a decision point for a cost only incurred by asking for it. Made a
standing rule instead of a per-skill call, in CLAUDE.md: **`install.sh` never
pre-builds a code.** Eagerly building twenty codes is far larger than TALYS's
11.2 GB and would fail on the first machine missing one system dependency.

**Under the packaging question sat the actual risk, and it was live.**
`have_structure()` checked that two directories existed. Its own comment
described the failure it was meant to prevent, a partially missing structure
database, after which TALYS falls back to Duflo-Zuker masses and still prints
a successful calculation; but the predicate could not see it. A complete
database is 16 top-level directories and 47,537 files, so the realistic move,
deleting subdirectories to reclaim disk, leaves both checked directories
standing. This is FUSION's founding fear (plausible, wrong, reported as
success) sitting in the heaviest skill, reachable by exactly the user most
likely to be short of disk.

**Fixed by reading the expected count from the clone's own git index** rather
than a hardcoded number or a written manifest: it follows the release, needs
no maintenance, and costs 0.06 s (0.012 s index read plus a 47k-file find),
cheap enough for every invocation. Trees with no git index (the frozen IAEA
tarball) fall back to presence only and SAY so, rather than implying they were
verified.

**The flip test lied on the first attempt, in the way this project keeps
meeting.** Hiding a subdirectory changed nothing, because the edit had not
been committed and the remote box had pulled the old file. Asserting the
guard's own message was present on the box first is what made the retest
meaningful: 46,044 of 47,537 detected, exit 4, and stdout EMPTY, so
`run_talys.sh` receives no path and cannot proceed on a broken database.
Checking stdout mattered as much as the exit code: a guard that warns and
still hands back a path is not a guard.

## 2026-08-13 (cold start): first install audit on a bare Linux box, six defects, and an architecture trap

**Setup worth reusing.** Every skill's install script already takes a path
override (`*_ROOT`, `*_ROOT_DIR`, or `*_BIN_DIR`+`*_SRC_DIR`), so all twenty
can be cold-started into throwaway roots without touching a working install.
heliumx turned out to be an ideal subject: full compiler toolchain, and NO
GSL, FFTW, HDF5, Boost, Eigen or Julia, which is exactly a student's fresh
Ubuntu. Harness in the session scratchpad, results in
`~/fusion-coldstart/results.tsv` on that box.

**GitHub is unreachable from heliumx** (`git ls-remote` fails 3/3, pythia.org
too), so the run would have measured the network, not the skills. Fixed with a
reverse tunnel from the laptop's proxy: `ssh -f -N -R 7897:127.0.0.1:7897
heliumx`, then `http_proxy=http://127.0.0.1:7897` on the remote side. Worth
keeping for any future upstream-fetching work on that box.

**The best find, and the reason to test on another architecture at all:
sky3d's install probe passed `mrest=0`.** Sky3D evaluates `MOD(iter,mrest)`
unconditionally, so that is an integer division by zero. On x86-64 the `idiv`
instruction raises `#DE` and the process dies with SIGFPE; on Apple Silicon,
AArch64 defines `SDIV` by zero as returning 0, so it is silently harmless.
The probe had shipped that input since the skill was written and had never
failed on the author's Mac. Chasing it also killed a wrong first hypothesis
(`-ffast-math` in the upstream `seq` target), which a debug build refuted in
one run: **get the backtrace before theorising about optimisation flags.**

**The other five, all Linux-fatal, none platform-specific in principle:**
COLOSS's upstream Makefile hardcodes an Apple-Silicon Homebrew LAPACK path
and `-lc++` (which would also break an Intel Mac); SWANLOP's makefile sets
`SHELL = /bin/csh`, absent on stock Ubuntu, though its recipes contain no csh
syntax; pikoe, nlat and azure2 used `mktemp -t <prefix>`, a BSD spelling GNU
coreutils rejects; gsm told Linux users to run `brew install open-mpi`.

**Note what the pikoe case says about the earlier evidence.** Its verification
records a real Linux cross-build, and the verify SCRIPT still failed on the
first Linux run, because that cross-build ran a bespoke harness rather than
the skill's own scripts. Testing the code on a platform is not testing the
skill on it.

**One self-inflicted defect, caught by testing the fix rather than trusting
it.** The first COLOSS fix passed `LIB=` on the make command line; the top
level recurses into `adyo_v1_0`, whose own Makefile uses `LIB` for the archive
it builds, so the sub-make ran `ar rv -llapack` and BOTH platforms broke. Make
command-line variables propagate into sub-makes, so a generic name (LIB, CC,
SRC) will collide; patch the file instead. The corrected patch is proven
behaviour-preserving the CNOK way: same input on both platforms gives
sigma_R = 1156.9048 mb, identical to every printed digit.

**TALYS, added the same day, was deferred on a wrong premise and turned out
to be the cheapest thing here.** "11 GB over a proxy tunnel" confused the
working tree with the transfer: git moves the compressed pack, 2.03 GB by
GitHub's own figure, and the script already shallow-clones. Measured at
4.38 MB/s through the tunnel: **install 5 min 19 s, 11.2 GB on disk**, and
the `n-Th232-fis-wkb` benchmark in 55 s. Worth generalising: before deferring
a job as expensive, check which number is actually on the wire.

**And it caught the audit's one honesty defect.** TALYS's verification tables
report 1419 of 1438 reference files byte-for-byte, with no platform named;
that was macOS/ARM. On Linux the same case agrees to ~5.4 significant figures
(1290 physical observables, worst relative difference 3.89e-06), which is an
ordinary compiler and libm difference and exactly what `verify_talys.sh`
already reports. The tooling was right and the documentation was
platform-blind, so a Linux user would read a correct run as a broken one.
Both tables now name their platform and carry the Linux number. This is the
2026-07-20 rule ("never overclaim bit-identical") failing in a new way: not
by claiming bit-identity that was never measured, but by stating a real
measurement without its scope.

**Scoreboard:** 7 installed and verified clean on the bare box (fresco,
ccfull, cgmf, cnok, sides, kshell, thermal-fist), later joined by smash,
gibuu, swanlop, pikoe, sky3d and coloss after the fixes; 4 correctly stopped
with an actionable missing-dependency message (azure2 GSL, skynet
HDF5/GSL/Boost, nucleartoolkit Julia, gsm MPI).

**Two nlat runs, two non-defects, both worth naming so they are not re-filed
as bugs.** One hit a Mendeley download that returned JSON instead of gzip;
the script's own guard caught it and printed the manual URL, so a flaky
upstream was reported correctly rather than producing a broken install. The
next run then tripped the harness's own 5400 s ceiling inside the nonlocal
case, which the skill's `verification.md` documents as **1 h 26 min on one
core**; the local case had already compared 14 files with zero failures. A
timeout budget chosen without reading the skill's stated runtime is a harness
artifact, not a finding, and the lesson generalises: **before calling a
long-running verification hung, check what the skill says it costs.** Re-run
with a real budget: `VERIFY OK` in 6500 s, 25 files compared across both
cases, zero failures.

**Final state of the audit: all 20 skills cold-start verified**, TALYS
included.

## 2026-08-13 (size): relations.tsv halved by deleting the rows that said nothing

**87.8 MB to 34.7 MB by dropping the 469,656 `background` rows.** The file had
grown to 88 MB and every re-typing pass pushed it toward GitHub's 100 MB HARD
limit (a push failure, not a warning). The choice between the two candidate
cuts was settled by the previous day's Codex pass, not by size: stripping the
`evidence` column would have saved 61 MB but removed exactly what makes a
`contrasts` row usable, since that pass established a dispute label must be
read with its evidence sentence. Background rows, by contrast, duplicate
information `citations.tsv` already holds, and `inject_relations` was skipping
them anyway. **New semantics, now documented in the skill: an edge with no
relations row means background.**

**The trap this created, and the fix.** 24,814 of 54,039 citing papers have
ALL-background rows, so after the cut they vanish from relations.tsv, and
`cmd_full` derived its resume set from that file's first column: the next run
would have re-classified a quarter of the corpus at real cost, and re-added
every row just deleted. The resume record therefore moved to
`kb-wiki/relations-classified.txt` (0.65 MB, 54,039 ids), read at startup
unioned with the tsv's first column so a pre-ledger checkout still resumes,
and appended per paper as work completes. Flip-tested per the standing rule:
ledger hidden reports 24,814 to go, restored reports 0, and the number
matches the all-background count exactly. `cmd_full` now also skips
background at write time, so the file cannot regrow.

**A stale framing corrected while closing the gate:** the 2026-08-11 note
called relations.tsv a build artifact that nothing at runtime reads, which
had made "drop it from the distribution" look like a live option. It is
false as of the `kb-search` skill: the who-disputes-X recipe greps it
directly. Re-check what reads a file before deciding it is disposable.

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

## 2026-07-23: SMASH round 5, the streak ends, and the skill ships

**Why we tried it:** four rounds in a row had found that the previous round's
fixes carried a new defect of the same shape. The stopping condition was never
a round count, it was "a round comes back without one".

**Result: round 5 found no new false pass.** First time in five rounds. It found
one wrapper-only incompatibility in the opposite direction: `Randomseed: +123`
is a valid YAML integer that raw SMASH runs with, and the wrapper rejected it.
A false REJECT fails closed, so nothing was ever wrongly certified by it, but
being stricter than the code you drive is a defect too. One character, covered
by three tests.

**What makes this round's negative result trustworthy** is that it was measured,
not asserted. It ran the int64 boundary from both ends, both quote styles,
`in_int64` with a shell-metacharacter payload (confirming argv, not eval), and
`python3` both absent and replaced by a python2, confirming that dependency
fails CLOSED rather than waving a seed through. Most importantly it ran **every
shipped config under `input/`** through the wrapper, which is what the new
fail-closed branch most risked breaking, and none was falsely rejected. The one
that needed `--end-time 10` (`input/list/`) is refused by raw SMASH at the short
time too, because its particles have a formation time of 5, so that is the
configuration and not the harness.

**The five-round arc, since it is the transferable part.** Severity decayed
monotonically: round 2 produced two blockers (a legitimate build rejected, real
output rejected), round 3 four silent false passes, round 4 two input-validation
boundary defects, round 5 one false reject. What never worked was inspection,
including my own immediately after writing the code. What worked, in order of
yield: running the harness on a SECOND MACHINE, the flip test, and an
adversarial reader allowed to run the real code. The one structural fix that
retired a whole class rather than a case was replacing a fail-open branch with
a fail-closed one: any validation whose "I could not read this" path is `skip`
is one unexpected spelling away from not existing.

**Status:** SHIPPED. Seventeenth per-code skill, tier 1. selftest 103/103 on
macOS/ARM and Linux/x86-64, ctest 104/104 first attempt on both, anchor
conservation exact on both.

## 2026-07-23: SMASH round 4, and the pattern is now a measurement

**Why we tried it:** the round-3 fixes were single-source. Given that rounds 2
and 3 had each found that the previous round's fixes carried new defects, the
question for round 4 was aimed accordingly: not "were the findings fixed" but
"did the fixes break something new".

**Result:** all six round-3 findings confirmed FIXED against real output. Two
NEW defects, both from round 3, both in the same two lines of input validation.

- **The 18-digit cap rejected a legitimate seed.** `Randomseed` is an `int64_t`
  and `9223372036854775807` is exactly its maximum; raw SMASH runs with it. The
  round-3 fix had replaced an unbounded regex with a DIGIT COUNT, and a digit
  count is not a range. Now range-checked properly, so the maximum is accepted
  and one past it is still refused.
- **Quoted YAML numerics.** `Randomseed: "123"` was rejected outright, and
  `Nevents: "2"` did something worse: `is_uint` failed, no `--events`
  expectation was passed, and the event-count check SILENTLY SWITCHED OFF while
  the run reported success having written one event of two.

**Root cause of the second, which is the one that generalizes:** the quoting was
only the trigger. The defect was that an unparseable value took the FAIL-OPEN
branch. Stripping quotes fixes the reported case; what fixes the class is that a
key present but unreadable is now an error. Any validation whose "I could not
read this" path is `skip` rather than `fail` is one unexpected spelling away
from not existing.

**Lesson, four rounds in.** Every round has introduced a defect of the same
shape as the one it repaired. That is a base rate, not bad luck, and the useful
consequence is knowing what actually catches them. In order of yield: running
the harness on a second machine, the flip test, and an adversarial reader with
permission to run the real code. **Nothing in four rounds was found by
inspection**, including my own inspection immediately after writing the code.

**Status:** both fixed and flip-tested, selftest 94 to 100 cases, 100/100 on
macOS/ARM and Linux/x86-64. One more confirmation pass before it ships; stop
when a round comes back clean.

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

## 2026-07-23: SkyNet macOS NSE block-3 is libm-limited, not a flag fix

**Why we tried it:** the full-network NSE (Saha) block at T9=3 reproduced the
shipped reference to 7.0e-3 on macOS against a 3.5e-5 gate. FMA contraction is a
common cause of such cross-platform deltas, so `-ffp-contract=off` was the first
suspect, cheap to test.

**What failed:** `-ffp-contract=off` gave the byte-identical 0.00701498, and -O3
and -O0 also agree. So it is neither FMA contraction nor optimization-sensitive UB.

**Root cause:** Apple libm vs glibc `exp`/`log` differences, amplified through a
Newton iteration over abundances spanning ~200 decades (ni56 ~ 5e-201 at T9=3).
The reference tolerance was calibrated on the authors' glibc platform; the
identical patched source passes 19/19 on Linux, so it is a platform numerical
property, not a build or patch defect.

**Lesson:** a stiff nonlinear solve's tightest reference may not survive a libm
change. Do not chase it with flags or by loosening the passing platform's gate:
reproduce cross-platform, document the delta, and encode the exception narrowly
(other blocks pass on both platforms; the excepted case bounded to a window).
Full reasoning in the 2026-07-23 CLAUDE.md key decision.

**Status:** Parked (documented macOS caveat; SkyNet ships tier-1-with-caveat).

## 2026-07-22: a results table is not an anchor, and 14N(p,g)15O cannot be built

**Why we tried it:** After the 16O(p,g)17F benchmark worked, 14N(p,g)15O was the
obvious next case and TODO called its Table IV "a better check than pikoe ever
had", because it tabulates S(0) per transition plus a total of 1.81 keV b.

**What failed:** the reconstruction, before a single run. Auditing the INPUT
side against the paper: Table II covers gamma widths for "the three strongest
transitions" only; the 5.18 MeV final state has neither an ANC in Table III nor
a gamma width anywhere, so it is 100% unspecified; and decisively, **the signs of
the reduced-width amplitudes are never published**, while the ground-state S(0)
is set by destructive interference among four 3/2+ components. Table III adds
its own warning that "there is a sign ambiguity in the conversion". Four
components give eight sign combinations spanning orders of magnitude in S(0).

**Root cause:** the attractiveness of a benchmark was judged from its OUTPUT
side. A table of results says nothing about whether the inputs that generated it
were all printed. 16O(p,g)17F happened to publish a complete parameter set;
14N(p,g)15O publishes a better-looking answer and an incomplete question.

**Lesson:** before promising a constructed benchmark, audit the input table for
completeness including signs and phases. Picking a sign to match a published
number is fitting to the answer, which is the exact failure the clean-room rule
exists to prevent. Tractable subsets can still be worth building: here the
6.79 MeV transition is 72% of the total, external-capture dominated with a single
ANC, and explicitly "added incoherently", so it carries no sign ambiguity.

**Status:** Full Table IV case abandoned. 6.79 MeV subset parked, in TODO.

**Also this session, two smaller dead-ends:**

- **`--no-transform` for entering published reduced-width amplitudes: rejected on
  physics.** It agrees with transform mode at the one radius where the
  amplitudes were converted and diverges by a **factor of 4** across
  ac = 4.0 to 6.0 fm, because it bypasses the ANC-to-amplitude conversion.
  Transform mode is flat to 0.4%, which is what ANC-normalised external capture
  must be. A single-radius check rates the two equally good. **Lesson: when a
  quantity is supposed to be invariant, test the invariance, not one point.**
- **The `codex:codex-rescue` plugin path was silently dead** for an hour: broker
  never started (0-byte log, no pid file), no live process, and the task kept
  reporting "still running". The Codex CLI itself was fine. This is a sixth
  false-success costume and the first at the ORCHESTRATION layer rather than in
  a physics code: silence was indistinguishable from work. **Lesson: a
  long-running delegated job needs a liveness check, not just a status string.**
  Workaround: drive `codex exec` directly.

## 2026-07-21: four skills, one failure shape, consolidated

Full text of all four entries in `devlog-archive.md`. Consolidated here because
they repeat one theme; every distinct mechanism is preserved below.

**The shape: a failed run that looks successful.** Six distinct mechanisms found
so far, each in a new costume:

| code | how a failure looked like success |
|---|---|
| CCFULL | leaves a stale reference file behind |
| GSM | exits 139 with empty stderr |
| TALYS | exits 0 on a fatal error |
| pikoe | opens every output file at zero bytes before computing |
| GEF | memoizes completed cases in `ctl/done.ctl`, silently skips, exits 0 |
| codex plugin (2026-07-22) | orchestration broker dies, task still reports "running" |

**Rule: verify content, never presence, and never status.** Corollary from GEF: a
scientific code may carry state between runs, so a clean room means clearing that
state (`ctl/`, a stale `Fitpar.dat`), not just the output directory.

**The second shape: destructive-command guards written against the wrong path.**
pikoe's `rm -rf` guard tested `$WORK/case` while deleting `$WORK`. NLAT's tested
whether the install contained the workdir when the danger was the reverse, in a
function whose comment cited the pikoe incident. AZURE2's (2026-07-22) escaped
through a symlinked path component. Three times, the third while quoting the
lesson from the first. **Writing a lesson down, and even citing it at the point
of use, does not transfer it. What caught all three was an adversarial agent
running the script with a hostile argument.** The guard must name the same
operand as the command, and the repro must be written before the guard.

**Verification philosophy, settled 2026-07-21:** the author's reference output is
produced by the SAME source as your run, so it certifies build integrity only,
never physics; a genuine physics bug sits in their reference too. Cross-build
reproduction certifies that same property over more configurations. Measured on
pikoe: bit-identical across macOS ARM64 gfortran 15.2 and Linux x86_64 gfortran
13.3, at `-O2`, `-O0` and `-finit-real=snan`, 5642 numbers. Consequence: do not
email authors for missing reference output. Physics correctness must be carried
separately, by published figures or tables.

**Other findings that must survive:** GEF is FreeBASIC and Linux-only, the first
platform-pinned row. `pkill -f GEF64` on a remote one-liner matches the ssh
session's own command line and self-kills silently. gfortran writes `.mod` files
into the caller's cwd unless given `-J`, which poisons a rebuild after any
compiler upgrade with an error naming neither cause nor fix. NLAT carries three
genuine upstream defects (a `(8,3)`/`(9,3)` index error at `front_end.f90:476`,
swapped print flags 16/17, a tolerance labelled "percent" that is dimensionless)
plus a paper recommendation that cannot be followed in the released code; worth
an email to Nunes. When a benchmark disagrees, find out whose fault it is before
deciding what to do about it, and encode any upstream exception narrowly enough
that a real regression still fails.

## 2026-07-21: "email the authors for the missing reference output" was the wrong plan for two skills at once

**Why we tried it:** pikoe and AZURE2 both ship without reference output, and the
2026-07-20 tier ruling treated that as the thing separating a tier-2 skill from a
tier-1 one. The plan that followed was to ask the authors: Yoshida for pikoe's
missing `tbl_*.dat` / `*.outlist`, deBoer for an AZURE2 `.azr` example set. Both
were written into TODO as actions, and the AZURE2 one was recorded as the
**top** action unblocking a paper-gating row.

**What failed:** the reasoning, not a run. The user pushed back twice, and both
pushes were right.

The first: a reference output is produced by the **same source** as your own run,
so it cannot certify physics. If pikoe has a genuine physics bug, that bug is in
the authors' reference too, and reproducing their numbers to 12 digits confirms
only that both builds executed the same wrong code. What a reference output
actually certifies is **build integrity**, and cross-compiler reproduction
certifies that same property across strictly more configurations. Measured:
macOS ARM64 gfortran 15.2.0 against Linux x86_64 gfortran 13.3.0, at `-O2`,
`-O0`, and `-finit-real=snan -finit-integer=-99999`, produced **bit-identical
output across all six builds**, 5642 numbers per comparison. `-O0` vs `-O2`
agreement rules out optimization-sensitive UB. The snan run plus a comparator
that rejects non-finite values rules out any uninitialized variable reaching the
output. No single reference file states anything that strong.

The second: an R-matrix case is **fully specified by published numbers**, so the
input is constructed from the paper rather than obtained from the authors. The
AZURE2 paper devotes Sec. IV to three worked examples and tabulates the complete
fits (Table V for ¹⁶O(p,γ)¹⁷F, Table I for ¹²C+p, Table IV for ¹⁴N(p,γ)¹⁵O S
factors totalling 1.81 keV b). Table IV is the valuable one: it is a table of
**results**, so it supports comparing digits rather than reading a plot, which is
a better anchor than pikoe has ever had. A fourth fully specified case sits in
deBoer's TALENT material with levels from TUNL/NNDC and data from EXFOR.

**Root cause:** the tier framework from 2026-07-20 quietly conflated two separate
properties, "did my build come out right" and "is the physics right", and made a
distributed reference file the single gate for both. Once they are separated, the
reference file is revealed as the weaker instrument for the first and no evidence
at all for the second. The framing then propagated into two skills and into a
paper-gating TODO before anyone questioned it.

**Lesson:** when a dependency on an external party appears in a plan, check what
property it is actually supposed to establish before writing the email. Here the
answer was "build integrity", which is obtainable locally in about ten minutes of
compute across two machines, and "physics correctness", which the authors' own
output could never have supplied. Two blockers dissolved and neither email needs
sending. Generalized into the Key decisions in CLAUDE.md.

**Also caught, by the cross-build test rather than by review:** `install_pikoe.sh`
wrote `.mod` files into the source directory, so a rebuild after any gfortran
upgrade dies on "Cannot read module file ... created by a different version of
GNU Fortran", which names neither cause nor fix. That is a live user-facing bug
on every compiler upgrade, and it surfaced only because the same source was
compiled by two gfortran versions. Fixed and verified against a deliberately
corrupted module file.

**Status:** Abandoned (both emails). Replaced by cross-build reproduction plus
published-table anchoring.

## 2026-07-21: GEF clears the fission row, and brings a fifth way for a failed run to look successful

**Why we tried it:** GEMINI++ was dropped that morning for failing the
publicly-obtainable rule, leaving GEF as the only candidate for the paper's
fission/statistical row. If GEF had also failed, the paper's cross-subfield
claim would have had to narrow from four subfields to three, so this was a
gate-deciding check rather than routine catalog work.

**Result: it clears, on every criterion.** GPL-3.0 (`License.txt` in the
tarball), anonymous direct download with no registration wall, actively
maintained (24 archived versions, 2025/1.4 released three weeks before the
check), and the citation verified live against CrossRef rather than from memory:
Nucl. Data Sheets **131**, 107-221 (2016). It was then actually run, not merely
licence-checked, and ²⁵²Cf(SF) gave nu-bar 3.8207 against the evaluated 3.7676.

**The new false-success mode, and it is a good one.** A rerun of an
already-completed case produced no output, printed "GEF is terminated", and
**exited 0**. The cause is `ctl/done.ctl`, a memo file listing finished cases,
which GEF silently skips on a later run. A wrapper keying on exit status, or on
the presence of the banner, would have recorded a calculation that did nothing as
a success. There is a second, quieter version of the same hazard: a `Fitpar.dat`
left behind by any earlier `FIT(...)` run is picked up on the next run and
silently overrides the shipped defaults, so a "clean" run can be using fitted
parameters from an unrelated earlier job.

That makes five distinct mechanisms across five codes: CCFULL leaves a stale
reference file, GSM exits 139 with empty stderr, TALYS exits 0 on a fatal error,
pikoe opens every output file at zero bytes, and now GEF memoizes completed work
and skips it. The rule stated after pikoe (**verify content, never presence, and
never status**) survives contact with a fifth instance, but GEF adds a corollary
worth stating separately: **a scientific code may carry state between runs, so a
clean room means clearing that state, not just clearing the output directory.**
The first attempt here removed `out` and `.ctl` and missed that the directory is
`ctl/`, which is exactly how the trap fired.

**A self-inflicted one worth recording too:** a remote cleanup used
`pkill -f GEF64`, which matched the ssh session's own command line (it contained
the string `GEF64`) and killed the shell before it did any work, producing a
completely silent no-op. `pkill -f` matches the invoking command too; on a remote
one-liner that is a self-kill.

**Cost of the row, honestly stated:** GEF is **Linux-only** for our purposes.
The source is FreeBASIC (33 `.bas` files), `fbc` is not installed and has no
Homebrew formula, and the shipped binaries are ELF Linux plus a Windows `.exe`
with no macOS build. Running the shipped `GEF64` on heliumx sidesteps the
toolchain question entirely and is where heavy compute belongs anyway, but it
makes this the first platform-pinned row in the benchmark, which the harness
design has to absorb rather than assume away. And like pikoe and AZURE2, GEF
ships plenty of input decks (97) and **no reference output**, so tier 1 is not
reachable from the distribution alone.

**Status:** Openness and feasibility resolved; skill not yet built. Fallbacks
(TALYS's fission channel carrying the row, or narrowing to three subfields) are
withdrawn.

## 2026-07-21: the same guard bug, in the script whose comment cites the same guard bug

**Why we tried it:** Seventh per-code skill, NLAT (Titus, Ross, Nunes, CPC 207,
499 (2016)), second of the Wave 1b batch, built the same day as pikoe.

**What failed:** Codex confirmed 21 defects. The one worth the entry: the
`rm -rf` guard in `run_nlat.sh` tested whether the **install contained the
workdir**, when the destructive case is the **workdir inside the install**.
Pointing the workdir at `LOCAL_SAMPLE` deleted the distributed reference output;
pointing it at `SOURCE/` deleted the source tree. Worse, after `SOURCE/` was
wiped the directory still existed, so `install_nlat.sh`'s
`[ -d "$SRCDIR/SOURCE" ]` short-circuit kept returning the broken install as
valid, making the damage unrecoverable without a manual purge.

This is the identical defect pikoe shipped with a few hours earlier, in a
function whose comment reads "Getting this wrong once destroyed 50 MB of data
tables in the pikoe skill."

Two more false-pass vectors in the same review. An all-NaN output file was
reported as a **perfect match**: every comparison against NaN is false, so
`d > worst` never fired and the worst-difference counter stayed at zero. NaN is
the characteristic output of a diverging iterative solve, and an iterative
nonlocal solve is precisely what NLAT does, so the comparator was blind to the
single most likely real failure. And the reference "fingerprint" that was
supposed to prove the run had not overwritten the references hashed `ls -l`
output, i.e. permissions, size and mtime, so a content change preserving size and
mtime was invisible.

**Root cause:** Writing a lesson down, and even citing it at the point of use,
does not transfer the lesson. The pikoe entry from the same day says "every
destructive command needs its guard written against its own literal argument".
The NLAT guard was then written against the wrong operand while quoting that
sentence. What actually caught it, both times, was an adversarial agent running
the script with a hostile argument. The written rule is worth keeping, but it
should be understood as a prompt for the test, not as a substitute for it.

**Lesson:** For any destructive operation, the test is cheap and the reasoning
is not. Write the repro first: point the workdir at the install, at the sample
directory, at the deck's own directory, and through a symlink, and confirm each
one refuses. Four `run_nlat.sh` invocations would have caught this before Codex
did. The same applies to the comparator: feed it NaN, feed it a truncated file,
feed it a real 1e-3 discrepancy, and check the exit status each time. All of
those are now in the skill's own repro set.

Second lesson, a repeat of the TALYS one: two numbers in `verification.md` were
wrong, a copy-pasted token count and a headline "worst 5.95e-14" that the table
two lines above contradicted with 2.067e-11. Both came from summarising by hand
rather than from re-deriving through the shipped comparator. The number in a
verification document must come out of the same code path the tool uses.

**A fifth upstream find, from the benchmark itself:** the nonlocal
`TransferCS.txt` reference has 180 angles where the shipped deck and code produce
179. Rather than wave it off as compiler noise, the mtimes settle it: the
nonlocal reference output is dated 2016-04-12, a month BEFORE the deck it ships
with (2016-05-13), while the local reference is same-day as its deck and matches
exactly. The 179 shared angles agree to 1.3e-12. The comparator was NOT relaxed
to absorb this; it takes one declared deviation with both counts pinned
(`--prefix-ok TransferCS.txt:360:358`), and refuses to fire on any other count.
The general principle: when a benchmark disagrees, find out whose fault it is
before deciding what to do about it, and if the answer is "upstream", encode the
exception narrowly enough that a real regression still fails.

**Also worth recording, on the code rather than the skill:** the review surfaced
three genuine upstream defects in NLAT, none of which affect the shipped
benchmarks but all of which affect a user driving the code themselves.
`front_end.f90:476` reads a neutron diffuseness into `DeuteronScatParameters(8,3)`
where `(9,3)` belongs, so a user-defined nonlocal ADWA deck silently gets zero
real-volume diffuseness for the neutron. Print flags 16 and 17 are swapped
between the parser's comments and `diffCS.f90`'s use of them. And the convergence
tolerance the decks label "percent" is a dimensionless relative tolerance, so the
default 0.001 means 0.1 percent, not 0.001 percent. Separately, the paper's
Sec. 6.4 advice to raise the small-radius cutoff from 2 to 3 at
`StepSize = 0.01` fm **cannot be followed in the released code**: there is no
such input, the value is hardcoded as `nmin = int(2*L)` in `nm.f90`, and the two
distributed decks both use 0.01. Worth an email to Nunes.

## 2026-07-21: pikoe, and a guard that watched the wrong path

**Why we tried it:** Sixth per-code skill, first of the Wave 1b optical-potential
batch, built the same day the user delivered the five CPC papers.

**What failed:** Codex's adversarial pass found 24 defects in a skill that had
already passed its own clean-room verification twice. Four were ship blockers,
and the worst is the one worth naming: `run_pikoe.sh` carried a comment saying it
had fixed "the self-destruct failure the TALYS wrapper hit", and it had, for the
exact case TALYS hit. The guard compared the deck's directory against `$WORK/case`
while the `rm -rf` two lines below deleted `$WORK`. So a deck sitting in the
workdir was destroyed before it could be read, and pointing the workdir at the
install tree deleted the binary and 50 MB of data tables. Second blocker: the
success test counted `.dat` files without testing size, and pikoe creates every
output file named in the deck header at zero bytes before computing anything, so
a run that produced nothing reported success. Third: `verify_pikoe.sh MD` printed
`VERIFY OK` having compared zero anchors, because no pin existed for that case.
Fourth: under `set -euo pipefail`, `ls *.dat` on an empty glob aborted the script
before the "no data table" message could print, so the most informative failure
mode produced silence.

**Root cause:** The first is the more instructive one. Knowing a failure shape
and having fixed it once produces a comment claiming immunity, and the comment
then discourages re-reading the code beneath it. The fix had been applied to the
path that appeared in the previous incident rather than to the path the
destructive command actually names. A guard is only meaningful against the exact
argument of the operation it guards.

The second is the fourth consecutive per-code skill where a failed run can look
successful, and each time in a new costume: CCFULL leaves a stale reference file
behind, GSM exits 139 with an empty stderr, TALYS exits 0 on a fatal error, pikoe
opens every output file empty at startup. The common shape is now clear enough to
state as a rule: **verify content, never presence, and never status.**

**Lesson:** Three. First, every destructive command needs its guard written
against its own literal argument, and a comment asserting a class of bug is fixed
should be treated as a claim to re-test, not as evidence. Second, "does the
output exist" is never a completion check for a scientific code; only size and
content are. Third, the review must run the scripts, not just read them: the
`.mod` pollution (gfortran writes module files into the caller's working
directory, so building from the skill directory littered it with six `.mod`
files, which then landed in the first commit) was invisible in review and
obvious in `git status`. Fixed with `-J`.

**Also worth recording:** the benchmark tier came out better than the 2026-07-20
ruling assumed. pikoe genuinely ships no reference output, so the FUSION standard
is unreachable, but its five sample decks are exactly the five figures of the CPC
paper and those figures carry numeric axes. Reading peaks off them gives a real
quantitative check (a few percent, positions to the plotted resolution) rather
than the "builds and looks sensible" of a plain tier-2 skill. Where a paper's
figures correspond one-to-one to its shipped decks, that is a benchmark, and it
is worth checking for before settling for tier 2. The MD case (392A MeV, over an
hour of CPU) was left explicitly unpinned rather than filled in from the figure
by eye; an early draft of the checker did carry two such eyeballed pins, which is
precisely the fabricated-anchor failure the clean-room rule exists to prevent.

## 2026-07-20: the TALYS skill's own verification harness had the false-positive bug it was written to prevent

**Why we tried it:** User directive to run Codex adversarial cross-validation on each finished skill instead of shipping on Claude's self-check alone.

**What failed:** Codex falsified six claims in the just-finished TALYS skill. The serious one: `run_talys.sh` staged the deck with `cp "$SRC"/* "$WORK"/ 2>/dev/null || true` and never cleaned the workdir. Given an empty or malformed source directory plus a workdir holding a previous run's `talys.inp`, the copy failed silently and TALYS ran the STALE deck, exiting 0 and printing a success banner. Codex demonstrated it with a two-command repro. Separately, the headline benchmark number was wrong: 1419 of 1438 files reproduce exactly, not the 1415 written; the error was a shell filter matching "date" as a bare substring, so lines containing "update" were dropped and four spurious differences appeared. Also: 61 sample cases not 62; a GNU-only `grep -v 'a\|b'` alternation that BSD grep ignores, leaking README and verify into the case listing; the 132-char limit attributed to `path` in A0_talys_mod.f90 when the one that matters is `codedir` in machine.f90; and the locale claim stated as "any UTF-8 locale" when `C.UTF-8` actually globs correctly.

**Root cause:** The skill carries three prime rules about never trusting exit status, written the same afternoon after the CCFULL and GSM traps. The harness enforcing those rules was then written with `|| true` on its own staging step. Knowing the failure mode in prose does not prevent implementing it fifty lines later; the rule was applied to TALYS's exit code and not to the wrapper's own file operations. The wrong file count has the same shape: a quick shell one-liner was used to produce a number that then got written into a document as a verified result, without the filter itself being checked.

**Lesson:** Two. First, the verification harness needs the same adversarial treatment as the code under test, and specifically: any `|| true`, `2>/dev/null`, or unchecked `cp` in a benchmark script is a false-positive vector and should be treated as a defect on sight. Second, a number that goes into a verification document must come from the same checked code path that the shipped tool uses, not from an ad-hoc shell loop written to answer the question once. Both fixes are in place, and fixing the first introduced a self-destruct bug (the new `rm -rf "$WORK"` deleted the input when source and workdir are the same path, which is exactly how verify_talys.sh calls it), caught only by re-running the regression, which is itself the argument for keeping a regression suite rather than spot-checking.

**Status:** Resolved. All six fixed and re-verified; the 5-case benchmark re-run clean after the fixes. Cross-AI validation promoted to a hard rule in CLAUDE.md.

## 2026-07-20: TALYS, three independent traps that each produce a confident-looking wrong result

**Why we tried it:** Fifth per-code skill, the headline community code of the statistical-model tier.

**What failed, in order:**
(1) The build died at link with a wall of undefined symbols (`_abundance_`, `_adjust_`, `_afold_`, `_angdis_`, `_astro_`). Cause: `source/Makefile` collects sources with `$(shell echo [A-z]*.f90)`. `[A-z]` is a **collation** range, not an ASCII range, and under `en_US.UTF-8` lowercase `a` collates before uppercase `A`, so the range beginning at `A` excludes all 13 files starting with lowercase `a`, plus `afold.f`. Measured: 349 files vs 362 under `LC_ALL=C`. I got this diagnosis right first, then talked myself out of it by testing the glob in zsh and bash (both return 362) instead of in `/bin/sh`, which is what make actually uses. Testing in the wrong shell cost a round.
(2) With that fixed, every run aborted with `TALYS-error: Error in <path>/structure/op, IOSTAT = 2` after a flood of Duflo-Zuker mass warnings. Not a missing database: TALYS keeps paths in `character(len=132)` and appends relative paths up to 69 characters, and the scratchpad directory alone is 120 characters, so the filename was being truncated at exactly 132. Entirely self-inflicted by the working directory, and invisible unless you count the characters in the error message.
(3) A sample deck referencing an auxiliary `energies` file aborted after producing 4 files instead of 451, **and still exited 0**.

**Root cause worth naming:** (3) is the CCFULL false-positive in a new costume. TALYS reports fatal errors only inside `talys.out` and always exits 0, so any harness keying on `$?` records a calculation that produced nothing as a success. That is the same shape as the CCFULL trap (a crash that leaves a plausible-looking output file behind) and the same shape as the GSM trap the day before (silent exit 139). Three consecutive per-code skills, three different ways for a failed run to look successful.

**Lesson:** stop treating "check the exit code" as the verification step. For scientific codes the exit code is frequently decorative. The real check is a positive assertion about the output: the expected files exist, the success banner is present, and the error string is absent. `run_talys.sh` asserts all three. Second lesson, from (1): when reproducing a build bug, reproduce it in the **exact shell the build system uses**; `make` uses `/bin/sh`, and testing the same glob in an interactive shell gave the opposite answer and nearly buried a correct diagnosis.

**Cross-validation:** citations were fetched live (CrossRef + INSPIRE agree; EPJA 59, 131 (2023), and note the code is MIT, not GPL as the catalog had recorded), and the input reference was written from the shipped 890-page manual rather than from memory, after the user pointed out that the GSM skill had been written without either check. Codex adversarial review commissioned on both skills.

**Status:** Resolved. 1415 of 1438 distributed reference files reproduce byte for byte across 5 samples; the remaining 18 data files agree to ~6 significant figures, which is the precision of TALYS's own output format.

## 2026-07-20: GSM would not run anywhere on macOS; the cause was an upstream infinite recursion, not the input

**Why we tried it:** Build the Gamow Shell Model book codes (github.com/GSMUTNSR/book_codes) for the fourth per-code skill and reproduce the book's own exercise outputs.

**What failed:** Three separate walls, in order.
(1) Apple clang refuses to compile numlib at all: it eagerly checks out-of-line template definitions against their declarations, and two in `total_diagonalization.hpp` genuinely do not match (a stray parameter, and `X.table` for `X.r_table`). GCC never noticed because those templates are never instantiated. GCC 15 then rejected the same code for the same reason via its new `-Wtemplate-body`.
(2) Homebrew GCC could not find `_bounds.h`: its private fixincludes copy of the macOS headers went stale after an Xcode SDK bump.
(3) With those cleared, every run died at `Pole basis states` with **exit 139 and a completely empty stderr**.

**Root cause of (3):** `numlib/complex_add.cpp` defines `finite(const complex<double>&)` and, inside it, calls `finite(x)` on a `double`, intending the legacy BSD `finite(double)` from `<math.h>`. POSIX removed that function in 2008 and macOS does not ship it, so overload resolution implicitly converts the `double` back to `complex<double>` and the function calls itself forever. It is invisible on Linux, where glibc still exposes `finite`. The crash lands in the function *prologue* writing to the stack guard page, so it reads as a memory bug deep in the physics.

**Lesson:** Two of these. First, an empty stderr plus exit 139 is not "no information": `EXC_BAD_ACCESS code=2` at an address in the stack region, with the faulting frame being a prologue, is the signature of unbounded recursion, and `lldb -k "bt"` names the cycle in one shot. Chasing it as a stack-size problem wasted a round, and raising the stack (`ulimit -s`, then relinking with `-Wl,-stack_size`) only moved the crash and briefly changed the signal, which is exactly the misleading evidence to expect. Second, a code that has clearly worked for years for its authors can still be unbuildable on your platform for reasons that have nothing to do with your input; before assuming the deck is wrong, confirm the binary can complete *any* run. Compiler-version drift (clang vs GCC, GCC 15's new eager template diagnostics, SDK-vs-fixincludes skew) is now a routine porting cost for older scientific C++, so the install script pins the workarounds rather than leaving them to the user.

**Status:** Resolved. `install_gsm.sh` autodetects a real GNU g++, adds `-fpermissive` on GCC 15+, prepends the live SDK headers on macOS, and applies the `std::isfinite` patch idempotently. Benchmarks pass in a clean room: 11 / 9 / 8 significant figures on the Chapter 2, 3, and 5 exercises respectively. The `finite()` bug is worth reporting upstream (on the TODO); it breaks every macOS build of the package.

## 2026-07-20: CCFULL benchmark false-positive caught only by a clean-room build test

**Why we tried it:** Verify the CCFULL skill by running the 16O+144Sm example and diffing OUTPUT against Hagino's reference OUTPUT.
**What failed:** The first check reported "bit-identical PASS" but was a FALSE POSITIVE. CCFULL asks interactive y/n questions on stdin (not just reading ccfull.inp); with no stdin it crashes at line 196 ("End of file") BEFORE truncating/rewriting OUTPUT. So the OUTPUT file still held the previously downloaded reference, and diffing it against its own copy trivially matched. The code had not actually run.
**Root cause:** Two compounding traps: (1) CCFULL's hidden stdin interactivity, and (2) verifying in a directory that already contained the reference OUTPUT, so a no-op run looked like a perfect reproduction. The `2>/dev/null` in the run wrapper hid the crash.
**Lesson:** A benchmark is only real if run in a CLEAN ROOM: fresh build from public source, fresh working dir with NO pre-existing reference file, and the run's stderr inspected (never silently discarded). After the real run (stdin fed 'n' answers), the physics reproduced exactly for sub-barrier rows and to 4-5 sig figs at the tail (a code-version rounding difference, honestly stated), not a bogus bit-identical claim. This is now a hard rule for every per-code skill (see CLAUDE.md).
**Status:** Resolved; CCFULL skill ships with the honest benchmark and the stdin quirk documented.

## 2026-07-14: first per-code skill embedded in-repo (fresco), with binary auto-install; cp -R symlink trap

**Why we tried it:** Start the Phase 2 skill pack by pulling the reference fresco skill into the repo (`skills/fresco/`, the layout the README already anticipated) and giving it the missing capability every per-code skill will need: provision the underlying code itself, rather than assuming a pre-built binary at `~/bin/fresco`. Added `scripts/install_fresco.sh` (checks `~/bin`/`PATH`, else clones https://github.com/I-Thompson/fresco and builds `make FC=gfortran`, copies fresco+sfresco to the bin dir) and wired `run_fresco.sh` to call it on first use.

**What failed / trap caught:** The initial `cp -R ~/.claude/skills/fresco skills/fresco` did NOT embed the files. `~/.claude/skills/fresco` is itself a symlink to `~/Desktop/claude_skills/skills/fresco`, and BSD `cp -R` copies a command-line symlink AS a symlink, so `skills/fresco` became a dangling-on-clone symlink and every subsequent edit wrote THROUGH it into the shared live skill repo, not into FUSION. Codex cross-review flagged it (its finding #2). Verified: `ls -ld` showed the symlink; the edits had landed in `~/Desktop/claude_skills/skills/fresco` (untracked there, so nothing committed was clobbered).

**Root cause:** BSD vs GNU `cp` semantics on a symlinked source; on macOS `-R` alone preserves the top-level symlink (need `-RL` to dereference). Compounded by the fresco skill being a symlink, which was invisible until Codex checked the inode.

**Lesson:** When "embedding" a skill/dir into a shippable repo, use `cp -RL` (or verify with `find -type l` after) so the result is real files, not a symlink that dies on `git clone`. Build+verify against a published anchor before trusting a freshly compiled binary: the gfortran build reproduced B1-elastic sigma_R = 1575.17495 (ref 1575.175). Cross-AI review earns its keep on filesystem/portability bugs a single agent misses.

**Status:** Resolved. `skills/fresco/` is now a real self-contained copy with auto-install; the global skill was reverted to pristine (the auto-install variant lives only in FUSION). Applied Codex fixes #1 (preserve FRESCO exit code), #12 (absolutize binary path before cd), #4 (recheck both binaries post-install), #16 (EXIT-trap the verify tmpdir), #17 (validate deck before any clone). Deferred as over-engineering for a single-user research wrapper: install locking, atomic rename, pinned commit, unique scratch dir.

## 2026-07-20: semantic full run made ZERO progress for 3 nights; KINGSTON .tex read hung the batch

**Why we tried it:** Weekend auto-finish of the last 3,181 semantic-layer papers via the off-peak launcher.
**What failed:** Three consecutive off-peak windows (Fri/Sat/Sun) each opened, started `full --workers 40`, and produced ZERO new edges; relations.tsv was byte-identical Friday to Monday, stuck at 51,197/54,378 citing papers. A manual `full` run confirmed: the first ~20 papers classify fast, then all workers freeze, and after 4 minutes there were 0 API-timeout fallbacks (so the hang was NOT the API).
**Root cause:** The hang is in `extract_citation_context` reading each citing paper's .tex from the KINGSTON exFAT drive. File I/O has no timeout, so a pathological/slow .tex read blocks a worker forever. The remaining 3,181 papers are all recent (2025-2026) whose edges came from the INSPIRE backfill; their .tex uses external `\bibliography{}` with no inline cites, so context extraction was both useless (nothing to find) AND the thing that hung. The API 300s timeout was a red herring (never reached).
**Lesson:** File I/O in a worker pool needs a timeout or a size/skip guard, same discipline as network calls. For backfill papers there is no .tex context to extract by definition, so skip it. Fix: added `--no-context` (classify on titles+abstracts, no .tex read) which cleared the 3,181 in ~3 minutes at ~19 papers/s; also lowered the API timeout 300s->60s and made a 3-retry failure write a background fallback so a poison paper is marked done instead of re-poisoning every future window.
**Status:** Replaced by --no-context path; semantic layer completed 2026-07-20.

## 2026-07-15: newest papers have near-empty citation edges (external .bib not in corpus)

**Why we tried it:** User asked whether the overnight digest increment got cross-referenced. Spot-checked the newest paper (2606.18165) then the last 500 ids in the date-sorted list.

**What was found:** The increment IS structurally cross-referenced: all 61,059 pages carry `## In-corpus citations` sections (inject_citations ran over the full corpus this morning) and 43,489 carry concepts frontmatter. BUT the citation EDGES for the newest papers are largely empty: the last 500 ids show 27% citation-graph coverage vs 81% corpus-wide. Direct cause measured: of those 500, 360 (72%) use external `\bibliography{}` with no inline refs; only 134 have inline `\bibitem`, and 27% coverage matches that 134/500. 2606.18165's .tex has zero arXiv ids or DOIs.

**Root cause:** The corpus (KINGSTON) stores only .tex, no .bib/.bbl. Recent papers are preprints submitted with an external `\bibliography{refs}` + separate .bib, so their .tex contains nothing extractable. Older papers went through journal production and carry an expanded .bbl / inline `\bibitem`, so kb_citegraph extracts them fine. The gap is therefore concentrated in the newest ~2 years and is a source-availability limitation, not a processing bug. kb_citegraph correctly scanned all 61,357 tex dirs; there was simply nothing to find in the preprint sources.

**Lesson:** .tex-only citation extraction has a hard ceiling on recent preprints. Do not chase it in the parser. The right fix is a different source: INSPIRE references API (structured, zero LLM tokens) for the ~11,489 zero-edge papers, mapped to corpus ids and merged into citations.tsv. Logged as a TODO, not yet run. Also note: the semantic layer (L3) feeds on citations.tsv, so it inherits this gap for recent papers until the backfill runs.

**Status:** Parked (INSPIRE backfill is the fix, on the TODO; parser is working as designed).

## 2026-07-14: Night 3 digest QC passed; +16,893 pages committed (53,258/61,059 total)

**Why we tried it:** Third off-peak digest window (00:30-08:25) produced 16,893 new paper pages, untracked. Before committing them, ran the Phase 3 QC protocol (log check, structural conformance, failure-mode scan, cost reconciliation) rather than committing blind.

**What was found:** Clean. Run log shows fail=0 across the whole night and a clean 08:25 deadline stop. Of the 16,893 pages: 0 empty/truncated/corrupt, 100% carry frontmatter + digest_date 2026-07-14, 100% carry the digest sections. Failure-mode scan turned up only false positives: the 101 `\cite{}` hits are all inside quoted source abstracts (not digest prose; one is Lei's own four-body IAV paper), and the AI-refusal / API-error hits are substring collisions with physics text (Drude formula, rate parameter). Token rate in~10.3k/out~666 per paper matches the 500-paper pilot; ~$29 off-peak.

**Root cause of the one real blemish:** ~52 pages (0.3%) render the digest headings as h3/h1 instead of h2 (one merged the "Key claim" heading into the H1 title line). Cosmetic model-output variance in DeepSeek's markdown; this variant did NOT appear in the night-1/night-2 committed pages, so it is new to this batch. Content underneath is intact.

**Lesson:** Commit the corpus in per-night batches with a QC gate, not blind; the gate is cheap (grep-level) and catches structural drift early. The h2/h3 drift is worth a one-line normalizer in the digest post-step or template if it recurs; not worth a rewrite for 0.3%. Keep the corpus commit scoped (kb-wiki/papers only, logs .gitignored) and separate from code/skill commits.

**Status:** Committed (f53d123c) and pushed. Run INCOMPLETE: 7,801 papers remain (53,258/61,059); the self-looping launcher resumes next off-peak window on skip-existing, so the "morning verification" TODO stays open by design.

## 2026-07-09: KB wiki form pivoted from DB-rendered + digest-on-touch to pre-generated md

**Why we tried it:** The first L3 design rendered pages from SQLite on demand through an MCP server, digesting papers only when touched, on the assumption that bulk-digesting 62k papers was cost-without-demand.
**What failed:** Nothing failed technically; the premise was wrong. Measured on the 500-paper pilot: 10.7k tokens in / 0.6k out / 8 s per paper, $1.74 per 500, so the FULL corpus costs ~$218 standard / ~$109 off-peak. At that price pre-generation strictly dominates: plain md files, grep/read access identical to the personal literature-wiki workflow, no server dependency, trivially shippable.
**Root cause:** Cost estimate made before measuring; the design guarded against an expense that turned out to be two dinners.
**Lesson:** Run the 100-sample cost measurement BEFORE designing around cost. Also: the user calls this instinct correctly ("反正用deepseek做，成本也很低"); check premises against the cheapest available model first.
**Status:** Replaced by pre-generated md wiki (kb-design.md L3, revised 2026-07-09; MCP server demoted to optional sugar).
## 2026-07-13, disabled inherited upstream community-bot workflows on the fork

**Why we tried it:** The daily `close-issues` workflow on jinleiphys/fusion-core failed with `403 Forbidden` (run #4). Root cause: `script/github/close-issues.ts:3` hardcodes `const repo = "anomalyco/opencode"`, so the fork's cron was trying to auto-close *upstream* opencode's stale issues using the fork's `github.token`. Reading upstream issues is public (worked), but POSTing a comment returned 403 (fork has no write access to upstream, and shouldn't). The log's real opencode issue numbers (#27459, #12723) and opencode maintainers as "exempt" are the tell.

**Scope:** A whole inherited family of upstream community-management bots, none gated to skip forks: close-issues, close-prs (`close-prs.ts:5` same hardcode), compliance-close, duplicate-issues, triage, pr-management, pr-standards, review, notify-discord. (publish/deploy/stats/docs-update already self-gate with `if: github.repository == 'anomalyco/opencode' / 'sst/opencode'`, so they no-op on the fork.)

**Fix:** Disabled all 9 at the repo level via `gh workflow disable <name>.yml`. Chose disable over editing the files because `fusion-weekly-rebase` force-pushes `fusion-brand` onto `upstream/dev` weekly; editing would bloat the brand patch and invite rebase conflicts. Disabled state lives in Actions config keyed by workflow path, decoupled from file content, so it survives the weekly force-push. Files stay byte-identical to upstream (clean rebases); they just never fire. Verified: all 9 now `disabled_manually`; fusion-weekly-rebase / test / typecheck stay `active`. Reversible with `gh workflow enable`.

**Residual (not fixed, flagged):** the `anomalyco/opencode` hardcode still sits in close-issues.ts / close-prs.ts. Harmless while disabled. Permanent root-fix would add an `if: github.repository == 'jinleiphys/fusion-core'` guard into the brand patch (upstream's own pattern), traded against a larger, conflict-prone patch. Deferred until it actually bites.

**Status:** Resolved; daily 403 stopped.

## 2026-07-09, Phase 1 started: fork, brand patch, rebase CI; two decisions + one discovery

**Decisions:**
1. Internal identifiers, config paths (~/.config/opencode), and package names stay "opencode"; the brand patch touches only user-visible surfaces (TUI logo done; icons/name-strings later). Reason: config/skill compatibility with upstream and with existing user setups; a full internal rename would balloon the patch and break the weekly rebase.
2. Fork repo = jinleiphys/fusion-core, default branch fusion-brand (= upstream dev + brand commits); dev kept as pristine upstream mirror, synced by CI.

**Discovery (zero-fork alternative, recorded not chosen):** opencode's TUI has an official plugin slot `home_logo` with mode="replace" (packages/tui/src/routes/home.tsx), so the home logo could be replaced by a FUSION plugin without any fork. User already chose the rebrand fork (needed anyway for icons/desktop/web); the slot is the fallback if fork maintenance ever becomes too costly.

**Scope correction from user (same day):** per-code skills cover the WHOLE open-source nuclear ecosystem, not just reactions codes; skills-catalog.md added as the living roadmap (reactions / statistical-fission / R-matrix-astro / structure / scoped transport-data / Lei family), with openness-verification flags and wave ordering.

**Status:** Phase 1 core done (fork + logo patch + green weekly-rebase CI); remaining = icon graphics, name-string sweep, build/release pipeline.

## 2026-07-09, Phase 0 quality gate run and passed (same day as init)

**Why we tried it:** The whole platform premise rests on skills surviving the move to opencode + domestic models. Gate = 3 skill types on real cases vs Claude reference.

**What happened:** All three passed on deepseek-chat: literature-search reproduced the exact Typel-Baur 2003 BibTeX with wiki-first + INSPIRE + CrossRef chain; fresco built a correct n+90Zr deck (understood the FRESCO cube-root-sum radius convention and pre-scaled radii), agreed with an independent Claude-side FRESCO run to 4-5 significant figures with the residual fully explained by its 4-digit rounding; prc-writing produced a PRC introduction with 10/10 verified citations, zero hallucination, and ran the qu-ai-wei-en pass unprompted. Details in phase0/report.md.

**Lesson (caveats, not failures):** (1) non-interactive opencode auto-rejects out-of-cwd permissions and the run dies silently; FUSION needs a shipped permission config, `--auto` is test-only. (2) opencode's skill loading returned a skill description instead of the body once (literature-wiki call in test 3); cross-skill invocation semantics need verification. (3) BSD grep breaks `grep -P` checks in skills. (4) Benchmark prompts must pin masses and radius conventions.

**Status:** Gate passed on objective criteria; user sign-off pending for Phase 1.

## 2026-07-09, project initialized; naming + architecture decisions from the founding conversation

**Why we tried it:** User wants a nuclear-physics-specific research agent platform built on opencode (github.com/anomalyco/opencode, MIT, 184k stars), integrating the existing ~30 research skills, per-code skills for nuclear open-source software, and a self-contained knowledge base from the local 62k-paper arXiv nucl-th corpus.

**Decisions made (not failures, founding record):**
- Name: FUSION (Framework for Unified Scientific Intelligence in Open Nuclear physics). Rejected alternatives: PION (collides with pion/webrtc GitHub org), FERMI, NORA, CORE, HALO, MENTOR, SCATTER. EMPIRE and TALYS are forbidden as names (existing nuclear reaction codes).
- Architecture: rebrand fork (VSCodium model), NOT a functional fork. Only brand assets change (logo, name strings, icons); functional code stays upstream. CI auto-rebases weekly. All domain capability lives in the customization layer (skills, agents, MCP servers, config), which upstream opencode supports without source changes.
- Knowledge base: reuse the existing literature-corpus pipeline (corpus.db, SQLite FTS5, BM25, query.py) rather than building a new embedding index. Stats verified 2026-07-09: 62714 papers, 61357 with full text, 1992-09 to 2026-06. Lexical-first is a deliberate prior decision of the literature-corpus skill; do not re-propose pre-embedding the whole corpus.
- Personal wiki (~/research-wiki, ~/research-wiki-personal) stays a PRIVATE layer, never shipped. FUSION defines the plug-in interface; each user grows their own wiki.

**Protocol note:** research-planning Steps 3a/3b (literature-wiki query + literature-search) intentionally not run at init: this is a software platform project, the README carries no physics-paper citations, so the wiki coupling has no trigger. If a paper citation ever enters a FUSION file, run the Step 5-wiki ingest protocol at that moment.

**Status:** Active, Phase 0 (quality validation) not yet started.

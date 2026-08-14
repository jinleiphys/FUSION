# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.
Full-length versions of consolidated entries live in `devlog-archive.md` (not auto-imported).

**Keep this file under 100 lines.** CLAUDE.md imports it with `@devlog.md`, so
every line is loaded into every session in this project. When it grows past
that, move the oldest entries to `devlog-archive.md` in full, cutting at an
entry boundary, and consolidate what stays. `scripts/hooks/pre-commit` enforces
this; install it with `ln -sf ../../scripts/hooks/pre-commit .git/hooks/`.

## 2026-08-14: the onboarding path finally run somewhere other than the author's machine

**It works, end to end, and that had never actually been checked.** Everything
verified up to now was the code-install layer; the path a real user takes
(clone, download the CLI, ask a question) had only ever run where it was
written. On heliumx, from an empty directory: clone 58.7 s, CLI downloaded and
extracted, `./fusion --version` prints 0.1.0, `fusion debug skill` finds the
skills from inside the clone with no configuration, and a Chinese question
("帮我算 d+58Ni 在 21.6 MeV 的弹性散射") brought up the first-run setup offer
AND reached for the FRESCO skill in the same turn, reading its examples and
namelist reference. That is the product's central claim, demonstrated on a
machine that is not the one it was built on.

**A false alarm worth recording, because the mistake is a general one.** The
first attempt ran without the proxy tunnel and both quick-start commands
failed (github.com 0 of 6, clone dead after 132 s), which I wrote up as a
distribution blocker for Chinese users. The user's correction: researchers and
students in China run a proxy as standard equipment, so heliumx, a bare server
with no proxy configured, is not a model of a student's laptop. The
measurement was sound and the inference was not. **A number from one box is
not a claim about a population**, and the cost of getting that backwards is
worse than silence: the READMEs briefly told students they faced a problem
they do not have. Retracted the same day; what survives is one line about
installing onto a LAB SERVER, which genuinely often cannot reach github.com,
pointing at `http_proxy` for the two download steps.

**Two documentation defects fell out of the same run.** The clone is no longer
229 MB compressed and 623 MB checked out; it is **256 MB transferred and 945
MB on disk**, so both READMEs understated the disk cost by about 50 percent.
And `./fusion --help` prints `opencode` on every line of its usage block: a
user who downloaded a binary named `fusion` is told, by the most likely first
command, that they are holding a different tool. That is the known open
"TUI/CLI display-name strings sweep", now with a confirmed user-visible
symptom.

## 2026-08-13: a Codex pass on kb-search, and everything it pulled loose

Full versions of this day's four entries are in `devlog-archive.md`. What is
worth carrying:

**The adversarial pass failed the skill, and every finding that mattered was
the skill VOUCHING for data quality it had not measured.** "Citation edges are
mechanical, trustable as-is" was the false sentence. Counterexamples came from
the raw .tex: the example paper's only `cites` edge resolved `\cite{Jin15}` to
an unrelated soliton paper through an author-year collision. **Aim a research
skill's adversarial pass at its DATA CLAIMS, not its command syntax**, and give
the reviewer access to the sources behind the shipped artifact, which is what
produced the blocker.

**Two thirds of all `contrasts` labels were wrong.** Of 17,408 edges typed as
disagreement, 6,000 survived a second pass asking one narrow question; the rest
were neutral comparisons. **When one label in a classification carries sharp
semantics, measure its precision with a dedicated single-question pass**: a
rule inside a six-way prompt is weaker than a pass that asks only that.

**Repairs, all verified converged:** collision guard on the Tier-B author-year
fallback (the blocker edge now resolves to the true predecessor, so the guard
repaired rather than deleted); dangling edges dropped; `relations.tsv` halved
to 34.7 MB by deleting `background` rows, so **an edge with no relations row
now MEANS background**, with `relations-classified.txt` separating that from
"not yet typed". Under those sat three pipeline bugs worth remembering: an
injector that never mapped old-style slash ids to underscore filenames, so
17,570 pages claimed "None detected" while holding edges; a default path
pointing at a 221 KB pilot sample rather than the real file; and sorting a set
by date alone, which made page content follow the hash seed.

**Cold-start install audit, 20 skills on a bare Linux box, six defects.** The
best one: sky3d's probe passed `mrest=0`, and Sky3D evaluates `MOD(iter,mrest)`
unconditionally, so it is an integer division by zero: SIGFPE on x86-64,
silently harmless on Apple Silicon where AArch64 defines division by zero as
returning 0. The others were a Makefile hardcoding Homebrew LAPACK and `-lc++`,
a makefile requiring `/bin/csh`, three uses of the BSD-only
`mktemp -t <prefix>`, and a brew-only message shown to Linux users.
**A documented cross-build of the CODE is not a test of the SKILL's scripts**:
pikoe had one and its verify script still failed on Linux. And **a make
command-line variable propagates into sub-makes**, which is how the first
COLOSS fix broke both platforms at once.

**TALYS packaging, settled as a rule.** Provisioning is lazy, so no code needs
an opt-in flag and `install.sh` never pre-builds one (CLAUDE.md carries the
decision). The disk question was hiding the real defect: the structure-database
guard checked that two directories existed where its own comment promised
completeness, and a partially missing database makes TALYS print a successful
calculation from Duflo-Zuker fallback masses. It now reads the expected file
count from the clone's own git index. **A guard must be flip-tested, and
checking the exit code is not enough: check that stdout hands back nothing**,
because a guard that warns and still returns a path is not a guard.

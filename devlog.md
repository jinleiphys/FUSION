# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.
Full-length versions of consolidated entries live in `devlog-archive.md` (not auto-imported).

**Keep this file under 100 lines.** CLAUDE.md imports it with `@devlog.md`, so
every line is loaded into every session in this project. When it grows past
that, move the oldest entries to `devlog-archive.md` in full, cutting at an
entry boundary, and consolidate what stays. `scripts/hooks/pre-commit` enforces
this; install it with `ln -sf ../../scripts/hooks/pre-commit .git/hooks/`.

## 2026-09-24: the cite-key heuristic was wrong four times in five; the graph now takes INSPIRE

**Tier B of `kb_citegraph.py` is gone.** For a paper with an external .bib the
corpus holds only keys like `Wang11`, and the heuristic grouped authors by
surname (every 2011 "Wang" was one person, accepted wholesale) and let a
self-citation key take every paper its author wrote that year. Against INSPIRE
reference lists (record numbers resolved), 15,709 of 84,587 tier-B edges were
right, 18.6%. The same 5,931 papers now take their references from INSPIRE,
and the backfill resolves record-number-only references (40% of a sample),
which also recovered edges for the 27k earlier backfill papers. Graph
703,430 -> 809,632 edges (69,949 removed, 176,151 added, calibrations pass);
26,719 relation rows on removed edges dropped; the 176,151 new edges are
listed untyped in `relations-untyped.tsv` (typed 2026-09-25: 30,088 typed,
861 new contrasts rechecked, 405 overturned; relations 237,009 rows). Codex
confirmed the counts offline and put the kept tex-derived edges at 98.7%
against INSPIRE. A Codex review of the backfill
change caught two recall losses of my own (an out-of-corpus eprint no
longer fell back to its DOI; a record with an unmapped DOI was never
looked up), worth 3.1% of edges, fixed before the final run. A first 150-paper sample said
12.9%; it undercounted because its truth set skipped record numbers, and the
same flaw made tier A look 79.5% right when every inspected miss was real.

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

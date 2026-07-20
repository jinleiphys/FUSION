# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.

## 2026-07-20: CCFULL benchmark false-positive caught only by a clean-room build test

**Why we tried it:** Verify the CCFULL skill by running the 16O+144Sm example and diffing OUTPUT against Hagino's reference OUTPUT.
**What failed:** The first check reported "bit-identical PASS" but was a FALSE POSITIVE. CCFULL asks interactive y/n questions on stdin (not just reading ccfull.inp); with no stdin it crashes at line 196 ("End of file") BEFORE truncating/rewriting OUTPUT. So the OUTPUT file still held the previously downloaded reference, and diffing it against its own copy trivially matched. The code had not actually run.
**Root cause:** Two compounding traps: (1) CCFULL's hidden stdin interactivity, and (2) verifying in a directory that already contained the reference OUTPUT, so a no-op run looked like a perfect reproduction. The `2>/dev/null` in the run wrapper hid the crash.
**Lesson:** A benchmark is only real if run in a CLEAN ROOM: fresh build from public source, fresh working dir with NO pre-existing reference file, and the run's stderr inspected (never silently discarded). After the real run (stdin fed 'n' answers), the physics reproduced exactly for sub-barrier rows and to 4-5 sig figs at the tail (a code-version rounding difference, honestly stated), not a bogus bit-identical claim. This is now a hard rule for every per-code skill (see CLAUDE.md).
**Status:** Resolved; CCFULL skill ships with the honest benchmark and the stdin quirk documented.

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

## 2026-07-14: first per-code skill embedded in-repo (fresco), with binary auto-install; cp -R symlink trap

**Why we tried it:** Start the Phase 2 skill pack by pulling the reference fresco skill into the repo (`skills/fresco/`, the layout the README already anticipated) and giving it the missing capability every per-code skill will need: provision the underlying code itself, rather than assuming a pre-built binary at `~/bin/fresco`. Added `scripts/install_fresco.sh` (checks `~/bin`/`PATH`, else clones https://github.com/I-Thompson/fresco and builds `make FC=gfortran`, copies fresco+sfresco to the bin dir) and wired `run_fresco.sh` to call it on first use.

**What failed / trap caught:** The initial `cp -R ~/.claude/skills/fresco skills/fresco` did NOT embed the files. `~/.claude/skills/fresco` is itself a symlink to `~/Desktop/claude_skills/skills/fresco`, and BSD `cp -R` copies a command-line symlink AS a symlink, so `skills/fresco` became a dangling-on-clone symlink and every subsequent edit wrote THROUGH it into the shared live skill repo, not into FUSION. Codex cross-review flagged it (its finding #2). Verified: `ls -ld` showed the symlink; the edits had landed in `~/Desktop/claude_skills/skills/fresco` (untracked there, so nothing committed was clobbered).

**Root cause:** BSD vs GNU `cp` semantics on a symlinked source; on macOS `-R` alone preserves the top-level symlink (need `-RL` to dereference). Compounded by the fresco skill being a symlink, which was invisible until Codex checked the inode.

**Lesson:** When "embedding" a skill/dir into a shippable repo, use `cp -RL` (or verify with `find -type l` after) so the result is real files, not a symlink that dies on `git clone`. Build+verify against a published anchor before trusting a freshly compiled binary: the gfortran build reproduced B1-elastic sigma_R = 1575.17495 (ref 1575.175). Cross-AI review earns its keep on filesystem/portability bugs a single agent misses.

**Status:** Resolved. `skills/fresco/` is now a real self-contained copy with auto-install; the global skill was reverted to pristine (the auto-install variant lives only in FUSION). Applied Codex fixes #1 (preserve FRESCO exit code), #12 (absolutize binary path before cd), #4 (recheck both binaries post-install), #16 (EXIT-trap the verify tmpdir), #17 (validate deck before any clone). Deferred as over-engineering for a single-user research wrapper: install locking, atomic rename, pinned commit, unique scratch dir.

## 2026-07-09: KB wiki form pivoted from DB-rendered + digest-on-touch to pre-generated md

**Why we tried it:** The first L3 design rendered pages from SQLite on demand through an MCP server, digesting papers only when touched, on the assumption that bulk-digesting 62k papers was cost-without-demand.
**What failed:** Nothing failed technically; the premise was wrong. Measured on the 500-paper pilot: 10.7k tokens in / 0.6k out / 8 s per paper, $1.74 per 500, so the FULL corpus costs ~$218 standard / ~$109 off-peak. At that price pre-generation strictly dominates: plain md files, grep/read access identical to the personal literature-wiki workflow, no server dependency, trivially shippable.
**Root cause:** Cost estimate made before measuring; the design guarded against an expense that turned out to be two dinners.
**Lesson:** Run the 100-sample cost measurement BEFORE designing around cost. Also: the user calls this instinct correctly ("反正用deepseek做，成本也很低"); check premises against the cheapest available model first.
**Status:** Replaced by pre-generated md wiki (kb-design.md L3, revised 2026-07-09; MCP server demoted to optional sugar).

# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.

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

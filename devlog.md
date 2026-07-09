# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.

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
- Name: FUSION (Framework for Unified Skills, Inference & Open Nuclear-science). Rejected alternatives: PION (collides with pion/webrtc GitHub org), FERMI, NORA, CORE, HALO, MENTOR, SCATTER. EMPIRE and TALYS are forbidden as names (existing nuclear reaction codes).
- Architecture: rebrand fork (VSCodium model), NOT a functional fork. Only brand assets change (logo, name strings, icons); functional code stays upstream. CI auto-rebases weekly. All domain capability lives in the customization layer (skills, agents, MCP servers, config), which upstream opencode supports without source changes.
- Knowledge base: reuse the existing literature-corpus pipeline (corpus.db, SQLite FTS5, BM25, query.py) rather than building a new embedding index. Stats verified 2026-07-09: 62714 papers, 61357 with full text, 1992-09 to 2026-06. Lexical-first is a deliberate prior decision of the literature-corpus skill; do not re-propose pre-embedding the whole corpus.
- Personal wiki (~/research-wiki, ~/research-wiki-personal) stays a PRIVATE layer, never shipped. FUSION defines the plug-in interface; each user grows their own wiki.

**Protocol note:** research-planning Steps 3a/3b (literature-wiki query + literature-search) intentionally not run at init: this is a software platform project, the README carries no physics-paper citations, so the wiki coupling has no trigger. If a paper citation ever enters a FUSION file, run the Step 5-wiki ingest protocol at that moment.

**Status:** Active, Phase 0 (quality validation) not yet started.

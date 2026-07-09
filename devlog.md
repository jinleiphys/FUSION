# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.

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

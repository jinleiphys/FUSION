# FUSION TODO

Validation rules and hard constraints live in [CLAUDE.md](CLAUDE.md); do not restate them here.

## Phase 0: quality gate (do this before writing any platform code)

Question to answer: how much does skill quality drop on opencode + a domestic model vs Claude Code + Claude?

- [x] Install stock opencode locally, connect one domestic model (was already done: opencode 1.17.15, DeepSeek + Qwen keys, all 36 skills symlinked into ~/.config/opencode/skills/)
- [x] Port 3 representative skills (no porting needed: opencode reads the SKILL.md symlinks directly)
- [x] Run each on one REAL case; compare against Claude reference (2026-07-09, deepseek-chat: test 1 litsearch PASS exact BibTeX; test 2 fresco PASS 4-5 sig figs vs independent Claude deck; test 3 prc-writing PASS 10/10 verified citations. See phase0/report.md)
- [ ] Verdict with user: prose taste on test 3 + sign-off to proceed to Phase 1 (objective verdict: acceptable; caveats in phase0/report.md)

## Phase 1: rebrand fork + CI

- [x] Fork created: github.com/jinleiphys/fusion-core (upstream anomalyco/opencode, forked at v1.17.16); local /Users/jinlei/Desktop/code/fusion-core; default branch = fusion-brand
- [x] Brand assets mapped: TUI packages/tui/src/logo.ts (patched); remaining surfaces = desktop icons (packages/desktop/icons/), web SVGs (packages/web/src/assets/), ui/components/logo.tsx, docs logo
- [x] Brand patch first cut (2026-07-09, commit 25eea06): TUI main logo "fu sion" + compact "fu" pulse logo, same block-glyph style and shadow marks as upstream; MIT notice untouched. Decision: internal identifiers/config paths stay "opencode" for upstream compatibility; only user-visible surfaces get rebranded
- [x] CI weekly rebase (fusion-rebase.yml, Mondays 02:00 UTC): rebases fusion-brand onto upstream/dev, force-with-lease push, syncs dev mirror; verified green on manual dispatch (run 29000283160)
- [ ] Remaining brand surfaces: desktop/web icons need an actual FUSION graphic (nature-figure skill or designer), TUI/CLI display-name strings sweep
- [ ] TUI logo v2: current block-glyph version verified rendering as "FUSion" (user: 效果一般, acceptable for now); revisit in the visual design pass together with the icons
- [ ] Build + release pipeline for FUSION binaries (adapt upstream release workflow; bun installed locally)
- [ ] Domain name [Please specify preference]

## Phase 2: skill pack

Scope (user directive 2026-07-09): **every excellent open-source nuclear-physics code gets its own skill**, across reactions, statistical/fission, R-matrix/astro, structure, and (scoped) transport/data. Full living roadmap with openness-verification flags and wave ordering: [skills-catalog.md](skills-catalog.md).

- [ ] Port the existing ~30 research skills (writing, review, literature, figures) to FUSION format; strip Claude-Code-only mechanics per skill
- [ ] User confirms wave ordering in skills-catalog.md
- [ ] Wave 1 per-code skills (user expert, benchmarks at hand): THOx, CCFULL, TALYS, smoothie, COLOSS
- [ ] Wave 2 (community heavyweights): KSHELL, GEMINI++, GEF, AZURE2, SkyNet
- [ ] Wave 3+ per catalog; each entry needs its open-source status verified before work starts
- [ ] Each per-code skill meets the quality bar in skills-catalog.md (install, verified deck examples, run/parse, benchmark to N digits, failure modes) before it ships

## Phase 3: knowledge base (design settled 2026-07-09: [kb-design.md](kb-design.md); PhySH taxonomy per user)

- [x] Design: PhySH-organized DB-backed wiki, 4 layers (taxonomy rules / mechanical classification / citation graph / wiki + digest-on-touch). Taxonomy verified: PhySH v2.8.0, CC0, Nuclear Physics subtree 176 concepts
- [ ] Prototype gate: 2 concepts (Breakup reactions + THM-adjacent), classify corpus, topic pages + 3 DeepSeek digests; validate against the user's 25 FRESCO-line papers
- [ ] L0: physh-nuclear.yaml (176 concepts + neighbor whitelist [user input]) with FTS match rules
- [ ] L1: paper_concept classification table, monthly re-run hooked into the corpus-update launchd job
- [ ] L2: within-corpus citation graph from raw .tex (needs KINGSTON mounted; fulfills literature-corpus Tier 2 cites/cited-by)
- [ ] L3: MCP server (kb_browse/kb_paper/kb_search/kb_cites) + digest cache + 176 topic syntheses
- [ ] Licensing decision for the public artifact: abstract snippets vs fetch-on-first-run [user decision]
- [ ] kb.db vs in-corpus.db decision at prototype time (leaning separate kb.db + ATTACH)

## Phase 4: distribution

- [ ] install.sh: opencode binary + skill pack + MCP servers + default config in one shot
- [ ] Default model config for CN users (domestic providers) and international users
- [ ] Student-facing docs (zh + en), first-run tutorial: one real FRESCO calculation end to end
- [ ] Pilot with 2-3 group students; collect failures into devlog

## Wiki ingest queue

(empty; no paper citations in the project yet)

## Completed

(nothing yet)

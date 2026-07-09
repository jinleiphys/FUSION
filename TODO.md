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

## Phase 3: knowledge base

- [ ] Domain-keyword classification layer on corpus.db: define domain list + keyword/category rules with user; add tag column + query filter to query.py
- [ ] MCP server wrapping query.py (text/abs/author/show/similar + domain filter)
- [ ] Licensing decision: public artifact = metadata+abstract index, or rebuild-from-arXiv script, or group-internal full copy only. Decide with user before any public release.
- [ ] Update pipeline: adapt the monthly launchd job so FUSION installs can refresh (or pin to releases)

## Phase 4: distribution

- [ ] install.sh: opencode binary + skill pack + MCP servers + default config in one shot
- [ ] Default model config for CN users (domestic providers) and international users
- [ ] Student-facing docs (zh + en), first-run tutorial: one real FRESCO calculation end to end
- [ ] Pilot with 2-3 group students; collect failures into devlog

## Wiki ingest queue

(empty; no paper citations in the project yet)

## Completed

(nothing yet)

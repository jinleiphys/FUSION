# FUSION TODO

Validation rules and hard constraints live in [CLAUDE.md](CLAUDE.md); do not restate them here.

## Phase 0: quality gate (do this before writing any platform code)

Question to answer: how much does skill quality drop on opencode + a domestic model vs Claude Code + Claude?

- [x] Install stock opencode locally, connect one domestic model (was already done: opencode 1.17.15, DeepSeek + Qwen keys, all 36 skills symlinked into ~/.config/opencode/skills/)
- [x] Port 3 representative skills (no porting needed: opencode reads the SKILL.md symlinks directly)
- [x] Run each on one REAL case; compare against Claude reference (2026-07-09, deepseek-chat: test 1 litsearch PASS exact BibTeX; test 2 fresco PASS 4-5 sig figs vs independent Claude deck; test 3 prc-writing PASS 10/10 verified citations. See phase0/report.md)
- [ ] Verdict with user: prose taste on test 3 + sign-off to proceed to Phase 1 (objective verdict: acceptable; caveats in phase0/report.md)

## Phase 1: rebrand fork + CI

- [ ] Fork anomalyco/opencode; identify every brand asset file (logo ASCII, name strings, icons, splash)
- [ ] Brand patch: FUSION name + logo; keep MIT license notice; confirm no opencode trademark remains
- [ ] CI job: weekly fetch upstream, rebase brand patch, build, release; alert on conflict
- [ ] Reserve names: GitHub org/repo, domain [Please specify preference], check collisions

## Phase 2: skill pack

Port order inside each tier: user confirms priorities before work starts.

- [ ] Port the existing ~30 research skills (writing, review, literature, figures) to FUSION format; strip Claude-Code-only mechanics per skill
- [ ] Tier 1 per-code skills (community, reactions, user is expert): FRESCO (exists, port), TALYS, CCFULL
- [ ] Tier 2 per-code skills (group-owned): smoothie, COLOSS, SLAM.jl, HPRMAT, inhomoR, swift.jl, PINN-ECS, transfer
- [ ] Tier 3 per-code skills (structure/other, need domain check): KSHELL, BIGSTICK, [Please specify which structure codes matter]
- [ ] Each per-code skill: benchmark case with published reference value, agreement stated to N digits, before it ships

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

# FUSION TODO

Validation rules and hard constraints live in [CLAUDE.md](CLAUDE.md); do not restate them here.

## Phase 1: rebrand fork + CI

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

## Phase 3: knowledge base ([kb-design.md](kb-design.md); PhySH taxonomy + pre-generated md wiki)

- [ ] **Morning verification of tonight's full run** (armed 2026-07-09 16:23, PID under caffeinate; window 00:30-08:25): check kb-wiki/full-run-*.log + kb-wiki/batch-summary.json, random-sample cross-review, cost reconciliation; re-arm next evening if incomplete
- [ ] Abstract-only pages for the ~1,655 corpus papers without fulltext (lighter template, separate small batch)
- [ ] L0: physh-nuclear.yaml (176 concepts + neighbor whitelist [user input]) with FTS match rules; add negative filters against hep-ph/astro leakage (pilot finding)
- [ ] L1: run classification, write concept tags into page frontmatter + build 176 topic pages; hook monthly re-run into the corpus-update launchd job
- [ ] L2: within-corpus citation graph from raw .tex (needs KINGSTON mounted; fulfills literature-corpus Tier 2 cites/cited-by); add cites/cited-by links into paper pages
- [ ] 176 topic landscape syntheses (DeepSeek, after L1)
- [x] Distribution decision for kb-wiki: user decided 2026-07-10, pages live directly in the main repo (night-1 19,202 pages pushed in a1c4357; final ~250 MB, revisit only if GitHub complains)
- [ ] Licensing decision for the public artifact: abstracts included vs snippets vs fetch-on-first-run [user decision]
- [ ] Optional later: MCP server exposing kb_search/kb_browse (demoted from load-bearing to sugar, per 2026-07-09 revision)

## Phase 4: onboarding + distribution (wizard design: [onboarding-design.md](onboarding-design.md))

- [ ] `fusion init` wizard v1 (CLI): model+key test, PhySH area picker, kb-wiki slice mount, personal-wiki seeding from user's arXiv ids, skill recommendation with benchmark-on-install
- [ ] concept-skill-map.yaml (PhySH concept -> skills-catalog entries)
- [ ] Monthly personal digest loop (filter corpus updates by user concepts, greet on launch)
- [ ] install.sh: opencode binary + skill pack + kb-wiki + default config in one shot
- [ ] Default model config for CN users (domestic providers) and international users
- [ ] Student-facing docs (zh + en); wizard closing demo doubles as the tutorial
- [ ] Pilot with 2-3 group students; collect failures into devlog
- [ ] v2+: TUI popup wizard (plugin slots), ORCID/INSPIRE author lookup, group mode (advisor-curated shared config)

## Wiki ingest queue

(empty; no paper citations in the project yet)

## Completed

- [x] 2026-07-14: Phase 2 first per-code skill landed in-repo: `skills/fresco/` real self-contained copy (establishes skills/ layer) + binary auto-install (install_fresco.sh clones+builds I-Thompson/fresco when ~/bin/PATH lack it, run_fresco.sh auto-wires); gfortran build reproduces B1-elastic sigma_R = 1575.17495 (ref 1575.175). Codex cross-checked; caught the cp -R symlink trap (see devlog 2026-07-14), applied fixes #1/#12/#4/#16/#17
- [x] 2026-07-09: Phase 0 quality gate, all items: opencode 1.17.15 + DeepSeek/Qwen keys + 36 skills symlinked (pre-existing); 3 real-case tests vs Claude references (litsearch exact BibTeX; fresco 4-5 sig figs; prc-writing 10/10 verified citations); user verdict = proceed (phase0/report.md)
- [x] 2026-07-09: Phase 1 fork created: github.com/jinleiphys/fusion-core @ v1.17.16, default branch fusion-brand, dev = pristine upstream mirror
- [x] 2026-07-09: Phase 1 brand assets mapped; TUI logo patched ("FUSion" block glyphs + compact "fu" pulse logo, 3 glyph iterations with user screenshots); MIT notice untouched
- [x] 2026-07-09: Phase 1 CI weekly rebase (fusion-rebase.yml, Mondays 02:00 UTC) verified green on manual dispatch (run 29000283160)
- [x] 2026-07-09: Phase 3 design settled then revised same day: PhySH v2.8.0 (CC0) taxonomy, Nuclear subtree 176 concepts; wiki form changed from DB-rendered + digest-on-touch to pre-generated md (user decision; see devlog)
- [x] 2026-07-09: Phase 3 pilot: 500-paper digestion by DeepSeek via deepseek.md brief (500/500, $1.74, 9.5 min); Claude cross-review passed (structure 0 violations, no fabrication on calibration set, one new finding: raw cite-key leakage, fixed in template v2); merged kb-pilot into main (fa5ee32)
- [x] 2026-07-09: Template v2 (cite-key resolution, numeric-bullet rule, review-paper branch, reference-stripping before truncation) smoke-tested on 1812.11248; full-corpus list 61,059; off-peak launcher armed under caffeinate for tonight 00:30 (~$109 off-peak; user topping up 900 RMB)

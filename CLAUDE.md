@devlog.md

# FUSION: agent rules

One-sentence goal: build FUSION, a rebrand fork of opencode that ships nuclear-physics skills, per-code expert skills, and a self-contained 62k-paper knowledge base; full statement in [README.md#project-goal](README.md#project-goal).

## Hard rules

- **Never modify opencode functional code.** The fork touches brand assets only (logo ASCII art, name strings, icons, splash). Any domain feature goes in the customization layer: skills, agent definitions, MCP servers, opencode config. If a feature seems to need a core change, stop and discuss; that is a red flag, not a task.
- **Keep the brand patch minimal and rebasable.** One commit (or small series) on top of upstream; CI rebases weekly. If rebase conflicts grow, the patch is too big.
- **Skills follow the existing house style.** Reference implementation: `~/.claude/skills/fresco/SKILL.md` (per-code skill) and the other skills in `~/.claude/skills/`. Each per-code skill must include: install/build, input authoring, run, output parsing, and at least one benchmark case with a published reference value.
- **Knowledge base reuses literature-corpus.** Interface and constraints in `~/.claude/skills/literature-corpus/SKILL.md`. Do not build a parallel index; extend query.py / corpus.db (domain-keyword tag layer, MCP wrapper). Lexical BM25 stays the base; no pre-embedding of the full corpus (logged decision, see devlog).
- **Validation uses real cases, not synthetic evals.** Phase 0 gate: 3 skills ported to opencode + a domestic model, each judged on a real task the user has actually done, compared against Claude Code output.
- **No em-dashes** in any generated text, Chinese or English (this file included).
- **Do not ship the user's personal wiki.** ~/research-wiki and ~/research-wiki-personal are private. FUSION only defines the mount point.
- **Corpus redistribution is an open legal question** (arXiv non-exclusive license does not permit public full-text redistribution for most papers). Until resolved (see TODO Phase 3), any public artifact ships metadata + index-without-fulltext or a rebuild-from-arXiv script, never the raw .tex or full-text corpus.db.

## Key decisions

- 2026-07-09: rebrand fork (VSCodium model) over functional fork and over pure distribution; reasons in devlog entry of same date.
- 2026-07-09: knowledge base = literature-corpus stack (FTS5/BM25), domain-keyword partition added as a tag layer on top, not a new index.
- 2026-07-09: domain taxonomy = PhySH v2.8.0 (user's pointer; CC0, so shippable; Nuclear Physics subtree 176 concepts). Match rules live in physh-nuclear.yaml, lexical only.
- 2026-07-09: KB wiki is PRE-GENERATED markdown (papers/ + topics/), bulk-digested by DeepSeek; not DB-rendered, no load-bearing MCP server (user decision after measured cost ~$109 off-peak for 62k papers; see devlog 2026-07-09 pivot entry).
- 2026-07-09: bulk API jobs run in the DeepSeek off-peak window (00:30-08:30 Beijing, half price) via scripts/run_full_digest.sh: time-gated start, 08:25 hard stop, resume next night on skip-existing.
- 2026-07-09: DeepSeek data policy, three tiers (their API trains on inputs by default; opt-out exists): referee/others' manuscripts NEVER; user's own unpublished drafts only after account opt-out or per-case clearance; public/corpus content freely. Full statement in the deepseek-delegate skill.
- 2026-07-14: per-code skills are embedded as REAL copies under skills/ (use `cp -RL`, never a symlink that dies on clone) and auto-provision their binary (check ~/bin + PATH, else clone+build from the code's upstream, verify against a published anchor). fresco is the reference: skills/fresco/scripts/install_fresco.sh. The auto-install variant lives only in FUSION; the user's global /fresco skill stays pristine (see devlog 2026-07-14).
- 2026-07-15: kb-wiki gets a semantic relation layer (L3) of author-asserted typed links (extends/applies/uses/compares/contrasts) mined from citation context, NOT independent-judgment relations (those hallucinate at 61k scale; deferred as a gated experiment). It complements, does not replace, the private literature-wiki. Every typed edge carries an evidence snippet. Design in semantic-layer-design.md; tooling scripts/kb_relations.py.
- 2026-07-15: `contrasts` is only for disagreement with the cited TARGET itself; when the target is cited as evidence against a third party, it is `uses`. This distinction is load-bearing (it is the classifier's main overfire mode) and is baked into the kb_relations.py prompt.

## References Claude must know

- opencode repo: github.com/anomalyco/opencode (MIT). Customization docs before touching anything.
- `~/.claude/skills/literature-corpus/SKILL.md`: corpus interface, paths, update pipeline.
- `~/.claude/skills/fresco/SKILL.md`: the template every per-code skill imitates.

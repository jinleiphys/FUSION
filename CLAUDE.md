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

## References Claude must know

- opencode repo: github.com/anomalyco/opencode (MIT). Customization docs before touching anything.
- `~/.claude/skills/literature-corpus/SKILL.md`: corpus interface, paths, update pipeline.
- `~/.claude/skills/fresco/SKILL.md`: the template every per-code skill imitates.

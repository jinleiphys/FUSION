# literature-wiki

A cross-harness agent skill (**Claude Code** + **Codex CLI**) for maintaining a personal, persistent literature knowledge base as a structured markdown wiki — instead of re-RAGing the same PDFs on every question.

## What it does

You drop a paper into your wiki's `raw/` folder (or hand the agent a DOI/arXiv ID/URL), and the skill:

1. Reads the paper and surfaces 3–5 key takeaways for you to confirm.
2. Files a per-paper summary at `sources/<paper-id>.md` with key claims, numbers, and figures.
3. Updates 5–15 cross-cutting wiki pages (`entities/`, `methods/`, `systems/`, `observables/`, `debates/`).
4. Updates `index.md` and appends to `log.md`.
5. Flags any contradiction with previously-filed sources.

You can later **query** the wiki ("what does my wiki say about X?"), and the skill synthesizes across pages with provenance. You can also **lint** for orphans, stale claims, contradictions, and gaps.

The pattern this implements is described in Andrej Karpathy's [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) gist: **the wiki is a persistent compounding artifact**, not a transient RAG retrieval. Cross-references and synthesis built up over months don't have to be rediscovered every query. This skill is one concrete instantiation, scoped to scientific literature, and wired for both Claude Code and Codex.

## Why this is different from RAG

Standard RAG: every question re-finds and re-stitches fragments from raw documents. Nothing accumulates.

This skill: knowledge is compiled once into a structured wiki, then *kept current* as new sources arrive. By month six you have a knowledge artifact that answers questions RAG can't, like "where do my sources contradict each other?" or "which entities are mentioned across papers but lack their own page?".

It scales well at moderate size (~hundreds of sources, low thousands of pages) without embeddings or vector DBs — `index.md` plus markdown grep is enough. Bolt on a search tool ([qmd](https://github.com/tobi/qmd) is good) only when you outgrow that.

## What v2 added

Schema v2 (current) layers controlled vocabulary and tag-driven indexing on top of v1's link-graph structure. v1 had concept pages (`methods/<slug>.md`, etc.) with hand-curated prose, but the cross-paper relationships hid in prose and degraded as the wiki grew. v2 fixes that with:

v2.1 adds the source-page gist: every sources/*.md opens with a `## For future agents` preamble (2-3 sentences, key number included) so query can triage pages in one read. Borrowed from obsidian-second-brain's AI-first vault rule.

- **Controlled vocabulary** in `<wiki>/CLAUDE.md` (four axes: entities / methods / systems / observables) with aliases and parent relationships. Tag drift is the silent killer at scale.
- **Tag fields in source frontmatter** — every paper page now declares its method/system/observable/entity tags using vocabulary slugs.
- **`update-index` operation** — auto-regenerates a "Papers using this <axis>" appendix on each concept page (`methods/<slug>.md`, etc.) by scanning all source frontmatter. Manual prose at the top is preserved; the AUTO block is rewritten between `<!-- AUTO:BEGIN -->` / `<!-- AUTO:END -->` markers.
- **`migrate` operation** — interactive walk that backfills tag fields and AUTO markers on a v1 wiki.

Cross-skill alignment with research-profile: the methods/systems/observables vocabularies should share slugs with research-profile's vocabulary. A single `~/research-vocabulary.yml` can be `include:`d from both wikis.

If you have a v1 wiki, run `migrate` once. If you are starting fresh, `init` ships v2 directly.

## File layout

```
literature-wiki/
├── SKILL.md          # canonical body — Claude Code entry (with YAML frontmatter)
├── AGENTS.md         # canonical body — Codex CLI entry (no frontmatter, Codex-flavored)
├── README.md         # this file
└── templates/
    └── CLAUDE.md     # vocabulary starter — four axes with example entries
```

`SKILL.md` and `AGENTS.md` mirror each other. They are kept in sync by hand because Codex does not support markdown imports yet (open issue [openai/codex#17401](https://github.com/openai/codex/issues/17401)). If you contribute, edit both.

## Install

### On Claude Code

```bash
# Project-local (this project only):
cp -r literature-wiki/ <your-project>/.claude/skills/

# Or user-level (every Claude Code session):
cp -r literature-wiki/ ~/.claude/skills/
```

The skill triggers automatically when the user says one of the trigger phrases listed in `SKILL.md`'s frontmatter description.

### On Codex CLI

Codex loads `AGENTS.md` files via filesystem walk + concatenation (no import directive). Two install patterns:

**Pattern A: global install (every Codex session, all projects)**
```bash
# Append this skill's AGENTS.md content to your global Codex doc:
cat path/to/literature-wiki/AGENTS.md >> ~/.codex/AGENTS.md
```

**Pattern B: project-local install (single project)**
```bash
# Append to the project's AGENTS.md:
cat path/to/literature-wiki/AGENTS.md >> <your-project>/AGENTS.md
```

If your combined AGENTS.md exceeds the 32 KiB default cap, raise it in `~/.codex/config.toml`:

```toml
project_doc_max_bytes = 65536
```

After install, the skill is active whenever Codex sees the matching trigger phrases. No per-skill activation step.

### Optional: Obsidian for browsing

Install [Obsidian](https://obsidian.md/) and open the wiki directory as a vault. Graph view, backlinks, and `[[wikilinks]]` rendering all work without configuration.

## Configuration

The skill picks the wiki location in this order on both harnesses:

1. `LITERATURE_WIKI_PATH` env var.
2. Single-line absolute path in `~/.literature-wiki-path`.
3. Default: `~/research-wiki/`.

On first use, ask the agent to set up the wiki. It will confirm the path before creating directories.

## Customizing for your field

The default category names — `entities/`, `methods/`, `systems/`, `observables/` — are tuned for physical-science research. If your field needs different axes, rename them in your wiki's `CLAUDE.md` / `AGENTS.md`:

| Field example | Suggested categories |
|---|---|
| Physics / chemistry | entities, methods, systems, observables |
| ML research | datasets, methods, models, benchmarks |
| Biology | organisms, mechanisms, pathways, assays |
| History | actors, events, sources, debates |
| Law | parties, doctrines, cases, statutes |

The skill reads `<wiki>/CLAUDE.md` (Claude Code) or `<wiki>/AGENTS.md` (Codex) on every invocation and respects whatever categorization you settle on. The skill body itself is field-agnostic.

## Quick start

```
> ingest this paper for me: arxiv:2401.12345
```

The agent fetches it (via your literature-search skill if installed, otherwise its own web tools), surfaces takeaways, proposes page updates, files the source, and updates cross-cutting pages.

```
> what does my wiki say about <topic>?
```

The agent reads `index.md`, drills into relevant pages, and synthesizes with citations to your existing wiki pages.

```
> lint the wiki
```

The agent produces a health report: orphans, contradictions, stale claims, missing pages.

## Companion skills

Most useful paired with:

- A **literature-search** skill (database fetcher with anti-hallucination protocol) — provides the source material this skill files away.
- A **research-profile** skill — your *personal* research record; cross-link your own papers into this field-level wiki via markdown links.
- Any **paper-writing** skill — should query this wiki when building related-work sections.

## Author and credit

Skill author: **Jin Lei**. Released under MIT-equivalent terms ("use freely, no warranty").

The underlying **LLM Wiki pattern is by Andrej Karpathy** (gist: `karpathy/442a6bf555914893e9891c11519de94f`). The original gist explicitly mentions both Claude Code and Codex as targets; this skill is one concrete cross-harness implementation. Credit for the original idea belongs upstream.

## Status

Vibe-tested. No formal eval suite yet. PRs welcome — especially for evals, non-physics field defaults, or schema variants.

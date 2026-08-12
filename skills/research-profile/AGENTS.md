# Research Profile — Codex CLI entry (Schema v2)

This is the **Codex CLI** entry for the research-profile skill. The Claude Code entry is `SKILL.md` next to this file. The two carry the same operational protocol; this file is a CONDENSED mirror that is self-sufficient for day-to-day operations (Codex does not support markdown imports, [openai/codex#17401](https://github.com/openai/codex/issues/17401)), while SKILL.md holds the extended per-page schema detail; read it via the file-read tool when the condensed schema is not enough. If you edit one, mirror to the other.

**Schema v2 (current)** introduces controlled vocabulary, tag-driven indexing, AUTO-marker profile sections, and an explicit `migrate` path from v1. **v2.1** adds bi-temporal `timeline:` frontmatter for tracked facts that change over time (see below); pages adopt it lazily, on the first change to a tracked fact.

## When to act

Activate when the user says any of:

- "记一下我做的" / "加进我的研究档案" / "我有个新研究 idea" / "这次没 work, 记一下"
- "我做过什么" / "我之前做过 X 吗" / "更新我的 profile"
- "log this project" / "add to my portfolio" / "what have I worked on" / "snapshot my research"

**PRECEDENCE**: if the user wants forward paths on a stuck research problem (brainstorming, "what should I try next") rather than a *record* of what they have done, do not activate this protocol — respond as a forward-thinking advisor instead. If the user is describing a game concept, this is not the right protocol.

## Why this skill exists

Memory of "what the user has worked on" should be a curated, persistent, **machine-queryable** artifact that:

1. Auto-loads into every new agent session, so the assistant starts with full context.
2. Captures **failures with reasons** — research's most common scarring is doing the same dead-end twice.
3. Makes cross-cutting queries cheap. "What have I done on topic X?" is a one-read answer through tag-driven indices.

This is the **factual record**, not a personality simulator.

## Wiki location

Resolution order:

1. `RESEARCH_PROFILE_PATH` env var.
2. `~/.research-profile-path` (single line, absolute).
3. Default: `~/research-wiki-personal/`.

Private. Treat with notebook-grade care. Local + private remote git repo recommended. Ask before creating if absent.

## The auto-load mechanism (Codex)

Codex does not support `@import`. Use Codex's documented global agent doc directly:

**Recommended (global, every Codex session):**

```bash
ln -sfn <wiki>/profile.md ~/.codex/AGENTS.md
```

If `~/.codex/AGENTS.md` already has content, merge it into profile.md's "Working preferences" section first. Per-project alternative: `cd <project> && ln -sfn <wiki>/profile.md AGENTS.md` (shadows project AGENTS.md; better privacy if you have many non-research projects).

`project_doc_fallback_filenames` does NOT work for `~/.codex/profile.md`. Verified against [Codex docs](https://developers.openai.com/codex/guides/agents-md) and [source](https://github.com/openai/codex/blob/main/codex-rs/core/src/project_doc.rs).

## Controlled vocabulary (the v2 contract)

Tag drift breaks indexing. All tag values come from a controlled vocabulary in `<wiki>/CLAUDE.md` (or `<wiki>/AGENTS.md`, whichever your harness reads). Six axes:

| Axis | Examples |
|---|---|
| `methods` | `cdcc`, `iav-cdcc`, `monte-carlo`, `ab-initio` |
| `observables` | `breakup-cs`, `fusion-suppression-factor`, `polarization` |
| `codes` | `fresco`, `ncsm`, `julia-nucleartoolkit` |
| `topics` | `icf`, `cf-suppression`, `weakly-bound`, `halo-nuclei` |
| `systems` | `d+93Nb`, `6Li+209Bi`, `11Li` |
| `collaborators` | `moro`, `phillips`, `furnstahl` |

### Vocabulary file format

```yaml
vocabulary:
  methods:
    cdcc:
      canonical: "Continuum-Discretized Coupled Channels"
      aliases: [CDCC, "continuum-discretized"]
    iav-cdcc:
      canonical: "Ichimura-Austern-Vincent CDCC"
      aliases: [IAV-CDCC]
      parent: cdcc
  topics:
    icf:
      canonical: "Incomplete fusion"
      aliases: [ICF, 不完全融合]
```

`canonical` is required. `aliases` (optional) are normalized to slug at `log` time; case-insensitive, multi-language. `parent` (optional) propagates: a page tagged `iav-cdcc` is auto-included in `cdcc` indices.

### Vocabulary discipline

When tagging during `log`:

1. Look up each candidate against the vocabulary (case-insensitive, alias-aware).
2. Known: use canonical slug.
3. Unknown: STOP and propose a vocab diff with definition + suggested aliases. Apply only after explicit user approval.

**Never invent a tag silently.** Cost of stop-and-ask is small; cost of polluted vocabulary compounds for years.

Reserved slug `uncategorized` exists across all axes for genuinely-novel content. `lint` warns if uncategorized usage exceeds 30%.

## Wiki layout

```
<wiki>/
├── CLAUDE.md / AGENTS.md      # vocabulary + style overrides
├── profile.md                 # ⭐ auto-loaded one-pager (AUTO + manual sections)
├── index.md                   # navigation hub
├── log.md
├── projects/{active,paused,done}/
├── papers/{published,submitted,drafts,rejected}/
│   └── *.md + *.private.md    # public + private companion (always paired)
├── ideas/{promising,parked,killed}/
├── methods-mine/  failures/  collaborators/
├── talks/  reviews/  snapshots/  funding/
└── index/                     # ⭐ AUTO-generated by update-index
    ├── by-method/<slug>.md
    ├── by-observable/<slug>.md
    ├── by-codes/<slug>.md
    ├── by-topic/<slug>.md     ← also serves as research-line page
    ├── by-system/<slug>.md
    └── by-collaborator/<slug>.md
```

`index/by-topic/<topic>.md` and `by-method/<method>.md` doubly serve as **research-line pages** (manual preamble + AUTO body). No separate `lines/` page type — a topic with 3+ papers IS a research line.

## Common frontmatter

```yaml
---
type: project | paper | idea | failure | method | collaborator | talk | review | funding
status: <type-specific>
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
sensitivity: public | private | embargoed
methods: []
observables: []
codes: []
topics: []
systems: []
collaborators: []
predecessor: [[other-page]]
successor: [[other-page]]
companion: [[other-page]]
featured: false
literature: [[../research-wiki/methods/<slug>]]

# Bi-temporal history (v2.1; append-only; omit until a tracked fact first changes)
timeline:
  - fact: "what was true"
    from: YYYY-MM-DD            # event time: when it became true
    until: YYYY-MM-DD | present
    learned: YYYY-MM-DD         # transaction time: when the wiki learned it
    source: "user 2026-05-19 | [[log.md entry]] | email | referee report"
---
```

### Bi-temporal facts (v2.1)

When a tracked fact on an existing page changes (collaborator role / institution / retirement, paper status or revision stance, method maintenance status, project state): never overwrite-only, never record it only as a prose patch. Top-level frontmatter always reflects the CURRENT state; the history goes into append-only `timeline:` with event time (`from`/`until`), transaction time (`learned`), and `source:` provenance. **`fact` is written as `key: value`** (e.g. `"status: submitted"`, `"institution: SCNT"`, `"revision_stance: multi-gpu accepted"`) so lint can group fact families mechanically; approximate dates carry an inline `# approx` comment, never fabricated precision. On the first change to a page without a `timeline:`, create it with TWO entries (reconstructed old state + new state). Prose may still narrate the story; the timeline entry is the queryable record. Why bi-temporal: distinguishes fact-changed from contradiction, answers "what did I believe when, and why did it change", survives profile refreshes. (Pattern borrowed from obsidian-second-brain.)

## Per-page schemas (highlights — see SKILL.md for full)

### project (active | paused | done)
Required body: `## Goal`, `## Methods used`, `## Current state`, `## Code/repo` (absolute paths with server), `## Collaborators`, `## Related literature`.

### paper (v2 — major change)
ALWAYS paired with `<slug>.private.md`. Frontmatter extras: `title`, `authors`, `submitted/first_decision/accepted/published`, `doi`, `arxiv`, `venue`. Required body sections (filter: "if reconstructable from abstract a year later, drop it"):

1. `## Key claim` — DEEPER than the abstract; the qualifier the abstract glossed over.
2. `## My contribution` — CRediT-style: Conceptualization / Methodology / Software / Formal analysis / Writing — original / Writing — review. Each "Lead | Equal | Contributing | Not involved", responsible co-author named.
3. `## Code and data location` — absolute paths including server (`heliumx:/scratch/jin/...`).
4. `## Lineage` — prose narrative of how this extends predecessor.
5. `## Key numbers worth remembering` — specific values + context.
6. `## What I'd do differently now` — future-self letter.

### paper.private (always paired)
`papers/<status>/<slug>.private.md`. `sensitivity: embargoed`. Optional sections: `## Reviewer N`, `## Response drafts`, `## Internal correspondence`, `## Co-author disagreements`. Cross-link from public via `See [[<slug>.private]] for embargoed material.` Never auto-quoted to outputs that could leak.

### idea
Required body: `## Seed thought`, one of `## Why promising | parked | killed` (matching status), `## What would unblock it`, `## Relevant literature`. Killed ideas MUST include `## Why killed` — highest-value AI context.

### failure
Required body: `## What was tried`, `## Why it should have worked`, `## What actually happened`, `## What was ruled out`, `## Conditions that might revive it`. Tag axes mandatory (at least method + topic + system).

### method (mine)
`methods-mine/<slug>.md`. Frontmatter: `language`, `code_repo`, `license`. Body: `## What it does`, `## Key API surface`, `## Gotchas`, `## Papers using it`.

### collaborator / talk / review / funding
Compact schemas, same shape as v1 with tag axes added. See SKILL.md for full body sections. Collaborator role / institution / retirement changes append a `timeline:` entry (bi-temporal rule), never overwrite-only.

## Operations

### 1. `init`
Privileged-write, gated. Steps: resolve path → create skeleton (copy `templates/profile.md`, `templates/.gitignore`, `templates/CLAUDE.md`, run `git init`) → wire auto-load (Codex symlink with idempotency check; both harnesses if present) → idempotent re-init → recommend next.

### 2. `log`
**For type=paper, FIRST split**: ask "your paper or one you read?" (cache for session). If "one you read", HAND OFF to literature-wiki and write a thin stub (only if user opts in) cross-linking to `research-wiki/sources/<paper-id>.md`.

For other types or "your paper":

1. Identify type, ask once if ambiguous.
2. **Vocabulary check** for tag axes the user mentioned. Unknown tags → propose vocab diff first.
3. Create page with required frontmatter and body sections per schema. If the page already EXISTS: read its current frontmatter FIRST and run the bi-temporal check (step 5) before writing anything.
4. For papers: ALWAYS create the `<slug>.private.md` companion stub.
5. **Bi-temporal check**: if updating an EXISTING page and a tracked fact flips (status, role, institution, venue decision, revision stance), append a `timeline:` entry and set top-level frontmatter to the new current state.
6. Append to `log.md`.
7. Update `index.md`.
8. Trigger `update-index`.
9. Ask if `profile.md` should refresh (yes if "Affects profile.md" applies).

### 3. `update-profile`
profile.md has AUTO blocks (rewritten) and manual blocks (untouched). Markers:

```markdown
<!-- AUTO:BEGIN active-research-lines -->
<!-- AUTO:END -->
<!-- AUTO:BEGIN recent-publications -->
<!-- AUTO:END -->
<!-- AUTO:BEGIN in-submission -->
<!-- AUTO:END -->
<!-- AUTO:BEGIN methods-i-own -->
<!-- AUTO:END -->
<!-- AUTO:BEGIN dead-ends -->
<!-- AUTO:END -->
```

**Active-research-lines algorithm**: for each topic / method tag, collect pages with status=active OR published in last 36 months. If count ≥ 3 AND any updated in last 12 months → line is active. Sort desc by latest update, take top 5. `featured=true` overrides.

**Recent-publications**: `papers/published/*` with `published` date in last 24 months, sorted desc.

**In-submission**: `papers/submitted/*` (all) plus `papers/drafts/*` naming an intended venue, sorted by `submitted:` desc (undated last).

**Methods-i-own**: `methods-mine/*` with status=active OR maintained.

**Dead-ends**: `failures/*` sorted by `last_updated` desc, top 5, with "Why X did not work" excerpt.

Flow: compute → locate markers → warn if hand edits inside AUTO → atomic replace → show diff → save on confirm.

### 4. `update-index`
Auto after `log`/`update-profile`/`migrate`; after `lint` only once the user approves the lint fixes (lint stays read-only). Always idempotent.

1. Walk all pages, read frontmatter only.
2. Build axis → tag → pages map. Apply `parent:` propagation.
3. For each (axis, tag), write `<wiki>/index/by-<axis>/<tag>.md` with format:

```markdown
# <Canonical name from vocab>

<!-- MANUAL preamble (preserved across runs) -->

<!-- AUTO:BEGIN -->
## Papers (N)
- [YYYY] *Title* — Key claim excerpt. → [[../../papers/published/<slug>]]
  Cross-tags: methods=[…], topics=[…], systems=[…]

## Failures (N)
## Open ideas (N)
## Methods I own (N)
<!-- AUTO:END -->
```

4. Skip embargoed pages from indices.
5. Delete `<axis>/<tag>.md` whose tag has zero pages.
6. Report changes.

### 5. `snapshot`
Read-only synthesis grouped by year. Optional save to `snapshots/YYYY-MM-DD-<scope>.md`.

### 6. `lint`
Stale active projects, long-pending submissions, stagnant ideas, profile staleness, missing schema sections, **vocabulary integrity** (off-vocab tags, unused vocab entries, uncategorized > 30%), **AUTO marker integrity**, **cross-link validity**, **lineage cycles**, **timeline integrity** (entries missing `learned`/`source`; latest `until: present` entry contradicting top-level current-state fields; overlapping ranges for the same fact family).

### 7. `migrate` — v1 → v2

For wikis built before v2:
1. Walk all pages, identify missing v2 fields.
2. For each gap, propose values from page content; user confirms / corrects.
3. Create missing `.private.md` companions for papers (empty stubs).
4. Append migration to `log.md`.
5. Run `update-index` once at the end.

Interactive and slow by design — user must validate each tag application.

## Working principles

- **Privacy and the model round-trip.** profile.md content is sent on every session. Keep it free of embargoed specifics; subpages with `sensitivity: embargoed` are never auto-quoted.
- **Capture, don't curate, on the way in.** Polish on `update-profile`.
- **Failures are first-class.** Same tag axes as papers; auto-index treats them as equal-rank entries.
- **Controlled vocabulary is a contract.** Never invent tags silently.
- **Frontmatter is the index, body is the narrative.**
- **Cross-link into the literature-wiki** when it exists.

## Cross-skill hand-off with literature-wiki

When the user reads a paper related to their own work:
1. The paper goes to literature-wiki (`research-wiki/sources/<paper-id>.md`).
2. If it informs an active project / idea / failure here, add `literature: [[../research-wiki/sources/<paper-id>]]` to that page's frontmatter + a one-sentence body note on relevance.
3. Method slugs should match across both wikis. Optional: a single `~/research-vocabulary.yml` symlinked into both `<personal-wiki>/CLAUDE.md` and `<literature-wiki>/CLAUDE.md`.

When the user logs their own paper using a method documented in literature-wiki:
1. Tag the page with method slug.
2. Add `literature: [[../research-wiki/methods/<slug>]]` to frontmatter.
3. The auto-index `<personal-wiki>/index/by-method/<slug>.md` adds a "See also: literature-wiki definition" line at the top.

## Codex install notes

The auto-load wiring above takes `~/.codex/AGENTS.md` for profile.md (via symlink). The skill protocol body (this AGENTS.md) is a separate concern. Two patterns:

- **Per-project install (recommended):** `cat /path/to/skills/research-profile/AGENTS.md >> <project>/AGENTS.md`. Skill protocol loads in that project alongside profile.md (separate file, both walked).
- **On-demand:** keep this AGENTS.md at the skill repo path; add a one-liner to profile.md's "Skills available" pointing at it. Codex reads on demand via file-read tool. Lower-token-budget option.

`project_doc_max_bytes` default is 32 KiB; raise in `~/.codex/config.toml` if needed:

```toml
project_doc_max_bytes = 65536
```

Codex has no skill-trigger mechanism. The "When to act" rules above shape Codex behavior in absence of explicit slash-commands.

## Templates shipped

- `templates/profile.md` — auto-loaded one-pager starter (with AUTO markers).
- `templates/CLAUDE.md` — vocabulary starter with empty axes + example entries.
- `templates/.gitignore` — privacy default.
- `templates/pre-commit-hook.sh` — optional Git pre-commit guard.

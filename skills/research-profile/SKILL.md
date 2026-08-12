---
name: research-profile
description: >-
  Maintain the user's personal research portfolio wiki at ~/research-wiki-personal/, including projects, papers, ideas, failures, methods, collaborators, talks, reviews, funding, profile refreshes, and CV snapshots. Use to record a project, log a paper, capture an idea, document a failed attempt, update collaborator notes, or snapshot research history. Trigger on 记一下我做的, 加进我的研究档案, 新研究 idea, 这次没 work, 更新我的 profile, log this project, add to my portfolio, what have I worked on, snapshot my research. For paper-content notes use literature-wiki instead.
---

# Research Profile Maintenance (Schema v2)

This file is the canonical operational protocol. It is harness-neutral. The skill ships parallel `SKILL.md` (Claude Code entry) and `AGENTS.md` (Codex CLI entry) bodies that mirror each other; if you edit one, edit the other.

**Schema v2 (current)** introduces controlled vocabulary, tag-driven indexing, AUTO-marker profile sections, and an explicit `migrate` path from v1. See [Migration from v1](#7-migrate--bring-existing-pages-up-to-current-schema) below if you have a v1 wiki.

**v2.1 addition**: bi-temporal `timeline:` frontmatter for tracked facts that change over time (see "Bi-temporal facts" below). Existing pages adopt it lazily, on the first change to a tracked fact.

## Why this skill exists

Memory of "what the user has worked on" should not live only in the user's head and in scattered drafts. It should be a curated, persistent, **machine-queryable** artifact that:

1. Auto-loads into every new agent session, so the assistant starts with full context.
2. Captures **failures with reasons** — research's most common scarring is doing the same dead-end twice. The wiki remembers so the user doesn't have to.
3. Makes cross-cutting queries cheap. "What have I done on topic X?" should not require manual grep across years of notes; tag-driven indices answer it in one read.

This is the **factual record** of what the user has done, not a personality simulator.

## Wiki location

Resolution order on every invocation:

1. `RESEARCH_PROFILE_PATH` env var.
2. `~/.research-profile-path` (single-line absolute path).
3. Default: `~/research-wiki-personal/`.

This wiki is **private**. Treat the path with notebook-grade care. Recommend a local + private remote git repo. If the directory does not exist, ask before creating.

## The auto-load mechanism

The single most important file is `<wiki>/profile.md` — a one-page summary structured to fit in <2k tokens. It is auto-loaded into every session via your harness's documented mechanism.

### On Claude Code (uses `@import`)

1. Append `@<wiki>/profile.md` (absolute path) to `~/.claude/CLAUDE.md` (user-level) or `<project>/CLAUDE.md` (project-scoped).
2. First import shows an external-import approval dialog; approve once.
3. Every new session in scope has profile.md content at session start.

### On Codex CLI (uses `~/.codex/AGENTS.md` symlink)

Codex does not support `@import` ([openai/codex#17401](https://github.com/openai/codex/issues/17401)). Use Codex's documented global agent doc directly:

```bash
ln -sfn <wiki>/profile.md ~/.codex/AGENTS.md
```

If `~/.codex/AGENTS.md` already has content, merge it into profile.md's "Working preferences" section first, then symlink. Per-project alternative: `cd <project> && ln -sfn <wiki>/profile.md AGENTS.md`.

`project_doc_fallback_filenames` does NOT work for `~/.codex/profile.md` — that mechanism only walks the project tree, never `~/.codex/`. The `~/.codex/AGENTS.md` symlink is the only reliable global path.

## Controlled vocabulary (the v2 contract)

Tag drift breaks indexing. To prevent it, all tag values come from a controlled vocabulary stored in `<wiki>/CLAUDE.md` (the per-wiki schema file the skill respects). The vocabulary defines six axes:

| Axis | What it tracks | Examples |
|---|---|---|
| `methods` | analytical / numerical / experimental methods | `cdcc`, `iav-cdcc`, `monte-carlo`, `ab-initio` |
| `observables` | physical quantities computed or measured | `breakup-cs`, `fusion-suppression-factor`, `polarization` |
| `codes` | code packages used | `fresco`, `ncsm`, `julia-nucleartoolkit` |
| `topics` | physics themes / open questions | `icf`, `cf-suppression`, `weakly-bound`, `halo-nuclei` |
| `systems` | specific reactions or nuclei | `d+93Nb`, `6Li+209Bi`, `11Li` |
| `collaborators` | people the user works with | `moro`, `phillips`, `furnstahl` |

### Vocabulary file format

Each axis is a YAML map of `slug → entry`:

```yaml
vocabulary:
  methods:
    cdcc:
      canonical: "Continuum-Discretized Coupled Channels"
      aliases: [CDCC, "continuum-discretized", "continuum discretized coupled channels"]
    iav-cdcc:
      canonical: "Ichimura-Austern-Vincent CDCC for transfer/breakup"
      aliases: [IAV-CDCC, "IAV CDCC"]
      parent: cdcc           # iav-cdcc IMPLIES cdcc; index propagates upward
  topics:
    icf:
      canonical: "Incomplete fusion"
      aliases: [ICF, 不完全融合]
  ...
```

- `canonical` — human-readable name. Required.
- `aliases` — alternate spellings (case-insensitive, multi-language). The agent normalizes any alias to the slug. Optional.
- `parent` — hierarchical inclusion. A page tagged with the child slug is auto-included in indices for the parent. Optional.

A starter `templates/CLAUDE.md` ships with the skill; copy it to `<wiki>/CLAUDE.md` on `init` and grow as papers are added.

### Vocabulary discipline

When the agent adds tags during any `log` operation:

1. **Look up** each candidate value against the vocabulary file. Use case-insensitive alias-aware matching.
2. **If known**: use the canonical slug (NOT the user's spelling).
3. **If unknown**: STOP. Propose a vocabulary diff to the user with a definition and suggested aliases. Apply only after explicit approval. Then update the page.

This is non-negotiable. **Never invent a tag silently.** The cost of a stop-and-ask is small; the cost of a polluted vocabulary compounds for years.

Escape hatch: an `uncategorized` slug is reserved across all axes for genuinely-novel content where the user wants to defer categorization. `lint` will report when uncategorized usage exceeds 30% of any axis (signal that taxonomy needs work).

## Wiki layout

```
<wiki>/
├── CLAUDE.md / AGENTS.md      # ⭐ vocabulary + per-wiki style overrides
├── profile.md                 # ⭐ auto-loaded one-pager (AUTO + manual sections)
├── index.md                   # navigation hub (manual; links into index/ tree)
├── log.md                     # chronological append-only log
├── projects/{active,paused,done}/
├── papers/{published,submitted,drafts,rejected}/
│   └── *.md + *.private.md    # ALWAYS paired: public stub + private companion
├── ideas/{promising,parked,killed}/
├── methods-mine/
├── failures/                  # ⭐ what didn't work and why
├── collaborators/
├── talks/  reviews/  snapshots/  funding/
└── index/                     # ⭐ AUTO-generated by update-index, do not hand-edit AUTO blocks
    ├── by-method/<slug>.md
    ├── by-observable/<slug>.md
    ├── by-codes/<slug>.md
    ├── by-topic/<slug>.md     ← also serves as your "research line" page
    ├── by-system/<slug>.md
    └── by-collaborator/<slug>.md
```

**Important**: `index/by-topic/<topic>.md` and `index/by-method/<method>.md` doubly serve as **research-line pages**. They have a hand-written preamble (motivation, key insight, current state, "is this line still alive?") above the AUTO block, which lists papers / ideas / failures / methods carrying that tag. There is no separate `lines/` page type — a topic that has 3+ papers IS a research line.

## Common frontmatter

Every non-profile page carries:

```yaml
---
type: project | paper | idea | failure | method | collaborator | talk | review | funding
status: <type-specific; see per-page schemas>
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
sensitivity: public | private | embargoed   # default private

# Tag axes (use vocabulary canonical slugs only; ask before adding new vocab)
methods: []
observables: []
codes: []
topics: []
systems: []
collaborators: []

# Lineage (papers / projects / ideas; optional otherwise)
predecessor: [[other-page]]
successor: [[other-page]]
companion: [[other-page]]

# Profile featuring (optional override)
featured: false   # if true, force this onto profile.md regardless of activity heuristics

# Cross-link into literature-wiki (when relevant)
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

When a tracked fact on an existing page changes, never overwrite it and never record the change only as a prose patch. Tracked facts are the ones that flip over a career: collaborator role / institution / retirement, paper status and revision stance, method maintenance status, project state.

Rules:

1. **Top-level frontmatter always reflects the CURRENT state** (`status:`, `role:`, `institution:`, ...). Queries against current state stay one-field cheap.
2. **The history goes into `timeline:`**, append-only, with both event time (`from`/`until`) and transaction time (`learned`) plus `source:` provenance. **`fact` is written as `key: value`** (e.g. `"status: submitted"`, `"institution: SCNT"`, `"revision_stance: multi-gpu accepted"`) so lint can group entries into fact families mechanically instead of guessing from free text. Approximate dates carry an inline `# approx` comment; never fabricate precision.
3. On the first change to a page that has no `timeline:` yet, create the block with TWO entries: the old state (reconstruct `from` as well as you can; `learned` may be the page's `created` date) and the new one.
4. Prose may still narrate the change (the "story" belongs in the body), but the timeline entry is the queryable record, not the prose.

Why bi-temporal: it distinguishes "the fact changed" from "two pages contradict each other" (different facts at different times are not a contradiction), it answers "what did I believe when, and why did it change" (e.g. a revision stance reversed after a referee round), and it survives profile refreshes that rewrite prose. (Pattern borrowed from obsidian-second-brain's bi-temporal facts rule.)

## Per-page schemas

### project (active | paused | done)

- Path: `projects/<status>/<slug>.md`
- Frontmatter: common + tag axes
- Required body:
  - `## Goal` — one paragraph
  - `## Methods used` — links to vocabulary slugs and `methods-mine/`
  - `## Current state` — what works, what doesn't, what's blocking
  - `## Code/repo` — absolute paths, including server (e.g. `heliumx:/scratch/jin/...`)
  - `## Collaborators` — slugs (vocabulary-controlled) + role each
  - `## Related literature` — links to `research-wiki/sources/` if literature-wiki installed
- Affects profile.md: yes if status=active OR featured=true.

### paper (published | submitted | drafts | rejected) — schema v2

The paper schema is the most-revised in v2. Key principle: **if a section can be reconstructed from the abstract a year from now, do not include it**. The wiki page captures what the abstract cannot.

- Path: `papers/<status>/<slug>.md` (public, safe to commit) **paired with** `papers/<status>/<slug>.private.md` (always created, gitignored by `*.private.md`).
- Frontmatter (paper-specific extras on top of common):
  - `title:`, `authors: [list, lead first]`
  - `submitted:` `first_decision:` `accepted:` `published:` (YYYY-MM-DD; optional per state)
  - `doi:`, `arxiv:`, `venue:`
  - tag axes (mandatory — at least one method, one topic, one system)
  - `predecessor:` / `companion:` / `successor:` lineage links
- Required body sections in `<slug>.md` (public):
  1. **`## Key claim`** — one sentence DEEPER than the abstract. The abstract has the claim; this is the claim with the actual hedge or qualifier the abstract glossed over.
  2. **`## My contribution`** — CRediT-style breakdown. Required structure: Conceptualization / Methodology / Software / Formal analysis / Writing — original draft / Writing — review. Mark each as "Lead | Equal | Contributing | Not involved" with the responsible co-author named for the lead-other items.
  3. **`## Code and data location`** — absolute paths including server hostname (e.g. `heliumx:/scratch/jin/cdcc-19/run42/`). Future-you will need this within 18 months.
  4. **`## Lineage`** — prose narrative of how this paper extends predecessor and what the next step is. Frontmatter has the links; body has the story.
  5. **`## Key numbers worth remembering`** — specific numerical results with their context (e.g. "epsilon = 0.27 ± 0.03 at Ec.m. = 38 MeV; matches m_pi/Lambda_chi = 0.28 (Sec. III.B)").
  6. **`## What I'd do differently now`** — future-self letter. Often becomes the seed of the successor paper.
- `<slug>.private.md` (companion, embargoed): see schema below.
- Affects profile.md: yes if status=published (last 24 months) OR status=submitted OR featured=true.

### paper.private (always create alongside paper)

- Path: `papers/<status>/<slug>.private.md`
- Frontmatter: `sensitivity: embargoed`, `paper: [[<slug>]]`
- Optional body sections (write as needed; the file slot is always created on `log paper`):
  - `## Reviewer N` — incoming reports, with date, journal, decision, verbatim quotes
  - `## Response drafts` — your reply text in progress
  - `## Internal correspondence` — slack/email summaries with co-authors about the paper
  - `## Co-author disagreements` — frank notes, who pushed back on what
- The public `<slug>.md` should cross-link with: `See [[<slug>.private]] for embargoed material.`
- **Never auto-quoted** to outputs that could leak (chat with non-private MCPs, public artifacts) without explicit user OK.

### idea (promising | parked | killed)

- Path: `ideas/<status>/<slug>.md`
- Frontmatter: common + tag axes
- Required body:
  - `## Seed thought` — what triggered it
  - One of `## Why promising` | `## Why parked` | `## Why killed` (matching status)
  - `## What would unblock it` (for promising/parked)
  - `## Relevant literature` — links into research-wiki when applicable
- **Killed ideas MUST include `## Why killed`** with concrete reason. Highest-value field for AI context: it prevents the agent from suggesting paths the user has already burned.
- Affects profile.md: killed ideas are surfaced under the auto "Strong opinions / dead ends" section; promising ideas surface only if `featured=true`.

### failure

- Path: `failures/<slug>.md`
- Frontmatter: common + tag axes (mandatory at least one method, one topic, one system — failures need to be findable by the same axes as papers)
- Required body:
  - `## What was tried`
  - `## Why it should have worked` — your prior belief
  - `## What actually happened` — observation
  - `## What was ruled out` — corollary findings
  - `## Conditions that might revive it` — when to revisit
- Affects profile.md: top 5 most informative are auto-surfaced under "Strong opinions / dead ends".

### method (mine)

- Path: `methods-mine/<slug>.md`
- Frontmatter: common + tag axes + `language` + `code_repo` + `license`
- Required body:
  - `## What it does` — one paragraph
  - `## Key API surface`
  - `## Gotchas`
  - `## Papers using it` — wikilinks (kept manually as a sanity check; auto-index also generates by-codes/<slug>.md)
- Affects profile.md: yes if status=active OR maintained.

### collaborator / talk / review (outgoing) / funding

(Compact; same shape as v1, with tag axes added.)

- **collaborator**: `collaborators/<slug>.md`. Frontmatter extras: `role: close|occasional|past`, `institution`, `expertise: [tags]`, `sensitivity: private` default. Body: `## How we met`, `## Common projects`, `## Communication preferences`, optional `## Frank notes` (sensitivity-gated). Role / institution / retirement changes append a `timeline:` entry (bi-temporal rule), never overwrite-only.
- **talk**: `talks/<YYYY>-<slug>.md`. Frontmatter extras: `venue`, `date`, `audience_level`, `public_url`. Body: `## Topic`, `## Key slides/figures`, `## What I'd change next time`.
- **review (outgoing)**: `reviews/<YYYY>-<slug>.md`. Always `sensitivity: embargoed`. Body: `## Paper summary`, `## My verdict`, `## Key concerns`, `## Lessons`.
- **funding**: `funding/<YYYY>-<slug>.md`. Frontmatter extras: `agency`, `status: submitted|awarded|rejected`, `amount`, `period`, `role`. Body: `## Project summary`, `## Key claims`, `## Deadlines`.

## Operations

### 1. `init` — first-time setup

Privileged-write operation; each side effect gated by confirmation.

1. **Resolve and confirm wiki path.** Default `~/research-wiki-personal/`. Stop if user declines.
2. **Create directory skeleton.** Copy `templates/profile.md` → `<wiki>/profile.md`, `templates/.gitignore` → `<wiki>/.gitignore`, `templates/CLAUDE.md` → `<wiki>/CLAUDE.md` (vocabulary starter), create empty `index.md` and `log.md`. Run `git init`.
3. **Wire auto-load (idempotent).** Detect harness (Claude Code presence at `~/.claude/`, Codex at `~/.codex/`). For each detected harness:
   - Claude Code: `grep -Fxq` for the import line in `~/.claude/CLAUDE.md` first; skip if present, else show diff and ask before appending.
   - Codex: inspect `~/.codex/AGENTS.md`. If absent, create symlink. If symlinked to same target, skip. If symlinked elsewhere, ask before overwriting. If a regular file with content, offer cancel / merge-into-profile.md / `.bak`-then-overwrite. Apply with `ln -sfn` for idempotence.
4. **Idempotent re-init.** If `<wiki>/profile.md` already exists, skip Step 2 and run only Step 3 (lets you wire a second harness on an existing wiki).
5. **Recommend next.** Set a private remote, fill `profile.md`, review `.gitignore`, optionally install pre-commit hook from `templates/pre-commit-hook.sh`.

### 2. `log` — capture a new entry

Trigger: `记一下`, `加进档案`, `log this`, `我有个 idea`, `这次没 work`.

**For type=paper, FIRST split:** ask "is this your paper or one you read?" (cache the answer in session). If "one you read", **HAND OFF** to literature-wiki: invoke its `ingest` operation with the source, then write a thin stub at `papers/read/<slug>.md` (only created if the user opts in) that cross-links to `research-wiki/sources/<paper-id>.md`. The detail lives there, not here.

For other types, or for "your paper":

1. Identify entry type from user phrasing. Ask once if ambiguous.
2. **Vocabulary check** for all tag axes the user mentioned. For unknown values, propose vocab diff first; do not silently invent.
3. Create the page at the path specified by its schema, with all required frontmatter and body sections present (sections can be sparse on first creation). **If the page already EXISTS: read its current frontmatter FIRST and run the bi-temporal check (step 5) before writing anything** — writing first and checking after is how old facts get silently overwritten.
4. For papers: ALWAYS also create the `<slug>.private.md` companion stub (with `sensitivity: embargoed`), even if empty.
5. **Bi-temporal check**: if this `log` updates an EXISTING page and flips a tracked fact (status, role, institution, venue decision, revision stance), append a `timeline:` entry per the bi-temporal rule; update top-level frontmatter to the new current state.
6. Append a one-line entry to `log.md`: `## [YYYY-MM-DD] log | <type> | <slug> | <one-line>`.
7. Update `index.md` (the manual hub).
8. **Trigger `update-index`** to refresh affected `index/by-<axis>/<tag>.md` pages.
9. Ask: should `profile.md` be refreshed? (Heuristic: yes if the new entry could affect the auto sections per "Affects profile.md" annotations above.)

### 3. `update-profile` — refresh the auto-loaded one-pager

profile.md is split into AUTO blocks (rewritten by this operation) and manual blocks (never touched). AUTO block boundaries:

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

#### Active-research-lines algorithm

```
for tag in topics + methods:
    pages = wiki pages tagged with tag whose status is "active" or "published in last 36 months"
    if len(pages) >= 3 AND any(updated within last 12 months):
        yield (tag, latest_update_date)
sort by latest_update_date desc
take top 5
also include any page with featured=true (override)
```

Each entry in this AUTO block is a one-line summary with a wikilink to `index/by-topic/<tag>.md` (the research-line page).

#### Recent-publications algorithm

`papers/published/*` with `published` date in last 24 months, sorted desc. One line per paper.

#### In-submission algorithm

`papers/submitted/*` (all) plus `papers/drafts/*` that name an intended venue, sorted by `submitted:` desc (undated last). One line per paper with venue + review state.

#### Methods-i-own algorithm

`methods-mine/*` with status `active` OR `maintained`. One line per method.

#### Dead-ends algorithm

`failures/*` sorted by `last_updated` desc, take top 5. One line per failure with the "Why X did not work" excerpt.

Flow:
1. Compute all four AUTO sections from current wiki state.
2. Read existing profile.md, locate AUTO markers.
3. If the user has hand-edited content INSIDE an AUTO block, warn and offer: discard manual edits / convert to a new manual section above the AUTO block.
4. Replace AUTO blocks atomically; manual sections are untouched.
5. Show diff. Ask before saving.

### 4. `update-index` — refresh the tag-indexed pages

Triggered automatically after every `log`, after `update-profile`, and after `migrate`. After `lint` it runs only once the user has approved the lint fixes (lint itself stays read-only). Can also be invoked explicitly. Always idempotent.

Flow:
1. Walk all pages under `projects/`, `papers/`, `ideas/`, `failures/`, `methods-mine/`, `collaborators/`, `talks/`, `reviews/`, `funding/`. Read frontmatter only (cheap).
2. Build an in-memory tag → pages map for each axis. Apply `parent:` propagation (a page tagged `iav-cdcc` is also indexed under `cdcc`).
3. For each (axis, tag) pair, write `<wiki>/index/by-<axis>/<tag>.md`:

```markdown
# <Canonical name from vocabulary>

<!-- MANUAL preamble (above AUTO marker; preserved across runs) -->

<!-- AUTO:BEGIN -->

## Papers (<count>)
- [YYYY] *Title* — Key claim excerpt. → [[../../papers/published/<slug>]]
  Cross-tags: methods=[…], topics=[…], systems=[…]

## Failures (<count>)
- [YYYY] What didn't work, one-line. → [[../../failures/<slug>]]

## Open ideas (<count>)
- [YYYY] Seed thought. → [[../../ideas/promising/<slug>]]

## Methods I own (<count>)
- <slug> — what it does. → [[../../methods-mine/<slug>]]

<!-- AUTO:END -->
```

4. Skip pages with `sensitivity: embargoed` from indices unless the index file is itself in a private-only directory (rare; default behavior: embargoed pages are NOT linked from auto indices to prevent leak via index summary).
5. Delete `<wiki>/index/by-<axis>/<tag>.md` files whose tag has zero pages (after this run).
6. Report what was added / changed / removed.

### 5. `snapshot` — CV-style export

Read-only synthesis grouped by year. Pulls from frontmatter dates and key claims. Optionally save to `snapshots/YYYY-MM-DD-<scope>.md` (gitignored by default).

### 6. `lint` — health check

Trigger: explicit, or suggest after every ~20 logs.

Checks:
- Active projects with no update in 90+ days → propose move to `paused/`.
- Papers in `submitted/` for >120 days → flag for status check.
- Ideas in `promising/` for >180 days with no movement → propose `parked/` or `killed/`.
- `profile.md` `last_updated` >60 days → propose `update-profile`.
- Pages where required schema sections are missing.
- **Vocabulary integrity**: pages using tags not in vocabulary; vocabulary entries with no pages using them; uncategorized usage > 30% of any axis.
- **AUTO marker integrity**: AUTO blocks with hand-written content inside (warns user); profile.md missing AUTO markers (after migrate).
- **Cross-link validity**: `predecessor` / `successor` / `literature` wikilinks pointing to non-existent pages.
- **Lineage cycles**: A → B → A in predecessor / successor chains.
- **Timeline integrity** (v2.1): `timeline:` entries missing `learned` or `source`; latest timeline entry (`until: present`) contradicting the top-level current-state fields; overlapping `from`/`until` ranges for the same fact family.

Output: a markdown report. Apply fixes only after the user reviews.

### 7. `migrate` — bring existing pages up to current schema

Use when upgrading from v1 (no controlled vocab, simpler frontmatter) to v2.

Flow:
1. Walk all pages.
2. For each page, identify missing v2 fields (tag axes, lineage, paper-private companion, schema body sections).
3. For each gap, prompt user: "Page `<path>` is missing tag axis `methods`. From the page content, I propose `[cdcc, iav-cdcc]` (existing vocab) — confirm or correct."
4. For papers without `<slug>.private.md`: create empty companion with frontmatter only.
5. After the page is brought to v2: re-write to disk, append migration entry to `log.md`.
6. After full pass: run `update-index` once.

This is interactive and slow on a large wiki — that's intentional. The user must validate each tag application; silent migration would defeat the purpose of controlled vocabulary.

## Working principles

- **Privacy and the model round-trip.** profile.md content is sent to the model provider on every session start. Keep profile.md free of embargo-sensitive specifics. Pages with `sensitivity: embargoed` are never auto-quoted to outputs that could leak.
- **Capture, don't curate, on the way in.** Polish only on `update-profile` cycles.
- **Failures are first-class.** Failure pages get the same tag axes as papers; the auto-index treats them as equal-rank entries for "what have I done on topic X".
- **Controlled vocabulary is a contract.** Never invent tags silently; always check vocab; new tags require explicit user approval. Tag drift breaks indexing for years; the cost of asking is small.
- **Frontmatter is the index, body is the narrative.** Cross-cutting queries hit frontmatter only; the body is for human reading and depth.
- **Cross-link into the literature-wiki** when it exists. Use `literature:` frontmatter and inline `[[../research-wiki/...]]` links.
- **Read the wiki's `CLAUDE.md` / `AGENTS.md` first** for vocabulary and personal style overrides.

## Cross-skill hand-off with literature-wiki

When the user reads a paper that relates to their own work:
1. The paper goes to **literature-wiki** (`research-wiki/sources/<paper-id>.md`) — the field-level record.
2. If it informs an active project, idea, or failure here, add a `literature: [[../research-wiki/sources/<paper-id>]]` line to the relevant page's frontmatter, plus a one-sentence note in body explaining the relevance.
3. If the read paper has a method that's also in this user's work, the method tag in vocabulary should be the same slug across both wikis (vocabulary file at the user-level, e.g. `~/research-vocabulary.yml`, can be symlinked into both `<personal-wiki>/CLAUDE.md` and `<literature-wiki>/CLAUDE.md` for true single source of truth — optional advanced setup).

When the user logs their own paper that uses a method documented in literature-wiki:
1. Page tagged with method slug as usual.
2. Add `literature: [[../research-wiki/methods/<method-slug>]]` to frontmatter.
3. The auto-index `<personal-wiki>/index/by-method/<method-slug>.md` adds a "See also: literature-wiki definition" line at the top.

## Detail on schema and workflows

The per-page schemas above are the contract. Templates ship in `templates/`:

- `templates/profile.md` — starter for the auto-loaded one-pager (with AUTO markers).
- `templates/CLAUDE.md` — vocabulary starter with empty axes and a few example entries.
- `templates/.gitignore` — privacy default.
- `templates/pre-commit-hook.sh` — optional Git pre-commit guard.

For extended workflows or schema variants, see `references/` if present.

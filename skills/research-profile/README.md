# research-profile

A cross-harness agent skill (**Claude Code** + **Codex CLI**) that maintains a **persistent record of your own research career** — projects, papers, ideas, failures, collaborators, methods you own — and **auto-loads a one-page summary into every new agent session** so the assistant always knows who you are and what you've done.

## What problem this solves

Every fresh agent session, you start from zero. The model doesn't know:

- Which 4 projects you're actively running.
- That you tried approach X in 2023 and it didn't converge for reason Y (so it shouldn't suggest X again).
- That your last three papers were about Z, and the new one extends them.
- That collaborator A is your closest co-author and B is a polite-but-skeptical reviewer.
- Your formatting preferences, methodological priors, and pet peeves.

You currently solve this by re-explaining context every session, or by losing it. This skill solves it by making your research record a **persistent, structured, and auto-loaded** artifact.

## How the auto-load works

Both Claude Code and Codex CLI support per-session imports of arbitrary markdown files, using different mechanisms. This skill wires the same canonical `profile.md` into both.

| Harness | Mechanism | What you do once |
|---|---|---|
| **Claude Code** | `@/absolute/path/to/file` import directive in CLAUDE.md | Append `@<wiki>/profile.md` to `~/.claude/CLAUDE.md` (user-level) or `<project>/CLAUDE.md`. First session shows external-import approval dialog. |
| **Codex CLI** | Symlink `~/.codex/AGENTS.md` to `<wiki>/profile.md` | One-time `ln -sfn <wiki>/profile.md ~/.codex/AGENTS.md`. If you have existing global content there, merge it into profile.md's "Working preferences" section first; the symlink replaces the original. |

**Dual-harness users:** both harnesses end up referencing the same canonical `<wiki>/profile.md` — Claude Code via `@/path` (no copy), Codex via symlink. After every `update-profile`, the new content is live in both with no extra step.

**Why not Codex's `project_doc_fallback_filenames`?** That mechanism only checks alternate filenames in directories *along the project walk path* (project root → cwd), never at `~/.codex/`. A symlink at `~/.codex/profile.md` is never loaded — confirmed against [Codex docs](https://developers.openai.com/codex/guides/agents-md) and [source](https://github.com/openai/codex/blob/main/codex-rs/core/src/project_doc.rs). The `~/.codex/AGENTS.md` symlink is the only reliable global path.

## What it captures

```
<wiki>/
├── profile.md                 # ⭐ the auto-loaded one-pager
├── projects/{active,paused,done}/
├── papers/{published,submitted,drafts,rejected}/   # incoming referee reports as sub-sections
├── ideas/{promising,parked,killed}/                # killed ideas keep "why killed"
├── methods-mine/                                   # tools and code you own
├── failures/                                       # ⭐ what didn't work and why — highest-value pages
├── collaborators/
├── talks/  reviews/  funding/
├── snapshots/                                      # CV-style exports (gitignored)
├── index.md  log.md  CLAUDE.md / AGENTS.md
```

Failures are deliberately first-class. Most researchers never write down what didn't work. For an AI agent that helps you, those pages are the difference between "suggesting things you've already burned through" and "actually contributing".

The skill defines mini-schemas for each entry type (project, paper, idea, failure, method, collaborator, talk, review, funding). See SKILL.md or AGENTS.md for full schema details.

## What v2 added

Schema v2 (current) builds tag-driven indexing on top of v1's hand-curated structure. The four real problems with v1 were: index.md degraded into an unreadable list past ~50 entries; `related: []` frontmatter was always empty (forgetfulness); cross-references hid in prose where machines couldn't query them; and `profile.md` sorted by "recent publications" but real questions are "what did I do on topic X?". v2 fixes them with:

v2.1 adds bi-temporal `timeline:` frontmatter: tracked facts that change (collaborator role/retirement, paper revision stance, project state) keep an append-only history with event time, learn time, and provenance, while top-level fields stay current. Borrowed from obsidian-second-brain's bi-temporal facts rule.

- **Controlled vocabulary** in `<wiki>/CLAUDE.md` (six axes: methods / observables / codes / topics / systems / collaborators) with aliases and parent relationships. Tag drift is the silent killer at scale; the vocabulary file is the contract.
- **Tag fields in frontmatter** on every page (papers, ideas, failures, methods, etc.) — same axes, same vocab.
- **`update-index` operation** — auto-generates `<wiki>/index/by-<axis>/<tag>.md` pages by scanning all frontmatter. Each page has a manual preamble (motivation, current state) above an AUTO block listing papers + ideas + failures + methods carrying that tag. Topic-index pages doubly serve as **research-line pages**.
- **Schema v2 paper format** — drops sections reconstructable from the abstract (Title and authors → frontmatter, Status timeline → frontmatter dates), adds mandatory user-only sections (My contribution in CRediT format, Code/data location with server paths, Lineage prose, Key numbers, What I'd do differently now). A `.private.md` companion is always paired for embargoed material (reviewer reports, response drafts).
- **AUTO-marker `profile.md` sections** — `update-profile` rewrites only the marked blocks; manual sections (Working preferences, Compute, Skills) are never touched. Active research lines are derived from tag activity, not hand-curated.
- **`migrate` operation** — interactive walk through v1 pages, prompting for each missing v2 field with vocabulary-controlled tag pickers.
- **`log paper` own/read split** — own papers take the v2 schema; read papers hand off to literature-wiki.

If you have a v1 wiki, run `migrate` once. If you are starting fresh, `init` ships v2 directly.

## File layout

```
research-profile/
├── SKILL.md                # canonical body — Claude Code entry (with YAML frontmatter)
├── AGENTS.md               # canonical body — Codex CLI entry (no frontmatter, Codex-flavored)
├── README.md               # this file
└── templates/
    ├── profile.md          # starter template for the auto-loaded one-pager (with AUTO markers)
    ├── CLAUDE.md           # vocabulary starter — six axes with example entries
    ├── .gitignore          # privacy-default gitignore for the wiki
    └── pre-commit-hook.sh  # optional Git pre-commit guard against committing private/embargoed files
```

`SKILL.md` and `AGENTS.md` mirror each other. They are kept in sync by hand because Codex does not yet support markdown imports ([openai/codex#17401](https://github.com/openai/codex/issues/17401)). If you contribute, edit both.

## Configuration (read this first)

Before running setup, decide:

1. **Wiki location.** Default `~/research-wiki-personal/`. To override, set `RESEARCH_PROFILE_PATH` env var or write the absolute path to `~/.research-profile-path` before the next step.
2. **Privacy posture.** This wiki holds unpublished ideas, embargoed results, and frank collaborator notes. Strongly recommend a local + private-remote git repo, never a public one. The skill ships a starter `.gitignore` template.
3. **Auto-load scope.** User-level (every session, every project) vs project-scoped (only when working in a specific repo). Default user-level.

## Install

### On Claude Code

```bash
# Project-local (this project only):
cp -r research-profile/ <your-project>/.claude/skills/

# Or user-level (every Claude Code session):
cp -r research-profile/ ~/.claude/skills/
```

### On Codex CLI

Codex install has two independent pieces: (1) auto-load of profile.md, (2) availability of the skill protocol body. The auto-load wiring is shown in the table above. For the protocol body:

```bash
# Recommended — per-project install in each project where you want skill ops available:
cat path/to/research-profile/AGENTS.md >> <your-project>/AGENTS.md

# Or — on-demand: do not install; keep the AGENTS.md at its repo path, and add
# one line to your profile.md (in "Skills available" section) telling Codex to
# read it when activating skill ops.
```

⚠️ Note: do **not** also `cat AGENTS.md >> ~/.codex/AGENTS.md` if you are using the global auto-load symlink — that file is taken by the symlink to profile.md. Pick one of the patterns above.

If your combined AGENTS.md exceeds the 32 KiB default cap, raise it in `~/.codex/config.toml`:
```toml
project_doc_max_bytes = 65536
```

## First-run setup

After install, in your agent (Claude Code or Codex), say:

```
> set up my research-profile wiki
```

The agent will run a gated checklist with confirmations at each side effect:

1. **Resolve wiki path.** Confirm the absolute path before any creation.
2. **Create directory skeleton.** Copies `templates/profile.md` and `templates/.gitignore` into the wiki, runs `git init`.
3. **Wire auto-load (idempotent).** Detects which harness(es) you use and shows the exact diff before:
   - Appending `@<wiki>/profile.md` to `~/.claude/CLAUDE.md` (skips if line already present).
   - Symlinking `~/.codex/AGENTS.md` to `<wiki>/profile.md` via `ln -sfn` (skips if already pointing at the right target; warns and asks before overwriting any existing content).
4. **Idempotent re-init.** If the wiki already exists (e.g., you set up Claude Code earlier and now want Codex too), skips creation and only adds the missing harness wiring.
5. **Recommends next:** set a private remote, fill `profile.md`, review the `.gitignore`, optionally install the pre-commit hook from `templates/pre-commit-hook.sh`.

After setup, open `<wiki>/profile.md` and fill in your details. Replace bracketed placeholders with real content. The first version doesn't need to be complete — you'll grow it through `log` and `update-profile` over weeks.

## Daily use

```
> 记一下我刚做完的：用 method-X on system-Y, 结果是 Z
```
Creates `projects/active/<slug>.md` and `papers/drafts/<slug>.md` if relevant, links them, appends to `log.md`.

```
> 我有个研究 idea: <description>
```
Creates `ideas/promising/<slug>.md` with seed thought and what would unblock it.

```
> 这次没 work, X-method on Y-system 发散了
```
Creates `failures/<slug>.md` with what was tried, why it should have worked, what actually happened, what conditions might revive it. **The most valuable kind of entry** for future AI context.

```
> 更新 profile
```
Rewrites `profile.md` from current subpages, shows diff, asks before saving.

```
> 我做过什么 X 类的工作？
```
Searches the wiki, synthesizes, gives provenance.

```
> snapshot my research from this year
```
Read-only export grouped by month: pubs, talks, projects, funded grants. Saves to `snapshots/` if requested.

## Privacy hardening

The wiki holds material that should never leave your control accidentally. Three layers of mitigation:

### 1. The `.gitignore` template

`templates/.gitignore` (copied to `<wiki>/.gitignore` on init) excludes by default:

- `raw/` — raw PDFs of papers (most are copyrighted)
- `funding/` — grant applications, often agency-confidential
- `reviews/` — peer reviews you wrote (outgoing), referee privilege is permanent
- `collaborators/` — frank notes about people
- `snapshots/` — CV-style exports change frequently and don't belong in git history
- `*.private.md` and `*.local.md` patterns — including `papers/<status>/<slug>.private.md` where incoming referee reports on your own papers belong (the public `<slug>.md` carries title, venue, status; the `.private.md` companion carries reviewer text)

Review and adjust on first run. If you want anything tracked, remove its entry from `.gitignore`.

### 1b. Optional pre-commit hook (structural enforcement)

`templates/pre-commit-hook.sh` is a Git pre-commit hook that **refuses to commit** files matching `*.private.md` / `*.local.md` or files with `sensitivity: embargoed` in their frontmatter. It catches accidents the gitignore alone cannot (e.g., `git add -f` of an ignored file).

Install in your wiki repo:
```bash
cp <skill-path>/templates/pre-commit-hook.sh <wiki>/.git/hooks/pre-commit
chmod +x <wiki>/.git/hooks/pre-commit
```

Bypass once with `git commit --no-verify` when you genuinely want to commit something the hook flags. Recommended: keep the hook on, never bypass for embargoed pages.

### 2. The model round-trip

`profile.md` is sent to your model provider on every session start — that is the cost of auto-load. Subpages are read on demand only when you mention the topic.

**Implication:**
- Keep `profile.md` itself free of embargo-sensitive specifics. Use generic descriptions ("working on hypernuclei reactions") and link to subpages for detail.
- Pages with `sensitivity: embargoed` in their frontmatter should never be quoted into outputs that could leak (chat with non-private MCPs, public artifacts) without explicit user OK.
- If you use a non-Anthropic / non-OpenAI provider, verify their data-handling policy matches what is in your `profile.md`. Consider a redacted variant for those sessions.

### 3. Tool boundary

If you have third-party MCPs installed (web scrapers, social media tools, anything that emits to non-private destinations), be aware they receive the same context as the agent. Consider disabling them for sessions where you are deeply working in the wiki, or scope them to specific projects.

## Customizing for your field

The skill is field-agnostic. `methods-mine/`, `papers/`, `failures/`, `collaborators/` apply to any research field. The starter `profile.md` template uses placeholders for affiliation, field, and active research lines that you fill in.

## Companion skills

- A **literature-wiki** skill (the field-level knowledge base) — cross-link from your personal pages to the field-level pages they cite or extend.
- A **personality / voice-style skill** if you have one — keeps separate the *factual* record (this skill) from the *voice* simulation (that one). They complement.

## Author and credit

Skill author: **Jin Lei**. Released under MIT-equivalent terms ("use freely, no warranty").

The underlying **LLM Wiki pattern is by Andrej Karpathy** ([gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)). The original gist explicitly mentions both Claude Code (CLAUDE.md) and Codex (AGENTS.md) as targets; this skill applies the pattern to a *personal* research-portfolio dimension and adds the cross-harness auto-load wiring. Credit for the original pattern belongs upstream.

## Status

Vibe-tested. No formal eval suite yet. PRs welcome — particularly for: non-physics field templates, integrations with reference managers (Zotero, Paperpile), or a CLI for the `log` operation.

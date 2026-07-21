<p align="center">
  <img src="assets/brand/fusion-github-logo.png" alt="FUSION" width="760">
</p>

# FUSION

**F**ramework for **U**nified **S**cientific **I**ntelligence in **O**pen **N**uclear physics

A nuclear-physics research agent platform, built as a rebrand fork of [opencode](https://github.com/anomalyco/opencode) (MIT). Not affiliated with the opencode project.

## Project goal

Give nuclear physicists (starting with students and group members, extending to the community) an agent that comes out of the box with:

1. **One expert skill per nuclear open-source code, for the whole ecosystem.** Reactions (FRESCO, THOx, CCFULL, TALYS, GEF, ...), R-matrix/astro (AZURE2, SkyNet, ...), structure (KSHELL, BIGSTICK, imsrg++, HFBTHO, ...), scoped transport/data (OpenMC, NJOY), plus the group's own codes (smoothie, COLOSS, SLAM.jl, ...). Each skill teaches the agent to install, write inputs for, run, and parse that code, validated against a published benchmark. Living roadmap: [skills-catalog.md](skills-catalog.md).
2. **A self-contained domain knowledge base.** The local arXiv nucl-th full-text corpus (62714 papers, 61357 with full text, 1992-09 to 2026-06, SQLite FTS5 + BM25), partitioned by domain keywords (reactions, structure, astro, EFT, ...) and exposed to the agent as a search tool. Offline, exhaustive, lexical.
3. **A private personalization layer.** Each user mounts their own read-literature wiki and research profile; FUSION defines the interface but never ships anyone's personal layer.

Provider-agnostic by inheritance from opencode: runs on domestic models (DeepSeek, Qwen, GLM) as well as Claude/GPT, which is the point; the target users often cannot access Anthropic APIs.

## Repository layout: FUSION vs fusion-core

The platform lives in TWO repos with a strict division of labor:

| | [jinleiphys/FUSION](https://github.com/jinleiphys/FUSION) (this repo) | [jinleiphys/fusion-core](https://github.com/jinleiphys/fusion-core) |
|---|---|---|
| Role | The platform itself: everything we write | The engine: fork of anomalyco/opencode |
| Local path | `/Users/jinlei/Desktop/code/FUSION` | `/Users/jinlei/Desktop/code/fusion-core` |
| Contents | docs, skills catalog, phase reports; later: skills/, agents/, mcp-servers/, config/, install.sh | full opencode source + the brand patch (branch `fusion-brand`, default; branch `dev` = pristine upstream mirror) |
| Changes | freely, by us | brand assets ONLY (TUI logo, icons, name strings); functional code never touched |
| Upstream sync | n/a | CI `fusion-rebase.yml` rebases the brand patch onto upstream `dev` every Monday and syncs the mirror; a failed run = a real conflict |
| End-user view | the product repo they install from (install.sh pulls a fusion-core binary) | build source; users normally never clone it |

Analogy: FUSION is Ubuntu, fusion-core is the (rebadged) kernel. Development happens here; fusion-core only carries the badge.

To see the current TUI branding: `cd fusion-core && git pull && bun install && bun dev` (dev mode runs the TS source directly, no rebuild step).

## Architecture

```
┌─ FUSION binary ──────────────────────────────┐
│ opencode upstream + brand patch (logo/name)  │  <- only fork surface, CI-rebased weekly
└──────────────────────────────────────────────┘
┌─ FUSION customization layer (this repo) ─────┐
│ skills/        per-code + research skills    │
│ agents/        literature / referee / runner │
│ mcp-servers/   corpus search, INSPIRE, HPC   │
│ config/        default opencode.json, models │
│ install.sh     one-shot setup                │
└──────────────────────────────────────────────┘
┌─ user private layer (never shipped) ─────────┐
│ ~/research-wiki, profile, credentials        │
└──────────────────────────────────────────────┘
```

## Knowledge base design

Base: the existing `literature-corpus` stack (`corpus.db` ~5.5 GB, `query.py`; see `~/.claude/skills/literature-corpus/SKILL.md`). FUSION builds on top a **pre-generated markdown wiki** (`kb-wiki/`): one page per paper (frontmatter + abstract + DeepSeek full-text digest + in-corpus citation links) and one page per **PhySH concept** (APS Physics Subject Headings, CC0, Nuclear Physics subtree 176 concepts) with citation-ranked paper lists and a landscape synthesis. Agents browse it with plain grep/read; no server required. Full design, measured costs, and licensing constraints: [kb-design.md](kb-design.md). Public artifacts must not redistribute arXiv full text (hard rule in CLAUDE.md).

## How to run

Not yet runnable. Phase 0 (quality validation on stock opencode) comes first; see [TODO.md](TODO.md).

## References

No paper citations yet (platform project). When physics papers enter this README, tag them `[wiki]` or `[TO INGEST -> literature-wiki]` per the research-planning protocol.

## Author

Jin Lei (金磊), Tongji University. Contact: jinl@tongji.edu.cn

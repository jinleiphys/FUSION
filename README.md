# FUSION

**F**ramework for **U**nified **S**kills, **I**nference & **O**pen **N**uclear-science

A nuclear-physics research agent platform, built as a rebrand fork of [opencode](https://github.com/anomalyco/opencode) (MIT). Not affiliated with the opencode project.

## Project goal

Give nuclear physicists (starting with students and group members, extending to the community) an agent that comes out of the box with:

1. **One expert skill per nuclear open-source code.** Each skill teaches the agent to install, write inputs for, run, and parse one community code (FRESCO, TALYS, CCFULL, KSHELL, ...) plus the group's own codes (smoothie, COLOSS, SLAM.jl, ...), each validated against a published benchmark.
2. **A self-contained domain knowledge base.** The local arXiv nucl-th full-text corpus (62714 papers, 61357 with full text, 1992-09 to 2026-06, SQLite FTS5 + BM25), partitioned by domain keywords (reactions, structure, astro, EFT, ...) and exposed to the agent as a search tool. Offline, exhaustive, lexical.
3. **A private personalization layer.** Each user mounts their own read-literature wiki and research profile; FUSION defines the interface but never ships anyone's personal layer.

Provider-agnostic by inheritance from opencode: runs on domestic models (DeepSeek, Qwen, GLM) as well as Claude/GPT, which is the point; the target users often cannot access Anthropic APIs.

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

Base: the existing `literature-corpus` stack (`corpus.db` ~5.5 GB, `query.py`; see `~/.claude/skills/literature-corpus/SKILL.md`). FUSION adds:

- a **domain-keyword tag layer**: each paper classified by arXiv category + keyword rules into domains (nuclear reactions, structure, astrophysics, chiral EFT, lattice, ML-applications, ...), exposed as query filters; classification rules to be defined in Phase 3, [Please specify final domain list];
- an **MCP server wrapper** around query.py so any opencode-compatible client can search the corpus;
- a **packaging story** compatible with arXiv licensing (see TODO Phase 3; public artifacts must not redistribute full text).

## How to run

Not yet runnable. Phase 0 (quality validation on stock opencode) comes first; see [TODO.md](TODO.md).

## References

No paper citations yet (platform project). When physics papers enter this README, tag them `[wiki]` or `[TO INGEST -> literature-wiki]` per the research-planning protocol.

## Author

Jin Lei (金磊), Tongji University. Contact: jinl@tongji.edu.cn

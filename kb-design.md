# FUSION knowledge base: 62k arXiv papers as a PhySH-organized wiki

Design settled 2026-07-09 (user directive: think this through before building; taxonomy = PhySH per user's pointer to physh.org/browse).

## The one-line design

Classify all 62,714 nucl-th papers against the **PhySH taxonomy** (APS Physics Subject Headings, **CC0 public domain**, v2.8.0, 3882 concepts; Nuclear Physics subtree = 176 concepts) using zero-token lexical rules on the existing corpus.db, add a within-corpus **citation graph** parsed from the raw .tex, and **pre-generate the whole wiki as real markdown files** (one page per paper with a DeepSeek full-text digest, one page per PhySH concept), so any agent can browse it with plain grep/read, no server required.

(Revision 2026-07-09 evening, user decision: pre-generated md replaces the earlier DB-rendered + digest-on-touch idea. Measured cost made bulk digestion cheap; see cost table below.)

## Why PhySH

- Authoritative and APS-aligned: the same headings PRC/PRL editors use; referees and editors (the user is both) already think in it.
- Right granularity: Nuclear reactions alone has 35 descendants (Breakup reactions, Knockout reactions, Coulomb dissociation, Fusion, ...): exactly the "领域关键词" level wanted.
- CC0: redistributable inside FUSION with zero legal risk (verified LICENSE.md in github.com/physh-org/PhySH).
- Maintained: releases up to 4x/year; deprecated.csv gives migration paths.

## The four layers (build order = this order)

### L0: taxonomy + matching rules (human-editable, versioned)

`physh-nuclear.yaml`: the 176 Nuclear Physics concepts (+ curated neighbors from Astrophysics / Particles & Fields for nucl-th cross-over topics like neutron-star EOS and chiral EFT), each with:
- PhySH id/uri, label, broader/narrower links (from the CC0 dump)
- `match:` a list of FTS5 query strings (seeded from the PhySH label + SKOS altLabels, then hand-tuned; e.g. Trojan horse concept also matches "quasi-free" phrasing)
- Calibration anchors: papers known to belong (the user's own 25 FRESCO-line papers pin the reactions concepts)

This file IS the "按领域关键词区分" definition: editable, reviewable, community-improvable. No ML, no embeddings (consistent with the literature-corpus lexical-first decision).

### L1: mechanical classification (zero tokens)

For each concept, run its FTS queries against corpus.db with tiered confidence: title hit > abstract hit > fulltext-only hit. Write to a new `paper_concept(arxiv_id, concept_id, tier, score)` table inside corpus.db. 176 concepts x FTS query = minutes of CPU. Re-run monthly with the existing corpus-update launchd job. Papers matching nothing fall into per-arXiv-category catchalls (report the rate; >30% means rules need work, same threshold philosophy as research-profile lint).

### L2: within-corpus citation graph (zero tokens; needs KINGSTON drive)

Parse \bibitem / .bbl / \cite from the 35 GB raw .tex; extract arXiv IDs and DOIs; keep edges where both ends are in the corpus. Table `citation(citing, cited)`. This fulfills the literature-corpus skill's own unbuilt Tier 2 (`cites` / `cited-by`). Payoff: "key papers" per topic = in-corpus citation rank (no external API), and wiki backlinks.

### L3: the wiki itself (pre-generated markdown, bulk-digested by DeepSeek)

A real file tree, Obsidian-compatible, grep-able, git-versioned:

```
kb-wiki/
├── papers/<arxiv_id>.md      62k pages: frontmatter (id/title/authors/date/doi/concepts)
│                             + abstract + DeepSeek FULL-TEXT digest
│                             (Key claim / Method / Key numbers / Context)
│                             + in-corpus cites / cited-by links
├── topics/<physh-slug>.md    176+ pages: PhySH lineage, paper count, top-15 by
│                             in-corpus citations, 10 most recent, LLM landscape
│                             synthesis, links to sibling topics
└── index.md                  PhySH discipline tree as the navigation hub
```

Digest pipeline: `scripts/digest_paper.py` (prototype validated 2026-07-09 on 1511.03214 + 2605.03342; the Lei-Moro digest checked correct against ground truth, zero fabrication). Bulk run = the same script with a worker pool, resumable by skipping existing files, capped at 40k chars of full text per paper.

**Measured cost (deepseek-chat, 2026-07-09):** 10.7k tokens in / 0.5-0.75k out / ~8 s per paper.
| | tokens | cost (standard) | cost (off-peak) |
|---|---|---|---|
| input 62,714 papers | ~690M | ~$190 | ~$50-95 |
| output | ~38M | ~$42 | ~$20 |
| **total** | | **~$230 (~1700 RMB)** | **~$70-115 (~500-800 RMB)** |

Wall clock: ~7 h at 20 concurrent requests. Monthly increment (~300 new papers) = pennies, hooked into the existing corpus-update cron.

Access: agents just grep/read the md tree (same pattern as the personal literature-wiki skills). An MCP server (a small program exposing kb_search/kb_browse as callable tools, per the Model Context Protocol that opencode and Claude Code both speak) is OPTIONAL later sugar for structured queries; it is no longer a load-bearing component.

Storage: ~260 MB of markdown for 62k pages; ships as a git repo (public version) or tarball.

## Relation to the existing three-layer stack

```
discovery : literature-search  (online, the whole world)
corpus    : literature-corpus  (62k, lexical search)        <- L1/L2 tables live here
corpus-wiki: THIS              (62k, browsable + digests)   <- new, shippable artifact
synthesis : literature-wiki    (hundreds actually read)     <- personal, private, richer
```

The personal wiki remains the private layer; the corpus-wiki is the shippable public knowledge base. A personal-wiki entry can link down to its corpus-wiki page; never the reverse.

## Licensing for shipping

- PhySH: CC0, ship freely.
- Paper metadata: fine. Abstracts: gray zone for bulk public redistribution (arXiv metadata license carve-out); group-internal full version, public version pending a check (options: abstracts truncated to snippets, or fetch-on-first-run).
- Full text / corpus.db with full text: NEVER in public artifacts (already a hard rule in CLAUDE.md).
- Digests + syntheses: original derived content, shippable.

## Prototype (the run-then-think gate before building it all)

One evening-sized demo: take 2 concepts (Breakup reactions; a THM-adjacent one), seed match rules from PhySH labels, classify the corpus, build their topic pages + 3 digest pages with deepseek-chat, and validate that the user's own papers land where they must (his 25 FRESCO-tagged papers are the calibration set). Only after this looks right do we run all 176 concepts.

## Open decisions

1. Neighbor-concept whitelist from other disciplines (astro / particles): which ones? (propose during prototype)
2. Public-version abstract policy (snippets vs fetch-on-first-run).
3. Where L1/L2 tables live: inside corpus.db (one file, self-contained) vs a separate kb.db attached at query time (keeps corpus.db pristine for the update pipeline). Leaning: separate kb.db, ATTACH at query time.

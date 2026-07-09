# FUSION knowledge base: 62k arXiv papers as a PhySH-organized wiki

Design settled 2026-07-09 (user directive: think this through before building; taxonomy = PhySH per user's pointer to physh.org/browse).

## The one-line design

Classify all 62,714 nucl-th papers against the **PhySH taxonomy** (APS Physics Subject Headings, **CC0 public domain**, v2.8.0, 3882 concepts; Nuclear Physics subtree = 176 concepts) using zero-token lexical rules on the existing corpus.db, add a within-corpus **citation graph** parsed from the raw .tex, and serve the result as a **DB-backed wiki** (topic pages + paper pages + on-demand LLM digests) through one MCP server.

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

### L3: the wiki itself (DB-backed, served by one MCP server)

Pages are rendered from SQLite on demand (no 62k-file dump; static md export only for snapshots/Obsidian):

- **Topic page** (one per concept): PhySH lineage (broader/narrower links), paper count + trend, top-15 by in-corpus citations, 10 most recent, sibling topics. Plus a **synthesis section**: LLM summary of the topic's landscape from top-paper abstracts (~176 topics x DeepSeek = trivial cost; refreshed quarterly).
- **Paper page** (one per arXiv id): metadata, abstract, concept tags, cites/cited-by within corpus, tex_dir pointer. Plus a cached **digest** section.
- **Digest-on-touch**: whenever the agent or user opens a paper page, a DeepSeek digest (key claim, method, numbers, relation to neighbors) is generated once and cached in `digest(arxiv_id, model, date, md)`. The wiki densifies along real usage paths, the same way the personal literature-wiki grows by reading, but automated. No bulk pre-digestion of 62k papers (cost without demand).

MCP tools: `kb_browse(concept)`, `kb_paper(arxiv_id)`, `kb_search(query, concept_filter)`, `kb_cites(arxiv_id)`. The existing query.py text/abs/author search stays as the raw search layer underneath.

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

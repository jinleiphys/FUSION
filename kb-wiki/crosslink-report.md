# KB cross-link layers: build report

Date: 2026-07-14

## What ran

Three scripts executed in order:

1. `scripts/build_physh_nuclear.py` -- extracted the Nuclear Physics subtree from PhySH v2.8.0 SKOS dump (data/physh.json) and wrote `kb-wiki/physh-nuclear.yaml`.
2. `scripts/kb_classify.py` -- ran tiered FTS5 queries against corpus.db for all 180 concepts, wrote `kb-wiki/classification.json`.
3. `scripts/build_wiki_layers.py` -- injected `concepts:` frontmatter into 35,688 existing paper pages, generated 108 topic pages under `kb-wiki/topics/`, and wrote `kb-wiki/index.md`.
4. `scripts/kb_citegraph.py` -- scanned 61,357 .tex files on KINGSTON drive for arXiv IDs and DOIs, built 351,338 citation edges, wrote `kb-wiki/citations.tsv`.
5. `scripts/inject_citations.py` -- injected `## In-corpus citations` sections into all 53,258 paper pages.

## L0: PhySH nuclear taxonomy

- **YAML:** kb-wiki/physh-nuclear.yaml
- **Concepts:** 176 Nuclear Physics (core + all descendants from the PhySH hierarchy) + 4 neighbor concepts (Neutron stars & pulsars, Neutron star crust, Big bang nucleosynthesis, Effective field theory)
- **Match seeding:** prefLabel + altLabels per concept, as quoted FTS5 phrases. 202 unique phrases across 180 concepts.
- **Hand rules applied:** breakup-reactions (+5 phrases for inclusive/elastic/nonelastic breakup), nuclear-fusion (+3 phrases for complete/incomplete fusion and fusion suppression), direct-reactions (+3 phrases for transfer/stripping/pickup reactions).
- **Tier system encoded:**
  - Tier 1: phrase hits title
  - Tier 2: phrase hits abstract
  - Tier 3: fulltext only, requires >= 2 distinct match phrases
- **Negative filter:** hep- and astro-ph papers cannot receive reaction-family concepts at tier 3 (fulltext only).
- **Dangerous words:** 16 bare words (spin, parity, mass, energy, etc.) restricted to title/abstract tiers only.

## L1: Classification

- **Total papers:** 61,059
- **Classified:** 38,824 (63.6%)
- **Unclassified:** 22,235 (36.4%) -- above the 30% target. Honest sample of 10 unclassified titles shown in script output; common reasons include old-style arXiv IDs (pre-2007), figure-only papers, and concepts that only match exact PhySH label spelling.
- **Tier distribution:**
  - Tier 1 (title hit): 18,456 concept assignments
  - Tier 2 (abstract hit): 37,606
  - Tier 3 (fulltext-only): 9,589

### Top 20 concepts by paper count

| Concept | Papers |
|---------|--------|
| Quantum chromodynamics | 15,203 |
| Spin | 5,935 |
| Nuclear matter | 4,107 |
| Perturbative QCD | 2,868 |
| Quark-gluon plasma | 2,805 |
| Effective field theory | 2,497 |
| Lattice QCD | 2,455 |
| Shell model | 2,308 |
| Parity | 2,018 |
| Relativistic heavy-ion collisions | 1,969 |
| Quark matter | 1,653 |
| Nuclear fusion | 1,624 |
| Fission | 1,446 |
| Symmetry energy | 1,367 |
| Chiral perturbation theory | 1,328 |
| Quark model | 1,313 |
| Strong interaction | 951 |
| Beta decay | 842 |
| Generalized parton distributions | 658 |
| Nuclear reactions | 535 |

- **Topic pages generated:** 108 (concepts with >= 5 papers)

## L2: Citation graph

- **Total edges:** 351,338
- **Tier A (direct arXiv/DOI extraction from tex):** 378,256 candidate matches, producing unique edges
- **Tier B (author-year heuristic for external-bibliography papers):** 111,130 edges from 11,833 resolved cite keys (of 255,353 evaluated)
- **Papers with >= 1 edge:** 49,570 (81.2% of all papers)
- **Mean out-degree:** 10.5
- **Missing tex dirs:** 0 (all 61,357 papers with tex_dir entries were reachable on KINGSTON)

### Calibration

- **Primary check:** 1711.07540 -> 1511.03214 -- PRESENT (resolved via Tier B author-year heuristic; 1711.07540 uses external `\bibliography{}` and the cite key `Jin15b` resolves to the first-author given name "Jin" + year "2015").
- **Secondary samples:**
  - 2604.11226: 0 cites, 0 cited-by (paper may not have a tex_dir with resolvable references)
  - 2101.09497: 15 cites (including 1511.03214 and 1510.02602), 0 cited-by

### Known limitations

1. **Tier 3 single-phrase constraint:** The classification enforces >= 2 distinct phrases for fulltext-only concept assignments. The "one phrase hitting 3+ times" clause is not enforced, as it requires per-paper highlight() scanning which is prohibitively slow. This may cause moderate under-classification for concepts with only 1 match phrase.
2. **External bibliography papers (1.7%):** Papers using `\bibliography{}` without inline `\bibitem` entries cannot have citations extracted from their .tex alone. Tier B resolves `\cite{}` keys via first-author name + year heuristic. This is imprecise: authors with multiple same-year publications produce a group acceptance (all are linked). Author surname collisions across different authors are resolved by preferring the largest group.
3. **No .bbl files:** KINGSTON drive contains only .tex files (no .bib or .bbl). This limits citation extraction to what is literally in the .tex source.
4. **Unclassified rate (36.4%):** Above 30% target. Common patterns: pre-2007 arXiv IDs with non-standard terminology, papers matching only very specific PhySH labels, and papers outside the Nuclear Physics / nuclear-theory scope of the taxonomy.

## 5 example topic pages worth eyeballing

1. **breakup-reactions** (377 papers) -- strong tier-1/2 separation; Lei-Moro calibration papers all present.
2. **nuclear-reactions** (535 papers) -- broadest reaction concept; check that sub-concepts like breakup-reactions have non-overlapping coverage.
3. **nuclear-fusion** (1,624 papers) -- benefits from hand-crafted match rules (complete/incomplete fusion, fusion suppression).
4. **quantum-chromodynamics** (15,203 papers) -- largest concept; many hep-ph cross-over papers; negative filter is relevant.
5. **effective-field-theory** (2,497 papers) -- neighbor concept from Particles & Fields; useful bridge between NP and hep-ph content.

## File inventory

```
kb-wiki/
  physh-nuclear.yaml        L0: taxonomy + match rules (180 concepts)
  classification.json       L1: arxiv_id -> [{slug, tier}]
  citations.tsv             L2: citing TAB cited (351,338 edges)
  papers/                   existing paper pages with injected concepts: [...] and ## In-corpus citations
  topics/                   108 topic pages for concepts with >= 5 papers
  index.md                  PhySH discipline tree navigation
  crosslink-report.md       this file

scripts/
  build_physh_nuclear.py    build L0 YAML from PhySH JSON-LD
  kb_classify.py            run FTS5 classification
  build_wiki_layers.py      inject frontmatter, generate topics + index
  kb_citegraph.py           build citation graph from .tex files
  inject_citations.py       inject citation sections into paper pages
```

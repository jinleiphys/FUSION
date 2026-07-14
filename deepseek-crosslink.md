# Task brief: build the kb-wiki cross-link layers (L0 taxonomy rules, L1 classification + topic pages, L2 citation graph)

You are running inside opencode in `/Users/jinlei/Desktop/code/FUSION`. Execute top to bottom, autonomously. No em-dashes anywhere in anything you write. Design context: `kb-design.md`.

## Environment

- Paper pages: `kb-wiki/papers/*.md` (~53k now, growing to 61,059 by tomorrow morning; everything you build MUST be idempotent and re-runnable so the same commands cover the stragglers later).
- Corpus (READ ONLY, never write): `~/literature-corpus/corpus.db`; `papers` table has arxiv_id/title/abstract/date/categories/primary_cat/doi/tex_dir; `papers_fts` is FTS5 over title/authors/abstract/fulltext. Master id list: `kb-wiki/paper-list-full.txt`.
- PhySH SKOS dump: `data/physh.json` (JSON-LD; 3910 entities). Nuclear Physics discipline id: `0213a5a0-0742-43f3-804b-3ccea08a13c0`. Concepts carry `skos:broader`, prefLabel, altLabel; concepts link to disciplines via `https://physh.org/rdf/2018/01/01/core#inDiscipline`.
- Raw .tex (for L2): `/Volumes/KINGSTON/nucl-th_tex_files/<arxiv_id>/` (drive is mounted; skip and count missing dirs).
- Python: `/Users/jinlei/anaconda3/bin/python`. New scripts go in `scripts/` (kb_classify.py, kb_citegraph.py); extend, never fork, existing ones.
- Link style everywhere: RELATIVE markdown links like `[Title](../papers/1511.03214.md)` (renders on GitHub and in Obsidian). Not [[wikilinks]].

## Deliverable A (L0): `kb-wiki/physh-nuclear.yaml`

1. Extract the Nuclear Physics subtree: the 31 concepts tagged inDiscipline=Nuclear Physics, plus ALL descendants via skos:broader (expect ~176 total).
2. Neighbor whitelist: search the full dump for concepts labeled "Neutron stars", "Nucleosynthesis", "Effective field theory" (and close variants); include the ones that exist, list them in the report.
3. YAML entry per concept: `slug` (kebab-case of label), `physh_id`, `label`, `broader: [slugs]`, `narrower: [slugs]`, `match: [FTS5 query strings]`.
4. Seed `match` from prefLabel + all altLabels (each as a quoted phrase). Then apply these hand rules (they override; calibration depends on them):
   - breakup-reactions: add "inclusive breakup", "elastic breakup", "nonelastic breakup", "non-elastic breakup", "breakup cross section"
   - nuclear-fusion: add "complete fusion", "incomplete fusion", "fusion suppression"
   - direct-reactions: add "transfer reaction", "stripping reaction", "pickup reaction"
   - Do NOT let one concept's phrase be a bare word that is a substring of everyday physics prose (e.g. never a lone "spin" or "parity" as fulltext-tier phrase; such concepts match on title/abstract tiers only).
5. Matching tiers (encode in the classifier, document in the YAML header): tier 1 = phrase hits title; tier 2 = hits abstract; tier 3 = fulltext only, and REQUIRES at least 2 distinct match phrases hitting OR one phrase hitting 3+ times (suppresses passing mentions).
6. Negative filter (pilot lesson): a paper whose `primary_cat` starts with hep- or astro-ph can only receive reaction-family concepts at tier 1 or 2, never on a tier-3 fulltext match.

## Deliverable B (L1): classification, frontmatter tags, topic pages, navigation

1. `scripts/kb_classify.py`: run every concept's match queries against the corpus for all ids in paper-list-full.txt; write `kb-wiki/classification.json` mapping arxiv_id -> [{slug, tier}].
2. Inject into every EXISTING page under kb-wiki/papers/: a frontmatter line `concepts: [slug1, slug2, ...]` (sorted, tier-1/2 first). Idempotent: replace the line if present, insert before the closing `---` otherwise. Touch nothing else in the page.
3. Generate `kb-wiki/topics/<slug>.md` for every concept with >= 5 papers: title + PhySH lineage (linked broader/narrower topic pages) + paper count + the papers as relative links with year and title, newest first, capped at 100 (state the total when capped).
4. Generate `kb-wiki/index.md`: the discipline tree as navigation (31 top concepts grouped, each linking its topic page, with counts), plus links to the whitelisted neighbor topics.
5. Metrics for the report: per-concept counts (top 20 table), tier distribution, and the UNCLASSIFIED rate (papers with zero concepts). Target < 30% unclassified; if you exceed it, say so honestly and show 10 sample unclassified titles instead of loosening rules silently.

## Deliverable C (L2): in-corpus citation graph + page links

1. `scripts/kb_citegraph.py`: for each id, read every .tex/.bbl file in its tex_dir; extract (a) arXiv identifiers, old style `nucl-th/9608041` and new style `1234.56789`, (b) DOIs (`10.\S+`, strip trailing punctuation). Map DOIs to arxiv ids through the corpus `papers.doi` column (normalize case). Keep only edges where BOTH ends are corpus ids; drop self-citations; dedupe. Write `kb-wiki/citations.tsv` (citing TAB cited).
2. Inject into every existing paper page an `## In-corpus citations` section (idempotent: replace whole section if present, else append at end): `Cites (N):` up to 30 links, then `Cited by (M):` up to 30 links newest first; omit an empty direction; if both empty write `None detected within the corpus.`
3. Metrics: total edges, papers with >= 1 edge, mean out-degree, count of missing tex_dirs.
4. Hard calibration check: the edge `1711.07540 -> 1511.03214` MUST be present (the 2018 Lei-Moro paper cites the 2015 one; both are in the corpus). If it is absent your extractor is broken; debug before proceeding. Also report whatever in-corpus edges you find for 2604.11226 and 2101.09497 as a sanity sample.

## Wrap-up

1. `kb-wiki/crosslink-report.md`: what ran, all metrics above, calibration outcomes, 5 example topic pages worth eyeballing, known weaknesses.
2. Verify no em-dash anywhere you wrote: scan kb-wiki/topics/, index.md, the report, the YAML.
3. `git checkout -b kb-crosslink && git add -A && git commit -m "KB cross-link layers: PhySH rules, classification, topic pages, citation graph"`. Do NOT push. Do NOT touch corpus.db in write mode. Never print API keys.

## Done criteria

physh-nuclear.yaml + classification.json + citations.tsv + topics/ + index.md exist; frontmatter concepts and citation sections injected across existing pages; the mandatory citation edge verified; report written; committed on kb-crosslink; working tree clean.

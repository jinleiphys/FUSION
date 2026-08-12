---
name: kb-search
description: >-
  Search FUSION's offline literature knowledge base (kb-wiki): 61,059 arXiv nucl-th paper pages with digests, 108 PhySH topic pages, a 728k-edge citation graph, and typed semantic relations. Use for 查文献, 搜文献, 知识库, 谁引用了这篇, find papers about X, who cites this, cited-by, related work, literature survey, has anyone done X, offline literature search. Works with plain grep and awk, no network, no API key. A miss here is not proof that no paper exists.
---

# kb-search: the offline literature knowledge base

FUSION ships its literature knowledge base in the repository's `kb-wiki/`
directory. It is plain markdown and TSV, searched with grep and awk: no server,
no index to build, no network. This skill is the map: what is in there, how to
query each layer, and where the trust boundaries sit.

## What is in kb-wiki/

- `papers/<id>.md`: 61,059 pages, one per arXiv nucl-th paper (including
  cross-lists), covering arXiv from 1992 to mid-June 2026 (newest page dated
  2026-06-16). Frontmatter keys: `arxiv`, `title`, `authors`, `date`, `doi`,
  `categories`, `digest_model`, `digest_date`, and on 43,489 of the pages
  `concepts` (absent when no PhySH concept matched; not an error). Then the
  abstract, a full-text digest (Key claim / Method / Key numbers / Context),
  typed related-work links, and in-corpus citation lists.
- `topics/<slug>.md`: 108 PhySH concept pages: lineage, a newest-first paper
  list (capped at 100), and a landscape synthesis grounded in the topic's
  most-cited papers.
- `citations.tsv`: 727,841 citation edges, `citing<TAB>cited`, both ends
  arXiv ids, parsed from .tex bibliographies plus INSPIRE backfill. Mostly
  right, not error-free: an author-plus-year fallback resolves some bibitem
  keys to the wrong paper (a `\cite{Lei15}` meaning Leidemann 2015 can map to
  a Lei 2015 paper), and 4,093 edges point at a cited id that has no page.
  Treat an edge as a lead to verify against the citing paper's bibliography,
  not as a fact.
- `relations.tsv`: the same edges with a model-assigned type:
  `citing  cited  type  confidence  evidence`. Types and counts:
  `background` 485,740, `uses` 187,742, `compares` 20,767, `contrasts`
  17,505, `extends` 11,361, `applies` 4,726. Most were typed from the
  citation's surrounding text, but about 3,200 recent citing papers were
  typed from titles and abstracts only, and the evidence column is a model
  rationale that may paraphrase (253,032 rows carry a literal `[TARGET]`
  placeholder), not a verbatim quote.

Find the directory relative to this skill: `../../kb-wiki` from the directory
containing this SKILL.md, i.e. `kb-wiki/` at the repository root. Set
`KB=<that path>` once and use it in every command below.

## Prime directive

**Every hit you report must come from a grep or awk you actually ran in this
task, and must carry its arXiv id.** Never recall a paper from training memory
and present it as a knowledge-base hit.

**Cite the paper, never the page.** The digest sections are machine-generated
(model and date are in each page's frontmatter) and can be wrong. Before a
digest claim goes into anything that matters (a manuscript, a referee report, a
design decision), verify it against the actual paper on arXiv. Only the
frontmatter metadata comes straight from arXiv and can be taken as-is; the
prose is model-generated and the citation edges are mechanical but carry a
known error rate (see above), so both get verified before they are relied on.

**A miss is not proof.** The base is nucl-th and its cross-lists only, through
June 2026, matched lexically. A paper in hep-ph or astro-ph without a nucl-th
cross-list, newer than the snapshot, or phrased differently will not match.
Say this whenever you report a miss, and settle any "nobody has done X" claim
against INSPIRE or arXiv online, not here.

## Filename convention (the one trap)

Old-style arXiv ids contain a slash; filenames replace it with an underscore.
`nucl-th/0703083` lives at `papers/nucl-th_0703083.md`. The TSV files and the
frontmatter keep the slash form. So to go from an id found in `citations.tsv`
to its page: replace `/` with `_`, append `.md`. Some in-page relative links
still use the slash form and will not resolve as file paths; resolve ids
yourself instead of trusting page links.

## Recipes

All tested against the shipped base; a full `grep -r` over the 61k pages takes
a few seconds.

**Look up one paper** (id in either form):

```bash
cat $KB/papers/1511.03214.md            # new-style id
cat $KB/papers/nucl-th_0703083.md       # old-style nucl-th/0703083
```

**Find papers by title or author** (frontmatter is one line each, so anchor on
the key):

```bash
grep -rli 'title:.*breakup' $KB/papers | head -20
grep -rl  'authors:.*Moro'  $KB/papers | head -20
```

**Find papers about a topic or claim** (full-page grep; then read the hits'
Key claim sections, which are one-sentence distillations and much higher
precision than raw matches):

```bash
grep -rli 'inclusive breakup' $KB/papers | head -20
grep -A3 '## Key claim' $KB/papers/1511.03214.md
```

**Start from a concept instead of a phrase.** The 108 topic pages are curated
entry points with the field's top-cited and recent papers already ranked:

```bash
ls $KB/topics/
cat $KB/topics/breakup-reactions.md
```

**Who cites this paper / what does it cite** (in-corpus only):

```bash
awk -F'\t' '$2=="1511.03214"{print $1}' $KB/citations.tsv   # cited-by
awk -F'\t' '$1=="1511.03214"{print $2}' $KB/citations.tsv   # cites
```

An empty cited-by is NOT "uncited": the graph mostly holds in-base pairs, and
anything outside the base is invisible to it. And a nonempty answer is not yet
a fact: the very example above returns one `cites` edge, and that edge is an
author-key collision (it points at an unrelated soliton paper). Check the hit
against the citing paper's actual bibliography before repeating it.

**Who disputes, extends, or uses a paper.** Filter `relations.tsv` by type and
read the evidence sentence before believing the label:

```bash
awk -F'\t' '$2=="1511.03214" && $3=="contrasts"{print $1"\t"$5}' $KB/relations.tsv
awk -F'\t' '$2=="1511.03214" && $3=="extends"{print $1}'         $KB/relations.tsv
```

These relations are author-asserted: they record what the citing paper's text
says about the cited one, not an independent judgment, and the type labels are
model-assigned. `contrasts` is MEANT to flag disagreement with the cited paper
itself, but the classifier overfires on contrast-shaped prose: a sentence like
"by contrast, the cited model can also describe this" gets labeled `contrasts`
though nobody disagrees. So never report a dispute from the label alone; quote
the evidence column and, for anything that matters, the citing paper itself.
Two thirds of all edges are `background` (plain reference-list citations); that
is normal, not a defect.

## The three standard jobs

1. **Literature survey for an introduction or proposal.** Topic page first,
   then phrase greps, then follow `extends`/`applies` edges forward from the
   founding papers. Deliver arXiv ids plus one verified sentence each.
2. **Missing-citation scan for a draft.** Grep the draft's distinctive phrases
   and methods; separately, run cited-by on the draft's key references and look
   for papers that cite the same foundations but are absent from the draft's
   bibliography. Candidates are then verified online before anything is added.
3. **"Has anyone challenged X."** cited-by for descendants, `contrasts` filter
   for explicit disputes, each with its evidence sentence quoted so the user
   can judge the call.

## Scope

This skill is part of FUSION and carries its rules: the knowledge base is
distributed under the terms in `kb-wiki/README.md` (machine-generated digests,
provenance in every page's frontmatter, author removal on request). Nothing
here replaces reading the paper.

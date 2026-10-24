---
name: literature-search
description: >-
  Find and verify citations live against INSPIRE-HEP, arXiv and CrossRef, with an anti-hallucination protocol: every author, title, journal, volume, page, year, DOI and arXiv id is fetched, never recalled. Use before writing any citation, reference list or BibTeX entry, and to check one. Triggers: 查引用, 核对引用, 参考文献, 找BibTeX, 生成bib, 查DOI, 这篇文章的DOI, 引用格式, BibTeX, DOI, arXiv id, INSPIRE, cite this, verify this reference. For offline discovery in nucl-th (has anyone done X, who cites this, related work) use `kb-search` first; this skill then verifies what it finds and covers everything outside the corpus.
---

# Literature Search with Anti-Hallucination Protocol

## Prime Directive

**Every citation must be obtained through a live tool call against an authoritative database. Never generate a citation from training memory. Never fill in authors, journal, volume, page, year, or DOI fields by pattern matching. If a field cannot be verified from a fetched source, mark it `UNVERIFIED` in the output and say so in prose.**

This skill exists because scientific writing with hallucinated references is harmful: it wastes reviewer time, damages credibility, and in fields like nuclear physics it can actively mislead subsequent work. Fabricated references are the single most common failure mode of LLM-assisted literature work. This skill's job is to make that failure mode impossible to fall into accidentally.

Operationally, this means:

- Before outputting a citation, a fresh WebSearch or WebFetch must have occurred in the current task that returned the exact fields (authors, title, journal, volume, page, year, DOI or arXiv ID) in its response body.
- If the user says "I know there is a paper by Koning 2003 about optical potentials", do not emit a citation. Search. Then verify. Then emit.
- If a search returns no unambiguous match, say so. Do not guess the closest-sounding paper.
- **The user's `literature-wiki` is a local cache, not an authoritative database.** So is FUSION's `kb-wiki`. Their entries were written by an earlier model run and can carry stale, mistyped, or drifted fields (pre-publication volume/page, arXiv-era author lists, in-press DOIs, short-form APS DOIs recorded before the paper appeared). A wiki entry supplies a *candidate identifier*; it is never a verification anchor. Every wiki-sourced citation goes through Stage 2 fetch and Stage 3 verify against INSPIRE-HEP, CrossRef, or arXiv before it may be emitted, exactly like a cold search hit. The authoritative databases are the only sources allowed to populate emitted fields.

## Step 0 (MANDATORY FIRST STEP): local precheck

Before any external database call, before the Fast path, before Stage 1, check what is already on the local disk. FUSION has two local sources, and neither is authoritative; both supply **candidate identifiers** only.

1. **The user's own literature wiki, if they keep one.** Resolve its location exactly as the `literature-wiki` skill does: `LITERATURE_WIKI_PATH`, then `~/.literature-wiki-path`, then `~/research-wiki/`. If that directory exists and has a `sources/` folder, **call the `Skill` tool with `skill: "literature-wiki"`** as a real tool call (not a mental note), passing the request as `args`, e.g. `Skill(skill="literature-wiki", args="query for: <paper/topic>; return Hit/Related-only/Miss state")`. If no wiki exists, say so in one line ("no personal literature wiki found") and treat this source as a Miss. Most users do not keep one; that is not an error and needs no setup offer.
2. **FUSION's offline knowledge base, `kb-wiki/`** (61k arXiv nucl-th pages, read with the `kb-search` skill). Grep it for the requested paper or topic: `kb-wiki/papers/<arxiv-id>.md` frontmatter carries `arxiv`, `doi`, `title`, `authors`. A page is a machine-generated digest: its arXiv id and DOI are good candidates, its prose is never a citation source, and its metadata can be pre-publication. Outside nucl-th, or for anything newer than the corpus, expect a Miss.

A personal wiki queried first prevents three failure modes:

1. **Re-discovery**: returning a paper the user already read months ago, with no link to the existing wiki entry, forcing them to re-summarize.
2. **Citation drift**: emitting fresh BibTeX for a paper already cited in the wiki with a slightly different canonical form (e.g., short-form DOI vs. journal-volume-page), creating two coexisting references for the same work.
3. **Synthesis loss**: ignoring contradictions / cross-cuts the user already logged in the wiki (e.g., "Su 2025 contradicts Zhang 2022 on the 11 keV resonance"), so the search returns both papers as isolated hits and the user has to manually reconnect them.

The precheck is **mandatory regardless of request type** (single lookup, topic scan, citation prep, contradiction brief). It is fast: both sources are local markdown, not a network call.

### Precheck outputs and routing

For each item in the user's request (a paper name, a DOI, a topic), `literature-wiki` returns one of three states:

| State | Meaning | Routing |
|-------|---------|---------|
| **Hit** | Wiki has an entry for this exact paper | Take the wiki's stored DOI / arXiv ID / INSPIRE recid as a **candidate identifier** and route it straight into **Stage 2** (fetch) + **Stage 3** (verify). Stage 1 is skipped because the candidate is already identified; Stage 2 and Stage 3 are **never** skipped. Emit only the fields returned by the live fetch, and include the `[[wiki-entry-name]]` link alongside them. If the wiki entry has no identifier at all, treat it as a fuzzy candidate: use its title in a Stage 1 search. If the user wants *related* citations around the hit paper, continue to **Step 0.5 (reference harvest)** rather than going to external search. |
| **Related-only** | Wiki has no entry for the exact item, but related entries exist on the same topic / system / method | Surface the related entries to the user first ("you already have notes on X, Y, Z"), then **go to Step 0.5 to harvest references from those related entries** before any external search. External Fast path / Stage 1 is the *fallback*, not the next step. Harvested candidates still go through Stage 2 + Stage 3. After verification, recommend ingest via `literature-wiki` for the new item. |
| **Miss** | Wiki has no relevant content | Step 0.5 is empty by definition; proceed to Fast path / Stage 1 as normal. After verification, if the user keeps a wiki, suggest filing the new paper there with `literature-wiki`. |

**A `kb-wiki` page routes like a wiki Hit** (its `arxiv` / `doi` go straight to Stage 2), with two differences. Its in-corpus citation lists and `citations.tsv` neighbours can seed Step 0.5 the way a wiki entry's references do. And the defect report below is for the user's own wiki only: when a `kb-wiki` page disagrees with the database (typically an arXiv-era page for a paper since published), say so in one line and move on, because those pages are regenerated in bulk, not repaired by hand.

### What the precheck does and does not buy you

Step 0 saves **Stage 1** (discovery): for any paper the user has touched before, the wiki hands you the identifier, so no searching is needed. It buys nothing on Stage 2 and Stage 3. The wiki tells you *which* paper to verify; it never tells you that the paper's metadata is correct.

## Second job: this skill is the wiki's auditor

Verifying a wiki-sourced citation and auditing the wiki entry are the same tool calls. This skill is the **only** place in the user's toolchain where a wiki entry's stored metadata ever meets an authoritative database, so it is the only place a wiki error can be caught. `literature-wiki` writes entries but cannot check them; the writing skills consume `[[wikilinks]]` and trust them. If this skill verifies a citation, silently notices the wiki disagreed, and emits only the good citation, the wiki error survives and keeps poisoning every future entry that links to it. **Catching wiki defects is a required output of this skill, not a side effect.**

Consequences of that:

- The audit runs **whenever a wiki entry supplied a candidate**, on a Hit or on a harvested reference, whether or not the user asked anything about the wiki.
- A defect is reported **even when the emitted citation is fine.** The citation being correct means the verification worked; it says nothing about the entry the candidate came from.
- Silence has meaning: emitting a wiki-sourced citation with no defect line asserts that you compared the fetched record against the wiki fields and they agreed. Never let that assertion be free.

### Wiki-versus-database discrepancy: the database wins, and say so

When the Stage 2 fetch of a wiki-sourced identifier disagrees with the wiki entry on any emitted field (authors, title, journal, volume, page, year, DOI, arXiv ID), the fetched record is authoritative and the wiki entry is wrong. Three things must happen, in this order:

1. **Emit the fetched fields.** Never reconcile toward the wiki, never blend the two records.
2. **Emit a defect report** in the fixed format below.
3. **Recommend a wiki repair**: name the entry at `<wiki>/sources/<paper-id>.md` and offer to run `literature-wiki` to fix it. Do not edit the wiki from inside this skill; this skill reads the wiki and reports on it, `literature-wiki` owns writes.

### Defect report: required format

One block per defective entry, appended after the citations:

```
Wiki defect: [[<paper-id>]]  (severity: <D1..D6>)

| Field   | Wiki value            | Database value        | Emitted |
|---------|-----------------------|-----------------------|---------|
| volume  | (none, in press)      | 113                   | 113     |
| pages   | (none)                | 064618                | 064618  |
| DOI     | 10.48550/arXiv.2602.x | 10.1103/xxxx-yyyy     | 10.1103/xxxx-yyyy |

Cause: ingested at arXiv stage 2026-02, never re-synced after publication.
Repair: <wiki>/sources/<paper-id>.md needs a literature-wiki re-sync. Want me to run it?
```

Only list fields that actually differ. If the wiki and the database agree on everything, write one line instead: `Wiki entry [[<paper-id>]] checked against <database> record <id>: all fields agree.`

### Defect severity classes

| Class | Defect | Why it matters |
|-------|--------|----------------|
| **D6** | Author list truncated to "et al." or reordered vs the published version | Cosmetic in the wiki, wrong in any paper that inherits it |
| **D5** | Entry has no DOI / arXiv ID / recid at all | Unverifiable by design; every future use re-runs a full search |
| **D4** | Stored identifier does not resolve (404 at CrossRef / arXiv / INSPIRE) | The entry names nothing that exists |
| **D3** | Stale metadata: volume, page, year, DOI drifted after publication | Silently miscites a real paper. The most common class by far |
| **D2** | Guessed DOI: long-form `10.1103/PhysRev<X>.<vol>.<artid>` on a 2025+ APS paper | A fabricated identifier that was never caught. Never derivable, always a guess |
| **D1** | Stored identifier resolves to a **different paper** than the entry describes | Catastrophic. Every page linking `[[<paper-id>]]` has been citing the wrong work, invisibly |

D1 and D2 get reported prominently in prose, not just in the table: they are fabrications rather than drift, and they propagate to anything that ever linked the entry. For D1, say explicitly which other wiki pages may be affected if the wiki result listed them.

### Bypass: never silent

The only acceptable bypass is when the user explicitly says "skip the wiki" or "I know it is not in the wiki" or similar. In that case, log the bypass in your reply ("bypassing wiki precheck per user instruction") and proceed. Never silently skip Step 0.

## Step 0.5 (MANDATORY whenever the wiki result does not by itself satisfy the request): Reference harvest from wiki-known papers

If Step 0 surfaced any wiki entry related to the user's request, the references cited in those wiki entries (and in the underlying PDFs) are the **primary citation candidates** for the new request. External search is the *fallback*, not the default.

Exactly when this step is mandatory:

| Step 0 state | Request | Step 0.5 |
|---|---|---|
| **Hit** | User wanted only that one paper (single lookup by name / DOI / title) | **Skip.** The hit paper, once verified, is the whole answer. Nothing to harvest for. |
| **Hit** | User wanted that paper *plus* related work, or a citation list / topic scan / intro bibliography that the hit paper alone does not fill | **Mandatory.** Harvest the hit paper's references before any external search. |
| **Related-only** | Any | **Mandatory.** Harvest from the related entries before any external search. |
| **Miss** | Any | **Skip**, empty by definition. Proceed to Fast path / Stage 1. |

The single-lookup Hit is the only case where a non-empty wiki result goes straight past this step. If you are producing more than one citation, you are in a case where harvest is mandatory.

### Why harvest before searching

When the user asks for references on topic X and has already read N papers on topic X, those N papers' bibliographies are a *better* candidate pool than a cold external search, because they are:

- **Pre-filtered by relevance**: the user kept the paper and ingested it.
- **Pre-filtered by quality**: peer-reviewed papers cite the literature they consider load-bearing.
- **Pre-clustered topically**: papers on topic X cite each other plus the foundational literature on X, exposing thematic clusters.
- **Pre-vetted in the wiki summary**: the `## References tiered` block in each wiki entry already ranks references as foundation / high / medium priority (author-judged signal that no external search reproduces).

### Harvest procedure

For each relevant wiki entry from Step 0:

1. **Read the wiki entry's `## References tiered` section** (in `<wiki>/sources/<paper-id>.md`). Extract every reference listed there. References that point to an existing wiki entry via wikilink (`[[1985-prc-...]]`) are already in the user's corpus; these are the strongest primary candidates.
2. **If the user's topic is more specific than the wiki entry's headline scope**, open the raw PDF (`<wiki>/raw/<paper-id>.pdf` via Read) and search for the section(s) discussing the user's topic. Collect references cited in those sections that did NOT appear in the curated `## References tiered`. These are *contextual* references the wiki summary did not surface but that the parent paper cites near the topic of interest.
3. Pool the references from steps 1 and 2 into a **primary candidate list**. Deduplicate by DOI / journal-volume-page.

### Routing after harvest

- **Primary list is non-empty**: Treat each entry in the primary list as a candidate going directly into Stage 2 (Fetch authoritative record). **Skip Stage 1**, the candidate set is already curated. Verify and emit each one normally. In the output, annotate each citation with the wiki-known paper(s) it was harvested from (e.g., `Harvested from: [[2023-prc-iav-cut-surface-approximation-liu-junzhe]]`). If after harvest + verify the user's request is fully satisfied, **do not** run external search.
- **Primary list is empty or insufficient** (rare; happens when wiki entries have no curated references block AND the raw PDF is not accessible, or when the user explicitly asks for *recent* literature past the wiki-known papers' publication date): fall back to the normal Stage 1 → Stage 2 → Stage 3 → Stage 4 workflow against external databases. State this transition explicitly in the reply ("wiki references exhausted; falling back to external search").

### Failure mode this blocks

Without Step 0.5, asking "give me 8 references for the THM intro" against a wiki that already has 12 THM papers ingested can emit 8 fresh external hits while completely missing the canonical Baur / La Cognata / Tribble cluster that the user already has notes on. The output looks plausible but is disconnected from the user's actual literature corpus, exactly the synthesis-loss failure mode Step 0 was meant to prevent, escalated to the citation list itself.

### Bypass: never silent

If the user explicitly asks for fresh external discovery ("only show me papers I have NOT read", "search arXiv directly"), log the bypass and skip Step 0.5. Otherwise harvest first.

## Fast path for direct identifiers

Steps 0 and 0.5 have already run. If the wiki returned a Hit, its stored identifier is your direct identifier: use the same fetch commands below, then verify. If Step 0.5 produced a primary candidate list, route those candidates directly into Stage 2 below. Otherwise scan the user's request itself for a direct identifier.

Whatever supplied the identifier (user, wiki entry, harvested reference list), if one is present, skip Stage 1 and go straight to Stage 2 Fetch:

- DOI pattern `10\.\d{4,9}/[\S]+` present: `python scripts/verify_doi.py <DOI>`
- arXiv ID pattern `\d{4}\.\d{4,5}` or `[a-z\-]+/\d{7}`: `python scripts/arxiv_search.py --id <ID>`
- INSPIRE record URL: fetch the record JSON directly

This saves roughly a factor of 2 in time and tokens on the common single-lookup case.

## Source selection

Pick the primary database based on the topic, fall back if the primary returns nothing conclusive.

| Topic | Primary | Secondary | Tertiary |
|-------|---------|-----------|----------|
| Nuclear and high-energy physics | INSPIRE-HEP | arXiv | Google Scholar |
| **Nuclear astrophysics** | **INSPIRE-HEP + CrossRef Nature-sweep (both, parallel)** | ADS (adsabs) | arXiv |
| Machine learning, computer science | Google Scholar | arXiv | Semantic Scholar |
| Condensed matter, AMO, general physics | arXiv | Google Scholar | Semantic Scholar |
| Chemistry, biology, medicine | Google Scholar | Semantic Scholar | PubMed |
| Recent preprints (< 6 months) | arXiv | Primary source as secondary | - |
| Cross-disciplinary, unclear topic | Semantic Scholar | Google Scholar | - |

For INSPIRE-HEP, arXiv, and Semantic Scholar the search can happen through public HTTP APIs (see `references/search-apis.md`). For Google Scholar use WebSearch with a site-scoped query, never reconstruct.

### Flagship cross-venue sweep for nuclear astrophysics

Key high-impact results in nuclear astrophysics (stellar reactions, nucleosynthesis, cross sections at astrophysical energies, CNO cycle, s-process, r-process, Pop III stars, underground lab experiments like JUNA/LUNA) routinely appear in **Nature, Nature Astronomy, Science, Nature Physics** in addition to PRC/PRL. INSPIRE-HEP indexes these with significant delay or sometimes not at all. Topic scans on nuclear astrophysics MUST run a parallel CrossRef journal-title sweep, not only INSPIRE.

Use `scripts/crossref_search.py` (see `references/search-apis.md` for the full CrossRef query syntax):

```
python scripts/crossref_search.py --journal "Nature" --title "<topic keywords>" --year-from 2020
python scripts/crossref_search.py --journal "Nature Astronomy" --title "<topic keywords>"
python scripts/crossref_search.py --journal "Science" --title "<topic keywords>"
```

Any CrossRef hit that survived verification is citation-grade, regardless of whether INSPIRE has indexed it.

### APS short-form DOIs (the default since 2025)

APS **switched all its journals to short-form DOIs starting in 2025**. This is not an edge case, it is the new normal. Every PRL, PRC, PRD, PRE, RMP, PRA paper from 2025 onward uses the format `10.1103/<alphanumeric>` (e.g., `10.1103/cq71-jy7s` for Su et al., PRL 135, 182701, 2025; `10.1103/8lm7-gs18` for Acharya et al., Solar Fusion III, RMP 97, 035002, 2025). The old `10.1103/PhysRev<X>.<vol>.<artid>` pattern still works for papers published before 2025 but cannot be guessed for new papers.

Operational consequences:

- **Never guess a DOI for a 2025+ APS paper.** The old journal-volume-page pattern does not produce a valid DOI anymore. A guess will 404 at CrossRef, and worse, the user may interpret the guess as verified.
- **INSPIRE is the most reliable path for recent APS papers**, because INSPIRE stores both the short DOI and the conventional journal-volume-page coordinates, so you can search by `j:Phys.Rev.Lett.,<vol>,<artid>` and pull the short DOI out of the returned record.
- **CrossRef title search is unreliable for short-DOI APS papers** because titles often contain MathML (`<mml:math>...</mml:math>`) that degrades plain-text relevance ranking. Use CrossRef only after you have the DOI in hand, not as a search entry point.

For any topic scan whose matching paper could be from 2025 onward, run INSPIRE first:

```
python scripts/crossref_search.py --journal "Physical Review Letters" --title "<topic>" --year-from <current_year-1>
python scripts/crossref_search.py --journal "Physical Review C" --title "<topic>" --year-from <current_year-1>
```

If CrossRef surfaces a recent paper that INSPIRE missed, the CrossRef record is authoritative for the metadata. Emit from the CrossRef fetch, do not wait for INSPIRE to catch up.

**Fallback to Google Scholar Discovery when CrossRef title search fails**: APS short-DOI papers often have MathML in their titles (e.g., `<mml:math>...</mml:math>19F(p,αγ)16O...`), which degrades CrossRef's plain-text relevance scoring. For topic scans where a very recent paper is expected but CrossRef title search comes back empty or irrelevant, invoke the Discovery sub-stage of the core workflow: `WebFetch` Google Scholar with natural-language topic keywords, extract candidate titles from snippets, then feed those titles back into CrossRef `--title` searches or directly into `verify_doi.py` if the snippet contains a DOI. Do not emit Scholar-derived fields into the final BibTeX; Scholar is only for Discovery.

### Group-series coverage for contested reactions

When the user's query describes a controversy or disagreement between two or more experimental groups on a specific reaction, a single flagship paper per group is **not enough**. Groups normally publish their measurements in a time series across multiple venues: a short-form announcement (PRL), a long-form companion with full systematics (PRC or PRD), sometimes a Nature or Science paper for the high-impact slice, and later refinements or reviews. Citing only the Nature paper or only the most recent PRL misleads the reader about which paper actually carries the quantitative claim that is in dispute.

For each group identified in the controversy, do an **exhaustive author-plus-reaction sweep**:

```
python scripts/inspire_search.py --size 20 "a:<lead_author> and t:<reaction or key isotope>"
python scripts/crossref_search.py --author "<lead_author>" --title "<reaction>" --year-from <controversy_start_year - 2>
```

From the results, pick at a minimum:

1. The **earliest announcement** of the group's measurement on that reaction (often a PRL or Letters-class paper).
2. The **long-form companion** with full systematics (often a PRC or PRD, same year or the year after).
3. Any **flagship venue paper** (Nature, Science, Nature Astronomy) if it exists, with the caveat that flagship papers often cover a *different channel or narrative framing* than the technical companion. Do not assume the flagship is the one with the disputed measurement.
4. The **most recent update or review** (annual review, later R-matrix re-analysis, technical erratum).

This sweep prevents a failure mode observed in practice: a naive scan that returns "Zhang 2022 Nature" as the JUNA paper misses the JUNA-specific 19F(p,alpha-gamma)16O PRL and PRC papers that actually carry the direct (p,alpha) measurement being disputed. The Nature paper measures a related but different channel.

Red flag to check for: if the user mentioned a direct vs indirect measurement disagreement, and your output cites only one paper per group, you probably missed the time series. Rerun.

## Discovery versus Verification

Before entering the core workflow, classify the request:

- **Precise request**: user named an author + year + venue, or gave a DOI / arXiv ID / title. Go straight to Stage 2 (Fetch) of the core workflow against INSPIRE-HEP, CrossRef, or arXiv. Do not waste a Google round-trip.
- **Fuzzy request**: user only gave a topic, a vague author memory ("the paper Bertulani wrote about THM a few years ago"), or a description of a result. Use **Google Scholar (via WebSearch or WebFetch)** in a dedicated Discovery sub-stage to produce candidate titles, then feed those titles into the core workflow's Stage 2 for verified metadata.

The critical rule: **Google Scholar outputs are never allowed into emitted citations directly**. They are used to discover what the paper is called, then thrown away. The authoritative metadata always comes from INSPIRE-HEP, CrossRef, or arXiv. This protects against the HTML-parsing failure modes that give the model room to fabricate missing fields.

### Discovery sub-stage (fuzzy requests only)

```
WebSearch: site:scholar.google.com <keywords>
```

or

```
WebFetch: https://scholar.google.com/scholar?q=<URL-encoded keywords>
```

Extract **only the titles** from the results. Do not extract authors, journal, year, or citation count from Scholar. Those fields come back less reliably than title and are the ones most likely to be silently wrong.

For each promising candidate title, move to Stage 2 of the core workflow: INSPIRE search by title, or CrossRef lookup if a DOI appears in the snippet, or arXiv search if the result is a preprint.

If Discovery surfaces a candidate whose verified record (Stage 2) disagrees with the Scholar snippet on year or volume, trust the verified record. Scholar snippets are not citation-grade data.

## Core workflow

Every literature request, precise or fuzzy, goes through these four stages once **Step 0 (wiki precheck)** and **Step 0.5 (reference harvest, when wiki returned Hit or Related-only)** have run and (if needed) the Discovery sub-stage has produced candidate titles. Steps 0 and 0.5 are not part of the four stages below; they precede them, and all they can short-circuit is **Stage 1**, by handing you an identifier or a curated candidate list instead of a search.

**Stage 2 (fetch), Stage 3 (verify), and Stage 4 (emit) run for every single citation, with no exception and no upstream source that exempts them.** Wiki hits, harvested references, user-supplied DOIs, and cold search results all converge here and are treated identically. A citation that reaches Stage 4 without a Stage 2 fetch in this turn's transcript is a protocol violation, and the whole output is unsafe to emit.

### Stage 1: Search

Call WebSearch or the appropriate source API to obtain a candidate list. Use explicit query operators.

- INSPIRE-HEP: `https://inspirehep.net/api/literature?q=<query>&format=json&size=10`
- arXiv: `https://export.arxiv.org/api/query?search_query=<query>&max_results=10`
- Semantic Scholar: `https://api.semanticscholar.org/graph/v1/paper/search?query=<query>&limit=10`
- Google Scholar: use WebSearch with the query prefix `scholar.google.com` or fetch `https://scholar.google.com/scholar?q=<query>`

Good query patterns:

- Nuclear physics author: `a:Koning and a:Delaroche and t:optical`
- Nuclear physics by journal-volume-page: `j:Phys.Rev.C,92,061602`
- Recent topic scan: `t:"trojan horse" and de > 2020`
- By DOI: direct fetch `https://doi.org/<DOI>`
- By arXiv ID: direct fetch `https://arxiv.org/abs/<id>`

Save the candidate list. Do not yet emit citations.

### Stage 2: Fetch authoritative record

For each candidate that looks promising, fetch the authoritative record page via WebFetch:

- INSPIRE-HEP: `https://inspirehep.net/literature/<recid>`, and for machine-readable data append `?format=json`
- arXiv: `https://arxiv.org/abs/<id>` for human page, `https://export.arxiv.org/api/query?id_list=<id>` for atom XML
- DOI: `https://api.crossref.org/works/<DOI>` returns verified JSON metadata
- Semantic Scholar: `https://api.semanticscholar.org/graph/v1/paper/<paperId>?fields=title,authors,venue,year,externalIds,abstract`

Extract the verified fields from the fetched response: `authors`, `title`, `journal_abbrev`, `volume`, `pages`, `year`, `DOI`, `arxiv_id`, `abstract` (if needed). These are the only fields allowed into the output.

If a WebFetch returns a 404, a blocked page, or a page that does not match the search candidate, treat it as unverified. Retry a different query or drop the candidate.

### Stage 3: Verify

Cross-check the fetched fields against the original query intent. For every emitted citation, the following must be true:

- Title in the fetched record contains at least 60% of the distinctive words the user asked about.
- Authors in the fetched record include at least one name the user named (if the user named anyone).
- Year is within the range the user asked about (if specified).
- DOI resolves: optional stronger check via `https://doi.org/<DOI>` returning 200 or 302.
- arXiv ID exists: optional stronger check via HEAD on the abs page.

If any check fails, the candidate is rejected. Say so in the output and try again or admit failure.

For a candidate that came from the wiki or from a harvested reference list rather than from the user's own words, run the same checks against the **wiki's stored fields**, then apply the discrepancy rule from Step 0: a mismatch means the wiki entry is wrong, not that the fetched record is a bad match. Only reject the record if it is a genuinely different paper (different title, different authors), which means the wiki's stored identifier itself points somewhere wrong: report that loudly, it is the most damaging kind of wiki error.

For stronger confidence on DOIs, run the helper script:

```bash
python scripts/verify_doi.py <DOI>
```

It hits the CrossRef API and returns the verified metadata as JSON, or exits non-zero if the DOI is invalid.

### Stage 4: Emit

Generate the citation in the requested format. Default formats live in `references/output-formats.md`. The default is BibTeX for physics users and a compact markdown list when the user is browsing results.

Every BibTeX entry must include a `url` field pointing at the authoritative landing page (INSPIRE record, arXiv abs, or DOI URL). This gives the user a one-click way to sanity-check the output.

**Final gate, run before writing any citation into the reply.** Walk the emit list one entry at a time. For each entry, write out a Stage 2 evidence line naming the concrete artifact that carried the fields:

```
Stage2 evidence: <tool call> -> <record id> -> <fields it returned>
e.g.  WebFetch inspirehep.net/api/literature/2812345?format=json -> recid 2812345 -> authors,title,journal,volume,pages,year,DOI
e.g.  python scripts/verify_doi.py 10.1103/xxxx-yyyy -> CrossRef 200 -> authors,title,journal,volume,pages,year
```

The evidence line must point at a call that appears in **this turn's transcript** and returned **those specific fields in its response body**. Naming a tool you did not call, or one that returned something else, is fabrication wearing a checklist. If you cannot write the line honestly, the entry does not get emitted: go fetch it, or drop it and say why.

Do not sample the list, do not trust that upstream steps covered it, and in particular do not let an entry through because the wiki, a harvested reference, or the user's own message already stated its fields. A citation whose evidence line would have to read "wiki entry" or "user said so" is not a citation this skill emits. The evidence lines are working notes: keep them out of the final reply unless the user asks to see the audit trail, but do not emit a citation you could not have written one for.

## What the output must always contain

Regardless of format, every citation emitted by this skill carries these fields:

1. The full author list from the fetched record, not abbreviated to "et al." unless there are more than ten authors.
2. The complete title exactly as in the fetched record.
3. Journal, volume, pages, year, all from the fetched record.
4. At least one of: DOI, arXiv ID, INSPIRE record ID. These are the verification anchors.
5. A `source` line stating which database provided the record and the date of retrieval. Example: `Source: INSPIRE-HEP record 1111111, fetched 2026-04-24`.

For compact markdown output, shorten the author list to first author and year, but the verification anchor (DOI or arXiv ID) must still appear in every bullet.

## When verification fails

Three failure modes and their handling:

- **Search returns nothing**: Tell the user "No match found on <database> for query <q>". Suggest a broader query or a different database. Do not invent a reference that "probably exists".
- **Search returns ambiguous matches**: Tell the user "Candidate A, B, C all plausible". Show the distinguishing fields (title, year, journal). Ask which one.
- **Fetched record contradicts user assertion**: If the user said "Koning 2002 optical potential PRC 68" but the fetched record shows Koning-Delaroche 2003 Nucl. Phys. A 713, 231, say so: "The paper you are likely remembering is Koning and Delaroche 2003 Nucl. Phys. A 713, 231, not PRC 68. Here is the verified citation."

Correcting the user gently but firmly is part of the job.

## Output formats

See `references/output-formats.md` for full templates. Brief summary:

- **BibTeX** (default for LaTeX users): one `@article` per citation, with `url` field.
- **Markdown list**: one bullet per citation, short form with DOI or arXiv link.
- **Comparison table**: for topic scans, a table with columns Author/Year | Method | Key finding | Venue | Link.
- **Contradiction brief**: when the user asks to identify conflicting results, a two-column side-by-side of claim versus counter-claim, each with its own verified citation.

## Usage patterns

Every pattern below starts with the Step 0 local precheck (`Skill(literature-wiki)` when the user keeps a wiki, plus a `kb-wiki` grep). There is no usage pattern of this skill that begins with a search.

### Single lookup, wiki Hit

User: "Find me the Lei-Moro 2018 PRC on post-prior equivalence with complex potentials."

Workflow: `Skill(literature-wiki)` returns a Hit with a stored DOI. Step 0.5 is skipped (single lookup, the hit paper is the whole answer). The stored DOI goes into Stage 2: `python scripts/verify_doi.py <DOI>`. Stage 3 checks the fetched record against both the user's words and the wiki's stored fields. Stage 4 emits BibTeX built **only** from the CrossRef response, plus the `[[wiki-entry]]` link, plus a one-line audit result (all fields agree, or a defect block).

### Single lookup, wiki Miss

User: same request, but the wiki has nothing.

Workflow: `Skill(literature-wiki)` returns Miss. Step 0.5 is empty. INSPIRE search `a:Lei and a:Moro and de:2018 and t:post prior`, fetch top record, verify, emit BibTeX. Recommend ingest at the end.

### Topic scan

User: "What has been published on THM extraction of 19F(p,alpha) in the last five years?"

Workflow: `Skill(literature-wiki)` first. Any Hit or Related-only makes Step 0.5 mandatory (this produces more than one citation), so harvest the wiki entries' references into the primary candidate list. Then INSPIRE search `t:"trojan horse" and t:19F and de > 2020` to cover what the wiki does not hold. Every candidate from both routes, wiki-harvested and freshly searched, goes through Stage 2 + Stage 3 identically. Drop false positives, present as comparison table, and audit each wiki-sourced entry.

### Preparing citations for a draft

User: "I am writing the introduction of the THM PRL, give me 8 to 10 key references for THM methodology."

Workflow: `Skill(literature-wiki)` first; with 8 to 10 slots to fill, Step 0.5 is mandatory on any non-Miss. Plan the citation skeleton (Baur 1986 original, one recent review, two foundational papers, two benchmark experiments, two HOES formalism papers, one contested recent result), then fill each slot from the harvested primary list before searching externally for the slots it cannot fill. Verify every slot through Stage 2 + Stage 3 regardless of which route produced it. Present as BibTeX block plus a two-sentence annotation per entry, plus any wiki defect blocks. This is the highest-stakes pattern for the audit: these citations are going into a Letter.

### Contradiction identification

User: "Is there a paper that contradicts the JUNA 2022 Nature result on the 11 keV resonance?"

Workflow: `Skill(literature-wiki)` first, which is also where the user's own logged contradictions live and may answer the question directly. Fetch the JUNA 2022 record for context (verify it, wiki Hit or not). Harvest the wiki's related entries, then search for papers that cite it with opposing claims, and look for THM re-analyses. Emit a contradiction brief showing both sides with verified citations.

## Anti-patterns

Signs that the anti-hallucination protocol is being violated. If any of these happen, stop and restart the workflow.

- Emitting a citation in the same turn as the search, without a fetched landing page.
- Filling in a volume or page number "from memory" when the search result only showed a title.
- Using "et al." where the author list was not actually fetched.
- Silently promoting a low-confidence search hit to a cited claim.
- Inventing a DOI or arXiv ID that was not returned by any tool call.
- Asserting the abstract or conclusion of a paper without having fetched its text or its authoritative abstract field.
- **Emitting a citation whose authors, volume, or page fields came from a Google Scholar snippet rather than from INSPIRE-HEP, CrossRef, or arXiv**. Scholar is for Discovery only, never for Emit.
- **Emitting a wiki-sourced citation without a live Stage 2 fetch of its identifier in this turn.** A Step 0 Hit shortcuts Stage 1 only. Treating the wiki entry as its own verification anchor, copying its BibTeX through, or writing `Source: wiki entry ...` all mean an unverified record reached the output wearing the skill's verified badge. The wiki is a cache written by a previous run; papers ingested in press or from arXiv drift once they publish.
- **Silently reconciling a fetched record toward the wiki**, or quietly "correcting" a field the database disagrees with. The database wins, and the disagreement is reported to the user with a repair recommendation, never absorbed.
- **Noticing a wiki defect and not reporting it because the user only asked for a citation.** Auditing the wiki is this skill's second job, not an optional courtesy. The emitted citation being correct is not a reason to drop the defect block: the entry stays broken for every future reader, and this skill is the only thing in the toolchain positioned to catch it.
- **Writing a Stage 2 evidence line for a call you did not make**, or one that returned different fields than you claim. This converts the final gate from a check into a rubber stamp, which is worse than having no gate, because the output now carries a verification claim it did not earn.
- **Skipping Step 0 (the `literature-wiki` precheck) silently.** Going straight to Fast path or Stage 1 without first checking the wiki violates the hard coupling between this skill and `literature-wiki`. The only acceptable bypass is explicit user opt-out, logged in your reply.
- **Skipping Step 0.5 (reference harvest) when the wiki result did not by itself satisfy the request.** Going from a non-empty wiki result straight to external search misses the user's already-vetted corpus of references on the topic and produces a citation list disconnected from the wiki, the synthesis-loss failure mode at the citation level. Harvest first; external search is the fallback. The one exemption is a single-lookup Hit, where the verified hit paper is the entire answer.

If the user presses for a citation that cannot be verified, the correct answer is "I could not verify this, here is the closest thing I could find, please check manually". The incorrect answer is to produce a plausible-looking citation.

## Language and style

- All generated prose must not contain em-dashes. Use commas or semicolons.
- In BibTeX and compact outputs, prefer LaTeX-safe accented characters (`{\'a}` not direct UTF-8) if the citation will go into a paper.
- In Chinese conversation, return the bibliography block in English (as it will appear in the paper) but explain retrieval and verification results in Chinese if the user is writing in Chinese.

## Related reference files

- `references/search-apis.md`: full query syntax for INSPIRE-HEP, arXiv, CrossRef, Semantic Scholar, including worked examples. Read this whenever a non-trivial search is needed.
- `references/output-formats.md`: BibTeX, markdown list, comparison table, contradiction brief templates. Read this before emitting output.
- `references/verification-checklist.md`: step-by-step verification protocol with examples of failed and passed cases. Read this when in doubt about whether a fetched record is a true match.
- `scripts/verify_doi.py`: command-line DOI verifier against CrossRef API.
- `scripts/inspire_search.py`: command-line INSPIRE-HEP search, returns JSON.
- `scripts/arxiv_search.py`: command-line arXiv search via Atom API.

# Search API Reference

Complete query syntax and worked examples for each supported database. Read this file whenever the top-level workflow in SKILL.md is insufficient.

## Table of contents

1. [INSPIRE-HEP](#inspire-hep)
2. [arXiv](#arxiv)
3. [CrossRef](#crossref)
4. [Semantic Scholar](#semantic-scholar)
5. [Google Scholar via WebSearch](#google-scholar-via-websearch)
6. [ADS (Astrophysics Data System)](#ads)

---

## INSPIRE-HEP

INSPIRE is the canonical database for nuclear and high-energy physics. It indexes PRC, PRL, NPA, PLB, arXiv nucl-th/nucl-ex/hep-*, conference proceedings, and theses.

### Base endpoint

```
https://inspirehep.net/api/literature?q=<QUERY>&format=json&size=<N>&fields=<FIELDS>
```

- `q`: the search query in INSPIRE search syntax
- `size`: max results per page, up to 250
- `fields`: comma-separated list of fields to return. Useful: `titles,authors,publication_info,arxiv_eprints,dois,control_number,abstracts`
- `format=json`: return JSON

### Search operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `a:<name>` | author | `a:Lei` |
| `a:<first>,<last>` | author with initials | `a:A.M.Moro` |
| `t:<word>` | title contains | `t:optical potential` |
| `j:<journal>` | journal, specific | `j:Phys.Rev.C` |
| `j:<j>,<v>,<p>` | journal-volume-page | `j:Phys.Rev.C,92,061602` |
| `de:<year>` or `de > <year>` | date | `de:2018` or `de > 2020` |
| `eprint:<arxiv>` | arXiv ID | `eprint:1812.05000` |
| `doi:<DOI>` | DOI | `doi:10.1103/PhysRevC.97.011601` |
| `citedby:recid:<id>` | cited by a given record | `citedby:recid:1111111` |
| `refersto:recid:<id>` | refers to a given record | `refersto:recid:1111111` |
| `collection:citeable` | exclude proceedings | add to any query to restrict |

Combine with `and`, `or`, `not`. Example:

```
a:Lei and a:Moro and t:post-prior and de > 2014
```

### Fetch a single record

By control number (INSPIRE internal ID):

```
https://inspirehep.net/api/literature/1111111?format=json
```

By DOI:

```
https://inspirehep.net/api/doi/10.1103/PhysRevC.97.011601
```

By arXiv ID:

```
https://inspirehep.net/api/arxiv/1812.05000
```

### Response parsing

The JSON response has a top-level `hits.hits` array. Each hit contains `metadata`, with relevant keys:

- `metadata.titles[0].title`: title
- `metadata.authors[].full_name`: author full names
- `metadata.publication_info[0]`: `journal_title`, `journal_volume`, `page_start`, `page_end`, `year`
- `metadata.arxiv_eprints[0].value`: arXiv ID
- `metadata.dois[0].value`: DOI
- `metadata.control_number`: INSPIRE record ID
- `metadata.abstracts[0].value`: abstract text

### Worked example: find Lei-Moro 2018 PRC

Query:

```
https://inspirehep.net/api/literature?q=a%3ALei+and+a%3AMoro+and+de%3A2018+and+t%3Apost-prior&format=json&size=5&fields=titles,authors,publication_info,dois,arxiv_eprints,control_number
```

Expected hit: record 1643611 or similar, title "Post-prior equivalence for transfer reactions with complex potentials", authors Lei and Moro, journal Phys.Rev.C, volume 97, page 011601, year 2018, DOI 10.1103/PhysRevC.97.011601.

Verify: the DOI field must match exactly. If not, pick the next hit.

---

## arXiv

arXiv is canonical for preprints and latest versions of nearly all physics papers. Use for finding papers not yet on INSPIRE and for accessing PDFs.

### Base endpoint (Atom XML)

```
https://export.arxiv.org/api/query?search_query=<QUERY>&start=0&max_results=<N>
```

Response is Atom XML. Each `<entry>` has `<title>`, `<author><name>`, `<published>`, `<id>` (which is the arXiv URL containing the ID), `<summary>` (abstract), `<arxiv:doi>` (if known), `<arxiv:journal_ref>` (if published).

### Search operators

| Field | Prefix | Example |
|-------|--------|---------|
| All fields | `all:` | `all:trojan+horse` |
| Title | `ti:` | `ti:post+prior` |
| Author | `au:` | `au:Moro` |
| Abstract | `abs:` | `abs:CDCC` |
| Category | `cat:` | `cat:nucl-th` |

Combine with `+AND+`, `+OR+`, `+ANDNOT+`.

### Worked example: find a specific preprint

```
https://export.arxiv.org/api/query?search_query=ti:%22post-prior+equivalence%22+AND+au:Lei&max_results=5
```

Extract from the Atom: `<id>http://arxiv.org/abs/1712.02005v1</id>` gives arXiv ID `1712.02005`. Strip `v1` when storing canonical ID.

### Direct fetch by ID

```
https://export.arxiv.org/api/query?id_list=1712.02005
```

---

## CrossRef

CrossRef is the authoritative source for DOI resolution. Use it to verify a DOI and retrieve the canonical metadata the publisher registered.

### By DOI

```
https://api.crossref.org/works/<DOI>
```

Response JSON has `message.title`, `message.author`, `message.container-title` (journal), `message.volume`, `message.page`, `message.published`, `message.DOI`.

### Search by title, journal, author, and year

```
https://api.crossref.org/works?query.title=<t>&query.container-title=<j>&query.author=<a>&filter=from-pub-date:<y1>,until-pub-date:<y2>&rows=<n>
```

CrossRef is good for last-mile verification of a known DOI but its title search is also the **only practical way to catch recent papers that INSPIRE has not yet indexed**, and the **only way to sweep Nature, Nature Astronomy, Science** for nuclear astrophysics topics (INSPIRE coverage of these venues is spotty).

Use the helper script:

```bash
python scripts/crossref_search.py --title "19F p alpha 16O trojan horse" --journal "Physical Review Letters" --year-from 2024
python scripts/crossref_search.py --title "CNO breakout first stars 19F" --journal "Nature" --year-from 2020
python scripts/crossref_search.py --title "fluorine destruction" --journal "Nature Astronomy"
```

The script returns normalized JSON with DOI, title, authors, journal, volume, pages, year, type. Use the DOI in the result as the verification anchor and feed it back through `verify_doi.py` for idempotency plus local caching.

### Nuclear-astrophysics flagship-venue patterns

Worked patterns that catch papers INSPIRE commonly misses:

| Goal | Command |
|------|---------|
| JUNA Nature 2022 paper on 19F(p,gamma)20Ne | `crossref_search.py --title "19F proton gamma 20Ne CNO breakout" --journal "Nature"` |
| CNO breakout in first stars | `crossref_search.py --title "CNO breakout first stars" --journal "Nature" --year-from 2020` |
| LUNA underground astrophysics Nature Astronomy | `crossref_search.py --title "<reaction>" --journal "Nature Astronomy"` |
| Population III star observation landmark | `crossref_search.py --title "<topic>" --journal "Nature"` |

### Recent APS short-DOI papers

APS has adopted short-form DOIs of pattern `10.1103/<alphanumeric>` (e.g., `cq71-jy7s` for Su et al. PRL 135, 182701, 2025). INSPIRE may lag by weeks. Direct CrossRef query:

```bash
python scripts/crossref_search.py --title "<keywords>" --journal "Physical Review Letters" --year-from 2024
```

Will return new short-DOI papers whose title keywords match, even while INSPIRE is still catching up.

### Example: verify a DOI

```
https://api.crossref.org/works/10.1103/PhysRevC.97.011601
```

Check that the returned `title` matches what the user asked about. Extract canonical fields.

---

## Semantic Scholar

Semantic Scholar has broad coverage (physics, ML, CS, biology, medicine) and a clean API. Useful for cross-disciplinary searches and for getting abstracts when INSPIRE does not carry them.

### Base endpoint

```
https://api.semanticscholar.org/graph/v1/paper/search?query=<QUERY>&limit=<N>&fields=<FIELDS>
```

Useful fields: `title,authors,venue,year,externalIds,abstract,openAccessPdf,tldr`.

### By Semantic Scholar paper ID

```
https://api.semanticscholar.org/graph/v1/paper/<paperId>?fields=<FIELDS>
```

### External ID resolution

```
https://api.semanticscholar.org/graph/v1/paper/DOI:<DOI>?fields=title,authors,venue,year
https://api.semanticscholar.org/graph/v1/paper/arXiv:<id>?fields=title,authors,venue,year
```

### Rate limits

Unauthenticated calls are rate-limited to 100 requests per 5 minutes. For larger sweeps, batch queries. If hitting limits, slow down or fall back to another source.

---

## Google Scholar via WebSearch

Google Scholar has no public API. Access it through WebSearch with scoped queries or WebFetch on the search URL.

```
WebSearch: site:scholar.google.com "19F(p,alpha)16O" trojan horse
WebSearch: site:scholar.google.com Koning Delaroche optical potential 2003
```

```
WebFetch: https://scholar.google.com/scholar?q=<URL-encoded query>
```

### Role: Discovery only

Google Scholar is a **discovery tool, never a citation source**. Its purpose is to surface candidate paper **titles** when the user's request is too fuzzy for a structured INSPIRE query (for example, "that Bertulani paper on THM from a few years ago"). Once titles are in hand, switch to INSPIRE, CrossRef, or arXiv for the actual metadata fetch. The reasons:

- Scholar output is HTML. There is no guarantee which fields are complete or correctly parsed.
- Scholar sometimes conflates a preprint with its published version, giving mixed year/venue data.
- Scholar author lists are truncated in ways that are easy to miss.
- BibTeX exported from Scholar has been observed to contain wrong pages, wrong years, and wrong venues.

If you find yourself writing a citation with fields that originated in a Scholar snippet and were never cross-checked against INSPIRE/CrossRef/arXiv, stop. That is a hallucination-risk path.

### When Scholar is the best entry point

- User request is vague on author or venue ("the paper that showed X").
- Topic is cross-disciplinary (physics + biology, physics + ML).
- Paper may not be indexed in INSPIRE (recent astrophysics review in a non-physics journal, chemistry paper on nuclear probes, medical-physics paper).
- Need to find papers that cite or are cited by a known paper, and INSPIRE's citedby/refersto did not help.

### Worked discovery example

User: "find the Bertulani paper that argues the Trojan Horse Method needs approximations to be assessed".

1. Scholar query: `WebFetch: https://scholar.google.com/scholar?q=Bertulani+trojan+horse+method+assessment`
2. Top hit snippet suggests a title containing "Assessing the foundation of the Trojan Horse Method".
3. Switch to INSPIRE: `a:Bertulani and t:"Assessing the foundation" and t:trojan`.
4. Single hit: record 1610047, Bertulani-Hussein-Typel, Phys. Lett. B 776, 217 (2018), DOI 10.1016/j.physletb.2017.11.050.
5. That INSPIRE record is the citation source, not the Scholar snippet. The Scholar snippet was only used to discover the title.

### Hard rule

Never emit a BibTeX entry whose `volume`, `pages`, `year`, or `author` fields originated in a Scholar result. Those fields must come from the structured Stage 2 fetch (INSPIRE, CrossRef, or arXiv Atom).

---

## ADS

The NASA Astrophysics Data System (ADS) is canonical for astrophysics. Use for papers in ApJ, MNRAS, A&A, Nature Astronomy, etc.

### Base endpoint

```
https://api.adsabs.harvard.edu/v1/search/query?q=<QUERY>&fl=<FIELDS>&rows=<N>
```

Requires an API token in the Authorization header. If no token is available, fall back to the web search URL:

```
https://ui.adsabs.harvard.edu/search/q=<URL-encoded query>
```

Fetch the result page and extract bibcodes. Each bibcode resolves at `https://ui.adsabs.harvard.edu/abs/<bibcode>/abstract`.

### When to use ADS over INSPIRE

- Pure astrophysics papers (stellar evolution, nucleosynthesis, galactic chemical evolution) that never go on arXiv nucl-th
- Observational astronomy papers
- Century-scale historical papers (Burbidge, Burbidge, Fowler, Hoyle 1957 etc.) that INSPIRE may miss

For nuclear astrophysics papers that bridge both fields (Käppeler s-process review, Iliadis Nuclear Physics of Stars, the Lei-Moro line of work), INSPIRE is sufficient.

---

## Selection rules of thumb

When the topic is ambiguous, pick the database as follows:

- Is the paper in PRC, PRL, NPA, PLB, or an arXiv nucl-* category? Use INSPIRE.
- Is the paper in ApJ, MNRAS, A&A? Use INSPIRE if also on nucl-* arXiv, otherwise ADS.
- Is the paper in Nature, Science, Nature Physics, or PNAS? Try INSPIRE first (they index if there is a physics angle), fall back to CrossRef by DOI.
- Is it an ML or CS paper? Go directly to Google Scholar or Semantic Scholar.
- Is it a preprint from less than 6 months ago? Try arXiv directly, INSPIRE indexes with a delay.

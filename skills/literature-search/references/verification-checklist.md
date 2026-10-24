# Verification Checklist

Read this file whenever there is doubt about whether a fetched record genuinely matches the user's request. The checklist exists to catch the most common failure modes before a citation is emitted.

## The five required checks

Before emitting any citation, verify that all five conditions are true. If any fails, reject the candidate and try a new search.

These checks run on **every** citation, whatever produced the candidate: a cold search, a DOI the user typed, a reference harvested from a paper's bibliography, or an entry the `literature-wiki` precheck returned as a Hit. A wiki Hit skips the *search*, never the *verification*. Where a check below says "the user asked about", read it as "the request, or the wiki entry that supplied the candidate" when the candidate came from the wiki.

### 1. Title overlap

The fetched title must contain at least 60% of the distinctive words the user asked about. Distinctive words exclude articles and prepositions and common physics words like "paper", "study", "analysis".

**Passed example**
- User: "the Lei-Moro paper on post-prior equivalence with complex potentials"
- Fetched title: "Post-prior equivalence for transfer reactions with complex potentials"
- Distinctive words: {post-prior, equivalence, complex, potentials}. All 4 present. Pass.

**Failed example**
- User: "Lei-Moro paper on post-prior equivalence"
- Fetched title: "Non-elastic breakup in the Ichimura-Austern-Vincent model"
- Distinctive words user asked: {post-prior, equivalence}. Zero present. Fail. This is a different paper by the same authors.

### 2. Author match

If the user named any author, that author must appear in the fetched author list.

**Passed**: User "Lei-Moro 2018", fetched authors ["Lei, Jin", "Moro, Antonio M."]. Pass.

**Failed**: User "the 2022 JUNA Nature paper by Zhang", fetched authors ["Liyong Zhang", "Jianjun He", ...]. Must check that "Zhang" is indeed in the list. If the fetched record authors are ["Wang, Y.", "Liu, J."], fail; "Zhang" was promised but not delivered.

### 3. Year range

If the user gave a year or range, the fetched `year` must fall inside it. Preprint years and publication years can differ by 1 to 2 years; allow ±1 year tolerance when the user gave a single year, but note the discrepancy in the output.

### 4. Journal or venue

If the user specified a journal or venue, the fetched `journal` or `venue` must match. Common abbreviation pairs that are all equivalent:

- `Phys. Rev. C` = `PRC` = `Phys.Rev.C` = `Physical Review C`
- `Phys. Rev. Lett.` = `PRL` = `Phys.Rev.Lett.`
- `Nucl. Phys. A` = `NPA` = `Nuclear Physics A`
- `Phys. Lett. B` = `PLB`

If the user said "PRL" and the fetched record says `Phys. Rev. C`, fail. Do not silently swap.

### 5. Verification anchor resolves

At least one of {DOI, arXiv ID, INSPIRE record ID} must be present in the fetched record and must resolve to a real page when opened.

Note the direction: the anchor must be present **in the fetched record**. An identifier that exists only in a wiki entry, or only in the user's message, has not been anchored by anything. If a wiki entry carries no identifier at all, there is nothing to fetch: fall back to a title-based Stage 1 search, verify the resulting record normally, and report the missing identifier as a D5 wiki defect.

- DOI: a HEAD request to `https://doi.org/<DOI>` returns 200 or 302.
- arXiv ID: `https://arxiv.org/abs/<id>` returns 200.
- INSPIRE record: the numeric `control_number` came from the INSPIRE API response itself, so it is always valid.

For high-stakes work (paper submission, grant applications), run the optional DOI verification script:

```bash
python scripts/verify_doi.py <DOI>
```

It calls CrossRef and returns the registered metadata. Cross-check once more against the fetched record.

## The sixth check: the Stage 4 evidence gate

The five checks above test whether a fetched record matches the request. This one tests whether a fetch happened at all. Run it on the assembled emit list, immediately before writing citations into the reply.

For each entry on the list, write the evidence line:

```
Stage2 evidence: <tool call> -> <record id> -> <fields it returned>
```

Three conditions, all required:

1. The named call appears in **this turn's transcript**. Not a previous turn, not a previous session, not "the wiki says I looked it up before".
2. The call **returned those fields in its response body**. A call that 404'd, got blocked, or returned a different paper is not evidence.
3. The emitted fields are **the ones that call returned**, not a merge of that call with anything else.

Any entry whose line cannot be written honestly is dropped or re-fetched. There is no third option. Note the asymmetry that makes this gate worth running: writing a false evidence line costs one sentence, and a reader cannot tell it from a true one. That is exactly why the check is mechanical and per-entry rather than a global "did I verify everything?" feeling. A global feeling is what lets the one unverified entry through.

Keep the lines as working notes; they go into the reply only if the user asks for the audit trail.

## Common failure modes and how to recognize them

### The wrong-paper-same-authors trap

Experienced researchers often have many papers with overlapping topics. A search for "Lei Moro THM" might return Lei-Moro 2015, 2017, 2018, 2019. Do not assume the most cited one is the one the user meant. Ask for the year or specific sub-topic.

### The reversed-authors trap

Some databases list authors as "Lei, J.", others as "J. Lei", others as "Jin Lei". Match on last name, not on string equality. A fetch that returns "Moro, Antonio M." for a user query "Moro" is a match.

### The off-by-one volume trap

Volume numbers in the user's memory are frequently off by one. If the user says "PRC 93" and the fetched record says "PRC 92", flag the discrepancy and verify via DOI. Do not silently correct.

### The arXiv-versus-published trap

An arXiv preprint and its published journal version are the same paper but have different metadata. If the user asks for the published version, do not cite the arXiv preprint with the journal's volume/page fields. Either fetch the journal version or emit an `@misc` arXiv entry.

### The proceedings trap

INSPIRE indexes conference proceedings. A user asking for "the Bertulani 2018 paper on IAV and THM" might find a conference proceeding that shares the title with a journal paper. The INSPIRE `document_type` field disambiguates: `article` versus `conference paper`. Prefer `article` unless the user specifically wants proceedings.

### The stale-wiki trap

A `literature-wiki` entry looks authoritative (it is local, it is the user's own, it is written in citation form) but it is a cache of what was true on the day it was ingested. Nothing in the wiki's own workflow ever re-checks it, so this skill is where its errors surface or never surface at all. The classes, matching the D1..D6 table in SKILL.md:

- **D3, ingested in press or from arXiv, never re-synced.** Volume, page, article ID, year, and DOI all change at publication. The wiki keeps the preprint's coordinates and they now name nothing. The most common class by far.
- **D2, guessed APS DOI.** Everything from 2025 onward uses short-form `10.1103/<alphanumeric>`, which cannot be derived from journal-volume-page. A wiki entry carrying a long-form `10.1103/PhysRevC.<vol>.<artid>` DOI for a 2025+ paper is a fabrication that was never caught.
- **D6, author list changed** between preprint and journal version, or was truncated to "et al." during ingest.
- **D4, transcription slips**: an off-by-one volume, a swapped article ID, a typo'd arXiv number, none of which the wiki has any mechanism to catch.
- **D1, the identifier resolves to a different paper.** Rare and catastrophic: the entry has been mis-citing that work everywhere it is linked.

Handling: fetch the wiki's identifier live, emit the fetched fields, report the diff in the defect block format from SKILL.md, and tell the user which `<wiki>/sources/<paper-id>.md` needs a `literature-wiki` repair pass. Report the defect even when the emitted citation came out clean.

The trap inside the trap: a wiki entry that is *mostly* right is more dangerous than one that is obviously wrong. A stale volume on an otherwise perfect entry passes every eyeball check the user will ever give it. Only a live fetch catches it.

### The self-citing-loop trap

Do not cite a paper as the source for a claim simply because its abstract mentions the claim. Fetch the paper's actual text (abstract, conclusion, table) to confirm the claim is in the paper, not in a paper the cited paper refers to.

## What to do when verification fails

Three tiers, in order of preference.

### Tier 1: Retry the search

Different query wording, different database, different time window. Usually a failed first search means the query was imprecise, not that the paper does not exist.

### Tier 2: Ask the user

"I found two candidates, A and B. They share these features. Which one did you mean?" Present the distinguishing fields in a mini-table.

### Tier 3: Admit failure

"No verified match found. The closest candidate I could confirm is <X>, with the caveat that <reason>. Please provide the DOI or a link if you have it."

This is acceptable. Never synthesize a missing field. Never claim a paper exists based on how plausible it sounds.

## Red-flag phrases from the model itself

If you find yourself writing any of these sentences (or their equivalents), stop and restart the workflow.

- "Based on the context, the citation is likely..."
- "This is probably the Nature paper by..."
- "The standard reference for this is..."
- "A commonly cited paper here would be..."
- "This one is already in the wiki, so the citation is verified."
- "The wiki entry gives the full BibTeX, so I can emit it as is."

Each of these phrases is a self-report that verification has been skipped. Do not emit a citation from these sentences. Go back and search, or, for the last two, go fetch the wiki's identifier from INSPIRE / CrossRef / arXiv and emit what comes back.

## Worked example: successful verification

**User request**: "Find me the JUNA Nature paper on 19F(p,gamma)20Ne."

**Workflow**:

1. INSPIRE search: `t:"19F(p,gamma)20Ne" and de > 2020`. One hit.
2. Fetch record: `https://inspirehep.net/api/literature/2120547?format=json`.
3. Fetched fields:
   - title: "Measurement of 19F(p, gamma)20Ne reaction suggests CNO breakout in first stars"
   - authors: ["Zhang, Liyong", "He, Jianjun", "deBoer, Richard J.", ...]
   - journal: "Nature"
   - volume: "610"
   - pages: "656"
   - year: 2022
   - DOI: 10.1038/s41586-022-05230-x
4. Verification checks:
   - Title overlap: user said "19F(p,gamma)20Ne Nature", fetched title contains both. Pass.
   - Author match: user did not specify an author. Pass.
   - Year match: user did not specify. Pass.
   - Journal match: user said "Nature", fetched says "Nature". Pass.
   - Anchor: DOI present, resolves. Pass.
5. Emit BibTeX with `url = "https://doi.org/10.1038/s41586-022-05230-x"`.

## Worked example: failure and recovery

**User request**: "The Bertulani paper from 2017 that proves IAV reduces to THM."

**Workflow**:

1. INSPIRE search: `a:Bertulani and de:2017 and (t:THM or t:"trojan horse" or t:IAV)`.
2. Returns two candidates. Neither claims to "prove IAV reduces to THM"; both only discuss the approximation.
3. Widen: `a:Bertulani and a:Hussein and a:Typel`. Returns Bertulani-Hussein-Typel 2018 PLB.
4. Verify: title "Nonelastic breakup and Trojan Horse Method", published 2018 not 2017, PLB 776 217.
5. Check against user claim "proves IAV reduces to THM": read abstract. Abstract says the reduction "requires several approximations that must be assessed". This is weaker than "proves". Flag.
6. Emit citation with the correct year (2018, not 2017) and note in prose: "Note: the paper you are likely remembering is Bertulani-Hussein-Typel 2018 PLB 776, 217, not 2017. The paper does not claim to prove the IAV-to-THM reduction; it states that the reduction requires approximations that must be assessed."

This is the protocol. Correct the user gently, never silently.

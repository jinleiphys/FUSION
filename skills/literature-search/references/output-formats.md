# Output Format Templates

Use the template that matches the user's request. If unclear, default to BibTeX plus a compact markdown list.

## BibTeX (default for LaTeX users)

Use `@article` for journal papers, `@inproceedings` for conferences, `@book` for books, `@misc` for arXiv-only preprints, `@techreport` for theses and lab reports.

Every entry must have a `url` field pointing at the authoritative landing page. This is the user's one-click verification path.

### Journal article template

```bibtex
@article{<citekey>,
    author = "<LastName1>, <First1> and <LastName2>, <First2>",
    title = "{<Title with LaTeX-safe braces around capitalized words>}",
    journal = "<Journal Abbrev>",
    volume = "<volume>",
    pages = "<start-end or article number>",
    year = "<year>",
    doi = "<DOI>",
    url = "https://doi.org/<DOI>"
}
```

### Worked example: Lei-Moro 2018

```bibtex
@article{Lei:2017dvh,
    author = "Lei, Jin and Moro, Antonio M.",
    title = "{Post-prior equivalence for transfer reactions with complex potentials}",
    journal = "Phys. Rev. C",
    volume = "97",
    pages = "011601",
    year = "2018",
    doi = "10.1103/PhysRevC.97.011601",
    url = "https://doi.org/10.1103/PhysRevC.97.011601"
}
```

Note: the citation key `Lei:2017dvh` came from the INSPIRE fetch, it is INSPIRE's texkey. Prefer INSPIRE texkeys when available; they are stable across the community.

### Preprint-only (no journal yet)

```bibtex
@misc{<citekey>,
    author = "<authors>",
    title = "{<title>}",
    year = "<year>",
    eprint = "<arxiv-id>",
    archivePrefix = "arXiv",
    primaryClass = "<category>",
    url = "https://arxiv.org/abs/<arxiv-id>"
}
```

### Citation key conventions

- Prefer INSPIRE texkey when fetched: `Lei:2017dvh`, `Moro:2019xdv`
- If INSPIRE not available, use `<FirstAuthorLastName><Year><Disambiguator>`: `Koning2003`, `LaCognata2025a`
- Never recycle the same key across different papers

## Compact markdown list

For browsing or when the user does not ask for BibTeX explicitly.

```markdown
- **Lei and Moro, PRC 97, 011601(R) (2018)**: Post-prior equivalence for transfer reactions with complex potentials. [DOI](https://doi.org/10.1103/PhysRevC.97.011601) · [INSPIRE](https://inspirehep.net/literature/1643611)
- **Zhang et al., Nature 610, 656 (2022)**: Measurement of 19F(p,gamma)20Ne reaction suggests CNO breakout in first stars. [DOI](https://doi.org/10.1038/s41586-022-05230-x)
```

Each bullet must contain author + journal + volume + page + year + a clickable link for verification. No exceptions.

## Comparison table

For topic scans where the user wants to survey a subfield.

```markdown
| Author/Year | Method | Key finding | Venue | Link |
|-------------|--------|-------------|-------|------|
| Lei, Moro 2015 | IAV post-form | NO+IN are 30-50% for inclusive NEB | PRC 92 061602R | [DOI](...) |
| Lei, Moro 2018 | IAV with complex U_x | Breit-Wigner spectral decomposition | PRC 97 011601R | [DOI](...) |
| Su et al. 2025 | THM + PWIA | 11 keV omega-gamma 5.8x smaller | PRL 135 182701 | [DOI](...) |
```

Sort by year unless the user asks for a different sort. Every row must have a verification link.

## Contradiction brief

When the user asks to identify or document conflicting results.

**Do not force the story into two positions.** Real controversies in nuclear physics often have 3 or more camps that each agree on some points and disagree on others. Read the source papers carefully and report the actual number of distinct quantitative claims, not the number that makes the brief cleaner to write.

```markdown
## Contested quantity: <one-line statement, e.g., "omega-gamma of the 11 keV resonance in 19F(p,alpha)16O and the resulting reaction rate at T = 5e7 K">

**Position 1: <short label, e.g., "Early THM (2011-2017)">**
- <Paper 1 lead author + venue + year>: <quantitative claim with number>. [DOI](...)
- <Paper 2 (same camp)>: <supporting or refining>. [DOI](...)

**Position 2: <label, e.g., "JUNA direct underground (2021-2022)">**
- <Group's first announcement, often a PRL>: <claim>. [DOI](...)
- <Group's long-form companion, often a PRC/PRD>: <claim>. [DOI](...)
- <Group's flagship paper if in Nature/Science>: NOTE if this flagship covers a DIFFERENT channel than Position 2's main claim. Do not conflate channels. [DOI](...)

**Position 3: <label, e.g., "Newest THM re-extraction (2025)">**
- <Paper>: <claim>. [DOI](...)

**(...add Positions 4, 5, ... as the evidence demands.)**

**Quantitative disagreement matrix**:

| | Position 1 | Position 2 | Position 3 |
|---|---|---|---|
| Resonance strength omega-gamma | <value 1> | <value 2> | <value 3> |
| Rate factor vs NACRE at T_ref | <x1> | <x2> | <x3> |

**Axes of agreement**: <where the camps concur, e.g., "all three agree the 11 keV level is real and has J=1+">

**Axes of disagreement**: <where they diverge, with magnitudes>.

**Proposed root causes** (only if user asked): <e.g., channel decomposition, PWIA vs IAV-DWBA, direct extrapolation vs indirect at-E measurement>.
```

Rules:
- Each position must cite at least one verified paper. Never present a position without a real paper to hang it on.
- If the user's query names specific groups (e.g., "JUNA vs THM"), verify you have the GROUP-SERIES coverage (see SKILL.md "Group-series coverage for contested reactions"): at least the earliest announcement, the long-form companion, and any relevant review, per group. One paper per group is a red flag for missing coverage.
- A flagship Nature/Science paper is **not interchangeable** with the technical PRL/PRC companion. Label the channel or observable explicitly on each paper. Do not let the Nature paper "represent" a measurement in a channel it did not measure.
- If only one side has published, say so explicitly and call the other side an informal expectation rather than manufacturing a symmetric "Position B".

## Source attestation footer

At the end of every output block, include:

```
Sources consulted: INSPIRE-HEP, arXiv, CrossRef. Retrieved 2026-04-24.
Records fetched: <N>. Records rejected on verification: <M>.
```

This footer is not cosmetic. It is part of the anti-hallucination audit trail. Never omit it.

## Handling Chinese-language user sessions

If the user is writing in Chinese, keep the bibliography block itself in English (that is the form it will take in the paper), but wrap it with a short Chinese explanation of what was searched, what was verified, and any unresolved ambiguities.

Example pattern:

```
我搜索了 INSPIRE-HEP 和 arXiv，以下为验证后的引用块（直接可放入 .bib 文件）：

[BibTeX block here]

检索注记：
- 一条候选 "Koning et al. 2002 PRC 68" 经 DOI 核查实际为 2003 年 NPA，已按正确版本输出。
- 另有一条 Mukhamedzhanov HOES review 未能在 INSPIRE 精确匹配，已附 arXiv 预印本链接，请你人工核对最终出版信息。
```

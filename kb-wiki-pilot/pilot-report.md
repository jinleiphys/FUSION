# FUSION knowledge base: 500-paper pilot report

Run date: 2026-07-09. Model: deepseek-chat. Fulltext cap: 40,000 chars/paper. Workers: 8.

## 1. Paper selection (Step 1)

Five corpus queries, deduped by arxiv_id in order of first appearance, truncated to 500.

| query | returned | new unique |
|---|---|---|
| text "inclusive breakup" (n=200) | 200 | 200 |
| text "complete fusion suppression weakly bound" (n=150) | 150 | 126 |
| text "elastic breakup CDCC continuum" (n=150) | 150 | 105 |
| abs "trojan horse method" (n=60) | 60 | 47 |
| text "incomplete fusion breakup fusion" (n=100) | 100 | 23 |
| **total unique** | | **500** |

All 8 calibration ids (1511.03214, 1711.07540, 2101.09497, 1705.07782, 1508.04822, 2604.11226, 2605.03342, 2605.16890) were already returned by the queries, so none had to be force-added. List saved to `paper-list.txt`.

## 2. Batch run (Step 2, 3)

`scripts/digest_paper.py` gained a `--list / --outdir / --workers` batch entry point: skip-if-exists resumability, one retry after 30 s per failure, accumulated token usage, a progress line every 25 papers, and a `batch-summary.json` dump. Single-paper behavior is unchanged (positional `arxiv_id [outdir]` still works).

| metric | value |
|---|---|
| attempted | 500 |
| succeeded | 500 |
| failed | 0 |
| wall clock | 570 s (9.5 min) |
| throughput | ~1.14 s/paper effective (8 workers) |
| input tokens | 5,078,152 (avg 10,156/paper) |
| output tokens | 330,545 (avg 661/paper) |

Zero failures, so the 5% abort gate was never approached. Token averages match the design-doc prototype (10.7k in / 0.5 to 0.75k out).

## 3. Cost and extrapolation

deepseek-chat standard pricing (input $0.27/M, output $1.10/M, no cache credit):

| | 500 papers | per paper | 62,714 papers |
|---|---|---|---|
| input | $1.371 | | $172 |
| output | $0.364 | | $46 |
| **total** | **$1.735** | **$0.00347** | **~$218 (~1570 RMB)** |
| off-peak (-50%) | ~$0.87 | | **~$109 (~780 RMB)** |

Prompt caching (identical template prefix on every call) and the off-peak window both push the real full-run cost toward the lower bound. This confirms the design-doc estimate: roughly $115 to $230 standard, $70 to $115 off-peak, for the whole 62k corpus. At 8 workers the full run projects to ~20 h wall clock; more workers (the design doc assumed 20) would cut that to the ~7 h estimate.

## 4. Quality checks (Step 4)

**Check 1, structural + frontmatter.** All 500 pages carry the four required sections (Key claim / Method / Key numbers / Context) and valid frontmatter (arxiv/title/authors/date/digest_model present). Violations: 0.

**Check 2, no-fabrication spot check (8 calibration papers).** For each digest I extracted every numeric token from the generated body and checked literal presence in the paper's own abstract + fulltext in corpus.db. Physics numbers: 100% matched. The only tokens not found literally were reference years in the Context section (1511.03214: "2011", "2015"; 2101.09497: "1987"), which are citation dates the model attached to named authors that do appear in the text (Thompson et al. 2011, Potel et al. 2015, Austern et al. 1987). No fabricated physical quantities were found. Manual reading of the 8 digests confirms the extracted results (cross sections, energies, S-factors, kernels) are all present in or directly computable from each paper.

**Check 3, em-dash scan.** The raw model output contained em-dashes in 31 of 500 pages. Fixed by adding a deterministic `strip_emdash()` sanitizer to the script (em-dash, horizontal bar, and two/three-em variants collapse to a comma; hyphen-minus and en-dash are kept) and applying it in place to the 31 files. `grep -rn $'\xe2\x80\x94' kb-wiki-pilot/papers/` now returns nothing. The sanitizer is wired into `digest()` so the full run is em-dash-free by construction rather than by post-hoc regeneration.

**Check 4, truncation audit.** 298 of 500 papers had fulltext exceeding the 40k-char cap. Ten largest (chars):

| arxiv_id | fulltext chars |
|---|---|
| 1010.5827 | 1,271,833 |
| 1004.4517 | 839,421 |
| 1504.00756 | 662,333 |
| 1903.09185 | 525,381 |
| 2211.15746 | 432,369 |
| 2012.14161 | 419,608 |
| 1108.4663 | 416,111 |
| 2008.10408 | 383,173 |
| 2005.08277 | 375,749 |
| 1912.10053 | 375,046 |

The extreme lengths (1.2M chars) come from multi-file .tex concatenations or appended data tables, not 1.2M chars of physics prose. Truncation to 40k mostly clips reference lists and appendices, but for the very largest papers it can cut real body sections. See recommendations.

## 5. Best and worst pages

**Best 5** (precise, deeper-than-abstract, well-sourced):

1. `2605.30980` Bayesian/emulator optical-potential inference. Concrete, hard numbers (emulator error 1.1e-3, discrepancy beta = 0.071 +/- 0.027, D_eff = 1.3/18), each with context.
2. `2410.19377` experimental ratio-method validation for 11Be. Clean beam energy, purity, target, and correct attribution to Capel and Crespo prior work.
3. `2605.03342` Lei four-body inclusive-breakup framework. Captures the pair vs single-particle distinction and the CFH kernel recovery exactly.
4. `2605.16890` IAV-to-THM diagonal-pole link. Key claim states the actual hedge (per-pole DWBA cross section, not a multiplicative PWIA factor) precisely.
5. `1508.04822` calibration paper, 16 numeric results all verified present in text.

**Worst 3** (thin or non-specific Key numbers):

1. `2011.05130` 12C+12C TDHF+path-integral S-factor. Key numbers section is entirely qualitative ("falls midway", "calculated with and without resonances") with no actual S-factor or rate values, though the paper has them; the model hedged instead of extracting.
2. `2604.11226` calibration paper, but Key numbers are definitional symbols (binding energy, reduced-mass formulas) rather than results. This is a formal-derivation paper, so partly expected, but the digest leans on equations the reader cannot see.
3. `2211.06281` FRIB white paper. Correctly reports "no numerical results", but the page is thin by nature; a perspectives document is a poor fit for the results-oriented template.

A separate observation from the best/worst sweep: the lexical queries pulled in genuinely off-domain papers (solar-neutrino flux compilations like 1208.5723 / 2209.14832, exotic-XYZ-state reviews like 1312.7408) because "inclusive breakup" and "elastic breakup continuum" collide with hep-ph and solar-physics phrasing. The digests of those papers are excellent, but they should not sit under nuclear-reaction PhySH concepts. This is a selection-rule problem for L1, not a digest-quality problem.

## 6. Recommended template improvements before the full run

1. **Ship the em-dash sanitizer** (done here). Deterministic post-processing beats asking the model to abstain; the instruction alone failed on 6% of pages.
2. **Raise or tier the fulltext cap.** 60% of papers were truncated. Either raise the cap to ~80k chars (still cheap, roughly doubles input cost on affected papers only), or strip the reference list / appendix before truncation so the 40k budget covers body text. For the pathological 0.5 to 1.3M-char papers, detect and body-extract first.
3. **Force numeric specificity in Key numbers.** Add to the template: "Every bullet must contain at least one number with units; if a claimed result has no number in the text, omit the bullet rather than paraphrasing it qualitatively." This directly fixes the 2011.05130 failure mode.
4. **Handle non-results papers explicitly.** Add a template branch: reviews, white papers, and conference summaries should get a short "Scope / open questions" treatment instead of being forced through Key numbers.
5. **Tighten L1 selection, not the digest.** The cross-domain leakage (solar neutrinos, XYZ states) means the PhySH match rules need negative filters (exclude papers whose primary category is hep-ph or astro-ph unless a nuclear-reaction concept dominates). Digest quality is not the bottleneck; concept assignment is.

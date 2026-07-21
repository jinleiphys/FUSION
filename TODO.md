# FUSION TODO

Validation rules and hard constraints live in [CLAUDE.md](CLAUDE.md); do not restate them here.

## Phase 1: rebrand fork + CI

- [ ] Remaining brand surfaces: desktop/web icons need an actual FUSION graphic (nature-figure skill or designer), TUI/CLI display-name strings sweep
- [ ] TUI logo v2: current block-glyph version verified rendering as "FUSion" (user: 效果一般, acceptable for now); revisit in the visual design pass together with the icons
- [ ] Build + release pipeline for FUSION binaries (adapt upstream release workflow; bun installed locally)
- [ ] Domain name [Please specify preference]

## Phase 2: skill pack

Scope (user directive 2026-07-09): **every excellent open-source nuclear-physics code gets its own skill**, across reactions, statistical/fission, R-matrix/astro, structure, and (scoped) transport/data. Full living roadmap with openness-verification flags and wave ordering: [skills-catalog.md](skills-catalog.md).

Strategy (user 2026-07-20): community codes first, self-consistent benchmarks (reproduce each code's own documented reference values, not cross-code matching), one at a time (build+benchmark cannot be parallelized). Private-code boundary: only published + publicly-open codes (excludes THOx, smoothie, transfer, STARS). Full roadmap + status: [skills-catalog.md](skills-catalog.md).

- [ ] Port the existing ~30 research skills (writing, review, literature, figures) to FUSION format; strip Claude-Code-only mechanics per skill
- [ ] TALYS follow-up: the 11 GB install (8.6 GB structure DB) is the heaviest skill so far and will dominate any `install.sh` bundle in Phase 4; decide whether the distribution offers TALYS as an opt-in extra rather than a default [user decision]
- [ ] **PRIORITY CORRECTION (2026-07-21): build to the paper's subfield gate, not down the Wave 1b list.** The fusion-paper benchmark gates submission on one completed skill per subfield row (reactions / structure / fission-statistical / astro-R-matrix). Reactions and structure are already satisfied; the entire remaining Wave 1b queue (NLAT done, CNOK, SIDES, SWANLOP) consists of reaction codes, so it deepens a satisfied row and moves the gate by nothing. The two rows that actually block the paper are **fission/statistical** and **astro/R-matrix**. Wave 1b is ordered by research-line relevance, which is a legitimate but different objective; when the paper deadline binds (2027-01-01), the gate wins
- [ ] **AZURE2 (astro/R-matrix row), IN PROGRESS.** `skills/azure2/scripts/install_azure2.sh` is written and clean-room verified: nothing to a working headless binary in 19 s, encoding six fixes (CMake 4 policy, standalone GooFit Minuit2 instead of a 1-2 GB ROOT, a Minuit2 finder probing a header modern Minuit2 no longer installs, the legacy BSD `finite()` that also breaks GSM, the Apple-clang OpenMP shim forcing a GNU build which in turn forces Minuit2 to be rebuilt with GNU for ABI compatibility, and a two-archive link). **Blocker: no test case.** The repo ships no `.azr` example and azure.nd.edu serves a placeholder, so L1 is solid and L2 has nothing to reproduce. Ask R.J. deBoer for the example set. Status and remaining work in `skills/azure2/STATUS.md`
- [ ] **Fission/statistical row: GEF CLEARS THE GATE (checked 2026-07-21), row is fillable, no fallback needed.** GEMINI++ was dropped the same day (both distribution URLs 404). GEF passes both halves of the private-code boundary: **GPL-3.0** (`License.txt` in the tarball), and an **anonymous direct download** with no registration, `khschmidts-nuclear-web.eu/GEF_code/GEF-2025-V1-4/Standalone/GEF-Full-Y2025-V1-4.tar.gz` (6.0 MB, sha256 `fc3b70a7...e803a7`), actively maintained with 24 archived versions and 2025/1.4 released 2026-05-04. Citation verified live against CrossRef: Schmidt, Jurado, Amouroux, Schmitt, *Nuclear Data Sheets* **131**, 107-221 (2016), DOI 10.1016/j.nds.2015.12.009. **Runs, verified end to end**: ²⁵²Cf(SF) produced `out/GEF_98_252_sf.dat`, nu-bar 3.8207 against the evaluated 3.7676 (1.4%, a model difference, not a porting error). So the paper's four-subfield claim is safe
- [ ] **GEF porting constraint: it is a LINUX-ONLY skill, and that is fine.** The source is **FreeBASIC** (33 `.bas` files), `fbc` is not installed and has no Homebrew formula, and the shipped binaries are ELF Linux 32/64 plus a Windows `.exe` with no macOS build. Rather than fight a FreeBASIC toolchain on Apple Silicon, run the shipped `GEF64` natively on heliumx (x86_64 Linux), which is where heavy compute belongs anyway. The skill must state the platform restriction plainly instead of pretending to be portable
- [ ] **GEF has TWO state-contamination traps, both of which make a failed or skipped run look successful.** (i) `ctl/done.ctl` memoizes completed cases: rerunning one already listed produces **no output, prints "GEF is terminated", and exits 0**. This is the fifth distinct false-success mechanism in the per-code series and a new costume (state-file memoization), so the run wrapper must assert on `out/` content, never on exit status, and must clear or honour `ctl/`. (ii) a `Fitpar.dat` left behind by any earlier `FIT(...)` run is picked up silently on the next run and **overrides the shipped defaults**, so a clean-room run must remove it. Note the deck format: line 3 is the options line, and omitting it silently shifts the Z,A line
- [ ] **GEF benchmark tier: expect tier 2 unless the NDS paper anchors it.** 97 input decks ship under `in/`, but **no reference output**, the same situation as pikoe and AZURE2. Before settling for tier 2, check whether the 115-page Nuclear Data Sheets paper carries tabulated GEF numbers for a shipped deck; it is a model-vs-evaluation paper, so it plausibly does. Also note GEF is Monte Carlo, so any reference reproduction needs the event count pinned and agreement stated as statistical, never bit-identical
- [ ] **New Wave 1b from the community optical-potential code list (2026-07-20)**, ahead of Wave 2 because each is small, CPC-published-and-distributed (openness already settled), ships author test cases, and sits on an active research line. Order: ~~**pikoe**~~, ~~**NLAT**~~ (both done 2026-07-21), **CNOK** (next) (Titus/Ross/Nunes, nonlocal ADWA/DWBA transfer; independent cross-check of the LG18891CR nonlocality engine), **CNOK** (Glauber knockout; partner for the IAV-vs-Glauber line), **SWANLOP + SIDES** as a pair (nonlocal-OMP scattering, siblings of COLOSS's Perey-Buck path)
- [ ] Look at **JITR** (Beyer, Python R-matrix built for calibration/UQ, github.com/beykyle/jitr) before deciding on a skill: it is the closest external code to Line D / DREAM / the emulator work, so it may be more useful as something to read and compare against than as a skill
- [ ] Verify publications for JITR and YAHFC, and licenses for the Alex Brown bundle, before any of them get a skill (open repo alone does not satisfy the hard rule)
- [ ] Decide FRESCO upstream: the skill builds I-Thompson/fresco, but LLNL/Frescox is the actively maintained fork [user decision]
- [ ] Theo4Exp (Seville/Krakow/Milano platform) is registration-gated, so it fails the publicly-obtainable rule as written; flagged not deleted, since it is Moro-adjacent [user decision]
- [ ] GSM follow-ups: benchmark a GSM-CC reaction case (Chapter 9), noting the book's Ex X/XI numbers are superseded by GSM-2.0
- [ ] Then Wave 2 community heavyweights: KSHELL, GEF, AZURE2, SkyNet (GEMINI++ dropped 2026-07-21, not publicly obtainable)
- [ ] Eligible Lei codes when convenient: SLAM.jl, PINN-ECS, inhomoR (COLOSS done)
- [ ] Each per-code skill meets the quality bar in skills-catalog.md (install from public source, verified deck examples, run/parse, benchmark to N digits with a CLEAN-ROOM build test, failure modes) before it ships. Since 2026-07-20 this also requires a **Codex adversarial pass** and **live citation verification**, and the skill must declare its benchmark tier (see CLAUDE.md Key decisions)
- [ ] **pikoe follow-up**: opportunistic email to the authors asking for the missing reference output (`tbl_*.dat` and `*.outlist` per sample directory, documented in their readme but absent from both releases). Yoshida is a co-author and the QFS-RB inviter, so it is a one-line ask, it fixes a packaging defect for everyone, and it would lift pikoe from figure-anchored to tier 1. All five sample decks are now pinned from measured runs, so nothing is blocked on it

## Phase 3: knowledge base ([kb-design.md](kb-design.md); PhySH taxonomy + pre-generated md wiki + semantic relations)

- [ ] relations.tsv exceeds GitHub's 50 MB soft warning (51 MB at 431k edges, will grow to ~90 MB at full 728k). Decide handling after L3 completes: gzip in-repo, or Git LFS, or fold into the eventual kb-wiki repo split. Not blocking (push still works)
- [ ] Abstract-only pages for the ~1,655 corpus papers without fulltext (lighter template, separate small batch)
- [ ] Widen neighbor whitelist to cut the 36.4% unclassified rate (hadron structure, heavy-ion subconcepts; sampled unclassified = mix of true out-of-scope and concept gaps)
- [ ] Tier-B citation edges (111k author-year heuristic edges) deserve a false-positive audit pass
- [ ] Hook monthly re-run (digest new papers + kb_classify + build_wiki_layers + kb_citegraph + inject + kb_relations) into the corpus-update launchd job
- [x] Distribution decision for kb-wiki: user decided 2026-07-10, pages live directly in the main repo (night-1 19,202 pages pushed in a1c4357; final ~250 MB, revisit only if GitHub complains)
- [ ] Licensing decision for the public artifact: abstracts included vs snippets vs fetch-on-first-run [user decision]
- [ ] Optional later: MCP server exposing kb_search/kb_browse (demoted from load-bearing to sugar, per 2026-07-09 revision)

## Phase 4: onboarding + distribution (wizard design: [onboarding-design.md](onboarding-design.md))

- [ ] `fusion init` wizard v1 (CLI): model+key test, PhySH area picker, kb-wiki slice mount, personal-wiki seeding from user's arXiv ids, skill recommendation with benchmark-on-install
- [ ] concept-skill-map.yaml (PhySH concept -> skills-catalog entries)
- [ ] Monthly personal digest loop (filter corpus updates by user concepts, greet on launch)
- [ ] install.sh: opencode binary + skill pack + kb-wiki + default config in one shot
- [ ] Default model config for CN users (domestic providers) and international users
- [ ] Student-facing docs (zh + en); wizard closing demo doubles as the tutorial
- [ ] Pilot with 2-3 group students; collect failures into devlog
- [ ] v2+: TUI popup wizard (plugin slots), ORCID/INSPIRE author lookup, group mode (advisor-curated shared config)

## Papers to download (user fetches from the office; added 2026-07-20)

Needed to write the Wave 1b per-code skills. Each code's SOURCE is already
obtainable (Mendeley Data / CPC Library), but the CPC paper is what documents the
input format, the keyword semantics, and the author's own test cases with
reference values, which is what a benchmark has to reproduce. ScienceDirect
blocks automated fetching (HTTP 403), hence this list.

All DOIs below were verified live against CrossRef on 2026-07-20; author, title,
journal, volume, page and year are as returned by the CrossRef record.

| # | code | paper | DOI |
|---|---|---|---|
| 1 | **pikoe** | Ogata, Yoshida, Chazono, *pikoe: A computer program for distorted-wave impulse approximation calculation for proton induced nucleon knockout reactions*, Comput. Phys. Commun. **297**, 109058 (2024) | `10.1016/j.cpc.2023.109058` |
| 2 | **NLAT** | Titus, Ross, Nunes, *Transfer reaction code with nonlocal interactions*, Comput. Phys. Commun. **207**, 499-517 (2016) | `10.1016/j.cpc.2016.06.022` |
| 3 | **CNOK** | Sun, Wang, *CNOK: A C++ Glauber model code for single-nucleon knockout reactions*, Comput. Phys. Commun. **288**, 108726 (2023) | `10.1016/j.cpc.2023.108726` |
| 4 | **SWANLOP** | Arellano, Blanchon, *SWANLOP: Scattering waves off nonlocal optical potentials in the presence of Coulomb interaction*, Comput. Phys. Commun. **259**, 107543 (2021) | `10.1016/j.cpc.2020.107543` |
| 5 | **SIDES** | Blanchon, Dupuis, Arellano, *SIDES: Nucleon-nucleus elastic scattering code for nonlocal potentials*, Comput. Phys. Commun. **254**, 107340 (2020) | `10.1016/j.cpc.2020.107340` |

Priority order is the Wave 1b build order: 1 first (pikoe is next up), then 2, 3,
then 4 and 5 together (SWANLOP and SIDES are siblings from the same group).

**pikoe packaging note (found 2026-07-20; user resolved the same day: proceed).**
The user's ruling: the skill's goal is to get the INPUT right, so an input manual
plus 5 real decks is sufficient to build it, and the missing reference output
does not block. Consequence to state honestly in the skill: pikoe's benchmark
tier is lower than FRESCO/COLOSS/CCFULL/GSM/TALYS. Those reproduce documented
reference numbers; pikoe can only be verified as builds + runs + produces
physically sensible output, plus internal consistency between its own samples
(sample1 normal vs sample4 inverse kinematics are the same reaction, and sample2
vs sample3 are the same observable at 392 vs 100 MeV). Upgrade path once the CPC
paper arrives: compare against its published figures. Details of what is missing:

The source is fetched
and fine (`pikoe1.1.f90`, 2025-03-18, from the author's RCNP page via the
attach-plugin URL; the plain `.zip`/`.f90` URLs 403/404, use
`index.php?plugin=attach&refer=files&openfile=pikoe1.1.zip`). It ships a real
input manual (`input_man.txt`) and 5 sample cases. **But it ships no reference
output.** `readme.txt` documents a `tbl_*.dat` and a `*.outlist` in every sample
directory; neither is in the archive. Verified against both releases: v1.1 has 22
entries, v1.0 has 13, and in both the `sampleN/` directories contain only the
`.cnt` input. So the FUSION standard benchmark (reproduce the code's OWN
documented reference values) cannot be run as things stand. Three options:
  (a) **Ask the authors.** Kazuki Yoshida is a co-author and is the person who
      invited Lei to QFS-RB 2026, so this is a one-line email and by far the
      cleanest fix. It also likely helps the authors, since the packaging defect
      is theirs and they may not know.
  (b) Use the CPC paper's figures as a weak qualitative check. Fails the
      N-significant-figures bar; not really a benchmark.
  (c) Cross-check against another DWIA code. The catalog strategy explicitly
      warns against this (convention archaeology, the COLOSS cautionary case).
(a) is still worth doing opportunistically, since the packaging defect is the
authors' and they likely do not know, but it is no longer blocking.

**All five PDFs delivered 2026-07-21** and read in full (structured extractions
of the program summaries, formalism, test cases and input formats). The pikoe
paper was used the same day to build the pikoe skill, where it turned out to be
worth more than expected: its five figures correspond exactly to the five shipped
sample decks and carry numeric axes, so it supplies the quantitative benchmark
that the distribution's missing reference output cannot.

Still open: ingesting all five into the literature-wiki. The ingest is paused at
the vocabulary-approval step (proposed: methods `dwia`, `johnson-tandy-adwa`,
`nonlocal-iteration-scheme`, `nonlocal-matrix-inversion-scheme`,
`t-rho-rho-folding`; observables `residue-momentum-distribution`,
`triple-differential-cs`; system `16c-12c`; five code entities plus lead-author
entities). Two findings from the reading worth filing when it resumes: SIDES
defines itself against NLAT by name ("without resorting to any ad-hoc seed as
required in iterative methods [4,13]", where [4] is NLAT), which is a real
methodological debate page; and NLAT's headline "4% accuracy" and "Ed = 10 to 70
MeV" appear only in its abstract, never derived in the body.

## Repo hygiene

- [ ] **Concurrent-session hazard, live as of 2026-07-20.** Another Claude session is working in this same repo: `scripts/kb_citegraph.py` (modified), `scripts/kb_citemap.py`, `scripts/citegraph_template.html`, and `fusion-web/` (a citation-graph web visualization) all appeared during this session and are not this session's work. They are deliberately left uncommitted. Consequence: **never `git commit -a` here**, always stage explicit paths, and check `git status` before and after. Same failure mode the profile records for 2026-07-14, when a parallel session silently dropped another's edits

## Wiki ingest queue

- TALYS code paper: Koning, Hilaire, Goriely, *TALYS: modeling of nuclear reactions*, Eur. Phys. J. A **59**, 131 (2023), DOI `10.1140/epja/s10050-023-01034-3`. Wiki precheck on 2026-07-20 returned **Related-only**: TALYS is named in 11 pages (methods/hauser-feshbach, entities/koning-aj, entities/ripl-library, and others) but has no source page of its own, so every mention is currently unanchored. Open access on SpringerLink, so no download trip needed.

## Completed

- [x] 2026-07-21: Seventh per-code skill: NLAT (skills/nlat/, Titus + Ross + Nunes, CPC 207, 499 (2016), GPLv3, CPC catalogue AFAY_v1_0). Single-nucleon transfer (d,p)/(d,n)/(p,d)/(n,d) in ADWA with explicitly NONLOCAL optical potentials, solved by iteration instead of the Perey correction factor. **Tier 1**: the distribution ships real reference output and the skill reproduces it. Local case 14 files / 1,863,151 numbers / worst 2.067e-11 (on a 6e-22 magnitude value); nonlocal case 11 files / worst 8.4e-07 on the iterated S-matrices with TransferCS at 1.3e-12, 1 h 26 min. Source is NOT where the paper says: the Queen's University CPC library is retired (HTTP 502) and AFAY_v1_0 lives on Mendeley Data, DOI 10.17632/xnwjvk86bs.1, free; archive byte count and line count both match the paper's own program summary. Codex adversarial pass confirmed **21 defects, all fixed**, three ship blockers (an rm -rf guard testing the reverse relationship to the dangerous one, the SAME class pikoe shipped with hours earlier; an all-NaN output reported as a perfect match; a reference fingerprint hashing ls -l metadata instead of content). Surfaced five upstream defects in NLAT itself, see devlog. FUSION now has 7 per-code skills (FRESCO, COLOSS, CCFULL, GSM, TALYS, pikoe, NLAT)

- [x] 2026-07-21: Sixth per-code skill: pikoe (skills/pikoe/, Ogata + Yoshida + Chazono, CPC 297, 109058 (2024), MIT). Exclusive (p,pN) knockout in DWIA: TDX, QDX, analyzing power, residue momentum distributions, normal and inverse kinematics. install/run/verify/check scripts; the run wrapper recreates the upstream sampleN/ layout with symlinks so the shipped decks are used verbatim. **Benchmark is figure-anchored, not reference-anchored**: upstream ships no reference output (readme documents one per sample directory, archive contains none, in both releases), but the five decks are exactly the paper's five figures, so peaks were compared against numeric axes (TDX 127.03 at 40.5 deg and 128.32 at 61.0 deg vs about 130 and 135; QDX 0.18147 at 185 MeV and 0.17408 at 325 MeV vs about 0.175 and 0.168; LG peak 36.724 vs about 37). Codex adversarial pass confirmed **24 defects, all fixed**, four of them ship blockers (an rm -rf guarding a different path than it deleted; zero-byte tables counted as results; a skipped check printing VERIFY OK; an unreachable diagnostic under set -euo pipefail). FUSION now has 6 per-code skills (FRESCO, COLOSS, CCFULL, GSM, TALYS, pikoe)

- [x] 2026-07-20: Fifth per-code skill: TALYS (skills/talys/, Koning + Hilaire + Goriely, EPJA 59, 131 (2023), MIT). install/run/verify scripts; 5 clean-room sample benchmarks (n-Nb093-14MeV-full, n-Sn120-omp-KD03, n-Th232-fis-wkb, n-Os187-astro-ng, p-Mo100-medical) reproducing 1415 of 1438 distributed reference files byte for byte, the remaining 18 data files to ~6 sig figs on 4633 observables (the precision of TALYS's own output format). Three traps found and handled, all of which produce confident-looking wrong results: locale-collation source glob dropping 13 files without LC_ALL=C; character(len=132) path cap forcing a short install root; and **exit status 0 on fatal error** (the CCFULL false-positive trap in a new guise). Citations verified live against CrossRef + INSPIRE; input reference written from the shipped 890-page manual, not from memory. FUSION now has 5 per-code skills (FRESCO, COLOSS, CCFULL, GSM, TALYS)
- [x] 2026-07-20: Fourth per-code skill: GSM (skills/gsm/, Michel + Ploszajczak, LNP 983 Springer 2021, github.com/GSMUTNSR/book_codes, AFL v3.0). Covers the whole Berggren/Gamow stack: one-body Gamow states, pole and antibound searches, complex-scaling widths, two-body and many-body GSM, GSM-CC. install_gsm.sh clones + unpacks the shipped zips + patches + builds any of 10 targets; run_gsm.sh runs with a clean-room guard; compare_gsm.sh does magnitude-split numeric comparison (a plain diff is wrong here: shipped references are GSM-1.0, sources are GSM-2.0, print format changed). Three clean-room benchmarks vs the book's own exercise outputs: Ch2 Ex XV neutron resonance 11 sig figs / 35 observables, Ch3 Ex XIII Berggren diagonalization in a foreign basis 9 sig figs / 562, Ch5 Ex II 18O many-body 8 sig figs / 2539 (ground state 12 figs). Found + patched an upstream infinite recursion in numlib `finite()` (see devlog). FUSION now has 4 per-code skills (FRESCO, COLOSS, CCFULL, GSM)
- [x] 2026-07-20: Phase 2 per-code skills, two shipped (both clean-room verified from public source). COLOSS (skills/coloss/, CPC 2025, Lei-eligible): builds from public repo (make + bundled C++ Coulomb lib + LAPACK), FRESCO cross-check n+40Ca sigma_R 1157.5 vs 1157.7 mb (4 sig figs) + complex-scaling theta-invariance 5 sig figs; radius convention (target-only At^1/3) documented. CCFULL (skills/ccfull/, Hagino CPC 1999, community): fetch+build from Kyoto page (FORTRAN77, gfortran -std=legacy), 16O+144Sm fusion reproduces reference barrier + sub-barrier excitation function exactly, tail 4-5 sig figs; caught+documented the interactive-stdin quirk. FUSION now has 3 per-code skills (FRESCO, COLOSS, CCFULL)
- [x] 2026-07-20: 108 topic-page Landscape syntheses written by DeepSeek (grounded in each topic's top-15 cited papers' abstracts), 108/108 topic pages, ~217k/40k tokens (pennies), 0 em-dash. Quality spot-checked (breakup, shell-model, astro all accurate)

- [x] 2026-07-20: Semantic layer (L3) COMPLETE. All 54,378 citing papers classified, 727,841 edges typed. Final distribution: background 485,740 (67%, dropped), uses 187,742, compares 20,767, contrasts 17,505 (2.4%), extends 11,361, applies 4,726; ~242k non-background kept (33%). `## Related work` injected into 44,891 pages (bidirectional). Claude QC: 0 fallbacks, contrasts spot-check all genuine disagreements, sample pages sensible. Phase 3 (knowledge base) core fully done: 4 layers live (concepts, citations, semantic relations, all on 61,059 pages). Bug fixed to get here: the last 3,181 recent/backfill papers hung the batch on KINGSTON .tex reads (no timeout on file I/O); fixed with --no-context (skip .tex for backfill papers, classify on titles+abstracts) + 60s API timeout + background-fallback-marks-done (see devlog 2026-07-20)
- [x] 2026-07-15: INSPIRE citation backfill DONE. Fetched references API for all 27,682 zero-outgoing-edge papers (27,630 hit INSPIRE, 99.8%, 52 not indexed), mapped to corpus ids, added 376,503 new in-corpus edges. Coverage: corpus-wide 81% -> 96%, newest-500 papers 27% -> 87% (the recent-preprint gap closed). Merged into citations.tsv (351k -> 728k edges), re-injected citation sections (36,980 pages updated). Verified 2604.11226 gains 8 correct edges. Zero LLM tokens. Tonight's semantic run now covers 54,378 citing papers (was 33,377)
- [x] 2026-07-15: Semantic layer (L3) built and validated. DeepSeek v4-pro on deepseek-semantic.md brief: citation-context extractor + relation classifier (6 types) + bidirectional page injector; 200-paper sample. Claude cross-review: hard gate 1711.07540->1511.03214 = extends verified against raw .tex; 3 contrasts edges independently confirmed real; type distribution healthy (76.6% background discarded, contrasts 2.6%). Fixed one self-flagged overfire (target-as-evidence-against-third-party now correctly `uses` not `contrasts`), re-verified. Merged kb-semantic; full 33,377-paper run armed off-peak
- [x] 2026-07-15: Phase 3 CORE COMPLETE. Full corpus digested (61,059/61,059 pages over 4 off-peak windows, zero API failures, ~$120 total). Cross-link layers built by DeepSeek v4-pro on the deepseek-crosslink.md brief and Claude cross-reviewed: L0 physh-nuclear.yaml (180 concepts, tiered matching, negative filters), L1 classification 38,824 papers tagged + 109 topic pages + index tree, L2 citation graph 351,338 in-corpus edges (calibration edge 1711.07540->1511.03214 verified; Tier A edge spot-checked in raw .tex; 81.2% of papers have >= 1 edge). All 61,059 pages carry concepts frontmatter + In-corpus citations sections. Final QC: 13 defect pages regenerated, 0 em-dash, 0 malformed
- [x] 2026-07-14: Phase 2 first per-code skill landed in-repo: `skills/fresco/` real self-contained copy (establishes skills/ layer) + binary auto-install (install_fresco.sh clones+builds I-Thompson/fresco when ~/bin/PATH lack it, run_fresco.sh auto-wires); gfortran build reproduces B1-elastic sigma_R = 1575.17495 (ref 1575.175). Codex cross-checked; caught the cp -R symlink trap (see devlog 2026-07-14), applied fixes #1/#12/#4/#16/#17
- [x] 2026-07-09: Phase 0 quality gate, all items: opencode 1.17.15 + DeepSeek/Qwen keys + 36 skills symlinked (pre-existing); 3 real-case tests vs Claude references (litsearch exact BibTeX; fresco 4-5 sig figs; prc-writing 10/10 verified citations); user verdict = proceed (phase0/report.md)
- [x] 2026-07-09: Phase 1 fork created: github.com/jinleiphys/fusion-core @ v1.17.16, default branch fusion-brand, dev = pristine upstream mirror
- [x] 2026-07-09: Phase 1 brand assets mapped; TUI logo patched ("FUSion" block glyphs + compact "fu" pulse logo, 3 glyph iterations with user screenshots); MIT notice untouched
- [x] 2026-07-09: Phase 1 CI weekly rebase (fusion-rebase.yml, Mondays 02:00 UTC) verified green on manual dispatch (run 29000283160)
- [x] 2026-07-09: Phase 3 design settled then revised same day: PhySH v2.8.0 (CC0) taxonomy, Nuclear subtree 176 concepts; wiki form changed from DB-rendered + digest-on-touch to pre-generated md (user decision; see devlog)
- [x] 2026-07-09: Phase 3 pilot: 500-paper digestion by DeepSeek via deepseek.md brief (500/500, $1.74, 9.5 min); Claude cross-review passed (structure 0 violations, no fabrication on calibration set, one new finding: raw cite-key leakage, fixed in template v2); merged kb-pilot into main (fa5ee32)
- [x] 2026-07-09: Template v2 (cite-key resolution, numeric-bullet rule, review-paper branch, reference-stripping before truncation) smoke-tested on 1812.11248; full-corpus list 61,059; off-peak launcher armed under caffeinate for tonight 00:30 (~$109 off-peak; user topping up 900 RMB)

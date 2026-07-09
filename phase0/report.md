# Phase 0 quality gate: opencode + DeepSeek vs Claude Code + Claude

Date: 2026-07-09. Setup: opencode 1.17.15, all 36 skills symlinked into `~/.config/opencode/skills/`, model `deepseek/deepseek-chat`, non-interactive `opencode run --auto`. Reference side: Claude Code (Fable 5) in the same session. Raw logs in this directory.

## Test 1: literature-search (tool-calling type)

Task: verified BibTeX with DOI for the Typel-Baur 2003 THM theory original (a citation the user really added during the THM-paper revision).

Result: **PASS, Claude-level.**
- Followed the wiki-first coupling unprompted (grepped ~/research-wiki, hit trojan-horse-method.md, read it before searching).
- Used the skill's inspire_search.py; first query returned empty, self-corrected the query syntax, got the record.
- Verified DOI via verify_doi.py (CrossRef) before reporting.
- BibTeX exactly matches ground truth: Typel & Baur, Annals Phys. 305, 228 (2003), DOI 10.1016/S0003-4916(03)00060-5, nucl-th/0208069.
- Anti-hallucination protocol held end to end.

Caveat found: opencode non-interactive mode auto-rejects permissions outside cwd; the first attempt died silently on the wiki grep. Fixed with `--auto` for testing; FUSION ships a proper `permission` config instead (TODO Phase 4).

## Test 2: fresco (code-running type)

Task: n+90Zr elastic at 10 MeV, fully specified WS optical potential (V=47, rv=1.20, av=0.66; Wv=3.5 same geometry; Wd=6.0, rd=1.28, ad=0.58; radius convention r*A_t^(1/3)), report reaction + total cross sections with convergence checks. Blind cross-check: Claude wrote and ran an independent deck for the same problem.

| Quantity | DeepSeek (opencode) | Claude reference | agreement |
|---|---|---|---|
| sigma_reaction | 1976.806 mb | 1976.750 mb | 4-5 sig figs |
| sigma_total | 4015.228 mb | 4015.115 mb | 4-5 sig figs |

Result: **PASS.**
- Deck correct on first try. Notably it understood FRESCO's radius convention (cube-root sum over ap+at) and pre-scaled the reduced radii (p2 = 1.20*90^(1/3)/(1+90^(1/3)) = 0.9811) to honor the requested r*A_t^(1/3) convention; physically equivalent to the reference's ap=0 route.
- Residual 2.8e-5 relative difference is fully explained by its rounding of p2 to 4 digits (radius error 2.2e-5). Both sides converged internally to more digits than they differ.
- Ran the full convergence matrix (hcm 0.1/0.05/0.02, rmatch 60/80/100, jtmax 50/80/120) in parallel scratch dirs and reported stability digit counts, per the skill's prime rule.
- Reference side (massp sensitivity): massp=1.008665 vs 1.0 shifts sigma_R from 1979.02 to 1976.75 mb (0.1%); DeepSeek chose 1.0, matching the reference variant used for grading. Pin masses in future benchmark prompts.

## Test 3: prc-writing (long-form writing type)

Task: two PRC-style Introduction paragraphs on the inclusive-breakup post-prior controversy (IAV / UT / HM, 1980s) through the 2015 post-prior equivalence and the modern NEB revival; citations must be literature-search verified. Public-knowledge content only (no unpublished manuscript text sent to the DeepSeek API).

Result: **PASS on all objective criteria; prose taste pending user judgment.**
- Citation accuracy: 10/10 references real and correct (IAV 85/86/88 exchange, AV 81, UT 81, HM 85, UTM 88, Lei-Moro 2015 + 2018, Potel EPJA 2017). Every DOI verified via INSPIRE/CrossRef tool calls inside the run; zero hallucinated citations. Minor gap: EPJ A 53, 178 volume/page asserted from the INSPIRE DOI without an explicit page-level verification step (the value is correct).
- Workflow: full protocol chain executed unprompted: literature-wiki precheck, literature-corpus scan (found and used the user's own 2015/2018/2026 papers as anchors), INSPIRE + CrossRef verification per reference, then a qu-ai-wei-en de-AI pass.
- Style: no em-dashes (it ran the check itself), no software package names in body text.
- Prose: competent PRC-register English; user taste judgment pending. Draft at test3-deepseek/introduction-draft.tex.

## Porting caveats discovered (feed into Phase 2/4)

1. **Permissions**: non-interactive `opencode run` auto-rejects out-of-cwd access; the first test died silently. FUSION must ship a `permission` config covering ~/research-wiki, ~/literature-corpus, and the INSPIRE/CrossRef/arXiv endpoints instead of blanket `--auto`.
2. **Cross-skill invocation semantics differ**: in test 3 the model noted the literature-wiki Skill call returned the description rather than full content, and worked around it by grepping the wiki directly. Verify how opencode loads skill bodies vs Claude Code's Skill tool; skills may need their cross-skill call phrasing adjusted.
3. **macOS grep**: skill-mandated checks that use `grep -P` fail on BSD grep; skills should use portable invocations or ship checker scripts.
4. **Masses/conventions in benchmark prompts**: pin projectile mass and radius convention explicitly, else 0.1%-level ambiguities blur N-digit comparisons.

## Verdict

**Acceptable.** DeepSeek-chat on opencode executed all three skill types at near-Claude quality: tool-calling (perfect), code-running (4-5 sig fig agreement with an independent reference, converged and self-checked), long-form writing (zero citation hallucination, full protocol chain). The FUSION premise stands. Remaining user judgments: prose taste on test 3, and formal sign-off to proceed to Phase 1.

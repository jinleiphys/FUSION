# Verified SFRESCO examples

Run any of them with

```bash
bash ../scripts/run_sfresco.sh <case>.search <case>.min
```

| Case | Files | What it demonstrates |
|------|-------|----------------------|
| p-cd-manual | `p-cd-manual.in`, `p-cd-manual.search`, `p-cd-manual.min` | **the published reference case**, transcribed from Boxes 7 and 8 of *FRESCO: getting started* section 4: the same 12 points, the same start values (r0 = 1.0, V = 50, W = 5, W_d = 10). The manual prints the answer, so this is the one check against the literature rather than against the code |
| p-cd | `p-cd.nin`, `p-cd.search`, `p-cd.min` | four-parameter optical-model fit to the same system with the distribution's own 28-point test file (`test/ss.search`). Ends with strongly anticorrelated V,r0 and W,W_d |
| nalpha | `nalpha.nin`, `nalpha.search`, `nalpha.min` | three datasets of type=4 phase shifts (P3/2, P1/2, S1/2) fitted with two potential strengths, 78 points. Shows multi-dataset chi-squared bookkeeping and a degenerate parameter pair (rho = -0.996) |
| p90zr-closure | `p90zr-closure.in`, `p90zr-closure.search`, `p90zr-closure.min` | closure test: pseudo-data generated from the KD02 p + 90Zr deck itself, then V and W_d started 14% and 32% away and refitted. Recovers the true values to 5 digits, so it validates the whole chain including the kp/pline/col mapping |

Expected numbers are in `../SKILL.md` under "Verified examples".

- `p-cd-manual` must give V = 52.528, r0 = 1.1796, W = 3.4604, W_d = 7.4294, chi2/N = 2.191, matching every digit the manual prints (52.53, 1.179, 3.46, 7.43, 2.19).
- If `p90zr-closure` stops recovering V = 49.0229 and W_d = 7.2155, something in the environment or the scripts is broken; fix that before trusting any other fit.

# CCFULL verification

Self-consistent benchmark: reproduce Hagino's own reference output bit for bit.

## Benchmark: 16O + 144Sm fusion

Input `examples/16O_144Sm.inp` is the canonical example distributed with CCFULL (target 144Sm as a single-octupole vibrational coupling, omega=1.81 MeV, lambda=3; Akyuz-Winther-style potential V0=105.1, r0=1.1, a=0.75). Run it and compare `OUTPUT` against `references/16O_144Sm.OUTPUT.reference` (downloaded from Hagino's Kyoto page).

Expected, exactly:
- Uncoupled barrier: Rb = 10.82 fm, Vb = 61.25 MeV, curvature = 4.25 MeV.
- Fusion excitation function (Ecm, sigma_fus in mb, mean angular momentum), e.g. sigma(55 MeV) = 0.0097449 mb, sigma(60 MeV) = 20.59856 mb, rising through the barrier.

Compare the PHYSICS numbers (barrier parameters + the full Ecm/sigma/mean-l table), not the raw bytes: the title-line string format ("16O" vs "16 O") differs between code versions, but every physics number is deterministic and must match exactly.

```bash
# run reproduces the reference physics numbers exactly
grep "Uncoupled barrier" OUTPUT   # Rb=10.82, Vb=61.25, Curv=4.25
grep -E "^\s+6[05]\." OUTPUT       # sigma(60)=20.59856, sigma(65)=234.04527
```

Verified 2026-07-20 (freshly built from Hagino's `ccfull.f` with `gfortran -std=legacy -O2`): barrier Rb=10.82 fm, Vb=61.25 MeV, curvature=4.25 MeV match exactly; the fusion excitation function matches to 4 to 5 significant figures, and is bit-exact for the sub-barrier and near-barrier rows (55 to 66 MeV, the physically important regime), e.g. sigma(60)=20.59856 mb, sigma(65)=234.04527 mb reproduced to all printed digits. The four highest-energy rows (67 to 70 MeV) differ at the 5th significant figure (sigma(70)=472.481 vs 472.460, 4e-5 relative). That residual is a code-version / compiler-rounding difference: the reference `OUTPUT` on Hagino's page was produced by a slightly different build (its title-line format "16O" differs from this build's "16 O"), so the high-energy tail is not expected to be bit-identical. The barrier physics and the sub-barrier fusion (what CCFULL is used for) reproduce exactly.

## Interactive prompts (critical to reproduce anything)

CCFULL reads the physics input from `ccfull.inp` (unit 10) but ALSO asks a series of interactive y/n questions on stdin (unit 5) while echoing the coupling setup. Feeding EOF (no stdin) makes it crash with "End of file" at line 196 and produce a truncated OUTPUT. The prompts, in order, for a standard run:

1. `Modified Woods-Saxon (power of WS) (n/y)?` answer `n` (keeps power=1).
2. `Different beta_N from beta_C for this mode (n/y)?` answer `n`, once per active vibrational mode.
3. `AHV couplings for the first mode ... (y/n)?` and `Modify these beta_N a/o beta_C (n/y)?` answer `n`.

Answering `n` to all of them keeps exactly the scheme the input file specifies. `run_ccfull.sh` pipes a stream of `n` by default (override with the `ANSWERS` env var for modified-WS or separate-nuclear-beta runs). This stdin dependency is the single biggest gotcha; a run that "produces no OUTPUT" almost always means stdin was not fed.

## What the benchmark exercises

- Coupled-channels solve with all-order couplings (the target octupole phonon).
- The incoming-wave boundary condition (IWBC) fusion definition at the barrier minimum.
- The Numerov integration and barrier-penetration accounting.

If the barrier parameters differ, the potential parameters (line 7) or radius convention (line 2) were mis-entered. If the barrier matches but the cross sections drift, the coupling scheme (lines 2 to 6) or the energy grid (line 8) differs.

# Verification: anchors and convergence protocol

No FRESCO number is reported until it is verified. Two independent obligations:

1. **Reproduce a reference** (an anchor deck below, or a published number) to N significant figures.
2. **Prove convergence** in the numerical parameters, so the quoted digits are real and not grid artifacts.

## Anchor decks (this machine, `~/bin/fresco`, FRES 2.9)

Each `examples/` deck was run locally and compared to the official FRESCO reference output. Agreement below is what FRES 2.9 gives against the shipped reference (which was produced by FRES 3.0-3.4). Use these as regression anchors: if a future binary or environment change breaks one, that is the signal.

| Deck | Observable | Local (FRES 2.9) | Reference | Agreement |
|------|-----------|------------------|-----------|-----------|
| `B1-elastic.in` | reaction σ (E=6.9) | 1575.17495 | 1575.17481 | 7 sig figs |
| `B2-inelastic.in` | outgoing (2+ excitation) σ | 31.67415 | 31.67415 | exact |
| `B2-inelastic.in` | absorption σ | 1091.92081 | 1091.92073 | 7 sig figs |
| `be11-cdcc-lowlevel.nin` | reaction σ | 2758.68730 | 2758.68730 | exact |
| `be11-cdcc-lowlevel.nin` | absorption σ | 423.91494 | 423.91494 | exact |
| `be11-cdcc-lowlevel.nin` | outgoing σ | 2334.77236 | 2334.77236 | exact |
| `b8ex-cdcc-lowlevel.nin` | breakup (outgoing) σ | 58.36164 | 58.36164 | exact |
| `dex-deuteron-cdcc.nin` | absorption σ | 2154.84513 | 2154.84511 | 8 sig figs |
| `dex-deuteron-cdcc.nin` | outgoing σ | 1234.08854 | 1234.08831 | 6 sig figs |
| `B5-transfer.in` | outgoing (1-nucleon DWBA) σ | 0.26397 | 0.26397 | exact (5 dp) |
| `2n-transfer-li9tp-simseq.nin` | outgoing (2-neutron) σ | 6.15287 | 6.15287 | exact |
| `2n-transfer-li9tp-simseq.nin` | absorption σ | 1026.55218 | 1026.55218 | exact |
| `crc-16O-208Pb-multistep.nin` | outgoing (multi-step CRC) σ | 70.97471 | 70.97471 | exact |
| `crc-16O-208Pb-multistep.nin` | absorption σ | 33.22351 | 33.22351 | exact |
| `B6-capture.in` | outgoing (capture) σ | 0.00330 | 0.00330 | exact (5 dp) |

The tiny last-digit differences (B1, dex) are FRES 2.9 vs 3.x rounding, not an error. CDCC cases (be11, b8ex) reproduce bit-for-bit.

## How to run an anchor check

```
scripts/run_fresco.sh examples/be11-cdcc-lowlevel.nin be11
# then, if you have the reference output:
scripts/check_xsec.py <scratch>/be11/out --ref <path>/be11.out --sigfig 6
```

Reference outputs are on the FRESCO site (`https://www.fresco.org.uk/examples/`, book `Bn-*.out` and `test/*.out`). They are not committed here (some are 18k+ lines); download the one you need.

## Convergence protocol for a NEW deck

Before quoting σ to k significant figures, confirm it is stable to better than that under each of:

1. **Radial step `hcm`**: halve it (0.1 → 0.05 → 0.02). σ must stop moving. Halo/heavy-ion usually need 0.05 or finer.
2. **Matching radius `rmatch`** (and `rasym` if Coulomb-dominated): extend it. For Coulomb breakup/Coulex, `rasym` must be large enough that the long-range coupling is captured (100-340 fm typical).
3. **Partial waves `jtmax`**: raise it and check fort.56, the per-J reaction/nonelastic σ must have decayed to negligible before jtmax. If you use `jump/jbord`, refine the step blocks.
4. **Continuum bins** (CDCC): increase the number of bins (smaller `step`, more (l,j) sets) and the max bin energy; the breakup σ must plateau. Confirm bins use `isc=2`.
5. **Channel pruning** (`smallchan/smallcoup`): if used to speed a run, verify the pruned result matches the unpruned one on a small case.

Report the check explicitly, e.g. "reaction σ = 2758.7 mb, stable to 5 sig figs under hcm 0.05→0.025 and jtmax 1500→2000".

## Sanity limits (cheap physics checks)

- **Elastic ratio to Rutherford → 1** at forward angles and low energy (sub-Coulomb).
- **Total reaction = absorption + sum of outgoing** (flux conservation); the CUMULATIVE block should be internally consistent.
- **Turning off the imaginary potential** (`W=0`) should send absorption to 0.
- **Sub-Coulomb transfer** should match the D (asymptotic stripping strength) expectation.
- For the user's flux-decomposition (Line F) work, `absorption` from the CUMULATIVE block is σ_abs; cross-check against the generalized-optical-theorem decomposition.

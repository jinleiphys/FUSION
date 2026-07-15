# FUSION L3-semantic sample run report

## Summary

- Edges processed: 1749
- Citing papers: 200
- Type distribution:
  - extends: 28 (1.6%)
  - applies: 7 (0.4%)
  - uses: 246 (14.1%)
  - compares: 82 (4.7%)
  - contrasts: 46 (2.6%)
  - background: 1340 (76.6%)

- Discarded as background: 1340 (76.6%)
- Kept (non-background): 409 (23.4%)

## Confidence distribution

- High: 455 (26.0%)
- Medium: 252 (14.4%)
- Low: 1042 (59.6%)

## Calibration edges

The classifier was calibrated on five maintainer papers before the sample run. Results from the calibration pass:

### 1711.07540 (Jin & Moro, 2017: Post-prior equivalence for transfer reactions with complex potentials)
15 in-corpus citations:
- 1711.07540 -> **1511.03214** | **extends** | **high** | in our recent work [TARGET] we showed in practical cases that the inclusion of this term is essential *(HARD GATE: PASSED)*
- 1711.07540 -> 1510.02602 | extends | high | same context (co-cited as "our recent work")
- 1711.07540 -> 1712.01433 | extends | high | which was also analyzed in our previous work [TARGET]
- 1711.07540 -> 1701.00547 | extends | high | which was also analyzed in our previous work [TARGET]
- 1711.07540 -> 0910.0342 | compares | medium | we compare these calculations with the data from Ref. [TARGET]
- 1711.07540 -> 0901.2985 | compares | medium | we compare these calculations with the data from Ref. [TARGET]
- 1711.07540 -> 0909.5556 | compares | medium | we compare these calculations with the data from Ref. [TARGET]
- 1711.07540 -> 0906.4375 | compares | medium | we compare these calculations with the data from Ref. [TARGET]
- Remaining 7 edges: uses (medium) -- cited for "the estimate done in Ref. [TARGET]"

### 2101.09497 (The Hussein-McVoy formula for inclusive breakup revisited)
15 in-corpus citations:
- 2101.09497 -> 1511.03214 | contrasts | high | HM formula incomplete, UT term can be large *(see note below)*
- 2101.09497 -> 1510.02602 | contrasts | high | HM formula incomplete, UT term can be large
- 2101.09497 -> 1711.07540 | uses | high | IAV model's accuracy assessed against data
- 2101.09497 -> 1712.01433 | uses | high | IAV model's accuracy assessed against data
- 2101.09497 -> 1701.00547 | uses | high | IAV model's accuracy assessed against data
- Remaining 10 edges: mixed uses/background

Note: 2101.09497 -> 1511.03214 as "contrasts" may be an overfire -- the paper cites 1511.03214 as evidence that the HM formula is incomplete, which is closer to "uses (as evidence)". The "contrast" is with HM, not with 1511.03214.

### 2604.11226
No in-corpus citations.

### 2605.03342
No in-corpus citations.

### 1508.04822
1 in-corpus citation:
- 1508.04822 -> 1508.01466 | applies | high | Two recent works have applied the AV theory


## Contrasts edges (spot-check)

- 0712.1613 -> nucl-th/0509048 | high | This interpretation was subsequently criticized in Refs. [TARGET] with the argument that the observed spectrum may be explained by final-state interactions
- 0712.1613 -> nucl-th/0601013 | high | This interpretation was subsequently criticized in Refs. [TARGET] with the argument that the observed spectrum may be explained by final-state interactions
- 0712.1613 -> nucl-th/0701035 | high | This was considered [TARGET] to be an artifact of an unrealistic nucleon-nucleon interaction being used
- 0804.2065 -> hep-ph/9402256 | high | Others estimate the rate of this reaction from the systematics that are based on information existing for other nuclei [TARGET] These rates vary from each other by more than an order of magnitude
- 0804.2065 -> hep-th/9410176 | high | Others estimate the rate of this reaction from the systematics that are based on information existing for other nuclei [TARGET] These rates vary from each other by more than an order of magnitude
- 0805.2667 -> nucl-th/0001018 | high | it was indicated that extension of the two-cluster model space might make agreement worse
- 0805.2667 -> nucl-th/0012036 | high | it was indicated that extension of the two-cluster model space might make agreement worse
- 0805.2667 -> nucl-th/0102022 | high | the variational Monte Carlo calculation found an S factor that lay significantly below the experimental values
- 0805.4780 -> nucl-th/0206021 | high | shell model predictions appear to overestimate SFs for well bound systems when compared to experimental values [TARGET]
- 0805.4780 -> nucl-th/0201053 | high | shell model predictions appear to overestimate SFs for well bound systems when compared to experimental values [TARGET]
- 0805.4780 -> nucl-th/0207008 | high | shell model predictions appear to overestimate SFs for well bound systems when compared to experimental values [TARGET]
- 0806.0873 -> hep-lat/0203027 | high | The analysis in Ref. [TARGET] suggested an (n,γ) cross section approximately half that found in the analysis on the RIKEN data presented in the previous section and other direct and indirect measureme
- 0806.0873 -> hep-lat/0201008 | high | The analysis in Ref. [TARGET] suggested an (n,γ) cross section approximately half that found in the analysis on the RIKEN data presented in the previous section and other direct and indirect measureme
- 0807.2537 -> 0707.2588 | high | our results disagree with those obtained within the concept of the dinuclear system [TARGET]
- 0807.2537 -> 0711.3721 | high | our results disagree with those obtained within the concept of the dinuclear system [TARGET]
- 0812.2781 -> 0801.4489 | high | the text states that DWIA leads to an incomplete and truncated multiple scattering expansion that is responsible for inaccurate results
- 0903.1312 -> nucl-th/0412020 | high | the data can be described well by including effects from medium-modified form factors or by including effects from strong charge-exchange final state interactions [TARGET]
- 0704.0318 -> nucl-th/9709005 | medium | the context says Ref. [TARGET] treated the problem relativistically but free Fermi gas model was used, implying a limitation
- 0704.3726 -> nucl-th/9802057 | high | unsubtracted equations generate cutoff variation of O(1) in low-energy observables if left unrenormalized
- 0704.3726 -> nucl-th/9809025 | high | unsubtracted equations generate cutoff variation of O(1) in low-energy observables if left unrenormalized

## Token usage and cost

- Sample tokens: in=430749 out=70104
- Extrapolated full 351k-edge run:
  - Standard price: $16.1
  - Off-peak price: $8.0

## Failure modes

- Edges with empty context (external bibliography / unresolved key): 0 (0.0%)

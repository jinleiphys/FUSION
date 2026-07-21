# 16O(p,gamma)17F: benchmark case constructed from PRC 81, 045805 (2010)

**Status: input deck verified exactly against the published parameter table.
Derived observable reproduces the published value to 5.8%, not to N significant
figures. Read the "What is and is not verified" section before citing this.**

The AZURE2 distribution ships no `.azr` example, so this case is **constructed
from published numbers** rather than obtained from the authors, per the
2026-07-21 decision in CLAUDE.md. Source: Azuma et al., *AZURE: An R-matrix code
for nuclear astrophysics*, Phys. Rev. C **81**, 045805 (2010), Sec. IV C and
Table V. Citation verified live against CrossRef, DOI `10.1103/physrevc.81.045805`.

## What the paper specifies, and where each number came from

| Input | Value | Source |
|---|---|---|
| Channel radius `ac` | 5.0 fm | Sec. IV C 1, "adopted from Ref. [55]" |
| Ground state | Jπ = 5/2+, `C_d5/2` = 1.05 fm^(-1/2) | Sec. IV C, Table V |
| First excited state | 0.495 MeV, Jπ = 1/2+, `C_s1/2` = 80.7 fm^(-1/2) | Table V |
| Resonance 1 | 3.103 MeV, Jπ = 1/2− (Ep = 2.659 MeV) | Sec. IV C 1 |
| Resonance 2 | 3.859 MeV, Jπ = 5/2− (Ep = 3.463 MeV) | Sec. IV C 1 |
| Background pole | 4.711 MeV, Jπ = 3/2− | Sec. IV C 1 |
| Reduced widths | the seven `γp`, `γγ0`, `γγ1` entries | Table V |
| Multipolarity | E1 only (`ecMultMask = 1`) | Sec. IV C 1 |
| Bound-state orbitals | 1d5/2 and 1s1/2 | Sec. IV C 1 |

Two things follow from the Jπ assignments rather than being stated: 1/2− and
3/2− are l = 1 proton channels, 5/2− is l = 3, since parity = (−1)^l for
p + 16O(0+). The separation energy 0.60027 MeV is not quoted in the paper but is
**checked against it**: it is what makes the computed lab energies reproduce the
Ep column of Table V (−638, −112, 2659, 3463, 4368 keV) to 1-2 keV.

## Conventions, and why the deck runs in transform mode

Table V mixes two conventions in one column, exactly as AZURE2's input does: the
bound levels carry an **ANC in fm^(-1/2)** and the unbound ones a **reduced
width amplitude in MeV^(1/2)**. AZURE2's default (transform) mode wants the ANC
verbatim for a bound particle channel but a **partial width in eV** for
everything else, so the seven unbound entries need conversion.

`calibrate_widths.py` does that conversion **using AZURE2's own transform**
rather than an independent penetrability calculation of mine: it runs the code,
reads `g_int` back out of `parameters.out`, and drives each width to its
published target by secant iteration. Converged: **all nine parameters in
`parameters.out` match Table V to every printed digit** (1.050000, 80.700000,
0.141500, 0.043590, 0.245600, 0.053440, 0.751900, −0.095860, 0.004040).

The alternative, running `--no-transform` and typing Table V's amplitudes in
directly, was tried and **rejected on physics**. It gives a similar number at
90 keV but destroys the ANC normalisation, because `--no-transform` skips the
ANC-to-amplitude conversion. The channel-radius test below is what exposed it:

| `ac` | S(90 keV), transform mode (ANC live) | S(90 keV), `--no-transform` |
|---|---|---|
| 4.0 fm | | 3.58 keV b |
| 4.5 fm | 7.612 keV b | 5.28 keV b |
| 5.0 fm | 7.584 keV b | 7.60 keV b |
| 5.5 fm | 7.590 keV b | 10.72 keV b |
| 6.0 fm | | 14.88 keV b |

ANC-normalised external capture **must** be nearly independent of the channel
radius, since the ANC fixes the asymptotic tail and the interior contributes
little. Transform mode shows exactly that: 0.4% spread over 4.5 to 5.5 fm. The
`--no-transform` variant varies by a factor of 4 over the same range, which is
the signature of a broken normalisation. Both modes happen to agree at
`ac = 5.0` fm because that is where the amplitudes were converted, so a check at
a single radius would have called them equally good.

## What is and is not verified

**Verified.** The deck reproduces every parameter of Table V exactly, is stable
against channel radius as the physics requires, and the S factor extrapolates to
S_tot(0) ≈ 10 keV b, consistent with the literature value near 10.5 keV b.

**Not verified to N digits.** The paper's one published observable for this case
is S(90 keV) = 8.07 keV b (Sec. IV C 2). This deck gives:

| | S (keV b) |
|---|---|
| gamma0 (to the 5/2+ ground state) | 0.399 |
| gamma1 (to the 1/2+ 495 keV state) | 7.203 |
| **total** | **7.602** |
| **paper** | **8.07** |
| deviation | **−5.8%** |

That gap is real and is **not** explained by any of the following, each tested:
the channel radius (0.4% over 4.5-5.5 fm), the resonance and background-pole
parameters (moving them from placeholders to their Table V values shifts the
total by 0.02 keV b, since 90 keV is far below every resonance), or the missing
li = 3 entrance pathway (adding a 7/2− group raises the total by 1.4%).

The most likely residue is that the published fit contains entrance Jπ groups or
level-scheme details that Table V does not tabulate. AZURE2 enumerates external
capture pathways only over Jπ groups that exist among the supplied levels
(`CNuc.cpp:740-800`), so any group the authors included but did not print is
silently absent here, and it can only add strength. That is consistent with the
sign of the discrepancy but has not been demonstrated, and is recorded as an
open question rather than a conclusion.

**Do not describe this case as reproducing the paper's S factor.** It reproduces
the paper's *inputs* exactly and its *observable* to 6%.

## Reproducing

```bash
bash ../../scripts/install_azure2.sh          # prints AZURE2=<path>
python3 calibrate_widths.py <path>            # converges, rewrites the .azr
printf '3\n\n\n6\n' | <path> --no-gui 16O_pg_17F.azr
awk 'NF{print $5*1000}' output/AZUREOut_aa=1_R=2.extrap   # S_gamma0, keV b
awk 'NF{print $5*1000}' output/AZUREOut_aa=1_R=3.extrap   # S_gamma1, keV b
```

`.extrap` columns are: E_cm (MeV), excitation energy (MeV), CM angle (deg),
cross section (b), S factor (**MeV b**, hence the factor 1000). The `minE`/`maxE`
in `<segmentsTest>` are **lab** energies, so 90 keV CM is entered as 0.095670.

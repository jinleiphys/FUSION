# 14N(p,gamma)15O, the 6.79 MeV transition, from PRC 81, 045805 (2010)

**Status: a deliberately PARTIAL reconstruction. It covers one transition out of
seven, and that is the honest maximum, not a shortcut.**

S_6.79(0) = **1.257 keV b** against the published **1.30 keV b**, i.e. **-3.2%**,
which sits inside the paper's own stated data-selection sensitivity for this
transition (see below).

## Why only one transition

The full 14N(p,gamma)15O case of this paper **cannot be reconstructed**, and the
reason is worth stating because Table IV looks like an ideal anchor: it publishes
S(0) per transition plus a total of 1.81 keV b. The input side does not support
it:

- **Table II is captioned "for the three strongest transitions"** and gives gamma
  widths for the 0.00, 6.18 and 6.79 final states only.
- **The 5.18 MeV final state has no ANC in Table III and no gamma width in
  Table II.** It is unspecified in both places, so it cannot be built at all.
- **The signs of the reduced-width amplitudes are never published**, while the
  ground-state S(0) is explicitly "determined by the interference between
  different Jpi = 3/2+ reaction components". Four components give eight sign
  combinations spanning orders of magnitude. Table III adds its own warning that
  "there is a sign ambiguity in the conversion".

Choosing those signs to land on 0.28 keV b would be fitting to the answer.

**The 6.79 transition is the exception, and it is the largest one**: 1.30 of the
1.81 keV b total, 72%. It is tractable because the paper says capture to it "shows
a strong I = 3/2 external capture component **added incoherently** to the
0.259 MeV resonance". Incoherent addition means no relative sign enters, so the
one blocking ambiguity does not apply here.

## Inputs, and where each came from

| Input | Value | Source |
|---|---|---|
| Channel radius | **5.5 fm** | Sec. IV B, "a radius parameter of a = 5.5 fm was adopted for all fits". **Not** the 5.0 fm used for 16O(p,g)17F |
| Final state 6.79 | Jpi = 3/2+, ANC `C_s3/2` = **4.86 fm^(-1/2)**, channel (s, 3/2) | Sec. IV B; Table III |
| 0.259 MeV resonance | Jpi = 1/2+, Gp = 1.0 keV, Ggamma_6.79 = 9.6 meV | Table II |
| Separation energy | Sp(15O) = **7.2971 MeV** | **External (TUNL A=15).** The paper never states it |
| Entrance partial wave | li = 1, E1, channel spin I = 3/2 | Sec. IV B |

The separation energy is checked against the paper rather than merely adopted:
with Sp = 7.2971 the level energies reproduce the paper's quoted center-of-mass
values, the subthreshold state landing at -0.504 MeV and the resonance at
+0.259 MeV.

Note the 6.79 MeV state **is** the subthreshold level at Ec.m. = -0.504 MeV, so
the final state of this transition and the subthreshold resonance are one state.

Three **dummy levels** (Jpi = 1/2-, 3/2-, 5/2- at 20 MeV) carry the li = 1,
I = 3/2 entrance channels. They are not physics and are not in any table; AZURE2
enumerates external-capture pathways only over Jpi groups present among the
supplied levels, so without them the transition has no entrance wave at all. See
`../../references/failure-modes.md`.

## Checks

All run through the shipped harness.

| check | expectation | result |
|---|---|---|
| dummy level placement, 15 / 20 / 30 MeV | inert | identical to 4 decimals |
| channel radius, 5.0 / 5.5 / 6.0 fm | nearly flat (ANC fixes the tail) | 1.2689 / 1.2572 / 1.2483, **1.6% spread** |
| ANC scaled by 0.5 / 1 / 2 | exactly C^2, so ratios of 4 | 3.93 and 3.97 |
| 0.259 MeV resonance gamma width -> 0 | small at E -> 0 | 1.2499, so the resonance is worth **0.6%** |

The last row settles a documented ambiguity rather than ignoring it. The paper
never states the multipolarity of the 1/2+ -> 3/2+ transition, which permits M1
(L=1) or E2 (L=2); this deck uses M1, following the paper's blanket rule that
"only the lowest incident li value and multipolarity L would contribute". Since
the entire resonance term is worth 0.6% of S(0), the choice cannot move the
anchor materially.

## The -3.2%

| | S_6.79(0) (keV b) |
|---|---|
| this deck | **1.257** |
| paper, Table IV | **1.30** |
| deviation | **-3.2%**, i.e. -0.043 keV b |

**The paper's own caption bounds its number more loosely than that.** Table IV
states: *"Excluding the data of Ref. [42] in the 6.79 MeV transition would give
an S(0) ~ 0.1 keV b lower."* So the authors report a **0.1 keV b (7.7%)**
sensitivity of this very number to a data-selection choice. The -0.043 keV b
found here is a factor of two inside that.

That is a bound, not an explanation, and it is stated as one. What has been
established is that the deck encodes the published inputs, behaves correctly on
every invariance the physics requires, and lands within the paper's own quoted
sensitivity. It has **not** been established that the remaining 3.2% is
accounted for.

Sp is again a candidate: as in the 16O case, a weakly bound final state makes S
sensitive to a separation energy the paper never prints. Not quantified here.

## Reproducing

```bash
bash ../../scripts/run_azure2.sh 14N_pg_15O_679.azr 3
awk 'NR==1{print $5*1000}' output/AZUREOut_aa=1_R=2.extrap   # S at E_cm = 1 keV, in keV b
```

The `<segmentsTest>` grid runs from 1 keV to 0.5 MeV in the CM (entered as lab
energies, ratio 1.0719717). S is flat enough at the bottom that the first grid
point stands in for S(0): 1.2572 at 1 keV.

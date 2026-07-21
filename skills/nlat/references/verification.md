# NLAT verification

Established 2026-07-21 on macOS 15 (arm64), gfortran 15.2.0 (Homebrew GCC),
upstream's own `makefile_gfortran` (`-std=legacy`), AFAY_v1_0 from Mendeley Data
(sha256 `f2b4441d...ced7c0d1`, 15253066 bytes).

## Benchmark tier: 1

The distribution ships **real reference output**, not just inputs:
`LOCAL_SAMPLE/` and `NONLOCAL_SAMPLE/` each contain the deck plus the full set of
result files it produces. So the FUSION standard applies directly, reproduce the
code's own documented values, and NLAT meets it.

Provenance of the archive is doubly confirmed against the paper's own program
summary: the byte count (15253066) and the total line count across the extracted
tree (662136) both match the figures printed there. This is the genuine
AFAY_v1_0 distribution, not a repackaging.

## Why the comparison is numeric and not `diff`

NLAT writes full double precision. A different compiler or architecture changes
the last digit or two of nearly every number while the physics is unchanged, so
a plain `diff` reports thousands of meaningless differences and buries any real
one. `compare_nlat.py` compares token by token and reports the worst **relative**
difference per file, with a 1e-6 threshold.

Two guards against a flattering result, both of which have bitten this project
before:

- A **zero-byte reference is SKIPPED, never counted as a match.** Five of the
  nineteen reference files in `LOCAL_SAMPLE` are empty by construction, because
  a local-only run still creates the nonlocal output files. "Empty equals empty"
  is not evidence.
- **If nothing was compared, the result is failure.** A comparison that silently
  checked zero files is the most flattering possible way to be wrong.

## Clean room, and why it matters more here than usual

Each shipped deck names its own output **directory**, and in the distribution
that name is the sample directory itself. Running a shipped deck from inside the
unpacked tree therefore writes results on top of the reference output, and every
comparison afterwards compares the run against itself.

`run_nlat.sh` always runs in a fresh workdir, so the install tree is never
written to. `verify_nlat.sh` additionally fingerprints every reference `.txt`
before and after the run and aborts the comparison if anything changed. The
clean room is asserted, not assumed.

## Results

### local: 48Ca(d,p)49Ca at Ed = 10 MeV, local DWBA

Deck `dp48Ca_10-0_DWBA.in`. Runtime 4 min 51 s on one core. Output 48 MB.

| file | numbers | worst relative difference |
|---|---|---|
| DeuteronBoundWF.txt | 6000 | 0 |
| DeuteronElasticCS.txt | 540 | 5.031e-15 |
| DeuteronLocalIntegral.txt | 549122 | 5.954e-14 |
| DeuteronLocalSmatrix.txt | 244 | 0 |
| DeuteronRatioToRuth.txt | 540 | 5.185e-15 |
| DeuteronScatWFs.txt | 548939 | 0 |
| LocalBoundWF.txt | 12000 | 0 |
| NucleonBoundWF.txt | 6000 | 0 |
| NucleonElasticCS.txt | 540 | 1.523e-15 |
| NucleonLocalIntegral.txt | 369082 | 2.067e-11 |
| NucleonLocalSmatrix.txt | 164 | 0 |
| NucleonRatioToRuth.txt | 540 | 1.767e-15 |
| NucleonScatWFs.txt | 369082 | 0 |
| **TransferCS.txt** | **358** | **2.411e-15** |

**14 files compared, 1,863,151 numbers, worst relative difference 2.067e-11,
zero values above 1e-6.** Five files skipped as empty references
(`NonlocalBoundWF`, `Deuteron/NucleonNonlocalIntegral`,
`Deuteron/NucleonNonlocalSmatrix`), which is correct for a local-only run.

The single 2.067e-11 outlier in `NucleonLocalIntegral.txt` sits on a value of
magnitude 6e-22, i.e. the double-precision noise floor of a quantity that is
numerically zero. It is not a physics difference.

Twelve of the nineteen files are **bit-identical** to the distribution; seven of
those twelve are non-empty, the other five being the empty-by-construction
nonlocal files.

### nonlocal: 48Ca(d,p)49Ca at Ed = 20 MeV, nonlocal ADWA

Deck `dp48Ca_20-0_NL.in`. This is the case that exercises the iterative solution
of the integro-differential equation with Perey-Buck nonlocality, i.e. the
code's reason for existing.

Runtime **1 h 26 min** on one core (5169 s), inside the paper's "less than 2
hours". Output 19 files.

| file | numbers | worst relative difference |
|---|---|---|
| DeuteronBoundWF.txt | 6000 | 0 |
| DeuteronElasticCS.txt | 540 | 1.398e-12 |
| DeuteronLocalSmatrix.txt | 244 | 0 |
| DeuteronNonlocalSmatrix.txt | 244 | 5.857e-09 |
| DeuteronRatioToRuth.txt | 540 | 1.398e-12 |
| NucleonBoundWF.txt | 6000 | 3.673e-10 |
| NucleonElasticCS.txt | 540 | 4.631e-12 |
| NucleonLocalSmatrix.txt | 164 | 3.316e-11 |
| NucleonNonlocalSmatrix.txt | 164 | 8.438e-07 |
| NucleonRatioToRuth.txt | 540 | 4.631e-12 |
| **TransferCS.txt** | **358 of 360** | **1.275e-12** |

**11 files compared, worst relative difference 8.438e-07, zero values above
1e-6.** Agreement is looser than the local case (1e-12 there) for the two
nonlocal S-matrices, which is expected: those come out of the iterative solution
of the integro-differential equation, so they carry the iteration's own stopping
tolerance rather than pure round-off. The transfer cross section itself still
agrees to 1.3e-12.

### The one declared deviation, and why it is upstream's

`NONLOCAL_SAMPLE/TransferCS.txt` holds **180** angles; the shipped deck and code
produce **179**. This is not a physics disagreement: the 179 shared angles agree
to 1.275e-12, and the extra reference row is a 180th angle the current code does
not emit.

The file dates settle it:

| file | mtime |
|---|---|
| `NONLOCAL_SAMPLE/dp48Ca_20-0_NL.in` | 2016-05-13 23:31 |
| `NONLOCAL_SAMPLE/TransferCS.txt` | **2016-04-12 09:34** |
| `LOCAL_SAMPLE/dp48Ca_10-0_DWBA.in` | 2016-05-13 23:29 |
| `LOCAL_SAMPLE/TransferCS.txt` | 2016-05-13 02:32 |

The nonlocal reference output predates its own input deck by a month, while the
local reference is same-day as its deck. So the nonlocal references were
generated with an earlier deck or code and were never regenerated when the deck
was updated. The local case, whose reference is current, produces 179 angles and
matches exactly.

`verify_nlat.sh` therefore declares this single deviation explicitly, with both
counts pinned:

```
compare_nlat.py ... --prefix-ok TransferCS.txt:360:358
```

which compares the 358 overlapping numbers and reports the 2 unmatched. The pin
is the point: any other length change, in either file, is still a hard failure.
This is a narrow exception backed by evidence, not a relaxed comparison.

## The paper's own accuracy claims

Worth separating carefully, because the headline number is not what it looks
like.

**The abstract states "cross sections with 4% accuracy" and a validity range
`Ed = 10` to `70` MeV. Neither is derived, defined, or restated anywhere in the
body.** They should not be quoted as verified figures.

What the body actually establishes, in Sec. 6, is three separate component
checks:

| check | agreement | where |
|---|---|---|
| local elastic dsigma/dOmega against FRESCO | better than 3 percent | Sec. 6.1, Fig. 2 |
| bound-state wave functions against FRESCO | better than 2 percent | Sec. 6.2, Fig. 4 |
| nonlocal adiabatic source term against an independent Mathematica evaluation | better than 2 percent | Sec. 6.3, Table 1 |

The local adiabatic potential is also compared against **TWOFNR** (Sec. 6.3,
Fig. 5), and the nonlocal elastic case against **digitized** figures from
Perey-Buck 1962, where the paper itself notes that any discrepancy may come from
the digitizing rather than the code.

Note also that Table 1's `L = 5, R = 0.05` entries disagree in sign and magnitude
between NLAT and Mathematica in both `beta` blocks. Those are the near-origin
values that motivate the `CutL` machinery, and the paper does not comment on
them.

## Citation check

- `10.1016/j.cpc.2016.06.022` resolved live against CrossRef: L.J. Titus,
  A. Ross, F.M. Nunes, *Transfer reaction code with nonlocal interactions*,
  Computer Physics Communications **207**, 499-517, published 2016-10. Received
  17 March 2016, revised 21 June 2016, accepted 27 June 2016.
- Licence GPLv3, from both the paper's program summary and the Mendeley Data
  record. CPC catalogue identifier AFAY_v1_0.
- Preprint: arXiv:1606.07341.

## What was not verified

- Any system other than 48Ca(d,p)49Ca. Both shipped decks are that one reaction.
- `(N,d)` (`WhatCalc` 6), which the paper obtains by detailed balance from
  `(d,N)`. No deck ships for it.
- Bound-state-only and scattering-only modes (`WhatCalc` 1 to 4) as standalone
  runs; they are exercised only as sub-steps of the transfer calculations.
- External read-in nonlocal kernels (`NLpotBound.txt`, `NLpotScat.txt`), which
  is the interesting hook for microscopic or dispersive potentials. No example
  ships and none was constructed.
- The TPM nonlocal potential; both shipped decks use Perey-Buck.
- `make-input`, the interactive deck generator, which this skill deliberately
  sidesteps in favour of editing the shipped decks in place.

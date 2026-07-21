# NLAT input reference

Written from `SOURCE/front_end.f90`, which is the routine that actually reads
the deck, cross-checked against `make_input.f90` (the interactive generator) and
`README.txt`. The CPC paper's Sec. 7 describes the same file; where they differ,
the source wins.

## The single most important fact about this input

**The deck is not a fixed-layout file. It is the transcript of a conditional
interview.** `front_end.f90` branches on values it has already read, and only
then decides what to read next. For example:

```fortran
read(*,*) common(1)                ! WhatCalc
WhatCalc = nint(common(1))
...
if (WhatCalc==3 .or. WhatCalc==4 .or. WhatCalc==5 .or. WhatCalc==6) then
  read(*,*) common(4)              ! beam energy, ONLY for scattering/transfer
  read(*,*) common(5)              ! Lmax
end if
if (WhatCalc==5 .or. WhatCalc==6) then
  read(*,*) common(6)              ! Q-value, ONLY for transfer
end if
```

The same pattern governs the potential blocks: whether a nonlocal parameter
block is read at all depends on the `NonLoc` flag read earlier, and whether a
pre-defined or user-defined parameter set is read depends on `WhatPot`.

Two consequences, and they are the whole reason this page exists:

1. **You cannot lift a line from one deck into another by position.** The line
   that is `Lmax` in a transfer deck may not exist at all in a bound-state deck.
2. **Adding or deleting a line silently reinterprets everything after it.** The
   reads are list-directed (`read(*,*)`), so there is no format to violate and
   no error to raise; the run completes and computes something else. This is the
   same failure class as a fixed-format column shift, but harder to spot.

The safe workflow is upstream's own: run `make-input`, answer the questions, and
let it emit a consistent deck. Edit an existing deck **in place, value by
value**, never by inserting or removing lines. The two decks in `examples/` are
known-good starting points.

## Recovering from a mistake in `make-input`

`make-input` reads any existing `inputfile.in` first and resumes prompting from
where that file runs out. So the documented recovery is:

```
cp inputfile.in temp.in
# delete the bad line and everything after it from temp.in
./make-input          # re-reads temp.in, then prompts for the rest
```

## Top-level controls

Read unconditionally, in this order:

| order | name | meaning |
|---|---|---|
| 1 | `WhatCalc` | 1 n+p bound state, 2 N+A bound state, 3 d+A scattering, 4 N+A scattering, **5 (d,N) transfer**, **6 (N,d) transfer** |
| 2 | `StepSize` | radial step in fm. The paper strongly recommends **0.01 fm** |
| 3 | `Rmax` | maximum radius in fm. **30 fm or larger** for transfer |

Then, only for `WhatCalc` 3, 4, 5, 6:

| order | name | meaning |
|---|---|---|
| 4 | `ElabEntrance` | total beam energy of the initial state in the lab frame, MeV |
| 5 | `Lmax` | maximum orbital angular momentum in the scattering state |

Then, only for `WhatCalc` 5 or 6:

| order | name | meaning |
|---|---|---|
| 6 | `Qvalue` | reaction Q-value, MeV |

`(p,d)` and `(n,d)` are obtained from the corresponding `(d,N)` calculation by
detailed balance rather than by a separate reaction calculation, which is why
`WhatCalc` 5 and 6 share the same input structure.

## Parameter blocks

Two families, each a two-index array whose first index selects a category:

**`BoundParameters`** (`DeuteronBoundParameters`, `NucleonBoundParameters`)
- `(1,:)` the system: masses and charges of fragment and core, spins, parities, `L`, `jp`, and the **number of nodes** of the bound state (`front_end.f90` comment: "NUMBER OF NODES OF THE BOUND STATE"; `bound_state.f90` counts sign changes starting from 1, so it is one-based, not a principal quantum number)
- `(2,:)` local potential selector
- `(3,:)` nonlocal selector (`NonLoc` 0 or 1; then which potential)
- `(4,:)` local Woods-Saxon parameters, 10 values: `Vv rv av Vd rvd avd Vso rso aso rc`. For a nonlocal run this block doubles as the initial guess that seeds the iteration
- `(5,:)` the local part of the nonlocal potential, same 10 values
- `(6,:)` the nonlocal part, 10 values ending in `beta` (the nonlocality range) instead of `rc`

**`ScatParameters`** (`DeuteronScatParameters`, `NucleonScatParameters`)
- `(1,:)` the system
- `(2,:)` local selector. For the deuteron, `PotType` chooses **1 deuteron optical potential** or **2 adiabatic potential**; `WhatPot` chooses user-defined or pre-defined; `WhatPreDefPot` selects **Daehnick** for the deuteron, **Koning-Delaroche** or **Chapel Hill CH89** for a nucleon
- `(3,:)` nonlocal selector: `WhatPot` 1 user-defined, 2 pre-defined, **3 read in**; `WhatPreDefPot` 1 **Perey-Buck**, 2 **TPM** (Tian-Pang-Ma)
- `(4,:)` local complex optical potential, **19 values**: `Vv rv av Wv rwv awv Vd rvd avd Wd rwd awd Vso rso aso Wso rwso awso rc`
- `(5,:)` the local part of the nonlocal potential, same 19 values, and it also serves as the `U_init` that seeds the iterative solution
- `(6,:)` the nonlocal part, same layout but ending in `beta`
- `(7,:)` and `(8,:)` local neutron and proton potentials used to build the adiabatic potential, **evaluated at half the deuteron energy**
- `(9,:)`, `(10,:)` their local-part-of-nonlocal counterparts
- `(11,:)`, `(12,:)` their nonlocal parts

For the **pre-defined** Perey-Buck and TPM potentials, nonlocality is applied to
the volume and surface terms only, with spin-orbit and Coulomb local, which is
how those two potentials are defined. This is **not** a property of the code:
on the user-defined route `nonlocal_scattering_potential.f90` builds
`Unl2 = Vnucl + Vsurf + Vspin + i*(Wnucl + Wsurf + Wspin)`, i.e. it does accept
and use a nonlocal spin-orbit term, and `front_end.f90` reads those fields.

**Upstream parser bug on this route.** `front_end.f90` reads the local-part
real-volume triple of the neutron adiabatic block as

```fortran
read(*,*) DeuteronScatParameters(9,1), DeuteronScatParameters(9,2), DeuteronScatParameters(8,3)
```

The third field should be `(9,3)`. As written it overwrites `(8,3)` and leaves
`(9,3)` at zero, and `nonlocal_scattering_potential.f90` then reads
`av = ScatParameters(9,3)`, so a user-defined nonlocal ADWA deck silently gets a
zero real-volume diffuseness for the neutron. This affects only the
user-defined (`WhatPot = 1`) route; the shipped decks use pre-defined
potentials and are unaffected.

## Output directory and print flags

The last block of the deck is a bare directory name followed by 19 flags, `0` or
`1`, in this fixed order (from the `printing(1..19)` reads at the end of
`front_end.f90`), with one upstream inconsistency flagged below:

```
 1 DeuteronBoundWF       2 NucleonBoundWF
 3 DeuteronScatWFs       4 NucleonScatWFs
 5 LocalBoundWF          6 NonlocalBoundWF
 7 DeuteronLocalIntegral 8 NucleonLocalIntegral
 9 DeuteronNonlocalIntegral  10 NucleonNonlocalIntegral
11 DeuteronLocalSmatrix  12 NucleonLocalSmatrix
13 DeuteronNonlocalSmatrix   14 NucleonNonlocalSmatrix
15 DeuteronRatioToRuth
16 DeuteronElasticCS     17 NucleonRatioToRuth
18 NucleonElasticCS      19 TransferCS
```

**Flags 16 and 17 are swapped between the parser and the consumer.** The
comments in `front_end.f90` label `printing(16)` as `NucleonRatioToRuth` and
`printing(17)` as `DeuteronElasticCS`, but `diffCS.f90` reads them the other way
round:

```fortran
print_DeuteronElasticCS = printing(16)
print_NucleonRatioToRuth = printing(17)
```

The list above gives the **runtime** behaviour, which is what actually decides
which file gets written. Both shipped decks set every flag to 1, so the
distributed reference output is unaffected.

**The directory name is passed to a shell.** `main.f90` builds the string
`'mkdir ' // trim(Directory)` and calls `system()` on it, with no quoting. Keep
the name plain: no spaces, no shell metacharacters. Both `Directory` and the
`command` string it is spliced into are declared `character(LEN=50)`, and the
`'mkdir '` prefix eats six characters, so the **effective limit is 44
characters**; anything longer is silently truncated.

Turning everything on is expensive. The paper warns that a full output set can
reach **100 GB**; the wave-function and integral dumps are the culprits, at
roughly 10 to 14 MB each even for the shipped 48Ca cases.

## Accuracy block, with the two settings that bite

`accuracy(:)` carries the numerical controls. Defaults, from the paper's Sec. 7.1:
`MassUnit` 931.494 MeV/c^2, `npoints` 20 (Gauss-Legendre nodes for the
nonlocality integral), `Rmatchd` 2.0 fm, `RmatchN` 2.5 fm, `Estart` -20 MeV,
`EnergyStep` 0.001 MeV, `convergence` 0.001, and a family of mesh and node
counts for the T-matrix integrals.

`convergence` is a **dimensionless relative tolerance**, not a percentage:
`scattering_state.f90` forms `diff = abs((Rold - Rmatrix)/Rmatrix)` and compares
it directly. So the default 0.001 means 0.1 percent. The shipped decks label
that line "Percent diff in energy at convergence", which is upstream's own
mislabel; do not propagate it.

Two settings interact in a way that is easy to get wrong:

- **`beta` must never be 0.** The local limit is reached with **`beta = 0.05` fm**,
  not zero, because the analytic Gaussian kernel divides by `beta`.
- **`CutL` is not an input.** The paper discusses raising it from 2 to 3 when
  `StepSize = 0.01` fm, but the released code has no such keyword: the value is
  hardcoded as `nmin = int(2*L)` in `SOURCE/nm.f90`. See
  `references/failure-modes.md` item 6.

## External nonlocal kernels

Selecting "read in" for the nonlocal potential takes the kernel from a file in
the run directory, with **the same step and maximum radius as the deck**:

- `NLpotBound.txt`, three columns: `r  r'  kernel`
- `NLpotScat.txt`, four columns: `R  R'  Re(kernel)  Im(kernel)`, in one block
  per `LJ` partial wave, ordered as NLAT loops: **L outer, J inner**, so
  (0,1/2), (1,1/2), (1,3/2), (2,3/2) and so on. A kernel must be supplied for
  every `LJ` combination even when the potential depends only on `L`.

In both cases the local part (spin-orbit and Coulomb) is still supplied through
the ordinary parameter block. This is the hook for driving NLAT with a
microscopic or dispersive optical potential.

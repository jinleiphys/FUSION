# pikoe output files

Every output file is opened by the header of the control file, so the names are
whatever that deck chose. What follows is the structure of each kind, taken from
the shipped `readme.txt` plus inspection of real runs of the five sample decks.

## The outlist (unit 6)

Unit 6 is stdout, and every shipped deck redirects it to `<case>.outlist`. This
is the calculation record and the only place the completion banner appears. Its
sections, in order:

1. the deck's comment line and the table of opened files,
2. the echoed input,
3. `-- bound-state calculation outputs --`: binding energy, central potential depth, spin-orbit depth. When `ish=1` the central depth is the result of the search that reproduces `ebind`, so it is a useful regression anchor.
4. `-- initial-channel kinematics outputs --`: energies, kinetic energies and wave numbers for the probe and nucleus A in the L, G and V frames,
5. `-- Lorentz factors --`: beta and gamma for the three frame transformations,
6. `-- integrated value of the calculated TDX --` in microbarn or millibarn, printed next to the NN total cross section at the same energy as a sanity comparison,
7. `>>> calculation completed ( N sec)`.

Only what stdout carries before the redirect (the file table) reaches the
terminal. **Absence of the banner in the outlist is the failure signal**, not
the exit status.

## TDX and QDX tables (`ivar` other than 9)

Single table on unit `kibtbl`, one header line then one row per kinematic point:

```
t1l[MeV] th1l[deg] ph1l[deg] t2l[MeV] th2l[deg] ph2l[deg] pbl[MeV/c] thbl[deg] phbl[deg] pr[MeV/c] isol tdx[ub/(MeVsr2)] Ay
```

The last two columns are the observable and the vector analyzing power. For a
QDX deck (`ivar=3`) the header reads `qdx[ub/(MeV2srrad)]` instead. The cross
section follows `ixunt` (1 microbarn, otherwise millibarn). `kunt` (0 fm^-1,
1 MeV/c, 2 GeV/c) rescales the `pbl` column only; `pr` is always printed in
MeV/c, as its own header says.

`isol` is the kinematic-solution group. In inverse kinematics a given
`(T1, Omega1, Omega2)` can have **two** solutions for `T2`, and the table is
sorted by `th2l` regardless of which branch a row belongs to, so a plot of the
raw table mixes the two branches into a scatter. Split on `isol` before
plotting; this is exactly what Fig. 4 of the CPC paper does.

`pr` is the signed recoil (missing) momentum in MeV/c: the magnitude with the
sign flipped when the residue goes backward. The `fkncut` cutoff on L10 acts on
the missing momentum.

## Momentum distributions (`ivar=9`)

Five files, all optional except the first:

| unit | file in the samples | content |
|---|---|---|
| `kibtbl` | `tbl_*.dat` | momentum distribution in the cylindrical representation with `phiB = 0`, as a 2D grid |
| `kiblg` | `LG_*.dat` | longitudinal momentum distribution |
| `kibpx` | `PX_*.dat` | p_x momentum distribution |
| `kibtr` | `TR_*.dat` | transverse momentum distribution |
| `kibtl` | `TL_*.dat` | total momentum distribution |

The `tbl_` file is written incrementally, one row per `K_Bz` value, with the
`K_Bb` grid as its header row. The four projection files are **created empty
when the deck header is read** and filled only at the end of the run, so a
partial run shows all four at zero bytes. Their presence is not a completion
check; only non-zero size is.

`kibpx` requires `ivthx=1` with more than three theta points; `kibtl` requires
that plus `ivvar=1` with more than three points. The distributions are always
computed in the A-frame.

## Transition matrix density (`kibtmd`)

Written only when `kibtmd > 0`, and only when at most one kinematic degree of
freedom is varied. Not available with `ielm=4` or `6`.

## Bound-state wave function (`kibbs`)

Written when `kibbs > 0`: radius, radial wave function, the nonlocality
(Perey) correction function, and the corrected normalized wave function. Useful
for checking that the s.p. state is the one intended before paying for a full
run.

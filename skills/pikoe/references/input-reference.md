# pikoe control-file reference

Written from `input_man.txt` as shipped with pikoe 1.1 (dated 2025-03-18), which
is the code's own manual, not from the CPC paper and not from memory. The paper
(Sec. 3.2) reproduces the same manual; where the two differ, the shipped file
wins. Line numbers below refer to the manual's own L1..L21 labels.

pikoe reads its control file from **stdin**:

```
./pikoe < input.cnt
```

Everything is fixed-format. A misplaced column is the most common way to get a
run that completes and is wrong, so start from a shipped deck in `examples/`
and edit values in place rather than retyping a deck.

## Header part

Line 1 is a comment. It is not used for anything, but it is echoed to stdout at
startup, so it is the one piece of a deck visible on the terminal. From line 2,
each line opens one external file with fixed format `A1,I3,1X,A8,2X,A50`:

```
   10:unknown ::./tbl_12Cp2pTDXnorm.dat
   11:old     ::../elem/nnampFL.dat
   12:old     ::../pot/EDAD1p12C_e.dat
   13:old     ::../pot/EDAD1p11B_e.dat
   06:unknown ::./12Cp2pTDXnorm.outlist
  999:
```

which becomes `open(11, file='../elem/nnampFL.dat', status='old')` and so on.
The list ends at the first unit number `< 0` or `>= 100` (the decks use `999`),
so valid unit numbers are `0 <= i <= 99`. The manual says `10 <= i <= 99`, but
the code accepts anything below 100 and the shipped decks themselves use `06`
for the outlist. One comment line follows the header.

**Unit 6 is stdout.** Every deck in `examples/` redirects it to a `.outlist`
file, so the calculation record, including the completion banner, lands there
and not on the terminal. A harness that watches stdout only will see almost
nothing.

The relative paths `../elem/` and `../pot/` are why `run_pikoe.sh` reproduces
the upstream directory layout instead of copying decks into a flat workdir.

## Main part

### L1 comment `[a50]`
Free text, echoed into the outlist.

### L2 `limfs ions ifrm imir ical [5i5]`
- `limfs` size cap for the unit-`kibtbl` table in MB (0 means roughly 1 TB); one line is about 128 bytes.
- `ions` 0 suppresses kinematically forbidden configurations, nonzero prints them.
- `ifrm` output frame: 0 laboratory (L), 1 c.m. (G), 2 projectile-rest (V).
- `imir` nonzero applies a `+z -> -z` conversion in the kinematics output.
- `ical` 0 is kinematics-survey mode (no observables), nonzero computes observables.

`ical=0` is the cheap way to check a kinematics setup before paying for a full run.

### L3 `zp ap za aa [f5.0,f10.0,f5.0,f10.0]`
Charge and mass (in u) of the probe (particle 0) and of nucleus A.

### L4 `ikin elab ictrein [i5,f10.0,i5]`
- `ikin` 0 normal kinematics (probe is the projectile), nonzero inverse kinematics (A is the projectile).
- `elab` kinetic energy **per nucleon** of the projectile, MeV.
- `ictrein` 0 uses `Ein = elab*nint(ap)` or `elab*nint(aa)`; nonzero uses the non-rounded mass.

### L5 `ish ebind zsp asp betasp ictrm [i5,f10.0,f5.0,2f10.0,i5]`
- `ish` 0 take `ebind` as the s.p. potential depth; 1 adjust the depth to reproduce binding energy `ebind`; `>9` read the s.p. wave function from that unit.
- `ebind` binding energy of the struck nucleon, MeV, positive.
- `zsp asp` charge and mass of the struck particle N.
- `betasp` range of nonlocality in fm for N in A, the **Perey-Buck correction**. Negative means read the correction function from unit `ish`, and the run aborts if `ish < 10`.
- `ictrm` mass in the bound-state Schrodinger equation: 1 mass of N, 2 reduced mass.

### L6 `fj fl sfac nod kibbs [2f5.0,f10.0,2i5]`
Total and orbital angular momentum of the s.p. state, spectroscopic factor
(maximum `2*fj+1` for nucleon knockout), node count (0 is the lowest state), and
the unit for the bound-state wave-function dump (written when `kibbs > 0`:
radius, wave function, nonlocality correction, corrected normalized wave function).

### L7 `ibmc rc ictrc a0c rcl ictrcl [i5,f10.0,i5,2f10.0,i5]`
Central part of the s.p. potential. `ibmc=1` uses Bohr-Mottelson, anything else
reads parameters. `ictrc` selects the mass factor multiplying the reduced radius
`rc`: 0 `aa^(1/3)`, 1 `(aa-asp)^(1/3)`, 2 `(aa-asp)^(1/3)+asp^(1/3)`, 3 unity.
`rcl`/`ictrcl` do the same for the Coulomb radius. If `ish>9` and `betasp>0`,
`ibmc` must be 1.

### L8 `ibms v0ls rs ictrs as [i5,2f10.0,i5,f10.0]`
Spin-orbit part, same pattern: `ibms=1` Bohr-Mottelson, else depth (MeV,
positive), reduced radius, its control flag, diffuseness.

### L9 `lmax0 lmax1 lmax2 [3i5]`
Maximum orbital angular momentum for particles 0, 1, 2. A negative value means
automatic: `lmax = min(nint(K_i*R_max), |lmax|)`.

### L10 `ivar iex fkncut ixunt kunt [2i5,f5.0,2i5]`
Energies in MeV, angles in degrees, wave numbers in fm^-1, all in the L-frame.

`ivar` selects what is scanned and therefore which observable is produced:
- 1: `T1, theta1, phi1, theta2, phi2` in L11..L15, **TDX** in `T1, Omega1, Omega2`.
- 2: `K_B, thetaB, phiB, theta2, phi2`, TDX in `K_B, OmegaB, Omega2`.
- 3: `T1, theta1, phi1, T2, phi2`, **QDX** in `T1, Omega1, T2, phi2`.
- 9: `K_Bz` in L11 and `K_Bb` in L12 (A-frame), L13-L15 unused, **momentum distributions** of B in the A-frame.
- `>9`: read a kinematics profile from that unit, 9 values per line `(t1,th1,ph1,t2,th2,ph2,kb,thb,phb)`. The manual says `9f10.0`; the code reads `9f11.0` (format label 501). Use 11-column fields. The sub-ranges select which five are used and which observable results: 9-19 TDX from `t1,th1,ph1,th2,ph2`; 20-29 TDX from `kb,thb,phb,th2,ph2`; 30-39 QDX from `t1,th1,ph1,t2,ph2`; 40+ all nine used with an energy-momentum conservation check.

Other fields: `iex=1` makes particle 1 the struck particle N rather than the
probe (not allowed with `ielm=4` or `ielm=6`); `fkncut` missing-momentum cutoff
in fm^-1; `ixunt` 1 microbarn else millibarn; `kunt` unit of `K_B` in output,
0 fm^-1, 1 MeV/c, 2 GeV/c.

### L11-L15 `ivx xmin xmax dx [i5,3f10.0]`
Scan control for, in order, the L11 variable, `theta_x`, `phi_x`, `T2`, `phi2`.
`ivx=0` fixes the quantity at `xmin`; nonzero sweeps `xmin` to `xmax` in steps
of `dx`.

### L16 `kibtbl kibout kibtmd kiblg kibpx kibtr kibtl [7i5]`
Output unit numbers. `kibtbl` (the TDX/QDX table, or the cylindrical momentum
distribution when `ivar=9`) and `kibout` (the outlist) must both be positive.
`kibtmd` dumps the transition matrix density and is allowed only when at most
one kinematic degree of freedom varies, and never with `ielm=4` or `6`.
`kiblg`, `kibpx`, `kibtr`, `kibtl` are the longitudinal, p_x, transverse and
total momentum distributions and are **effective only when `ivar=9`**. `kibpx`
additionally requires `ivthx=1` with more than three theta points; `kibtl`
requires that plus `ivvar=1` with more than three points. All unit numbers must
differ.

### L17 `ielm kibelm ionsh kinelm ielmedg [5i5]`
The elementary NN process:
- `ielm` 0 isotropic free NN cross section at `elab` in mb; 3 free differential NN cross section in mb/sr from unit `kibelm`; 4 free on-shell NN t-matrix from unit `kibelm`, coplanar kinematics only.
- `ionsh` on-shell prescription when `ielm` is 3 or 4: 1 final-state, 2 initial-state, 3 energy-average, 4 momentum-average.
- `kinelm=1` prints the elementary-process kinematics; forced to 0 when `ivar=9`.
- `ielmedg` 0 aborts when the scattering energy falls outside the tabulated range, nonzero clamps to the nearest edge.

The manual documents `ielm` values 0, 3 and 4 only, yet `ielm=6` appears as an
exclusion in the L10 and L16 entries. The code rejects anything outside 0, 3, 4
with `ERROR: ielm must be 0, 3, or 4`, so `ielm=6` is unreachable.

### L18 `rmax dr ngr ngth ngph ngk1 ngph1q [2f10.0,5i5]`
Maximum radius and radial step in fm, then Gauss-Legendre node counts for R,
theta_R, phi_R, K1 and phi_1Q. The last two matter only when `ivar=9`, which is
why the momentum-distribution decks are much more expensive than the TDX decks.

### L19-L21 `ipot facv facw facvs facws beta ims iedg [i5,4f5.0,f10.0,2i5]`
One line each for particle 0, 1, 2:
- `ipot` 0 plane wave; 1 built-in global potential (Koning-Delaroche for a nucleon, Avrigeanu for an alpha, Coulomb included); `>9` read the optical potential from that unit, which must cover the needed energy range.
- `facv facw facvs facws` multiply the real central, imaginary central, real spin-orbit and imaginary spin-orbit terms. **A negative `facv` turns the Coulomb potential off** and uses `|facv|`.
- `beta` range of nonlocality in fm for that particle; negative means read the correction function from unit `ipot`, and the run aborts if `ipot < 10`.
- `ims` 0 reduced energy as the kinematical factor, nonzero reduced mass.
- `iedg` 0 abort outside the tabulated energy range, nonzero clamp to the edge.

## External file formats

### Bound-state wave function (unit `ish`, when `ish > 9`)
Line 1 `rspmax drsp` free format; `rspmax` must not be smaller than `rmax`, and
`drsp` may differ from `dr`. Then `rspmax/drsp + 1` lines of
`rsp wfsp fnlspw` with `[f10.0,2e20.12]`: radius in fm, radial wave function in
fm^-3/2 **not multiplied by R**, and the nonlocality correction function (used
only when `betasp < 0`).

### Optical potential (unit `ipoti`, when `ipoti > 9`)
Line 1 `nepmaxw rpmaxw drpw r0clw ictrclw [i5,3f10.0,i5]`: number of energy
points, maximum radius (not smaller than `rmax`), radial step, reduced Coulomb
radius and its control flag (1 `ax^(1/3)`, 2 `asc^(1/3)+ax^(1/3)`, 3 unity,
where `ax` is `aa` for particle 0 and `ab` otherwise). If `r0clw` is 0 and no
Coulomb potential is supplied, the Koning-Delaroche Coulomb radius is used.

Then, repeated `nepmaxw` times in **ascending energy order**: a line with the
scattering energy in MeV in the nucleus rest frame, followed by
`rpmaxw/drpw + 1` lines of `[7e20.12]` giving real central, imaginary central,
real spin-orbit, imaginary spin-orbit, Coulomb (all MeV), then the real and
imaginary nonlocality correction functions (used only when `beta < 0`).

### NN differential cross sections (unit `kibelm`, when `ielm=3`)
Line 1 `nennmax thnnmax dthnn`. Then per energy: a line with the NN scattering
energy in MeV in the NN laboratory frame, followed by `thnnmax/dthnn + 1` lines
of `dsigpp dsigpn` in mb/sr. Energies ascending.

### NN transition amplitudes (unit `kibelm`, when `ielm=4`)
Coplanar kinematics only. Line 1 `q0mn q0mx dq0` (relative wave number, fm^-1),
line 2 `th0mn th0mx thmn thmx dth` (degrees). Amplitudes then follow as
`ampr ampi` in MeV fm^3, in a strictly nested order: q0, then initial polar
angle, then initial azimuth (over 0, 180, 360 degrees), then final polar angle,
then final azimuth (0, 180, 360), then the four spin projections in the order
particle 0, particle N, particle 1, particle 2, each up then down. That is
`nq0mx * ntht0 * 3 * ntht * 3 * 16` records, and nothing in the file marks the
boundaries, so an off-by-one in any loop silently shifts every amplitude.

## Shipped data tables

- `elem/nnampFL.dat` NN transition amplitudes, Franey-Love (`ielm=4`), 50 MB.
- `elem/FLtbl_rede.dat` NN elastic differential cross sections, Franey-Love (`ielm=3`).
- `elem/N4He_Mel_10-800MeV.dat` nucleon-alpha table, for `(p,palpha)`-type use.
- `pot/EDAD1p12C_e.dat`, `pot/EDAD1p12C@100_e.dat`, `pot/EDAD1p11B_e.dat` Dirac-phenomenology (EDAD1) potentials for p+12C at 392 and 100 MeV and p+11B over several energies.

For unstable nuclei the authors recommend supplying microscopic optical
potentials as external files rather than relying on the built-in
Koning-Delaroche parametrization, and state that one of them (K. Ogata) will
provide such files on request.

# vHLLE input format

vHLLE is driven by a single **parameter file** plus command-line options. There
is no monolithic input deck; the physics inputs are (1) the parameter file, (2)
the compile-time equation of state, and (3) for tabulated initial states, an
external initial-state file.

## Command line

```
hlle_visc -params <param-file> [-system <SYS>] [-ISinput <IS-file>] -outputDir <dir>
```

- `-params` (required): the parameter file below.
- `-outputDir` (required in practice): where output is written; created if absent.
- `-ISinput`: an initial-state table, required for every icModel EXCEPT optical
  Glauber (1) and Gubser (4), which are self-contained.
- `-system`: a collision-energy label (`RHIC200`, `LHC276`, ...), mandatory for
  the Glissando and Trento initial states only.

vHLLE reads `eos/` and `ic/` **relative to the current directory**, so it must be
run from the repository root (where `install_vhlle.sh` links those directories).
`run_vhlle.sh` handles this.

## Parameter file

Whitespace-delimited `key  value  ! comment`. Unlisted keys keep their defaults.
The keys used by the shipped decks:

| key | meaning |
|---|---|
| `outputDir` | default output directory (overridden by `-outputDir`) |
| `eosType` | 0 Laine/conformal, 1 Chiral, 2 AZH bag, 3 CMF, 4 CMFe. **Under a SIMPLE build, eosType 0 is the conformal p=e/3 EoS; under TABLE it is the Laine nf3 lattice EoS.** |
| `etaS` | shear viscosity eta/s |
| `zetaS` | bulk viscosity zeta/s |
| `e_crit` | particlization energy density (GeV/fm^3). Also gates when the freeze-out surface finder stops the run (see failure-modes) |
| `nx ny nz` | grid cell counts in x, y and spatial rapidity eta |
| `xmin xmax ymin ymax etamin etamax` | grid extents (fm, fm, dimensionless) |
| `icModel` | initial state: **1 optical Glauber, 2 Glauber table + parametrized rapidity, 3 UrQMD, 4 analytic Gubser, 5 Glissando, 6/10 SMASH, 7/8 Trento, 9 SuperMC, 11 test** |
| `glauberVar` | Glauber scaling: 0 by epsilon, 1 by entropy |
| `epsilon0` | initial energy-density normalization (unused by the Gubser IC) |
| `impactPar` | impact parameter (fm) |
| `tau0` | hydro start proper time (fm/c). **For Gubser it MUST be 1.0** (the analytic IC is written at reference time _t = 1) |
| `tauMax` | proper time to stop |
| `dtau` | timestep (fm/c) |

## The equation of state is a COMPILE-TIME choice

`src/eos.cpp` selects the EoS backend at compile time:

```cpp
#define TABLE   // Laine, etc      <- default in the main branch
//#define SIMPLE  // p=e/3
```

- **TABLE** (default): `eosType 0` loads the Laine nf3 lattice EoS from
  `eos/Laine_nf3.dat`. This is the production build for realistic collisions.
- **SIMPLE**: `eosType 0` becomes the analytic conformal EoS, `p = e/3` and
  `T = (e/const)^{1/4}`, with no data file. This is required to reproduce the
  analytic Gubser test, which assumes conformal symmetry.

`install_vhlle.sh --` selects this with `VHLLE_EOS=table|simple`; it toggles only
those two `#define` lines and restores the file afterwards, so the working tree
stays pristine. This is the code's own documented switch (see `README.txt`, the
`-D TABLE` recompile note), not a modification of functional code.

## The two shipped decks

- `examples/gubser.params` (SIMPLE): icModel 4, ideal (etaS 0), self-contained.
- `examples/glauber.params` (TABLE): icModel 1, viscous (etaS 0.08), Laine EoS,
  self-contained. A realistic production-path run.

Both need no `-ISinput` file. The companion repo `vhlle_params` supplies the EoS
tables and the tabulated initial states used by the other icModels.

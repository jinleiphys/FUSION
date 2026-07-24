# vHLLE output format

Each run writes into its `-outputDir`. The profile files record the fluid state
along cuts through the grid, one block per timestep.

## Profile tables (outx / outy / outz.dat)

Rectangular, 20 whitespace-delimited columns, `nx` (or `ny`, `nz`) rows per
timestep, blank-line separated between timesteps:

```
t  x  vx  vy  eps  nb  T  mub  pi^tautau pi^taux pi^tauy pi^taueta pi^xx pi^xy pi^xeta pi^yy pi^yeta pi^etaeta  Pi  cut_flag
```

| col | symbol | meaning |
|---|---|---|
| 1 | t | proper time tau (fm/c) |
| 2 | x / y / z | coordinate (fm) or rapidity for outz |
| 3 | vx | x 3-velocity (for outz: vz, longitudinal flow rapidity) |
| 4 | vy | y 3-velocity |
| 5 | eps | energy density in the fluid rest frame (GeV/fm^3) |
| 6 | nb | baryon density (1/fm^3) |
| 7 | T | temperature (GeV) |
| 8 | mub | baryon chemical potential (GeV) |
| 9-18 | pi^{mu nu} | 10 shear-stress components (GeV/fm^3) |
| 19 | Pi | bulk pressure (GeV/fm^3) |
| 20 | cut_flag | viscous-correction cut factor (1.0 = uncut) |

- `outx.dat`: cells `(ix, ny/2, nz/2)`, ix = 0..nx-1 (cut along x through center).
- `outy.dat`: cells `(nx/2, iy, nz/2)`.
- `outz.dat`: cells `(nx/2, ny/2, iz)`.

`check_output.py` validates these (finite, rectangular, min rows/cols).

## outdiag.dat is NOT rectangular

The diagonal cut `(ix, ix, iz)` wraps each 20-field record across TWO physical
lines (8 fields then 12). A parser that assumes one record per line, or a fixed
column count per line, breaks on it. `run_vhlle.sh` and the checks deliberately
skip `outdiag.dat` for that reason; use `outx/outy/outz.dat` for cuts.

## Other files

- `out.aniz.dat`: grid-integrated `t  <vt>  <epsilon_p>  <epsilon_p'>` (spatial
  and momentum anisotropy of the whole fluid).
- `out2D.dat`: 2D transverse slice at midrapidity.
- `outx.visc.dat`, `outy.visc.dat`, `diag.visc.dat`: viscous diagnostics (often
  empty for ideal runs).
- `freezeout.dat`: the particlization hypersurface elements (Cornelius). Empty if
  the run never crossed `e_crit`.

## Console output

The Gubser IC prints two deterministic setup scalars before evolution:

```
average initial flow = 0.601067
total energy = 328.325
```

These are functions of the grid alone and are identical on every platform for a
fixed deck. Each timestep prints a summary line (`tau E Efull Nb Sfull ...`); for
the energy-conservation test (paper Table 1) E and S are watched for constancy.

## Reproducibility

For the shipped Gubser deck (SIMPLE, no GSL in the EoS path), every physically
meaningful column (tau, x, vx, eps, T) is **bit-identical** between macOS/ARM
(clang 21) and Linux/x86-64 (gcc 13.3). Only the numerically-zero `vy` column
(~1e-18) differs at the ~4e-16 level (last-bit roundoff of a zero), which shifts
the printed field widths but not the physics. See `verification.md`.

---
name: coloss
description: >-
  Drive COLOSS, the complex-scaled optical and Coulomb scattering solver (Liu Junzhe, Lei, Ren; CPC 311, 109568, 2025). Write, run, and verify COLOSS input for two-body elastic scattering with local or Perey-Buck nonlocal optical potentials, computing S-matrices and cross sections by complex scaling. Use for 跑coloss, COLOSS input, complex scaling scattering, 复标度散射, bound-state technique scattering, S-matrix from Lagrange-Laguerre basis.
---

# Driving COLOSS

COLOSS (Complex-scaled Optical and couLOmb Scattering Solver) solves the two-body scattering problem with a bound-state technique: complex scaling rotates the radial coordinate by an angle theta so the oscillatory scattering boundary conditions become exponentially decaying, and the problem is solved in a square-integrable Lagrange-Laguerre basis. It handles general local optical potentials and the Perey-Buck nonlocal potential, and returns S-matrices and cross sections. Reference: Liu Junzhe, Lei, Ren, Comput. Phys. Commun. 311, 109568 (2025); source github.com/jinleiphys/COLOSS.

## Prime rules (do not skip)

1. **Never report a COLOSS number you have not verified.** Two checks live in `references/verification.md`: a cross-code benchmark against FRESCO (n+40Ca, agrees to 4 significant figures) and complex-scaling angle invariance (the answer must not depend on theta). State the agreement explicitly.
2. **Start from a verified example.** `examples/` holds real input decks (n40Ca.in, alpha40Ca.in, 6Li208Pb.in) that run and converge. Copy the closest one and edit it; do not hand-write a namelist from memory.
3. **Radius convention is target-only.** COLOSS builds Woods-Saxon radii as R = r * A_t^(1/3) (target mass only), NOT the (A_p^(1/3) + A_t^(1/3)) sum used by many codes. This matters whenever you compare COLOSS to another code or to a published potential: getting it wrong shifts the reaction cross section by tens of percent. See `references/verification.md`.
4. **No em-dashes in any prose or comments you write** (user's flat rule).

## Environment (auto-install)

- **Binary is auto-provisioned.** `scripts/install_coloss.sh` checks `~/bin/COLOSS` (override `COLOSS_BIN_DIR`) and `PATH`; if absent it clones github.com/jinleiphys/COLOSS, builds the bundled C++ Coulomb-wave library (`adyo_v1_0/`, `make`), then the Fortran solver (top-level `make FC=gfortran`), and copies the binary in. `scripts/run_coloss.sh` calls it on first use. Requires `gfortran`, `g++`, `git`, `make`, and LAPACK/BLAS (macOS: `brew install gcc lapack`).
- The repo ships an interactive `compile.sh`; the installer bypasses it and calls `make` directly (non-interactive). The architecture warning it prints on Apple Silicon (aarch64 vs arm64) is a false alarm; the build links fine.
- Run pattern: `COLOSS < input.in > output`. COLOSS writes several numbered files (fort.1, 2, 10, 60, 61, 67) into cwd; run in a scratch dir.
- `timeout`/`gtimeout` are absent on this macOS. Runs are fast (a typical case is under 0.1 s), so a cap is rarely needed.

## Input structure (namelists)

A COLOSS deck is a small set of Fortran namelists:

| namelist | controls | key variables |
|---|---|---|
| `&general` | numerics and complex scaling | `nr` (Laguerre basis size), `Rmax`, `ctheta` (scaling angle, degrees), `method` (1 = Lagrange approximation, 3 = Gauss-Legendre quadrature), `matgauss`/`bgauss` (integration flags), `backrot` (back-rotation), `thetah`/`thetamax` (output angle grid) |
| `&system` | the reaction | `zp`,`massp`,`namep` (projectile), `zt`,`masst`,`namet` (target), `jmin`,`jmax` (partial-wave range), `elab` (lab energy, MeV), `sp` (projectile spin) |
| `&pot` | optical potential | volume real `vv`,`rv`,`av`; volume imaginary `wv`,`rw`,`aw`; surface real `vs`,`rvs`,`avs`; surface imaginary `ws`,`rws`,`aws`; spin-orbit `vsov`,`rsov`,`asov` (real) and `vsow`,`rsow`,`asow` (imag); Coulomb `rc`. Optional `a1`,`a2` mass overrides (default to massp,masst) |
| `&nonlocalpot` | Perey-Buck nonlocality | `nonlocal` (t/f), `nlbeta` (nonlocality range) |

Woods-Saxon depths are in MeV, radii `r` are reduced radii (multiply by A_t^(1/3) for the physical radius, see rule 3), diffusenesses in fm. The surface term is a derivative Woods-Saxon.

## Workflow

1. Pick the closest `examples/` deck (nucleon: `n40Ca.in`; light charged: `alpha40Ca.in`; weakly-bound heavy-target: `6Li208Pb.in`).
2. Edit `&system` for your projectile/target/energy and `&pot` for your potential. Keep the radius convention in mind (rule 3).
3. Run with `scripts/run_coloss.sh <input.in> <scratchdir>`, which auto-installs the binary and prints the summed total reaction cross section.
4. **Converge and verify:** raise `nr` and `Rmax` until sigma_R is stable; confirm the partial-wave series is converged in `jmax` (last rows a small fraction of a mb); confirm sigma_R is invariant under `ctheta` over a stable window (rule 1). For a physics check, reproduce the FRESCO benchmark in `references/verification.md`.

## Output

- stdout: the per-partial-wave table (L, S, J, Re(S), Im(S), partial-wave reaction cross section in mb). Sum the last column for the total (helper in `references/verification.md` and baked into `run_coloss.sh`).
- fort.60: S-matrix LSJ distribution. fort.61: scattering amplitude LSJ. fort.67: cross-section angular distribution (ratio to Rutherford for charged systems).

## Gotchas

- **Radius convention** (rule 3), the single most common cross-code mismatch.
- **Spin-orbit convention:** COLOSS spin-orbit strength is a plain depth; when comparing to another code, its spin-orbit factor may differ, so cross-check central potentials with spin-orbit off first (that is how the FRESCO benchmark was done).
- **theta window:** too small `ctheta` leaves oscillatory tails; too large pushes the rotated potential into an unphysical region. If sigma_R drifts with theta, widen `nr`/`Rmax` before touching theta.
- **method=3** (Gauss-Legendre) needs its own mesh flags (`matgauss`,`numgauss`,`rmaxgauss`); if the output table is empty, the mesh settings are inconsistent with `method`. Default to `method=1` (Lagrange) unless you specifically need direct quadrature.

# Sky3D input format

Sky3D reads a single file of Fortran namelists. Everything below is taken from
the namelist declarations in the source (`Code/*.f90`) and from the decks the
distribution ships in `Test/`, not from memory or from the README.

**The file must be named `for005` and sit in the working directory.** Sky3D does
`OPEN(unit=05,file='for005',status='old',form='formatted')` in `main3d.f90`, so
it does NOT read standard input. `sky3d.seq < mydeck` fails with
`Fortran runtime error: Cannot open file 'for005'`. See `failure-modes.md`.

The namelists are read in a fixed order, and each is read by the module that owns
it, so a namelist placed out of order or omitted where it is required will fail
inside that module rather than at parse time.

## Order and ownership

| order | namelist | read in | required |
|---|---|---|---|
| 1 | `&files` | `main3d.f90` | yes |
| 2 | `&force` | `forces.f90` | yes |
| 3 | `&main` | `main3d.f90` | yes |
| 4 | `&grid` | `grids.f90` | yes |
| 5 | `&static` | `static.f90` | when `imode=1` |
| 5 | `&dynamic` | `dynamic.f90` | when `imode=2` |
| 6 | `&fragments` | `fragments.f90` | when `nof` /= 0 |
| 7 | `&extern` | `external.f90` | when `texternal=T` |
| 7 | `&user` | `user.f90` | only with a user-supplied routine |

## `&files`

Declared as `wffile, converfile, monopolesfile, dipolesfile, momentafile,
energiesfile, quadrupolesfile, spinfile, extfieldfile`.

`wffile` is the one that matters in practice: it names the wavefunction file the
run WRITES (static mode) or the restart file. In the shipped static deck it is
`'O16'`, and that file is what the collision deck later reads as a fragment. The
others rename the `.res` tables and default to sensible names.

## `&force`

Declared as `name, pairing, ex, zpe, h2m, t0, t1, t2, t3, t4, x0, x1, x2, x3,
b4p, power, ipair, v0prot, v0neut, rho0pr, mixture, turnoff_zpe`.

Normally only two are set: `name` selects a parametrization from the shipped
`Code/forces.data` (the benchmark uses `'SV-bas'`), and `pairing` is `'NONE'`,
`'VDI'` or `'DDDI'`. The remaining fields exist so a force can be overridden or
defined inline; `h2m`, `v0prot` and `v0neut` are initialized to negative
sentinels and are treated as "undefined" unless you set them.

## `&main`

Declared as `tcoul, mprint, mplot, trestart, writeselect, write_isospin, mrest,
imode, tfft, nof, r0`.

- `imode` **1 = static, 2 = dynamic**. `main3d.f90` sets `tstatic=imode==1` and
  `tdynamic=imode==2`, and stops with `Illegal value for imode` otherwise.
- `mprint` print interval in iterations (static) or time steps (dynamic).
- `mplot` interval for the ASCII contour plots and the `*.tdd` density dumps;
  `0` disables them, which is what you want for a benchmark.
- `mrest` interval for writing the restart file.
- `nof` number of fragments to read through `&fragments`. `0` means a fresh
  static calculation from harmonic-oscillator-like initial wavefunctions; the
  shipped collision deck uses `2`.
- `tcoul` include the Coulomb interaction, `tfft` use FFT derivatives.
- `writeselect` selects which observables are written to the `.res` tables.

## `&grid`

Declared as `nx, ny, nz, dx, dy, dz, periodic`.

`nx, ny, nz` are the numbers of grid points and `dx, dy, dz` the spacings in fm.
If `dy` and `dz` are omitted they default to `dx` (they are pre-set to 0 and
filled in). `periodic=F` is the isolated-nucleus boundary condition. The shipped
static case uses `24^3` at 1.0 fm; the collision uses `48 x 24 x 48` at 1.0 fm,
elongated along the collision axis.

## `&static`

Declared as `tdiag, tlarge, maxiter, radinx, radiny, radinz, serr, x0dmp, e0dmp,
nneut, nprot, npsi, tvaryx_0`.

- `nprot`, `nneut` proton and neutron numbers. Unlike a shell-model code these
  are the FULL numbers, not valence occupations: 16O is `nprot=8, nneut=8`.
- `radinx, radiny, radinz` radii of the initial Gaussian wavefunctions in fm.
- `maxiter` iteration cap, `serr` the convergence criterion. `static.f90`
  compares `sumflu` per particle against `serr`.
- `x0dmp`, `e0dmp` damped-gradient step and energy damping. These control the
  iteration only, not the converged answer, but a bad pair will fail to converge.
- `npsi` number of single-particle states; `0` lets the code choose.

## `&dynamic`

Declared as `nt, dt, mxpact, mrescm, rsep, texternal`.

- `nt` number of time steps, `dt` the step in fm/c. The shipped collision uses
  `nt=1000, dt=0.2`, so 200 fm/c of evolution.
- `rsep` separation in fm at which the calculation stops or the two-body analysis
  triggers.
- `texternal` switches on the `&extern` boost, used for the strength-function
  (GR) mode rather than for a collision.

## `&fragments`

Declared as `filename, fcent, fboost, ecm, b, fix_boost`.

- `filename` an array of wavefunction files, one per fragment. The shipped
  collision deck uses `2*'../Static/O16'`, i.e. the SAME file twice, read by a
  path relative to the working directory. This is the input that the
  distribution does not ship; see `verification.md`.
- `fcent(:,i)` the initial centre of fragment i, in fm.
- `ecm` centre-of-mass energy in MeV and `b` the impact parameter in fm.
- `fix_boost=F` lets the code compute the boosts from `ecm` and `b`.

## A minimal static deck

```
 &files wffile='O16' /
 &force name='SV-bas', pairing='NONE' /
 &main mprint=10,mplot=10,
  mrest=100,writeselect='r',
  imode=1,tfft=T,nof=0 /
 &grid nx=24,ny=24,nz=24,dx=1.0,dy=1.0,dz=1.0,
	periodic=F /
 &static nprot=8, nneut=8,
  radinx=3.1,radiny=3.1,radinz=3.1,
  x0dmp=0.40,e0dmp=100.0,tdiag=T,tlarge=F,
  maxiter=2000,serr=1D-6 /
```

This is the distributed benchmark verbatim (`Test/Static/for005.static`). It
converges 16O in 370 iterations to a total energy of -116.6577 MeV.

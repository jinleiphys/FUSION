---
name: sky3d
description: >-
  Drive Sky3D, the nuclear time-dependent Hartree-Fock code of J.A. Maruhn, P.-G. Reinhard, P.D. Stevenson and A.S. Umar (Comput. Phys. Commun. 185, 2195 (2014); version 1.1 in Comput. Phys. Commun. 229, 211 (2018)). Solve the Skyrme-Hartree-Fock problem on a symmetry-unrestricted three-dimensional cartesian grid in two modes: static, for ground states and constrained states, giving binding energies, single-particle spectra, rms radii and multipole moments; and time-dependent, for heavy-ion collisions (fusion, deep-inelastic, quasi-fission), giant-resonance strength functions from a multipole boost, and any real-time evolution of the mean field. Use for 跑Sky3D, TDHF, 时间相关Hartree-Fock, time-dependent Hartree-Fock, Skyrme mean field, heavy-ion collision dynamics, fusion dynamics, deep inelastic, giant resonance strength function, dissipation, nuclear ground state on a 3D grid, SV-bas, SLy6, for005, for006.
---

# Driving Sky3D

Sky3D solves the Skyrme energy-density-functional mean-field problem on a
three-dimensional cartesian grid with no symmetry restrictions. The static mode
converges a ground state by damped gradient iteration; the dynamic mode
propagates the single-particle wavefunctions in real time, which is what makes it
a heavy-ion collision and giant-resonance code rather than only a structure code.

Fortran 90, optionally OpenMP or MPI, needs FFTW3 and LAPACK/BLAS.

## Prime rules (do not skip)

1. **The input file must be named `for005` and live in the working directory.**
   Sky3D opens that literal filename; it does NOT read standard input, so
   `sky3d.seq < mydeck` fails with `Cannot open file 'for005'`. Use
   `scripts/run_sky3d.sh --deck <file>`, which copies the deck into place.
2. **Every run gets its own directory.** The wavefunction file, all the `.res`
   tables and the `*.tdd` density dumps are opened by fixed name in the current
   directory, so two runs in one directory overwrite each other silently.
3. **Never compare `for006` with `diff`.** A physically identical run differs
   from the reference on about 1900 lines, all of them either the orientation of
   a degenerate single-particle multiplet (an arbitrary basis inside a degenerate
   subspace) or a quantity that is zero by symmetry. Use
   `scripts/compare_sky3d.py`, whose header explains exactly what it excludes and
   why.
4. **This is a TIER 1 skill on the static case, and the collision case is NOT a
   reference benchmark.** `Test/Static` ships input and the authors' output, and
   this skill reproduces it exactly at printed precision. `Test/Collision` ships
   reference `.res` tables whose actual input, the binary O16 wavefunction, is
   NOT distributed, so those tables cannot be reproduced. See
   `references/verification.md`; do not quietly present the collision as a
   benchmark.
5. **A zero exit status does not mean converged.** A static run that exhausts
   `maxiter` exits 0 and prints a full final block. Compare the iteration count
   against `maxiter`.
6. **Sky3D is not open source.** CPC non-profit use licence (see
   `references/failure-modes.md`). Academic use is granted; redistribution is not
   yours to grant, and this skill vendors no Sky3D source.
7. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_sky3d.sh` clones upstream at a pinned commit, locates FFTW,
builds with gfortran, runs a 5-iteration probe that requires a finite bound
energy, and prints three lines:

```
SKY3D=<path to the executable>
SKY3D_ROOT=<repository root>
SKY3D_TESTS=<Test/ directory with the distributed cases>
```

About 16 s from a cold clone (measured: clone, build and probe). It occupies 37 MB, of which 26 MB is git history, so a shallow clone lands nearer 11 MB. Needs `git`, `gfortran`, `python3`, FFTW3, and
LAPACK/BLAS (Accelerate provides it on macOS; on Linux use `-llapack -lopenblas`,
and get FFTW from conda-forge if the box lacks it).

Environment overrides: `SKY3D_ROOT_DIR`, `SKY3D_REPO`, `SKY3D_PIN`,
`SKY3D_MAKE_TARGET` (`seq`, `omp`, `apple`, `apple_omp`, or a `*_debug` variant),
`SKY3D_FFTW_PREFIX`.

## Running a deck

```bash
scripts/run_sky3d.sh --deck mydeck.in --workdir /tmp/run1
```

Prints `RESULT_DIR=` and `RESULT_FOR006=`. It asserts a zero exit, a non-empty
`for006`, no fatal error on stderr, no NaN or numeric-field overflow, a finite
total energy, and at least one printed iteration (static) or time step (dynamic).

A dynamic run needs its fragments staged:

```bash
scripts/run_sky3d.sh --deck collision.in --workdir /tmp/coll \
  --fragment /tmp/run1/O16:../Static/O16
```

The destination is relative to the working directory because the deck's
`filename=` is; absolute paths and `..`-escapes are rejected.

## Verifying

```bash
scripts/verify_sky3d.sh                  # static 16O, about 20 seconds
scripts/verify_sky3d.sh --with-collision # plus the 16O + 16O case, about 45 min
scripts/selftest_sky3d.sh                # harness only, seconds, no build needed
```

## Writing an input

Full field reference, taken from the namelist declarations in the source:
`references/input-format.md`. The shape is always the same:

```
 &files   wffile='O16' /
 &force   name='SV-bas', pairing='NONE' /
 &main    imode=1, mprint=10, mplot=0, nof=0, tfft=T /
 &grid    nx=24,ny=24,nz=24, dx=1.0, periodic=F /
 &static  nprot=8, nneut=8, radinx=3.1,radiny=3.1,radinz=3.1,
          x0dmp=0.40, e0dmp=100.0, maxiter=2000, serr=1D-6 /
```

`imode=1` is static and `imode=2` dynamic; `nof` is the number of fragments read
through `&fragments`. `nprot`/`nneut` are the FULL proton and neutron numbers, not
valence occupations. Set `mplot=0` for a benchmark, or the run writes large
density dumps you do not need.

For a collision, replace `&static` with `&dynamic nt=1000, dt=0.2, rsep=16 /` and
add `&fragments filename=2*'../Static/O16', ecm=100, b=2, fix_boost=F, ... /`,
whose wavefunction files come from a prior static run.

## Reading the output

`references/output-format.md`. In short: `for006` is the log, and the three
blocks worth parsing are the energy functional (`Total:` plus the `tN part`
terms), the single-particle tables (use `Ekin` and `Energy`, never the `Lx`
through `Sz` columns), and the moments table (`Part.Num.`, `rms-radius` and
`<x_i**2>` are determined; `q20` and the centroids are symmetry residues for a
spherical case). The `.res` tables are plain columns, one row per `mprint`.

## Benchmark

16O with SV-bas, no pairing, 24^3 grid at 1.0 fm, converged in 370 iterations:

| quantity | value |
|---|---|
| total binding energy | -116.6577 MeV |
| rms radius (total / n / p) | 2.6884 / 2.6764 / 2.7004 fm |
| lowest neutron s.p. energy | -31.245 MeV |

Reproduces the distributed `Test/Static/for006.static` exactly at printed
precision: 266 energy-functional values, 2432 single-particle values and 570
determined moments, on both macOS ARM (gfortran 15.2) and Linux x86-64
(gfortran 13.3), same 370 iterations. Details and the collision caveat:
`references/verification.md`.

## Failure modes

`references/failure-modes.md`, ten of them, starting with the `for005` filename
trap and ending with the licence.

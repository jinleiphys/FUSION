# Sky3D failure modes

Ordered by how much time each one costs before you work out what happened.

## 1. The input file must be called `for005`

`main3d.f90` does `OPEN(unit=05,file='for005',status='old',form='formatted')`.
Sky3D does not read standard input, so the natural

```
sky3d.seq < mydeck > mylog          # WRONG
```

dies with

```
At line 81 of file main3d.f90 (unit = 5)
Fortran runtime error: Cannot open file 'for005': No such file or directory
```

Copy the deck to `for005` in the run directory instead. `run_sky3d.sh` does this
for you, which is the main reason to use it.

## 2. Everything is written into the current directory

`for006` is stdout, but the wavefunction file, all the `.res` tables and the
`*.tdd` density dumps are opened by fixed name in the cwd. Two runs in the same
directory silently overwrite each other's `.res` files, and a second run started
before the first finished will interleave. Always give a run its own directory.

## 3. A collision deck reads a wavefunction file by a RELATIVE path

The shipped collision deck contains `filename=2*'../Static/O16'`, which resolves
against the working directory, not against the deck's location. Run it in the
wrong directory and it fails to find the fragment. Note also that this file is a
real input that must be produced by a prior static run; see `verification.md` for
why that makes the collision reference non-reproducible.

## 4. Stale `.mod` files break a rebuild with an unrelated message

The Makefile writes module files next to the sources. Rebuilding after a
compiler upgrade then fails with

```
Fatal Error: Cannot read module file 'params.mod' ... created by a different version of GNU Fortran
```

which names neither the cause nor the fix. Delete `Code/*.mod` and `Code/*.o`
first; `install_sky3d.sh` does this on every build.

## 5. The Makefile's macOS target hardcodes a Homebrew path

The `apple` target links `-lfftw3 -framework Accelerate -L/opt/homebrew/lib`.
That path is right only for Apple-Silicon Homebrew; on an Intel Mac it is
`/usr/local/lib`, and on Linux none of it applies. `install_sky3d.sh` locates
FFTW through `pkg-config`, then `brew --prefix fftw`, then a short list of common
prefixes, and passes the result in as `LIBS_SKY`.

On Linux the `seq` target wants `-lfftw3 -llapack -lopenblas`, and FFTW is the
one piece a bare machine usually lacks. conda-forge supplies it without root:
`conda create -n sky3d -c conda-forge fftw`. Do not substitute `-llapack` for
`-framework Accelerate` on macOS: a Homebrew LAPACK will not be found without its
own `-L`, the same trap the KSHELL skill documents.

## 6. `-ffast-math` is on in every shipped optimized target

`seq`, `omp` and `apple` all compile with `-O3 -ffast-math -finline-functions
-funroll-loops`. That permits reassociation and flushes some special-value
handling, so in principle results can depend on the compiler and architecture.
In practice the static benchmark reproduces exactly across gfortran 15.2 on
Apple Silicon and gfortran 13.3 on x86-64 (see `verification.md`), but if you
ever chase a last-digit difference, this flag is the first suspect, and the
`debug` target (`-g -fbacktrace`, no fast-math) is the control.

## 7. Do not compare `for006` with `diff`

A plain `diff` of a physically identical run against the distributed reference
reports about 1900 differing lines. Every one of them is either the orientation
of a degenerate single-particle multiplet or a quantity that is zero by symmetry.
Use `scripts/compare_sky3d.py`, and read its header before loosening any
tolerance in it.

## 8. Convergence is not guaranteed by a zero exit status

A static run that hits `maxiter` without reaching `serr` still exits 0 and still
prints a full final block. Check the iteration count against `maxiter`: if they
are equal, the run did not converge, and its energies are whatever the damped
gradient happened to reach. The shipped 16O case converges in 370 of a permitted
2000 iterations.

## 9. The build produces differently named executables

`seq`, `debug`, `seq_debug` and `apple` produce `sky3d.seq`; `omp`, `omp_debug`
and `apple_omp` produce `sky3d.omp`; the MPI targets produce `sky3d.mpi`. A
script that hardcodes one name breaks when someone builds another target.
`install_sky3d.sh` derives the name from the target it was asked for.

## 10. Licensing

Sky3D is NOT open source. There is no LICENSE file, no copyright header in the
sources, and the CPC program summary in `Paper/v1.0/Sky3D.tex` reads
`Licensing provisions: none`, whose template comment is "enter 'none' if CPC
non-profit use license is sufficient". So the code is under the CPC non-profit
use licence: academic and non-profit use is granted, commercial use is not, and
redistribution is not yours to grant. This skill clones from the public upstream
and vendors no Sky3D source. If you want it for commercial work, contact the
authors.

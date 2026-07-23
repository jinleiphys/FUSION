# Sky3D cross-platform evidence manifest

The claims in `verification.md` about the Linux build were measured on another
machine, so this file records what was run and what came back, in enough detail
for someone else to repeat it. Measured 2026-07-23.

## Commands

macOS (Apple Silicon):

```
git clone https://github.com/manybody/sky3d && git checkout be42efc7fba93aeb3a18ed0b5155b5f6bc9c6c1b
cd Code && make apple LIBS_SKY="-L<fftw>/lib -lfftw3 -framework Accelerate"
mkdir w && cp Test/Static/for005.static w/for005 && (cd w && ../Code/sky3d.seq > for006)
python3 scripts/compare_sky3d.py w/for006 Test/Static/for006.static
```

Linux (heliumx, x86-64):

```
cd Code && make seq LIBS_SKY="-L$CONDA/lib -Wl,-rpath,$CONDA/lib -lfftw3 -llapack -lopenblas"
# same run and comparison
```

FFTW on heliumx came from `conda create -n sky3d -c conda-forge fftw`; the box
has LAPACK and OpenBLAS from the distribution.

## Toolchains

| | macOS | Linux |
|---|---|---|
| compiler | `GNU Fortran (Homebrew GCC 15.2.0) 15.2.0` | `GNU Fortran (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0` |
| kernel / arch | Darwin, arm64 | Linux, x86_64 |
| make target | `apple` | `seq` |

## Static case

Both platforms: 370 `Static Iteration No` lines, matching the reference's 370.
`compare_sky3d.py` against `Test/Static/for006.static` on each platform:

```
  energy functional ... : 266 values, EXACT at printed precision
  single-particle ...   : 2432 values, EXACT at printed precision
  moments ...           : 570 values, EXACT at printed precision
  q20: NOT compared, both runs are spherical to 5.25e-05 of N*rms^2
COMPARE OK
```

macOS against Linux directly: the same three lines, `COMPARE OK`.

Raw `diff` of the two platforms' `for006` gives 1840 differing lines, classified
as 1208 single-particle rows (the `Lx`..`Sz` and residual columns), 228 moment
rows (q20 and the centroids only), 76 plot-axis signed zeros, 10 `de/e`
residual lines, and **0 energy-functional lines**.

The two `O16` wavefunction files are not byte-identical
(`8bd272e0e788e0624dc29cb38d471f1d` on macOS, `52312c4f700907eaeb5ce7d744e56fdd`
on Linux, both 7,079,660 bytes), first differing at byte 69.

## Collision case

Both platforms ran the shipped `Test/Collision/for005.coll` from their OWN
static `O16`, and both terminated during step 943 through the separation
criterion with a scattering angle of 18.702 degrees.

| output | macOS vs Linux |
|---|---|
| `energies.res` | `diff` reports no difference |
| `dipoles.res`, `momenta.res`, `spin.res` | `diff` reports no difference |
| `quadrupoles.res` | worst relative 1.791e-10 (0.001267136523779 vs 0.001267136523552) |
| `monopoles.res` | worst relative 1.458e-13 (0.583422532897771 vs 0.583422532897686) |
| `for006` | 13890 numbers each; 5187 differ, all in per-orbital columns, worst being a parity sign 1.0 vs -1.0 |

Against the shipped reference, both platforms give E(sum) = -133.3082692 MeV at
t = 0 where the reference has -133.3074922 MeV.

## Reproducing this

`scripts/verify_sky3d.sh` runs the static comparison on whatever machine it is
called from. To repeat the cross-platform half, run it on a second machine and
compare the two `for006` files with `scripts/compare_sky3d.py`.

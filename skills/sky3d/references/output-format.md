# Sky3D output

A Sky3D run writes into the CURRENT DIRECTORY, so give every run its own
(`run_sky3d.sh` does this). Nothing is written to the path of the input file.

## Files produced

| file | written when | content |
|---|---|---|
| `for006` | always (it is stdout) | the human-readable log: echo of the input, per-iteration or per-step energies, single-particle tables, moments, ASCII contour plots |
| `<wffile>` | static, and at `mrest` intervals | binary wavefunction / restart file, named by `&files wffile`. **This is a real output**, and it is the input a later collision run reads as a fragment |
| `conver.res` | static | convergence series (this is the static run's energy table, not `energies.res`) |
| `energies.res` | **dynamic only** | time series of the energies |
| `dipoles.res`, `spin.res` | both modes | dipole and angular-momentum series |
| `monopoles.res`, `quadrupoles.res`, `octupoles.res`, `hexadecapoles.res`, `diatriacontapoles.res` | dynamic | multipole moment series |
| `momenta.res` | dynamic | momentum series |
| `NNNNNN.tdd` | **both modes**, every `mplot` iterations or steps | binary density snapshot; large, and disabled by `mplot=0`. `writeselect` chooses which fields go inside these |
| `Restart` | dynamic with `mrest` | restart file |

Verified rather than assumed: the static 16O benchmark directory contains
`conver.res`, `dipoles.res`, `spin.res`, the wavefunction `O16`, and 38 `.tdd`
files, and NO `energies.res`.

`for006` is the process's standard output, so it exists only because the caller
redirects it. If you run Sky3D without redirecting, the log goes to the terminal
and the `.res` files are still written.

## Reading `for006`

Three blocks matter for verification. They are what `scripts/compare_sky3d.py`
parses.

**Energy functional**, printed every `mprint`:

```
 Energies integrated from density functional:
 Total: -1.166577E+02 MeV. t0 part: -9.761758E+02 MeV. t1 part:  1.268929E+01 MeV. t2 part:  4.347195E+01 MeV
                           t3 part:  5.560523E+02 MeV. t4 part: -7.476126E-01 MeV. Coulomb:  1.354168E+01 MeV.
```

`Total` is the binding energy. The `tN part` terms are the Skyrme functional
contributions and `Coulomb` the electrostatic energy. These are the most
reproducible numbers Sky3D prints.

**Single-particle tables**, one for neutrons and one for protons:

```
  #  Par   v**2   var_h1   var_h2    Norm     Ekin    Energy     Lx      Ly      Lz     Sx     Sy     Sz
   1  1. 1.00000  0.00000  0.00000 1.000000  10.141   -31.245   0.000   0.000  -0.000 -0.000  0.000  0.500
```

`Par` is parity, `v**2` the occupation, `var_h1`/`var_h2` per-state convergence
residuals, `Ekin` and `Energy` the kinetic and single-particle energies in MeV,
then the orbital and spin expectation values.

**Do not compare `Lx` through `Sz` between runs.** For a spherical nucleus the
levels form degenerate multiplets, and any unitary mixing inside a degenerate
subspace is an equally valid eigenbasis, so those six columns are arbitrary. They
differ between two runs of the same binary on different machines, and they differ
from the distributed reference, while every energy in the same table agrees
exactly. `var_h1`/`var_h2` are likewise noise-dominated near convergence.

**Moments table**, printed with each energy block:

```
              Part.Num.   rms-radius   q20         <x**2>      <y**2>      <z**2>        <x>            <y>            <z>
    Total:      16.0000      2.6884  1.4983E-09  2.4092E+00  2.4092E+00  2.4092E+00 -3.1657359E-16 ...
```

`Part.Num.`, `rms-radius` and the three `<x_i**2>` are determined observables.
`q20` and `<x>`, `<y>`, `<z>` are zero by symmetry for a spherical nucleus and
print as numerical residue (`q20` reaches about 1e-9 at convergence after passing
through 1e-3 to 1e-2 in the transient, the centroids stay around 1e-16 to 1e-11);
their run-to-run relative difference is order unity and means nothing.
For a genuinely deformed case `q20` IS an observable, which is why the comparator
decides adaptively from `|q20| / (N * rms^2)` rather than always excluding it.

## Reading the `.res` tables

Plain columns with a `#` header line, one row per `mprint` interval. For a
collision, `energies.res` is:

```
#    Time    N(n)    N(p)       E(sum)        E(integ)      Ekin       Ecoll(n)     Ecoll(p)
      0.00  16.000  16.000   -133.3082692   -133.3342577   560.04       45.434       45.421
```

`E(sum)` and `E(integ)` are the same total energy computed two ways, from the sum
of single-particle energies and by integrating the functional. Their agreement is
a running accuracy diagnostic: they drift apart when the time step is too large
or the grid too coarse. `N(n)` and `N(p)` should stay at the initial particle
numbers, and their drift measures how much density has left the box.

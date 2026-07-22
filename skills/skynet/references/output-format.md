# SkyNet output

SkyNet produces two kinds of output: an HDF5 history file (the full time
evolution, written by a driver's `Evolve` call) and, for the shipped test
drivers, printed abundance/observable tables on stdout that self-compare against
a reference. The skill parses the printed tables; the HDF5 file is for a user's
own analysis.

## Printed test output (what `run_skynet.sh` parses)

Each network test prints comment-prefixed rows. Abundance rows are:

```
#  ni56: 1.7794E-02 7.9857E-07
```

that is `# <nuclide>: <value> <error>`, where `<value>` is a mass fraction (or a
molar abundance Y, depending on the test) and `<error>` is the fractional or
absolute deviation from that test's reference. Equilibrium tests also print a
summary line:

```
max error = 0.000777272
```

`run_skynet.sh` reads the `<value>` of each abundance row and every
`max error = <x>`, requires at least one finite result, and rejects any
non-finite value (a `nan`/`inf` token is caught, not silently skipped).
`verify_skynet.sh` pins specific values (X(ni56), the NSE block errors).

Interpreting the columns per benchmark case is in `verification.md`
(AlphaNetwork X(ni56); the three NSE blocks).

## HDF5 history (a driver's own output)

A driver that calls `net.Evolve(...)` or `EvolveSelfHeating...` with a basename
`"my_run"` writes `my_run.h5`, the full network history. Convert it to plain-text
columns with:

```python
NetworkOutput.MakeDatFile("my_run.h5")     # writes my_run.dat-style text tables
```

The HDF5 file holds, as a function of time: temperature, density, entropy,
electron fraction Ye, the energy generation rate, and the molar abundance Y of
every nuclide in the network. The final composition is available directly:

```python
YvsA = np.array(output.FinalYVsA())   # final molar abundance summed by mass number A
A    = np.arange(len(YvsA))
np.savetxt("final_y", np.array([A, YvsA]).T, "%6i  %30.20E")
```

`output.FinalYVsA()` (abundance vs A) and `output.FinalYVsZ()` (vs Z) are the
usual reduced observables; the abundance pattern Y(A) is the standard r-process /
nucleosynthesis result to plot.

## Units and conventions

- **Molar abundance** Y_i = X_i / A_i (mass fraction over mass number); sum of
  A_i Y_i is the total mass fraction, conserved to `MassDeviationThreshold`.
- Temperature in GK (10^9 K), density in g/cm^3, entropy in k_B per baryon, time
  in seconds, energy generation in erg/g/s.
- NSE results are molar abundances at equilibrium for the given (T, rho, Ye).

## Movies

The distribution can render abundance-chart movies (see `README_make_movie`),
which needs Cairo/FreeType. That path is OFF in this build (`-DENABLE_MOVIE=OFF`)
and is not part of the skill; plot `FinalYVsA()` or the `.h5` history instead.

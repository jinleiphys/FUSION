# GSM deck format

All GSM codes read the deck on **stdin** and write everything to **stdout**:

```
run_res < deck.in > deck.out
```

The format is free-form and positional: one item per line, blank lines act as
block separators and are load-bearing, and the trailing parenthetical on each
line is a label for the reader, not something the code parses. Delete or add a
line and every subsequent read shifts silently. Always start from a working deck.

The authoritative parameter list is `GSM_manual.pdf` at the repository root. The
book exercise `README` files say what each deck is *for*, which is usually what
you actually need.

## Pole search (`res` target)

`examples/Exercise_XV_A_neutron_narrow_resonance.in`, a 0d3/2 neutron resonance
in a Woods-Saxon well:

```
 1  WS-analytic                      potential type: WS-analytic | WS | PTG
 2  neutron                          particle: neutron | proton
 3  80 points(Gauss.Legendre)        radial mesh, Gauss-Legendre points
 4  500 points(uniform)              radial mesh, uniform points
 5  20 fm(rotation.point)            complex-scaling: where the contour leaves the real axis
 6  100 fm(real.maximal.radius)      outer radius
 7
 8  0d3/2                            partial wave to search
 9
10  0.65 fm(diffuseness)             Woods-Saxon a
11  63 MeV(Vo)                       depth
12  7.5 MeV(Vso)                     spin-orbit strength
13  3 fm(R0)                         radius
14
15  12 (A)                           mass number of the target
16  target.recoil.neglected(no)      include recoil
17  12 amu(mass)                     target mass
18  1 amu(particle.mass)             particle mass
19
20  E.search                         problem type: E.search | plot | fit | phase.shifts
21  starting.energy(no)              supply an initial guess, or let the code choose
```

For a proton the deck gains target charge and charge-radius lines after the
particle line. Problem types other than `E.search` change what follows line 20,
so copy from the matching exercise.

## One-body Berggren diagonalization (`one` target)

`examples/Exercise_XIII_1s1I2.in`. Same opening blocks, then the part that makes
it GSM rather than a pole search:

```
proton
10 protons(target)                   charge of the BASIS-generating potential
3.000 fm(charge.radius)

s1/2                                 partial wave
2 pole.state(s)                      how many S-matrix poles enter the basis
0s1/2
1s1/2

(0.25,-0.1) fm^(-1)(k.peak)          Berggren contour, complex turning point
1 fm^(-1)(k.middle)                  contour segment boundaries
4 fm^(-1)(k.max)
20 (N.k.peak)                        points on each of the three segments
20 (N.k.middle)
20 (N.k.max)

52 MeV(Vo.potential.to.diagonalize)  the potential actually diagonalized,
8 protons(target.potential.to.diagonalize)   which may differ from the basis one
```

**The contour is the physics.** `k.peak` must lie below the real axis and enclose
the resonance you want the basis to describe. Chapter 5 Exercise I ships three
decks (`correct_contour`, `contour_too_close`, `contour_too_far`) that exist
precisely to show the failure modes.

The last block letting the diagonalized potential differ from the
basis-generating potential is what makes this a real completeness test rather
than a tautology.

## Many-body GSM (`gsm2`, `gsm1d`, `gsm2d` targets)

`examples/Exercise_II.in`, 18O as a 16O core plus two valence neutrons:

```
 1  1 MPI.processes                  must match how you launch (mpirun -n N)
 2  1 OpenMP.threads
 3
 4  /tmp/workspace/                  WORKSPACE DIRECTORY: must already exist
 5
 6  print.detailed.information(no)
 7  MSGI-COSM                        interaction / model
 8  pivot.from.file(no)
 9
10  basis.potential(Berggren.basis)  Berggren.basis | HO | MSDHF
11  WS-analytic
12
13  OBMEs.interaction.read(no)       read precomputed one-body matrix elements
14  no.TBMEs.read                    read precomputed two-body matrix elements
15
16  16 amu(frozen.core.mass)
17  16 (A.core)
18  8 (Z.core)
19
20  neutrons (basis.space)
21  neutrons (space)
22
23  2 neutron(s)[basis]              valence particles in the basis
24  2 neutron(s)                     valence particles in the diagonalization
...
30  15 fm(rotation-point)            contour and mesh, as above but split
31  50 fm(real.maximal.radius)       before/after the rotation point
32  80 points.before.R(Gauss.Legendre)
...
48  6 neutron.pole.state(s)
50  0s1/2 HO.state(core.frozen)      occupied core orbits, frozen
51  0p3/2 HO.state(core.frozen)
52  0p1/2 HO.state(core.frozen)
54  0d5/2 S.matrix.pole    1 hw(truncation.energy)    valence orbits, with
55  1s1/2 S.matrix.pole    1 hw(truncation.energy)    per-orbit truncation
56  0d3/2 S.matrix.pole    1 hw(truncation.energy)
60  0 neutron.scattering.like.partial.wave(s)
```

Later blocks select the J-pi values to diagonalize, how many eigenstates per
J-pi, and which observables (densities, electromagnetic transitions,
spectroscopic factors) to compute.

**Line 4 must be an existing directory** holding whatever interaction files the
deck reads (`USDB.int`, `sd.int`, the `v2body_*` tables, all from
`workspace_for_GSM/`). The shipped decks hardcode `/tmp/workspace/`. If it is
missing the run prints

```
MPI process:0 /tmp/workspace// does not exist
```

and calls `MPI_ABORT`, exiting 1. Set `GSM_WORKSPACE` and `run_gsm.sh` prepares
the directory and rewrites line 4 for you.

## Where to find a deck for your problem

The exercise tree is the deck library. Each directory has a `README` naming what
its decks do:

| chapter | topic | target |
|---|---|---|
| 2 | Coulomb wave functions, poles, bound/antibound/resonant states, widths | `res`, numlib test binaries |
| 3 | complex scaling, Berggren basis, one-body diagonalization, PTG potential | `one`, `one-ptg` |
| 4 | two-body in relative coordinates (deuteron, dineutron, diproton), particle-plus-rotor | `gsm2rel`, `rotor` |
| 5 | contour choice, many-body GSM, 6He/6Li/6Be, natural orbitals, truncations | `gsm2`, `gsm1d` |
| 7 | one-body observables, splines, radii | `res`, `one` |
| 9 | GSM-CC reactions, radiative capture | `cc1d` |

Note that Chapter 9 Exercises X and XI in the printed book have superseded
numbers: GSM-2.0 fixed a bug affecting GSM-CC observables and effective charges.
The repository `README.md` gives the corrected values and the replacement text.

# GiBUU job cards

A GiBUU job card is a sequence of **Fortran namelists**, fed to the executable
on standard input:

```bash
./GiBUU.x < myJobCard.job
```

The distribution ships 84 example cards in `testRun/jobCards/`. Start from one
of them rather than from scratch; the namelist set a run needs depends on the
event type and is not documented in one place.

## The minimum every card needs

```fortran
&input
      eventtype       = 2            ! see the table below
      numEnsembles    = -10          ! negative = per-nucleon scaling
      numTimeSteps    = 140
      delta_T         = 0.25         ! fm/c
      num_runs_SameEnergy = 1
      path_To_Input   = '/path/to/buuinput'
      version = 2025
/

&initRandom
      SEED = 20260723                ! PIN THIS, see below
/
```

`path_To_Input` must point at the unpacked `buuinput` database. Every shipped
card carries the authors' own `'~/GiBUU/buuinput'`; `run_gibuu.sh` rewrites it
into the copy it runs and refuses a card that has no such entry.

## The seed

**`Seed = 0` is not "use zero", it is "draw one from the system clock"**, and
that is also what an absent `&initRandom` block does. A run made either way
cannot be compared with anything, including itself. With an explicit non-zero
seed the output is bit-identical between runs and, measured here, between
macOS/ARM and Linux/x86-64. Pin it.

`run_gibuu.sh --seed N` rewrites an existing `SEED=` entry or appends an
`&initRandom` block if the card has none. Verify from the run log (`Seed: N`),
never from the card: a misspelled Fortran namelist is silently ignored, so a
card that looks right can still run with default physics.

## Event types

`eventtype` in `&input` selects the reaction class and therefore which further
namelists are read. **Transcribed from `code/database/EventTypes.f90`**, which
is the authority; an earlier version of this table was inferred from the job
card file names and was right about the low numbers while missing more than half
the list.

| eventtype | name in the source | note |
|---|---|---|
| 0 | `elementary` | elementary interactions; also the do-nothing minimal card |
| 1 | `HeavyIon` | heavy ion collision |
| 2 | `LoPion` | pion induced, low energy |
| 3 | `RealPhoton` | photon induced |
| 4 | `LoLepton` | lepton induced, low energy |
| 5 | `Neutrino` | neutrino induced |
| 12 | `HiPion` | pion induced, high energy |
| 14 | `HiLepton` | lepton induced, high energy |
| 22 | `ExternalSource` | replay an externally supplied particle list |
| 31, 32, 33 | `InABox`, `InABox_pion`, `InABox_delta` | box calculations |
| 41 | `Box` | box |
| 100 | `groundState` | ground-state test |
| 200 | `transportGivenParticle` | propagate one given particle |
| 300 | `hadron` | hadron induced |

The numbering is deliberately sparse, so do not assume an unlisted value is
valid. Neutrino- and lepton-induced reactions (4, 5, 14) are the part of GiBUU's
range that SMASH does not cover at all, and they are why this code is in the
catalog.

## Statistics knobs, and what they cost

| key | meaning |
|---|---|
| `numEnsembles` | parallel ensembles; negative values scale with target mass |
| `num_runs_SameEnergy` | independent repetitions at the same energy |
| `numTimeSteps`, `delta_T` | propagation grid |

Measured on the shipped pion card at 50 MeV: 1 run takes about 19 s, 5 runs
about 72 s. Error columns in the output are sentinel values (`9999.`) until
there is more than one run, so a single-run result carries no uncertainty at
all and must not be quoted as a cross section.

## Overriding a card

GiBUU accepts no command-line overrides for namelist entries. `run_gibuu.sh`
copies the card into the output directory as `jobcard_used.job` and edits the
copy, so a run always records the input it actually used.

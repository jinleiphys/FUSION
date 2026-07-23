---
name: gibuu
description: >-
  Drive GiBUU (Giessen Boltzmann-Uehling-Uhlenbeck), the hadronic transport model of O. Buss et al. (Phys. Rept. 512, 1-124 (2012)), release 2025. Solve the coupled Boltzmann equations for hadrons and resonances across a very wide entrance channel range: heavy-ion collisions, pion-, photon-, electron- and neutrino-induced reactions on nuclei, hadron transport in a box, and replay of external particle lists. Covers intermediate energies and lepton- or neutrino-nucleus reactions that a pure hadronic cascade does not. Use for 跑GiBUU, BUU输运, hadronic transport, 中微子核反应, neutrino-nucleus, pion induced, photon induced, electron scattering off nuclei, heavy-ion transport, final state interactions, FSI, quasi-elastic, particle production, 重离子输运.
---

# Driving GiBUU

GiBUU solves the Boltzmann-Uehling-Uhlenbeck transport equations for hadrons and
their resonances in a nuclear medium. Its distinguishing range is the entrance
channel: the same transport core is driven by heavy ions, pions, photons,
electrons and neutrinos, which makes it the natural tool for final-state
interactions in lepton- and neutrino-nucleus scattering.

Fortran, GNU make. Needs gfortran, perl, libbz2, and GNU find on macOS.

## Prime rules (do not skip)

1. **Pin the seed, and know that zero is not a seed.** GiBUU's `initRandom`
   namelist reads `Seed = 0`, the default, as "draw one from `SYSTEM_CLOCK()`",
   and a card with no `&initRandom` block behaves the same way. Measured: two
   `Seed = 0` runs used 735342345 and 1426869522 and gave different physics.
   With an explicit non-zero seed the output is bit-identical, including across
   macOS/ARM and Linux/x86-64. `run_gibuu.sh` refuses a zero or absent seed
   unless you pass `--allow-random-seed`.
2. **Never verify a setting by reading the job card.** Fortran namelist input is
   not validated, so a misspelled block is silently ignored and the run proceeds
   with defaults and exit status 0. Read back what GiBUU echoed into the run log
   instead.
3. **This is a TIER 2 skill and claims no physics benchmark.** GiBUU ships no
   reference output at all, so "reproduce the distributed numbers" is not
   available. What is established: it builds unpatched on two platforms, runs,
   is bit-reproducible under a pinned seed across both, and is internally
   consistent. Physics correctness is NOT verified here. See
   `references/verification.md`.
4. **A half-built tree cannot be repaired, only re-extracted.** GiBUU generates
   a per-directory Makefile in every source directory; a build that dies partway
   leaves that half-done and every later `make` fails with a misleading
   `No rule to make target 'iterate'`.
5. **On macOS install GNU findutils.** GiBUU's own Makefile asks for `gfind`,
   and `Makefile.SUBlink` calls `find` with no path argument, which BSD find
   rejects. Do not work around it with `make FIND=find`; that gets further and
   then breaks the one call that matters.
6. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_gibuu.sh` downloads, verifies, builds and probes, then prints:

```
GIBUU=<executable>
GIBUU_ROOT=<source tree>
GIBUU_INPUT=<buuinput database>
GIBUU_LIBPATH=<extra library path, or empty>
```

It pins both tarballs by SHA-256 and checks `version.txt`. **That is weaker
provenance than a git pin and the skill says so**: GiBUU is distributed as
hepforge tarballs and anonymous svn was switched off in 2018, so there is no
commit to pin.

First run takes a few minutes plus a 67 MB download. Overrides:
`GIBUU_ROOT_DIR`, `GIBUU_RELEASE`, `GIBUU_SRC_SHA`, `GIBUU_INPUT_SHA`,
`GIBUU_JOBS`, `GIBUU_LIBPATH`, `FC`.

## Running

```bash
scripts/run_gibuu.sh --jobcard "$GIBUU_ROOT/testRun/jobCards/002_Pion.job" \
  --outdir /tmp/run1 --seed 20260723
```

Prints `RESULT_DIR=`. It copies the job card into the output directory as
`jobcard_used.job`, rewrites `path_To_Input` to the real database (every shipped
card carries the authors' own `'~/GiBUU/buuinput'`), applies the seed, then
asserts a zero exit, the `BUU simulation: finished` banner, at least one
non-empty `.dat` file, no NaN or Infinity, and no `ERROR`-severity log line.

GiBUU writes into the **current working directory**, so the wrapper runs it
inside the output directory.

## Verifying

```bash
scripts/verify_gibuu.sh              # three stages, about 2 minutes
scripts/verify_gibuu.sh --stage 1
scripts/selftest_gibuu.sh            # harness only, 37 cases, seconds, no build needed
```

The three stages are determinism in **both** directions (same seed identical,
different seed different, because the second half is what proves the seed is
used at all), a regression against pinned values, and a bookkeeping identity.

A clean run ends in `VERIFY OK (tier 2: no physics benchmark is claimed)`. The
parenthesis is deliberate: this skill never prints a bare tier-1 style verdict.

## Writing a job card

Field reference taken from the source: `references/input-format.md`, including
the `eventtype` table transcribed from `code/database/EventTypes.f90`. The
shape:

```fortran
&input
      eventtype       = 2            ! 2 = LoPion; see the table
      numEnsembles    = -10
      numTimeSteps    = 140
      delta_T         = 0.25
      num_runs_SameEnergy = 1
      path_To_Input   = '/path/to/buuinput'
      version = 2025
/
&initRandom
      SEED = 20260723                ! PIN THIS; 0 means "use the clock"
/
```

Start from one of the 84 cards in `testRun/jobCards/` rather than from scratch:
which further namelists a run needs depends on `eventtype` and is not documented
in one place.

## Reading the output

`references/output-format.md`. Two things to know before quoting any number:

- Most of the output is **not** results. A pion run writes 343,039 numbers of
  which only **1,026** are driven by the Monte Carlo; the rest are potential and
  density lookup tables. The split was measured by re-running with a second
  seed, not assumed.
- In `pionInduced_xSections.dat`, columns 7 and 8 agree **by construction**, not
  as an independent physics check, and column 6 (`absorption_xSection`) comes
  out **negative** at modest statistics because of how it is defined. Neither is
  a defect; both are traps. `scripts/check_gibuu_output.py` is the single
  implementation of the 15-column layout.

## Benchmark

| stage | what | result |
|---|---|---|
| build | macOS/ARM gfortran 15.2, Linux/x86-64 gfortran 13.3 | unpatched on both |
| cross-build | same card and seed, all 8 output files | bit-identical; 1,026 MC-driven numbers |
| determinism | same seed / different seed | identical / differs, both asserted |
| identity | two routes to the total | agree (by construction, see verification.md) |

Evidence, and what each item is and is not worth:
`references/verification.md`.

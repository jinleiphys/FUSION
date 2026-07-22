---
name: sides
description: >-
  Drive SIDES, the nonlocal-optical-potential nucleon-nucleus elastic scattering code of Blanchon, Dupuis, Arellano, Bernard and Morillon (Comput. Phys. Commun. 254, 107340 (2020); GPL, Mendeley Data 10.17632/cmpjgyrngr.1). Solve the integro-differential Schrodinger equation in coordinate space for neutron or proton elastic scattering off a spin-zero target with an arbitrary nonlocal optical potential (Perey-Buck, Tian-Pang-Ma, Koning-Delaroche local, or an external microscopic potential such as chiral N3LO / AV18 folding), with Coulomb and no restriction on nonlocality type or energy: differential cross sections, analyzing power and spin rotation, plus integral cross sections (reaction/elastic/total for a neutron; reaction only for a proton, where Coulomb makes the integrated elastic and total ill-defined). Use for 跑SIDES, SIDES input, nonlocal optical potential, 非局域光学势, nonlocality, elastic scattering, nucleon-nucleus scattering, Perey-Buck, Tian-Pang-Ma, integro-differential Schrodinger, reaction cross section, analyzing power, spin rotation, n+40Ca, p+40Ca, seedless nonlocal solver, alternative to iterative nonlocal (NLAT).
---

# Driving SIDES

SIDES solves the integro-differential Schrodinger equation for nucleon-nucleus
elastic scattering with a nonlocal optical potential, directly in coordinate
space (following Raynal's DWBA method), with no iterative seed. It builds or reads
the potential (Perey-Buck or Tian-Pang-Ma nonlocal, Koning-Delaroche local, or an
external microscopic potential), integrates the radial equation, and outputs the
differential cross sections plus analyzing power and spin rotation for a neutron
or proton projectile including Coulomb, and integral cross sections (reaction,
elastic and total for a neutron; reaction only for a proton).

Upstream: Mendeley Data DOI 10.17632/cmpjgyrngr.1 (CPC Program Library),
Fortran 90 + gfortran, no external libraries. It is the seedless counterpart to
the iterative nonlocal transfer/scattering codes; SIDES is explicitly designed as
the alternative to NLAT's iteration (both are FUSION skills).

## Prime rules (do not skip)

1. **Content is the verdict, never the exit status.** `sides.x` echoes its parsed
   inputs to stdout and writes the answer to `INTEGRAL-CROSS-SECTION-<system>`.
   Success means: a zero exit, a result file, finite positive cross sections
   (reaction/elastic/total for a neutron, reaction only for a proton), and for a
   neutron the optical theorem TOTAL = ELASTIC + REACTION. `run_sides.sh` asserts
   these from the file.
2. **This is a TIER 2 skill.** The distribution ships no reference output, so the
   benchmark is input alignment plus cross-build build-integrity plus the optical
   theorem, not a reproduction of a documented number. Stated honestly in
   `references/verification.md`. The shipped n+40Ca 20 MeV TPM case gives
   (reaction, elastic, total) = (1115.717600, 769.200182, 1884.917782) mb,
   agreeing to ~12 significant figures across gfortran 13.3 and 15.2.
3. **The input is a bare stdin sequence with no keywords.** Each line answers one
   prompt in order; a missing or extra line silently shifts every later answer.
   Start from the shipped `INPUT` and change one field at a time. Field-by-field
   reference: `references/input-format.md`.
4. **`sides.x` runs from and writes to its source directory.** The wrappers run it
   there and locate the freshest `INTEGRAL-CROSS-SECTION-*` (clearing stale ones
   first, since the filename is derived from the case and a leftover file would
   otherwise be read as a fresh result).
5. **The optical-theorem check is neutron-only.** For a proton, Coulomb breaks
   TOTAL = ELASTIC + REACTION, so the wrappers apply it only when line 1 is `0`.
6. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_sides.sh` downloads `SIDES.zip` from Mendeley Data, builds it
with gfortran, runs the shipped example as a probe, and prints two lines:

```
SIDES=<path to sides.x>
SIDES_DIR=<source directory; sides.x reads INPUT and writes output here>
```

About 2 s. Requires `gfortran`, `curl`, `unzip`. The build overrides the shipped
Makefile's `../sides` target (which points outside the package and fails to link
on some layouts) with `make exe=sides.x`; details in
`references/failure-modes.md`.

## Command line

`sides.x` takes no arguments; it reads answers from stdin:

```
./sides.x < INPUT        # pipe a deck
./sides.x                # or answer the prompts interactively
```

## Workflow

```bash
bash scripts/install_sides.sh                # prints SIDES= and SIDES_DIR=
bash scripts/run_sides.sh                    # the shipped n+40Ca 20 MeV TPM case
bash scripts/run_sides.sh /path/to/my_deck   # a custom stdin deck
bash scripts/verify_sides.sh                 # tier-2 benchmark (cross-build pin + optical theorem)
bash scripts/selftest_sides.sh               # test the harness guards (11 cases)
```

## Verified benchmark

**n + 40Ca elastic at 20 MeV, Tian-Pang-Ma nonlocal potential** (shipped `INPUT`):

| check | result |
|---|---|
| L1 reaction / elastic / total | (1115.717600, 769.200182, 1884.917782) mb, ~12 sig figs across gfortran 13.3 (Linux) and 15.2 (macOS) |
| L2 neutron optical theorem | TOTAL = ELASTIC + REACTION to ~3.6e-16 |

Tier 2: no shipped reference number exists to reproduce, so L1 is a cross-build
integrity check (not bit-identical, because the integro-differential iteration
makes the last digits toolchain-dependent) and L2 is a code-internal physics
identity. Upgrade path: feed SIDES and NLAT the same Perey-Buck potential and
compare, the intended seedless-vs-iterative benchmark. Full account:
`references/verification.md`.

## Failure modes

See `references/failure-modes.md`. The ones that bite: the Makefile links to
`../sides` outside the package (overridden to `sides.x`); the stdin deck is
positional so a shifted line silently changes the run; output is in the
integral-cross-section file, not stdout; and the result is not bit-identical
across compiler versions (the regression gate is 1e-9 relative, not bit-for-bit).

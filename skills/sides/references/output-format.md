# SIDES output format

SIDES writes to the current working directory. The executable echoes its parsed
inputs to stdout (useful to confirm the deck was read as intended) and writes the
physics to named files.

## Integral cross sections: `INTEGRAL-CROSS-SECTION-<system>`

The primary numeric output. One header line plus one row per energy:

```
 ###     ENERGY        REACTION            ELASTIC             TOTAL
   20.000000...   1115.7176002621441   769.20018156053038   1884.9177818226751
```

Columns: incident energy (MeV), reaction, elastic and total cross sections (mb),
each printed to ~16 digits. This is the file the wrappers parse. **That four-column
layout is neutron-only.** For a proton, Coulomb makes the elastic and total
integrated cross sections ill-defined (the Rutherford divergence), so SIDES writes
only two columns, energy and reaction; the run wrapper validates a proton file as
energy+reaction and skips the optical-theorem check. For a neutron, TOTAL =
ELASTIC + REACTION (optical theorem) holds exactly.

## Angular distribution: `SIDES-<system>-<E>-<pot>-...`

The differential elastic cross section and spin observables versus scattering
angle, with a commented header block recording the constants, reaction, energies,
masses, Coulomb eta and the grid. Columns are angle and the observables
(differential cross section, analyzing power, spin rotation). Read the header for
the exact column layout of a given run, since it depends on projectile and
potential type.

## Distorted waves: `DW-<system>-...`

The distorted scattering wave functions, for users who need the wave rather than
the observables (e.g. as input to a DWBA matrix element).

## Saved potentials (only if SAVE = 1)

`NLPOTENTIAL-*` and/or `LOCPOTENTIAL-*` hold the generated potential so a later
run can read it back (potential choice 1). The shipped `UNSAVE` script renames
`*-SAVE` copies for that purpose.

## Filename encoding

Output filenames encode the case: `nCa40` = neutron on 40Ca, the energy, the
potential tag (`TPM`, `PB`, `KD`, ...) and grid markers. Because the name is
derived from the input, a run wrapper locates the freshest
`INTEGRAL-CROSS-SECTION-*` after the run rather than assuming a fixed name;
`run_sides.sh` clears stale ones first so a leftover file is never read as a fresh
result.

## What is on stdout

Only the echoed input prompts and a final `SIDES cpu time: N s` line. No cross
sections are printed to stdout, so success must be read from the
integral-cross-section file, not from stdout or the exit status.

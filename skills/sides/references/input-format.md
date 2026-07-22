# SIDES input format

SIDES reads its input as a sequence of answers on stdin, one per prompt. Run
interactively (`./sides.x`) to be prompted, or pipe a deck (`./sides.x < INPUT`).
Most lines carry a single value with a trailing comment, but some read several
fields (the target line reads Symbol, A, Z; the single-energy line reads Elab and
Lmax), so the field count is per-prompt, not one token per line. Documented from
the shipped `INPUT` and the code's echoed prompts, not from memory.

## The deck, line by line (shipped `INPUT`)

```
0            ! PROJECTILE: (0) NEUTRON, (1) PROTON
Ca 40 20     ! TARGET NUCLEUS: Symbol, A, Z
1            ! INCIDENT ENERGY & LMAX: (1) SINGLE ENERGY, (2) FROM 'ENERGIES' FILE
20.00   10   !   -> if (1): Elab[MeV]  Lmax   (one line)
1            ! KINEMATICS: (0) NON-RELATIVISTIC, (1) RELATIVISTIC
2            ! POTENTIAL TYPE: (1) LOCAL, (2) NONLOCAL, (3) LOCAL+NONLOCAL
2            ! POTENTIAL CHOICE (see table below)
0            ! SAVE POTENTIAL TO FILE: (0) OFF, (1) ON
1            ! METHOD: (1) NUMEROV, (2) MODIFIED NUMEROV, (3) GIBBS
2            ! MAXIMUM RADIUS: (1) User Choice, (2) Pre-defined (Rmax=15 fm)
2            ! RADIAL STEP NUMBER: (1) User Choice, (2) Pre-defined (Nmax=150)
2            ! ANGULAR STEP NUMBER: (1) User Choice, (2) Pre-defined (TTMAX=179)
```

Notes on the branches:

- **Energy line 3 == 1** (single energy): the next line is `Elab Lmax`. If it is
  `2`, energies and per-energy Lmax are read from a file named `ENERGIES` in the
  run directory (format: one `Elab Lmax` pair per line; the shipped `ENERGIES`
  holds `30.00 30`).
- **Potential choice (line 7)** depends on the type on line 6:
  - LOCAL (type 1): (1) READ from file, (2) Koning-Delaroche (KD), (3) MR, (4) local custom.
  - NONLOCAL (type 2): (1) READ from `NLPOTENTIAL` file, (2) Tian-Pang-Ma (TPM),
    (3) Perey-Buck (neutron only), (4) nonlocal custom.
  - LOCAL+NONLOCAL (type 3): the sum of a local and a nonlocal choice.
- **SAVE POTENTIAL (line 8) == 1** writes the generated potential to
  `NLPOTENTIAL-*` / `LOCPOTENTIAL-*` files; the shipped `UNSAVE` shell script
  renames `*-SAVE` files so a later run can READ them back (choice 1).
- **User Choice branches (10-12)**: choosing `1` prompts for the numeric value
  (Rmax in fm, Nmax radial steps, TTMAX angular steps) on the following line;
  `2` uses the pre-defined default shown.

## Reading an external potential

Choice (1) under NONLOCAL reads a coordinate-space nonlocal potential from an
`NLPOTENTIAL` file (the format the code writes when SAVE is on, or a folding
potential such as the chiral N3LO / AV18 tables discussed in the paper). Choice
(1) under LOCAL reads a local potential likewise. This is how SIDES is fed a
microscopic potential rather than a built-in phenomenological one.

## Projectile and the optical theorem

The projectile on line 1 controls whether Coulomb is present. For a neutron
(`0`) there is no Coulomb and the integral cross sections obey the optical
theorem TOTAL = ELASTIC + REACTION exactly; `run_sides.sh` and `verify_sides.sh`
check this. For a proton (`1`) Coulomb is included and that identity does not
hold, so the run wrapper applies the optical-theorem check only for neutrons.

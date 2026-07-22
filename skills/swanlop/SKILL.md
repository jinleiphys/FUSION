---
name: swanlop
description: >-
  Drive SWANLOP, the nonlocal-optical-potential nucleon elastic scattering code of H.F. Arellano and G. Blanchon (Comput. Phys. Commun. 259, 107543 (2021); GPL, Mendeley Data 10.17632/89gw9jdfv4.1). Compute scattering waves and elastic observables for a neutron or proton off a spin-zero nucleus (A>=4, up to ~1.1 GeV) with a local or nonlocal optical potential plus long-range Coulomb: differential cross section dsigma/dOmega, dsigma/dt, analyzing power Ay, spin rotation Q, ratio to Rutherford, and the integrated reaction cross section. Potentials are built-in Perey-Buck or Tian-Pang-Ma, a local model, or an external microscopic potential read in coordinate (VRR) or momentum (VKK) space. Use for 跑SWANLOP, SWANLOP input, nonlocal optical potential, 非局域光学势, elastic scattering, nucleon-nucleus scattering, scattering waves, Coulomb, Perey-Buck, Tian-Pang-Ma, differential cross section, analyzing power, spin rotation, reaction cross section, momentum-space optical potential, p+208Pb, sibling of SIDES.
---

# Driving SWANLOP

SWANLOP computes the scattering wave functions and elastic observables for a
nucleon off a spin-zero target with a nonlocal optical potential and Coulomb. It
builds or reads the potential (Perey-Buck or Tian-Pang-Ma built-in, a local model,
or an external coordinate-space VRR / momentum-space VKK table), solves the
scattering problem, and outputs the differential cross section, analyzing power,
spin rotation, ratio to Rutherford, and the integrated reaction cross section,
with an optional chi-square against experimental data.

Upstream: Mendeley Data DOI 10.17632/89gw9jdfv4.1 (CPC Program Library), Fortran +
gfortran, no external libraries. It is the sibling of SIDES from the same group
(both are FUSION skills): SWANLOP works from the scattering-wave side, SIDES from
the integro-differential Schrodinger side.

## Prime rules (do not skip)

1. **Content is the verdict, never the exit status.** `swanlop.x` prints
   `STOP SWANLOP [OK]` and writes `zz.main`, `zz.xaq` (angular observables +
   reaction cross section) and `zz.dsdt` (dsigma/dt). Success means: a zero exit
   and a `zz.xaq` with a finite positive reaction cross section and angular rows.
   `run_swanlop.sh` asserts these from the file, not from the OK string.
2. **This is a TIER 1 skill.** The distribution ships `zz.{main,xaq,dsdt}.REF`
   for the quick-start, and this build reproduces `zz.xaq` and `zz.dsdt`
   line-for-line (`zz.main` too, bar the timestamp). `verify_swanlop.sh` matches
   against those references after stripping the per-run `Date:`/`Time:`/`UTC`
   lines. The reaction cross section is 1.66084 b. See
   `references/verification.md`.
3. **`swanlop.x` reads and writes the current directory.** It needs `fort.1`,
   `NucChart` and any data file in the cwd. The wrappers run it in a scratch copy
   of `runs/` so the shipped tree and its `.REF` files are never overwritten.
4. **The main input `fort.1` is positional.** One labeled value per line in a
   fixed order; a shifted line silently changes the run. Start from the shipped
   `fort.quick-start` (or a `temp0N` template) and change one field at a time.
   Field-by-field reference: `references/input-format.md`.
5. **KPOT selects the potential and its extra files.** KPOT=1/2 are built-in
   (Perey-Buck / Tian-Pang-Ma, no extra file); KPOT=3/4 read an external
   potential from `fort.2` (3 = r-space VRR, 4 = q-space VKK); KPOT=0 needs a local potential in `fort.22`. The
   quick-start is KPOT=2 and needs no potential file.
6. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_swanlop.sh` downloads the 8 MB `swanlop.tar.gz` from Mendeley
Data (NOT the 530 MB potential-table supplement, which the benchmark does not
need), builds it with gfortran, runs the quick-start as a probe, and prints two
lines:

```
SWANLOP=<path to swanlop.x>
SWANLOP_RUNS=<the runs/ directory>
```

About 8 s. Requires `gfortran`, `curl`, `tar`.

## Command line

`swanlop.x` takes no arguments; it reads `fort.1` (and `fort.2`/`fort.22`/
`NucChart`/data files) from the current directory:

```
cp fort.quick-start fort.1
../sources/swanlop.x
```

## Workflow

```bash
bash scripts/install_swanlop.sh                  # prints SWANLOP= and SWANLOP_RUNS=
bash scripts/run_swanlop.sh                      # the shipped quick-start (p+208Pb 30.3 MeV TPM)
bash scripts/run_swanlop.sh /path/to/my_fort.1   # a custom fort.1 deck
bash scripts/verify_swanlop.sh                   # tier-1 benchmark (reproduces zz.*.REF)
bash scripts/selftest_swanlop.sh                 # test the harness guards (10 cases)
```

## Verified benchmark

**p + 208Pb elastic at 30.3 MeV, Tian-Pang-Ma nonlocal potential** (quick-start):

| check | result |
|---|---|
| L1 zz.xaq (dsigma/dOmega, Ay, Q) | IDENTICAL to shipped zz.xaq.REF (193 lines, modulo timestamp) |
| L1 zz.dsdt (dsigma/dt) | IDENTICAL to shipped zz.dsdt.REF (192 lines) |
| L1 zz.main (run summary) | IDENTICAL to shipped zz.main.REF (369 lines, modulo timestamp) |
| L2 reaction cross section | 1.66084 b, matches the shipped reference |

Tier 1: the distribution ships the reference output and this build reproduces it,
on macOS/ARM gfortran 15.2. The `.REF` carry no toolchain metadata, so this is a
reproduction of the shipped reference on this build, not a proven cross-compiler
result; if a future build stops matching, suspect the toolchain and fall back to
the reaction cross section as the physics anchor. Full account:
`references/verification.md`.

## Failure modes

See `references/failure-modes.md`. The ones that bite: the Mendeley dataset has a
530 MB supplement that is NOT the code; `swanlop.x` overwrites the shipped `runs/`
outputs if run there (use a scratch copy); the fort.1 deck is positional; and a
raw diff against the `.REF` always shows the timestamp line, so strip it before
comparing.

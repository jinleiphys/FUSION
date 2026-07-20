---
name: gsm
description: >-
  Drive the Gamow Shell Model codes of N. Michel and M. Ploszajczak (Lecture Notes in Physics 983, Springer 2021; github.com/GSMUTNSR/book_codes). Build, run, and verify GSM input decks for Berggren-basis one-body Gamow states, resonance and antibound-state searches, complex-scaling widths, two-body and many-body GSM eigenstates with continuum coupling, densities, electromagnetic transitions, spectroscopic factors, and GSM-CC reaction channels. Use for 跑GSM, GSM input, Gamow shell model, Berggren basis, Gamow state, 复标度, complex scaling, resonance width, antibound state, open quantum system shell model, 连续态耦合.
---

# Driving the Gamow Shell Model codes

The Gamow Shell Model is the shell model built on the Berggren basis, so bound states, resonances, and the non-resonant scattering continuum are treated on the same footing. Single-particle states carry complex energies, matrix elements are complex-symmetric (not Hermitian), and widths come out of the diagonalization rather than being added afterwards. The package covers one-body Gamow states, two-body and many-body GSM, and the coupled-channel GSM-CC extension for reactions.

Reference: N. Michel and M. Ploszajczak, *Gamow Shell Model: The Unified Theory of Nuclear Structure and Reactions*, Lecture Notes in Physics 983, Springer (2021). Code: `github.com/GSMUTNSR/book_codes`, Academic Free License v3.0. Manual: `GSM_manual.pdf` at the repository root.

## Prime rules (do not skip)

1. **Never report a GSM number you have not verified.** The package ships reference outputs for every book exercise under `Exercises/Chapter_N/Exercise_M/`. Reproduce the relevant one after any build. Verified benchmarks and their agreement are in `references/verification.md`.
2. **The `.out` files in `Exercises/` are reference outputs, never inputs.** Run in a workdir that does not already contain them. `run_gsm.sh` refuses to start if the target `.out` exists, because a crashed run in a directory holding the reference is indistinguishable from a perfect reproduction.
3. **Always check the exit status and stderr.** GSM failures are frequently silent on stdout: a truncated run just stops printing. Exit 139 (SIGSEGV) and MPI_ABORT are the two common ones, both diagnosed under Gotchas.
4. **Compare numerically, not with `diff`.** The shipped references were produced by GSM-1.0 and the current code is GSM-2.0, which changed the print format (`k:(...)` became `k : (...)`). Last-digit rounding also varies by compiler. Use `scripts/compare_gsm.sh`, and state agreement as significant figures.
5. **A real GNU `g++` is required.** Apple clang cannot compile this code (see Gotchas). The install script autodetects and refuses to proceed with clang.
6. **No em-dashes in any prose or comments you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_gsm.sh [targets...]` clones the repository, unpacks it, applies the portability patch, and builds. Requires `git`, `unzip`, `make`, `mpic++` (OpenMPI or MPICH), and a real GNU `g++`. On macOS: `brew install gcc open-mpi`.

The repository ships **zip archives at top level**, not an unpacked tree. The install script unpacks `GSM_code_repository.zip` (sources) and `workspace_for_GSM.zip` (interaction files). `Qbox_interaction.zip` is large and only needed for Qbox-format wave functions, so it is left packed.

Build targets (`install_gsm.sh one res gsm2`, default is those three):

| target | directory | binary | what it does |
|---|---|---|---|
| `one` | `Gamow_one/One_particle_dir` | `run_one` | one-body Berggren-basis diagonalization |
| `one-ptg` | `Gamow_one/One_particle_PTG_dir` | `run_one` | same, Poschl-Teller-Ginocchio potential |
| `res` | `Gamow_one/resonances_dir` | `run_res` | pole search: bound, antibound, resonance; phase shifts |
| `opt` | `Gamow_one/optimization_code_dir` | `run_opt` | one-body potential fitting |
| `rotor` | `CC_rotor_dir` | `CC_rotor_exe` | particle-plus-rotor coupled channels |
| `gsm2` | `GSM_two_dir` | `GSM_two_exe` | two-valence-particle GSM, observables, EM transitions |
| `gsm2rel` | `GSM_two_relative_dir` | `GSM_two_relative_exe` | two-body in relative coordinates (deuteron, dineutron) |
| `gsm1d` | `GSM_dir_1D/GSM_dir` | `GSM_exe` | full many-body GSM, 1D MPI partitioning |
| `gsm2d` | `GSM_dir_2D/GSM_dir` | `GSM_exe` | full many-body GSM, 2D MPI partitioning |
| `cc1d` | `GSM_dir_1D/CC_dir` | `CC_exe` | GSM-CC coupled channels (reactions) |

Env overrides: `GSM_ROOT` (install tree, default `~/.cache/fusion/gsm`), `GSM_CXX`, `GSM_JOBS`.

## Workflow

1. Pick the exercise closest to your problem and read its `README`. The book exercises are the documentation that matters; the manual describes parameters, the READMEs describe intent.
2. Copy the deck, edit numbers. Do not hand-write a deck from scratch: the format is positional and free-form, with blank lines significant as separators, so a shifted line silently misreads everything after it.
3. Run: `scripts/run_gsm.sh <target> <deck.in> <workdir>`. It builds on first use, guards the clean room, and reports stderr and exit status.
4. Verify: `scripts/compare_gsm.sh <reference.out> <workdir/deck.out>`.
5. For a new system with no reference, check the physics before the numbers: pole positions should be near where the potential puts them, widths of bound states must be zero, and the Berggren completeness residual (`Maximal |overlap|oo`) should be small (1e-8 or below in the verified cases).

## Input structure

All GSM codes read the deck **on stdin** and write everything to **stdout**:

```
run_one < deck.in > deck.out
```

Decks are free-format, one item per line, with a trailing parenthetical naming the parameter. Blank lines separate blocks and are load-bearing. Layout of a one-body deck (`examples/Exercise_XIII_1s1I2.in`):

- potential type (`WS-analytic`, `WS`, `PTG`), then diffuseness, depth `Vo`, spin-orbit `Vso`, radius `R0`
- mass number `A`, and whether target recoil is neglected
- **complex-scaling contour**: rotation point (fm) and real maximal radius (fm)
- radial mesh: uniform points, then Gauss-Legendre points
- particle type (`proton` / `neutron`), target charge, charge radius
- partial wave (`s1/2`, `d3/2`, ...) and the list of pole states
- **Berggren contour in momentum space**: `k.peak` (complex, the resonance being enclosed), `k.middle`, `k.max`, and the number of points on each of the three segments
- the potential to diagonalize (depth and charge), which may differ from the basis-generating potential

Many-body decks (`examples/Exercise_II.in`) begin with MPI processes, OpenMP threads, and **a workspace directory path on line 4** which must exist (see Gotchas).

The contour is the physics. `k.peak` must enclose the resonance you want; Chapter 5 Exercise I is built precisely to show what happens when the contour is too close to or too far from the pole.

## Output

Everything goes to stdout in sections: echo of the input, pole basis states (complex `k`, `E`, width `G`, Jost residual), the scattering basis on the contour, Berggren completeness diagnostics, the Hamiltonian dimension, then per-eigenstate results. Many-body runs add densities, electromagnetic transitions, and a final spectrum table:

```
Z:8 N:10   J Pi (index):0+(0)   E:-11.3636534616811 MeV G:-8.13793226533975 keV   E:0 MeV ...
```

The first `E` is absolute (relative to the core), the second is excitation energy relative to the ground state. `G` is the width; for a bound state it is a numerical zero (1e-5 keV or below), and a bound state showing a genuinely nonzero width means the contour or the mesh is wrong.

## Gotchas

- **A real GNU `g++` is mandatory.** Apple clang rejects out-of-line template definitions whose signatures do not match their declarations. Two exist in `numlib/total_diagonalization` and are harmless because they are never instantiated, but clang checks eagerly and refuses. GCC 15 also turned these into errors via `-Wtemplate-body`, so the install script adds `-fpermissive` for GCC 15 and newer.
- **`finite()` infinite recursion (fixed automatically, and the fix is enforced).** `numlib/complex_add.cpp` defines `finite(const complex<double>&)` and calls `finite(x)` on a `double` inside it, expecting the legacy BSD `finite(double)` from `<math.h>`. That function was removed in POSIX 2008 and is absent on macOS, so the `double` converts back to `complex<double>` and the function recurses until it hits the stack guard page. The symptom is **exit 139 with an empty stderr**, crashing right after `Pole basis states`. Linux glibc still exposes `finite`, so the bug does not appear there.

  `install_gsm.sh` rewrites those calls to `std::isfinite` on every run, and because an unapplied patch builds fine and only dies at run time (where it looks like a bad deck), the fix is not allowed to fail quietly:
  - the match tolerates any spacing, so a reformatted upstream line cannot slip past it;
  - after patching it re-checks the file and aborts (exit 6) if the self-call survives;
  - if it can find neither the bug nor the fix, it aborts rather than shipping a binary that might recurse, and tells you to re-check the function;
  - applying the patch **deletes every object file and built binary first**, so a tree that was already compiled before the patch cannot leave a stale recursing binary in place.

  All of that is idempotent: a second run on a patched, built tree does nothing and returns in well under a second.
- **Homebrew GCC vs the macOS SDK.** After an Xcode update, brew GCC's private `fixincludes` copy of `_stdio.h` refers to a `_bounds.h` it cannot find. The install script prepends the live SDK headers (`-I$(xcrun --show-sdk-path)/usr/include`) instead of modifying the brew installation. If you see `fatal error: _bounds.h: No such file or directory`, this is it.
- **Many-body decks need an existing workspace directory.** Line 4 of the deck names it and the shipped decks hardcode `/tmp/workspace/`. If it does not exist the run prints `MPI process:0 <path> does not exist` and calls `MPI_ABORT` (exit 1). Set `GSM_WORKSPACE` and `run_gsm.sh` will create it, populate it from `workspace_for_GSM`, and rewrite line 4. Interaction files (`USDB.int`, `sd.int`, and the `v2body_*` tables) must be in that directory for decks that read them.
- **Blank lines are separators and are significant.** Deleting one shifts every subsequent read.
- **The reference outputs are GSM-1.0, the code is GSM-2.0.** Expect a print-format difference in pole lines (`k:(...)` vs `k : (...)`) and last-digit rounding. That is why rule 4 exists. GSM-2.0 also corrected real bugs, so a few book exercises have genuinely different answers; the repository `README.md` lists them (Chapter 9 Exercises X and XI in particular, whose numbers in the printed book are superseded).
- **MPI is compiled in but a plain run is serial.** The binaries call `MPI_Init` and run fine launched directly. Use `mpirun -n N` only for the `gsm1d` / `gsm2d` many-body targets, and match the `MPI.processes` line at the top of the deck.
- **Some features are explicitly unfinished upstream:** many-body projectiles and the no-core framework in GSM-CC "might run, but results might not be correct", and hypernuclei are untested. Do not build a result on those without an independent check.

## Verified benchmarks

Full detail, commands, and numbers in `references/verification.md`. All three were run in a clean room: fresh clone from the public repository, fresh build, fresh workdir with no reference file present, stderr inspected.

| case | target | what | agreement |
|---|---|---|---|
| Ch. 2 Ex. XV | `res` | neutron 0d3/2 narrow resonance in a Woods-Saxon well, complex-scaling width | 11 significant figures on 35 observables |
| Ch. 3 Ex. XIII | `one` | 1s1/2 proton, diagonalization in a Berggren basis generated by a different potential | 9 significant figures on 562 observables |
| Ch. 5 Ex. II | `gsm2` | 18O = 16O core + 2 valence neutrons: spectrum, densities, EM transitions | 8 significant figures on 2539 observables |

The 18O ground state comes out at E = -11.3636534616779 MeV against the reference -11.3636534616811 MeV, which is 12 significant figures on the headline number.

---
name: talys
description: >-
  Drive TALYS, the nuclear reaction simulation code of A. Koning, S. Hilaire and S. Goriely (Eur. Phys. J. A 59, 131 (2023); github.com/arjankoning1/talys, MIT). Build, run, and verify TALYS decks for neutron-, proton-, deuteron-, alpha- and photon-induced reactions below 200 MeV: optical model, direct reactions, compound nucleus Hauser-Feshbach, pre-equilibrium, fission, level densities, photon strength functions, astrophysical reaction rates, and nuclear data evaluation. Use for 跑TALYS, TALYS input, TALYS keyword, Hauser-Feshbach, 统计模型, preequilibrium, 预平衡, excitation function, 激发函数, nuclear data, TENDL, cross section evaluation, 核数据评价.
---

# Driving TALYS

TALYS simulates nuclear reactions below 200 MeV for target mass 12 and above, combining the optical model, direct reactions, compound-nucleus Hauser-Feshbach with width-fluctuation corrections, pre-equilibrium (exciton model), and fission, on top of structure models for masses, discrete levels, level densities, photon strength functions and fission barriers. Its design point is that every model choice is a keyword, so model sensitivity studies are loops over decks rather than code changes. It is the engine behind the TENDL library.

Reference: A. Koning, S. Hilaire, S. Goriely, *TALYS: modeling of nuclear reactions*, Eur. Phys. J. A **59**, 131 (2023), DOI `10.1140/epja/s10050-023-01034-3`. Manual: *TALYS-2.2 - Simulation of nuclear reactions*, IAEA(NDS)-0255, DOI `10.61092/iaea.jk8k-mm54`, shipped as `talys/doc/talys.pdf` (890 pages). Both citations verified against CrossRef and INSPIRE; see `references/verification.md`. Source: `github.com/arjankoning1/talys`, MIT License.

## Prime rules (do not skip)

1. **Never trust the exit status.** TALYS exits **0 even when it aborts on a fatal error**; the error appears only inside `talys.out`. Always `grep "TALYS-error" talys.out`. A harness that checks `$?` will report a calculation that produced nothing as a success. This is the single most important thing on this page.
2. **Never report a TALYS number you have not verified.** The code ships 61 sample cases with reference output in each `org/` directory. `scripts/verify_talys.sh <case>` reproduces one in a clean room. Benchmarks and their agreement: `references/verification.md`.
3. **Build under `LC_ALL=C`.** The Makefile's source glob is collation-dependent and silently drops 13 files in a UTF-8 locale, giving a link failure that looks like a corrupt source tree. `install_talys.sh` handles this and asserts it worked.
4. **Install at a short path.** TALYS holds paths in a `character(len=132)` buffer; a long install root truncates filenames and fails at run time with `IOSTAT = 2`. Budget is 63 characters for the code directory; `install_talys.sh` refuses to exceed it.
5. **Copy the whole sample directory, not just `talys.inp`.** Several cases ship an auxiliary `energies` file that the deck names; without it TALYS aborts (while still exiting 0, see rule 1).
6. **The manual is the authority on keywords.** It is 890 pages and ships with the code. Do not invent keywords or their semantics; look them up. `references/input-format.md` covers the rules and the common keywords, with section pointers.
7. **No em-dashes in any prose or comments you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_talys.sh` clones, checks the structure database is present, builds under `LC_ALL=C`, and verifies the binary. Requires `git`, `make`, `gfortran`.

- **Disk: about 11 GB.** The nuclear structure database is 8.6 GB and the samples 432 MB. This is unavoidable, TALYS cannot run without the structure database, and a shallow clone does not help because the bulk is in the working tree. This is by far the heaviest FUSION per-code skill.
- Default install root is `~/.cache/fusion/talys` (short, as rule 4 requires). Override with `TALYS_ROOT`, but keep it short. `TALYS_FC` and `TALYS_FFLAGS` override the compiler and flags.
- Build takes about 25 seconds. A typical sample case runs in a few seconds.
- The repo now bundles `structure/` and `samples/`; the separate `structure.tar` and `talys_samples.tar` downloads that older instructions mention are no longer needed.

## Workflow

1. Find the sample case closest to your problem: `scripts/verify_talys.sh` with no argument lists all 61. The names encode the variation (`n-Sn120-omp-KD03`, `n-Nb093-WFC-Moldauer`, `n-Tc099-ld2`, `n-Th232-fis-wkb`, `n-Os187-astro-ng`).
2. Copy its whole `new/` directory and edit the deck. A minimal deck is four mandatory keywords: `projectile`, `element`, `mass`, `energy`.
3. Run: `scripts/run_talys.sh <deck.inp|deck-dir> <workdir>`. It builds on first use, runs, and fails loudly on `TALYS-error` regardless of exit status.
4. Verify against a distributed reference where one exists: `scripts/verify_talys.sh <sample-name>`. For a new system, check the excitation function is smooth and that the reaction cross section approaches the geometric limit at high energy before trusting anything.
5. For a model sensitivity study, loop over decks changing one keyword. That is what TALYS is for, and the sample naming shows the intended axes.

## Input essentials

Full detail in `references/input-format.md`. TALYS reads the deck on **stdin** and writes hundreds of files into the current directory:

```
talys < talys.inp > talys.out
```

Seven rules from the manual (Sec. 3.1): one keyword per line; keyword and value separated by a blank; any order; case-insensitive; a keyword must have a value (omit it to get the default); `#` in column 1 comments a line; and the four keywords `projectile`, `element`, `mass`, `energy` are mandatory.

The `energy` keyword takes four forms and two of them depend on a file: a single number, **the name of a file in the working directory** with one energy per line, a predefined grid (`n0-200.grid`), or a start/end/step triple. The file form is the origin of rule 5.

## Output

`talys.out` is the human-readable report and ends with a success banner. Data files follow a naming scheme (`cross_*.tot` inverse cross sections, `nn.L08`-style exclusive channels by residual level, `*spec*` spectra, `populationE*.out`, `parameters.dat` with `partable y`, `astrorate.*` with `astro y`). Every data file carries a YANDF-0.4 header whose `date:` and `user:` lines vary between runs and must be excluded from any comparison.

## Gotchas

- **Exit status 0 on failure** (rule 1). Grep the output. Also treat a missing success banner as suspect.
- **`LC_ALL=C` at build time** (rule 3). Symptom without it: undefined symbols `_abundance_`, `_adjust_`, `_afold_`, `_aldmatch_`, `_angdis_`, `_astro_` at link.
- **Path length limit** (rule 4). Symptom: `TALYS-error: Error in <path truncated at 132 chars>, IOSTAT = 2`, usually preceded by a flood of `TALYS-warning: Duflo-Zuker mass for ...` meaning the mass tables were unreadable.
- **Missing auxiliary input** (rule 5). Symptom: `TALYS-error: give a single incident energy ... or give a correct name for a pre-defined energy grid`.
- **`TALYS-warning` lines are normal.** Duflo-Zuker fallbacks for exotic nuclei with no tabulated mass are expected. They are only a red flag when they appear for well-measured nuclei, which means the structure database is not being found.
- **Comparing against `org/` needs the date and user lines excluded**, otherwise every file appears to differ. `verify_talys.sh` handles this and additionally falls back to a magnitude-split numeric comparison, because near-zero populations differ by float32 residues (exactly 2^-17) whose relative differences are meaningless.
- **Do not cite the old TALYS-1.0 reference for new work.** The TALYS-1.x series ended at 1.97 in 2023; cite the 2023 EPJA paper. Verified DOIs for all three references are in `references/verification.md`.

## Verified benchmarks

Clean room: fresh clone, fresh build, fresh workdir with no reference present, stderr inspected, output grepped for errors. Full detail in `references/verification.md`.

| sample | physics | result |
|---|---|---|
| `n-Nb093-14MeV-full` | full output set, spectra, angular distributions, DDX | 750/750 files bit-identical |
| `n-Th232-fis-wkb` | fission, WKB barriers | 128/128 bit-identical |
| `n-Os187-astro-ng` | astrophysical (n,gamma) rates | 37/37 bit-identical |
| `p-Mo100-medical` | proton medical isotope production | 74/74 bit-identical |
| `n-Sn120-omp-KD03` | KD optical model over an energy grid | 430/449 bit-identical; of the 19 differing, 1 is `talys.out` (timing) and 18 are data files agreeing to ~6 significant figures on 4633 physical observables, which is the precision of the output format |

Totals: 1419 of 1438 distributed reference files reproduced byte for byte (ignoring the date, user and timing lines); the 19 that differ are all in the one Sn120 case and agree to the last printed digit. The count was independently re-derived in an adversarial review, which corrected an earlier draft figure of 1415.
